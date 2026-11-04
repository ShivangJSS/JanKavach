import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/local/app_database.dart';
import '../../data/models/dashboard_response.dart';
import '../../data/local/beneficiary_local_dao.dart';
import '../../data/services/beneficiary_sync_service.dart';
import '../../data/services/connectivity_sync_service.dart';
import '../../data/repository/beneficiary_repository.dart';
import '../../data/repository/scheme_repository.dart';
import '../../data/services/api_service.dart';
import '../../data/services/geography_service.dart';
import '../../data/services/storage_service.dart';
import '../beneficiaries_screen/beneficiaries_screen.dart';
import '../schemes_screen/schemes_screen.dart';
import '../settings_screen/settings_screen.dart';
import '../beneficiary_registration/beneficiary_registration_screen.dart';
import '../followup/followup_hub_screen.dart';
import '../../data/models/followup_model.dart';
import '../../data/repository/followup_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSummary _summary = const DashboardSummary();
  bool _isDashboardLoading = true;
  int _offlinePendingCount = 0;
  bool _isSyncingOffline = false;

  Map<String, dynamic>? _userProfile;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialCachedData();
    _loadDashboardData();
  }

  Future<void> _loadInitialCachedData() async {
    await _loadUserProfile();
    await StorageService.ensureUserCacheIsolation();
    final localMetrics = await _computeLocalDashboardMetrics();
    final pendingCount =
        await BeneficiaryLocalDao().getPendingRegistrationsCount();

    if (!mounted) return;

    setState(() {
      _summary = localMetrics;
      _offlinePendingCount = pendingCount;
      _isDashboardLoading = false;
    });
  }

  Future<DashboardSummary> _computeLocalDashboardMetrics() async {
    await StorageService.ensureUserCacheIsolation();
    final cached = await StorageService.getDashboardSummary();
    final followupCached = await StorageService.getFollowupDashboard();

    int totalRegisteredCount = 0;
    int localAppliedCount = 0;
    int localApprovedCount = 0;
    int localFollowupsDue = 0;

    try {
      final db = await AppDatabase.instance.database;
      final currentUserId = await StorageService.getCurrentUserId();

      // 1. Count cached server beneficiaries in SQLite for this user
      final cachedRows = await db.rawQuery(
        'SELECT COUNT(*) as count FROM beneficiary_cache WHERE user_id = ? OR user_id IS NULL',
        currentUserId != null && currentUserId.isNotEmpty ? [currentUserId] : null,
      );
      final serverBeneficiaryCount = Sqflite.firstIntValue(cachedRows) ?? 0;

      // 2. Count local offline registrations for THIS user only (EXCLUDING DRAFTS!)
      int localPendingRegisteredCount = 0;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final localRows = await db.rawQuery(
          "SELECT COUNT(*) as count FROM beneficiary_records WHERE record_state IN ('pending_sync', 'sync_failed') AND (user_id = ? OR user_id IS NULL)",
          [currentUserId],
        );
        localPendingRegisteredCount = Sqflite.firstIntValue(localRows) ?? 0;
      }

      // Base server count: combine registered counts dynamically
      final cachedSummaryRegistered = cached?.beneficiariesRegistered ?? 0;
      final followupRegistered = followupCached?.totalUsersRegistered ?? 0;
      final baseRegistered = [serverBeneficiaryCount, cachedSummaryRegistered, followupRegistered]
          .reduce((a, b) => a > b ? a : b);

      totalRegisteredCount = baseRegistered + localPendingRegisteredCount;

      // 3. Count applications and stages from cached beneficiaries for this user
      final stageRows = await db.rawQuery(
        'SELECT data FROM beneficiary_cache WHERE user_id = ? OR user_id IS NULL',
        currentUserId != null && currentUserId.isNotEmpty ? [currentUserId] : null,
      );
      for (final row in stageRows) {
        try {
          final data = jsonDecode(row['data'] as String);
          if (data is Map) {
            // --- Applications Submitted Calculation ---
            int appliedOnBeneficiary = 0;
            final appCount = (data['application_count'] as num?)?.toInt() ??
                (data['applications_submitted'] as num?)?.toInt() ??
                (data['total_applied'] as num?)?.toInt() ?? 0;
            if (appCount > 0) {
              appliedOnBeneficiary = appCount;
            } else if (data['applications'] is List) {
              appliedOnBeneficiary = (data['applications'] as List).length;
            } else if (data['scheme_applications'] is List) {
              appliedOnBeneficiary = (data['scheme_applications'] as List).length;
            } else {
              final stage = (data['journey_stage'] as num?)?.toInt() ?? 0;
              final status = (data['record_status'] ?? '').toString().toLowerCase();
              if (stage >= 2 || status.contains('appl')) {
                appliedOnBeneficiary = 1;
              }
            }
            localAppliedCount += appliedOnBeneficiary;

            // --- Applications Approved Calculation ---
            // Represents total approved scheme applications count across beneficiaries.
            // Note: NEVER use assessment_status here (which indicates survey completion e.g. "Complete").
            int approvedOnBeneficiary = 0;
            final approvedCount = (data['approved_applications_count'] as num?)?.toInt() ??
                (data['applications_approved'] as num?)?.toInt() ??
                (data['approved_schemes_count'] as num?)?.toInt() ??
                (data['approved_count'] as num?)?.toInt() ?? 0;

            if (approvedCount > 0) {
              approvedOnBeneficiary = approvedCount;
            } else if (data['applications'] is List) {
              for (final app in data['applications'] as List) {
                if (app is Map) {
                  final appStatus = (app['status'] ?? app['application_status'] ?? '').toString().toLowerCase();
                  if (appStatus.contains('approv') || appStatus.contains('sanction') || appStatus == 'complete') {
                    approvedOnBeneficiary++;
                  }
                }
              }
            } else if (data['scheme_applications'] is List) {
              for (final app in data['scheme_applications'] as List) {
                if (app is Map) {
                  final appStatus = (app['status'] ?? app['application_status'] ?? '').toString().toLowerCase();
                  if (appStatus.contains('approv') || appStatus.contains('sanction') || appStatus == 'complete') {
                    approvedOnBeneficiary++;
                  }
                }
              }
            } else {
              final appStatus = (data['application_status'] ?? '').toString().toLowerCase();
              if (appStatus.contains('approv') || appStatus.contains('sanction')) {
                approvedOnBeneficiary = 1;
              }
            }

            localApprovedCount += approvedOnBeneficiary;
          }
        } catch (_) {}
      }

      if (followupCached != null) {
        final dueTotal = followupCached.today +
            followupCached.upcoming +
            followupCached.overdue;
        localFollowupsDue = dueTotal > 0
            ? dueTotal
            : (followupCached.pending > 0 ? followupCached.pending : 0);
      }
    } catch (e) {
      debugPrint('Error computing local dashboard metrics: $e');
    }

    final cachedSummaryApplied = cached?.applicationsSubmitted ?? 0;
    final followupApplied = followupCached?.totalApplied ?? 0;
    final effectiveApplied = [cachedSummaryApplied, followupApplied, localAppliedCount]
        .reduce((a, b) => a > b ? a : b);

    final cachedSummaryApproved = cached?.applicationsApproved ?? 0;
    final followupApproved = followupCached?.complete ?? 0;
    var effectiveApproved = [cachedSummaryApproved, followupApproved, localApprovedCount]
        .reduce((a, b) => a > b ? a : b);

    // Guardrail: Approved applications cannot exceed submitted applications
    if (effectiveApplied == 0) {
      effectiveApproved = 0;
    } else if (effectiveApproved > effectiveApplied) {
      effectiveApproved = effectiveApplied;
    }

    final cachedDue = cached?.followupsDone ?? 0;
    final effectiveDue = [cachedDue, localFollowupsDue]
        .reduce((a, b) => a > b ? a : b);

    return DashboardSummary(
      beneficiariesRegistered: totalRegisteredCount > 0
          ? totalRegisteredCount
          : (cached?.beneficiariesRegistered ?? 0),
      applicationsSubmitted: effectiveApplied,
      applicationsApproved: effectiveApproved,
      followupsDone: effectiveDue,
    );
  }

  Future<void> _loadDashboardData() async {
    try {
      final response = await ApiService().dio.get('/dashboard');

      final responseData =
          Map<String, dynamic>.from(response.data as Map);

      final data =
          Map<String, dynamic>.from(responseData['data'] as Map);

      if (data['user'] is Map) {
        await StorageService.saveUserProfile(
          Map<String, dynamic>.from(data['user'] as Map),
        );
      }

      final summaryJson =
          Map<String, dynamic>.from(data['summary'] as Map);

      var summary = DashboardSummary.fromJson(summaryJson);

      // Fetch dynamic live metrics from Follow-up Module (/followup/dashboard)
      // to keep all 4 cards dynamically updated with live database counts!
      FollowupDashboardData? followupMetrics;
      try {
        followupMetrics = await FollowupRepository().getDashboardMetrics();
      } catch (fe) {
        debugPrint('Followup dashboard metrics sync: $fe');
        followupMetrics = await StorageService.getFollowupDashboard();
      }

      if (followupMetrics != null) {
        final dueTotal = followupMetrics.today +
            followupMetrics.upcoming +
            followupMetrics.overdue;

        final effectiveFollowups = dueTotal > 0
            ? dueTotal
            : (followupMetrics.pending > 0
                ? followupMetrics.pending
                : summary.followupsDone);

        summary = summary.copyWith(
          beneficiariesRegistered: summary.beneficiariesRegistered > 0
              ? summary.beneficiariesRegistered
              : followupMetrics.totalUsersRegistered,
          applicationsSubmitted: followupMetrics.totalApplied > 0
              ? followupMetrics.totalApplied
              : summary.applicationsSubmitted,
          applicationsApproved: followupMetrics.complete > 0
              ? followupMetrics.complete
              : summary.applicationsApproved,
          followupsDone: effectiveFollowups > 0
              ? effectiveFollowups
              : summary.followupsDone,
        );

        await StorageService.saveFollowupDashboard(followupMetrics);
      }

      final pendingCount =
          await BeneficiaryLocalDao().getPendingRegistrationsCount();

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _offlinePendingCount = pendingCount;
        _isDashboardLoading = false;
      });
      await StorageService.saveDashboardSummary(summary);

      // Pre-cache schemes catalog in background for offline eligibility evaluation
      try {
        SchemeRepository().syncAllSchemesOnline();
      } catch (_) {}

      // Pre-cache registered beneficiaries catalog in background for offline use
      try {
        BeneficiaryRepository().getBeneficiaries(page: 1, perPage: 50);
      } catch (_) {}

      // Pre-cache assigned geography in background for offline registration
      try {
        final assignedLoc = await StorageService.getUserAssignedLocation();
        if (assignedLoc?.hasAssignedState == true) {
          final geo = GeographyService();
          await geo.getStates();
          await geo.getDistricts(assignedLoc!.stateId!);
          if (assignedLoc.hasAssignedDistrict) {
            await geo.getBlocks(assignedLoc.districtId!);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Dashboard API error: $e');

      // Offline mode fallback: compute directly from local database and storage for the current user!
      final fallbackSummary = await _computeLocalDashboardMetrics();
      final pendingCount =
          await BeneficiaryLocalDao().getPendingRegistrationsCount();
      if (mounted) {
        setState(() {
          _summary = fallbackSummary;
          _offlinePendingCount = pendingCount;
          _isDashboardLoading = false;
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _isDashboardLoading = false;
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final profile = await StorageService.getUserProfile();

    if (!mounted) return;

    setState(() {
      _userProfile = profile;
      _profileLoading = false;
    });
  }

  String _profileValue(String key) {
    final value = _userProfile?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    return value.toString();
  }

  static const Color green = Color(0xFF075832);
  static const Color darkGreen = Color(0xFF06452D);
  static const Color background = Color(0xFFF4F7F5);
  static const Color textColor = Color(0xFF26352E);
  static const Color muted = Color(0xFF78847E);

  int _selectedTab = 0;
  String _selectedPeriod = 'This Month';
  final GlobalKey<BeneficiariesScreenState> _beneficiariesKey =
      GlobalKey<BeneficiariesScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildHomeContent(),
                  BeneficiariesScreen(key: _beneficiariesKey),
                  const SchemesScreen(),
                  _buildPlaceholder(
                    Icons.grid_view_rounded,
                    'More',
                    'More Jan Kavach features will appear here.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
          ),

          const SizedBox(width: 8),

          const Expanded(
            child: Text(
              'Jan Kavach',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          Container(
            height: 38,
            width: 38,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Image.asset(
              'lib/assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.shield_outlined, color: green, size: 27),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // HOME DASHBOARD
  // --------------------------------------------------

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      color: green,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),

            const SizedBox(height: 14),

            _buildOfflineSyncCard(),

            const SizedBox(height: 16),

            _buildSectionHeading('Overview', trailing: _buildPeriodDropdown()),

            if (_isDashboardLoading &&
                _summary.beneficiariesRegistered == 0) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(
                minHeight: 2,
                color: green,
                backgroundColor: Color(0xFFEDF7EE),
              ),
              const SizedBox(height: 4),
            ] else
              const SizedBox(height: 10),

            // Overview statistics
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _StatCard(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF168A53),
                  iconBackground: Colors.white,
                  cardBackground: const Color(0xFFEDF7EE),
                  borderColor: const Color(0xFFD2EBD9),
                  value: _summary.beneficiariesRegistered.toString(),
                  label: 'Beneficiaries\nregistered',
                  valueColor: const Color(0xFF116B3F),
                ),
                _StatCard(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFFD9700C),
                  iconBackground: Colors.white,
                  cardBackground: const Color(0xFFFFF4E8),
                  borderColor: const Color(0xFFFFE0BE),
                  value: _summary.applicationsSubmitted.toString(),
                  label: 'Applications\nsubmitted',
                  valueColor: const Color(0xFFB85900),
                ),
                _StatCard(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF1377CC),
                  iconBackground: Colors.white,
                  cardBackground: const Color(0xFFEEF6FF),
                  borderColor: const Color(0xFFCCE2FE),
                  value: _summary.applicationsApproved.toString(),
                  label: 'Applications\napproved',
                  valueColor: const Color(0xFF0F60A5),
                ),
                _StatCard(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFFE5434B),
                  iconBackground: Colors.white,
                  cardBackground: const Color(0xFFFFEEEE),
                  borderColor: const Color(0xFFFFD4D6),
                  value: _summary.followupsDone.toString(),
                  label: 'Follow-ups\ndue',
                  valueColor: const Color(0xFFD42E37),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildSectionHeading('Quick Actions'),

            const SizedBox(height: 10),

            _buildActionCard(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: const Color(0xFF168A53),
              iconBackground: Colors.white,
              cardBackground: const Color(0xFFEDF7EE),
              borderColor: const Color(0xFFD2EBD9),
              title: 'Add a Beneficiary',
              subtitle: 'Six-step questionnaire',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BeneficiaryRegistrationScreen(),
                  ),
                ).then((_) {
                  _loadDashboardData();
                  _beneficiariesKey.currentState?.refreshBeneficiaries();
                });
              },
            ),

            _buildActionCard(
              icon: Icons.search_rounded,
              iconColor: const Color(0xFF1377CC),
              iconBackground: Colors.white,
              cardBackground: const Color(0xFFEEF6FF),
              borderColor: const Color(0xFFCCE2FE),
              title: 'Check Eligibility',
              subtitle: 'Find matching schemes',
              onTap: () {
                setState(() => _selectedTab = 1);
              },
            ),

            _buildActionCard(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFFD9700C),
              iconBackground: Colors.white,
              cardBackground: const Color(0xFFFFF4E8),
              borderColor: const Color(0xFFFFE0BE),
              title: 'Record a Follow-up',
              subtitle: 'Track application status',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FollowupHubScreen()),
                ).then((_) => _loadDashboardData());
              },
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PROFILE CARD
  // --------------------------------------------------

  Widget _buildProfileCard() {
    final name = _profileValue('name');
    final userCode = _profileValue('user_code');

    // Use the actual address/location fields returned by your API.
    final addressParts = [
      _profileValue('village'),
      _profileValue('gram_panchayat'),
      _profileValue('block'),
      _profileValue('district'),
      _profileValue('city'),
      _profileValue('state'),
      _profileValue('address'),
    ].where((value) => value.isNotEmpty).toSet().toList();

    final address = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Location not provided';

    final displayName = _profileLoading && name.isEmpty
        ? 'Loading profile...'
        : name.isNotEmpty
        ? name
        : 'User';

    final initials = name.trim().isEmpty
        ? 'U'
        : name.trim().split(RegExp(r'\s+')).length > 1
        ? '${name.trim().split(RegExp(r'\s+')).first[0]}'
              '${name.trim().split(RegExp(r'\s+')).last[0]}'
        : name.trim()[0];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F0E5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D9566),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: muted,
                  ),
                ),
                if (userCode.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    userCode,
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F7E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              initials.toUpperCase(),
              style: const TextStyle(
                color: green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // OFFLINE SYNC BUTTON & CARD
  // --------------------------------------------------

  Future<void> _handleManualSync() async {
    if (_isSyncingOffline) return;

    final isOnline = await ConnectivitySyncService.instance.isConnected();
    if (!isOnline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No internet connection. Please connect to internet to sync offline records.',
          ),
          backgroundColor: Color(0xFFC0392B),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isSyncingOffline = true;
    });

    try {
      final count =
          await BeneficiarySyncService.instance.syncPendingRegistrations();
      final remainingCount =
          await BeneficiaryLocalDao().getPendingRegistrationsCount();

      if (!mounted) return;

      setState(() {
        _offlinePendingCount = remainingCount;
      });

      // Refresh dashboard metrics
      await _loadDashboardData();
      _beneficiariesKey.currentState?.refreshBeneficiaries();

      if (!mounted) return;

      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count beneficiary registration(s) synced to server successfully!',
            ),
            backgroundColor: green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (remainingCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not sync all records. $remainingCount record(s) still pending.',
            ),
            backgroundColor: const Color(0xFFD9700C),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All offline records are already synced.'),
            backgroundColor: green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: const Color(0xFFC0392B),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncingOffline = false;
        });
      }
    }
  }

  Widget _buildOfflineSyncCard() {
    final hasPending = _offlinePendingCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasPending ? const Color(0xFFFFF8E7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPending ? const Color(0xFFFFD59E) : const Color(0xFFE2E8E4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: hasPending ? const Color(0xFFFFEAD0) : const Color(0xFFEDF7EE),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasPending ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
              color: hasPending ? const Color(0xFFD9700C) : green,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Offline Sync',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasPending ? const Color(0xFFD9700C) : const Color(0xFF168A53),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        hasPending
                            ? '$_offlinePendingCount Pending'
                            : 'All Synced',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasPending
                      ? '$_offlinePendingCount registration${_offlinePendingCount > 1 ? 's' : ''} stored locally'
                      : '0 offline records pending sync',
                  style: const TextStyle(
                    fontSize: 11,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: hasPending ? const Color(0xFF075832) : const Color(0xFFEDF7EE),
              foregroundColor: hasPending ? Colors.white : green,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: hasPending
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFFD2EBD9)),
              ),
            ),
            onPressed: _isSyncingOffline ? null : _handleManualSync,
            icon: _isSyncingOffline
                ? SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: hasPending ? Colors.white : green,
                    ),
                  )
                : Icon(
                    Icons.sync_rounded,
                    size: 15,
                    color: hasPending ? Colors.white : green,
                  ),
            label: Text(
              _isSyncingOffline ? 'Syncing...' : 'Sync Now',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: hasPending ? Colors.white : green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // SECTION HEADING AND PERIOD DROPDOWN
  // --------------------------------------------------

  Widget _buildSectionHeading(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  Widget _buildPeriodDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedPeriod,
        isDense: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 17,
          color: muted,
        ),
        style: const TextStyle(color: muted, fontSize: 11),
        items: const [
          DropdownMenuItem(value: 'This Month', child: Text('This Month')),
          DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
          DropdownMenuItem(value: 'This Year', child: Text('This Year')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedPeriod = value);
            _loadDashboardData();
          }
        },
      ),
    );
  }

  // --------------------------------------------------
  // QUICK ACTIONS
  // --------------------------------------------------

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required Color cardBackground,
    required Color borderColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardBackground,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 23),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),

                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // BOTTOM NAVIGATION
  // --------------------------------------------------

  Widget _buildBottomNavigation() {
    const labels = ['Home', 'Beneficiaries', 'Schemes', 'More'];

    const icons = [
      Icons.home_rounded,
      Icons.people_outline_rounded,
      Icons.account_balance_outlined,
      Icons.more_horiz_rounded,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = _selectedTab == index;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    final previousTab = _selectedTab;
                    setState(() => _selectedTab = index);
                    if (index == 0 && previousTab != 0) {
                      _loadDashboardData();
                    }
                    if (index == 1) {
                      _beneficiariesKey.currentState?.refreshBeneficiaries();
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          icons[index],
                          size: 21,
                          color: selected ? Colors.white : muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[index],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? green : muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PLACEHOLDER TABS
  // --------------------------------------------------

  Widget _buildPlaceholder(IconData icon, String title, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F3E8),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: green),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: muted),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => setState(() => _selectedTab = 0),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
              style: OutlinedButton.styleFrom(foregroundColor: green),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFEDF0EE)),
    );
  }
}

// --------------------------------------------------
// STATISTICS CARD
// --------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color cardBackground;
  final Color borderColor;
  final String value;
  final String label;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.cardBackground = Colors.white,
    this.borderColor = const Color(0xFFEDF0EE),
    required this.value,
    required this.label,
    this.valueColor = const Color(0xFF26352E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    color: Color(0xFF78847E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
