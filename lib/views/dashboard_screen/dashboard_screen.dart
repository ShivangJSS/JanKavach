import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
import '../support_screen/support_screen.dart';
import '../beneficiary_registration/beneficiary_registration_screen.dart';
import '../followup/followup_hub_screen.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../../data/models/followup_model.dart';
import '../../data/repository/followup_repository.dart';
import '../../core/localization/app_localizations.dart';

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
    AppNavigationController.activeTab.addListener(_onExternalTabChanged);
    _loadInitialCachedData();
    _loadDashboardData();
  }

  @override
  void dispose() {
    AppNavigationController.activeTab.removeListener(_onExternalTabChanged);
    super.dispose();
  }

  void _onExternalTabChanged() {
    final target = AppNavigationController.activeTab.value;
    if (_selectedTab != target) {
      _switchTab(target);
    }
  }

  void _switchTab(int index) {
    final previousTab = _selectedTab;
    setState(() => _selectedTab = index);
    if (index == 0 && previousTab != 0) {
      _loadDashboardData();
    } else if (previousTab != index) {
      BeneficiaryLocalDao().getPendingRegistrationsCount().then((
        pendingCount,
      ) {
        if (mounted) {
          setState(() => _offlinePendingCount = pendingCount);
        }
      });
    }
    if (index == 1) {
      _beneficiariesKey.currentState?.refreshBeneficiaries();
    }
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
    int localUniqueApprovedBeneficiaries = 0;

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
        'SELECT server_id, beneficiary_code, data FROM beneficiary_cache WHERE user_id = ? OR user_id IS NULL',
        currentUserId != null && currentUserId.isNotEmpty ? [currentUserId] : null,
      );
      final Set<dynamic> uniqueApprovedBeneficiaryKeys = {};
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

            // Unique beneficiary with at least one approved/received scheme
            if (approvedOnBeneficiary > 0) {
              final key = row['server_id'] ?? data['id'] ?? row['beneficiary_code'] ?? data['beneficiary_code'];
              if (key != null) {
                uniqueApprovedBeneficiaryKeys.add(key);
              }
            }
          }
        } catch (_) {}
      }
      localUniqueApprovedBeneficiaries = uniqueApprovedBeneficiaryKeys.length;

      if (followupCached != null) {
        localFollowupsDue = followupCached.pending > 0
            ? followupCached.pending
            : (followupCached.today +
                followupCached.upcoming +
                followupCached.overdue);
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
    final effectiveApproved = [cachedSummaryApproved, followupApproved, localApprovedCount]
        .reduce((a, b) => a > b ? a : b);

    final cachedDue = cached?.followupsDone ?? 0;
    final effectiveDue = localFollowupsDue > 0
        ? localFollowupsDue
        : cachedDue;

    final int cachedUnique = cached?.beneficiariesWithApproved ?? 0;
    final int effectiveUnique = [cachedUnique, localUniqueApprovedBeneficiaries]
        .reduce((a, b) => a > b ? a : b);

    final currentUserId = await StorageService.getCurrentUserId();
    num localCoordAmt = 0;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      localCoordAmt = await StorageService.getCoordinatorTotalAmountDistributed(currentUserId);
    }

    return DashboardSummary(
      beneficiariesRegistered: totalRegisteredCount > 0
          ? totalRegisteredCount
          : (cached?.beneficiariesRegistered ?? 0),
      applicationsSubmitted: effectiveApplied,
      applicationsApproved: effectiveApproved,
      followupsDone: effectiveDue,
      beneficiariesWithApproved: effectiveUnique,
      totalAmountDistributed: localCoordAmt > 0 ? localCoordAmt : (cached?.totalAmountDistributed ?? 0),
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

      if (summary.totalAmountDistributed == 0 && responseData['data'] is Map) {
        final dMap = responseData['data'] as Map;
        num parseAmt(dynamic val) {
          if (val is num) return val;
          if (val != null) {
            final cleaned = val.toString().replaceAll(',', '').replaceAll('\u20B9', '').replaceAll('Rs.', '').trim();
            return num.tryParse(cleaned) ?? 0;
          }
          return 0;
        }
        final topAmt = parseAmt(dMap['total_amount_distributed'] ?? dMap['amount_distributed'] ?? dMap['total_amount']);
        if (topAmt > 0) {
          summary = summary.copyWith(totalAmountDistributed: topAmt);
        }
      }

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
        final unsyncedCount = await StorageService.getUnsyncedPendingExclusionCount();
        if (unsyncedCount > 0) {
          final adjustedPending = (followupMetrics.pending - unsyncedCount).clamp(0, double.infinity).toInt();
          followupMetrics = followupMetrics.copyWith(pending: adjustedPending);
        }

        final effectiveFollowups = followupMetrics.pending > 0
            ? followupMetrics.pending
            : (summary.followupsDone > 0
                ? summary.followupsDone
                : (followupMetrics.today +
                    followupMetrics.upcoming +
                    followupMetrics.overdue));

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

      // Calculate unique beneficiaries who have received scheme benefits and coordinator amounts
      final Set<dynamic> uniqueBeneficiariesSet = {};
      num coordinatorApiAmount = 0;
      final currentUserId = await StorageService.getCurrentUserId();
      try {
        final completedFollowupRegister = await FollowupRepository().getRegister(
          status: 'Complete',
          perPage: 100,
        );
        for (final item in completedFollowupRegister.items) {
          if (item.beneficiaryId > 0) {
            uniqueBeneficiariesSet.add(item.beneficiaryId);
          } else if (item.beneficiaryCode.isNotEmpty) {
            uniqueBeneficiariesSet.add(item.beneficiaryCode);
          }
          if (item.receivedAmount != null && item.receivedAmount! > 0) {
            if (item.coordinatorId == null || item.coordinatorId == currentUserId || currentUserId == null) {
              coordinatorApiAmount += item.receivedAmount!;
            }
          }
        }
      } catch (ce) {
        debugPrint('Completed followups unique check: $ce');
      }

      num localCoordAmt = 0;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        localCoordAmt = await StorageService.getCoordinatorTotalAmountDistributed(currentUserId);
      }
      final effectiveCoordAmount = localCoordAmt > coordinatorApiAmount ? localCoordAmt : coordinatorApiAmount;
      if (effectiveCoordAmount > 0) {
        summary = summary.copyWith(totalAmountDistributed: effectiveCoordAmount);
      }

      // Also incorporate local database unique beneficiaries who have approved schemes
      try {
        final db = await AppDatabase.instance.database;
        final currentUserId = await StorageService.getCurrentUserId();
        final localRows = await db.rawQuery(
          'SELECT server_id, beneficiary_code, data FROM beneficiary_cache WHERE user_id = ? OR user_id IS NULL',
          currentUserId != null && currentUserId.isNotEmpty ? [currentUserId] : null,
        );
        for (final row in localRows) {
          try {
            final d = jsonDecode(row['data'] as String);
            if (d is Map) {
              int approved = (d['approved_applications_count'] as num?)?.toInt() ??
                  (d['applications_approved'] as num?)?.toInt() ??
                  (d['approved_schemes_count'] as num?)?.toInt() ??
                  (d['approved_count'] as num?)?.toInt() ?? 0;
              if (approved > 0) {
                final k = row['server_id'] ?? d['id'] ?? row['beneficiary_code'] ?? d['beneficiary_code'];
                if (k != null) uniqueBeneficiariesSet.add(k);
              } else if (d['applications'] is List) {
                for (final app in d['applications'] as List) {
                  if (app is Map) {
                    final appStatus = (app['status'] ?? app['application_status'] ?? '').toString().toLowerCase();
                    if (appStatus.contains('approv') || appStatus.contains('sanction') || appStatus == 'complete') {
                      final k = row['server_id'] ?? d['id'] ?? row['beneficiary_code'] ?? d['beneficiary_code'];
                      if (k != null) uniqueBeneficiariesSet.add(k);
                      break;
                    }
                  }
                }
              }
            }
          } catch (_) {}
        }
      } catch (_) {}

      var effectiveUniqueBeneficiaries = uniqueBeneficiariesSet.length;
      if (summary.beneficiariesWithApproved > effectiveUniqueBeneficiaries) {
        effectiveUniqueBeneficiaries = summary.beneficiariesWithApproved;
      }
      if (_summary.beneficiariesWithApproved > effectiveUniqueBeneficiaries) {
        effectiveUniqueBeneficiaries = _summary.beneficiariesWithApproved;
      }

      summary = summary.copyWith(
        beneficiariesWithApproved: effectiveUniqueBeneficiaries,
      );

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Scaffold(
          backgroundColor: background,
          body: Column(
            children: [
              _buildHeader(),

              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        _buildHomeContent(),
                        BeneficiariesScreen(key: _beneficiariesKey),
                        const SchemesScreen(),
                        const SupportScreen(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigation(),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: darkGreen,
       // borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Row(
            children: [
              IconButton(
                tooltip: context.tr('profile.app_settings'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  context.tr('common.app_name'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              _buildHeaderSyncButton(),
              const SizedBox(width: 10),

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
        ),
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
            // 2. User Profile Card
            _buildProfileCard(),

            const SizedBox(height: 16),

            // 3. Overview Section (4 ORIGINAL CARDS)
            _buildSectionHeading(
              context.tr('dashboard.overview'),
              trailing: _buildPeriodDropdown(),
            ),

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

            // 4 Original Overview statistics cards in 2-column grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _StatCard(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF0A8754),
                  iconBackground: Colors.white,
                  gradientColors: const [Color(0xFF28D17C), Color(0xFF0B8A54)],
                  glowColor: const Color(0xFF16B85C),
                  borderColor: Colors.white.withValues(alpha: 0.48),
                  value: _summary.beneficiariesRegistered.toString(),
                  label: context.tr('dashboard.registered_beneficiaries'),
                  valueColor: Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.94),
                ),
                _StatCard(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFFE65C00),
                  iconBackground: Colors.white,
                  gradientColors: const [Color(0xFFFFA726), Color(0xFFE65C00)],
                  glowColor: const Color(0xFFF57C00),
                  borderColor: Colors.white.withValues(alpha: 0.48),
                  value: _summary.applicationsSubmitted.toString(),
                  label: context.tr('dashboard.applications_submitted'),
                  valueColor: Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.94),
                ),
                _StatCard(
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF06846C),
                  iconBackground: Colors.white,
                  gradientColors: const [Color(0xFF14CFA8), Color(0xFF06846C)],
                  glowColor: const Color(0xFF0D9488),
                  borderColor: Colors.white.withValues(alpha: 0.48),
                  value: _summary.applicationsApproved.toString(),
                  label: context.tr('dashboard.applications_approved'),
                  valueColor: Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.94),
                ),
                _StatCard(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFFD61F45),
                  iconBackground: Colors.white,
                  gradientColors: const [Color(0xFFFF5E7E), Color(0xFFD61F45)],
                  glowColor: const Color(0xFFF43F5E),
                  borderColor: Colors.white.withValues(alpha: 0.48),
                  value: _summary.followupsDone.toString(),
                  label: context.tr('dashboard.followups'),
                  valueColor: Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.94),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 4. New Total Amount Distributed Card (1 NEW CARD)
            _buildTotalAmountDistributedCard(),

            const SizedBox(height: 20),

            // 5. Quick Actions Section (3 ORIGINAL CARDS)
            _buildSectionHeading(context.tr('dashboard.quick_actions')),

            const SizedBox(height: 10),

            _buildActionCard(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: const Color(0xFF0B8A54),
              iconGradientColors: const [Color(0xFF28D17C), Color(0xFF0B8A54)],
              gradientColors: const [
                Color(0xFFD5FDE4),
                Color(0xFFF5FFF9),
                Color(0xFFC4FBD9),
              ],
              borderColor: const Color(0xFF6CE29D),
              title: context.tr('dashboard.register_beneficiary'),
              subtitle: context.tr('dashboard.register_beneficiary_sub'),
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
              iconColor: const Color(0xFF0B62D6),
              iconGradientColors: const [Color(0xFF33A3FF), Color(0xFF0B62D6)],
              gradientColors: const [
                Color(0xFFD1EBFF),
                Color(0xFFF4FAFF),
                Color(0xFFBEE2FF),
              ],
              borderColor: const Color(0xFF6CB9FF),
              title: context.tr('dashboard.check_eligibility'),
              subtitle: context.tr('dashboard.check_eligibility_sub'),
              onTap: () {
                setState(() => _selectedTab = 1);
              },
            ),

            _buildActionCard(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFFE65C00),
              iconGradientColors: const [Color(0xFFFFA726), Color(0xFFE65C00)],
              gradientColors: const [
                Color(0xFFFFE2BA),
                Color(0xFFFFF8EE),
                Color(0xFFFFD49C),
              ],
              borderColor: const Color(0xFFFFB24D),
              title: context.tr('followup.title'),
              subtitle: context.tr('dashboard.followups'),
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
  // TOTAL AMOUNT DISTRIBUTED CARD
  // --------------------------------------------------

  String _formatIndianCurrency(num amount) {
    if (amount == 0) return '\u20B90';
    if (amount % 1 == 0) {
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '\u20B9',
        decimalDigits: 0,
      ).format(amount);
    }
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '\u20B9',
      decimalDigits: 2,
    ).format(amount);
  }

  Widget _buildTotalAmountDistributedCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF28D17C), Color(0xFF0B8A54)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.48),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16B85C).withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 0.8],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -20,
              right: -15,
              child: IgnorePointer(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.currency_rupee_rounded,
                      color: Color(0xFF0A8754),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount Distributed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatIndianCurrency(_summary.totalAmountDistributed),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Total financial benefits received by beneficiaries.',
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.88),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
        : context.tr('dashboard.location_not_provided');

    final displayName = _profileLoading && name.isEmpty
        ? context.tr('dashboard.loading_profile')
        : name.isNotEmpty
        ? name
        : context.tr('dashboard.user_fallback');

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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF28D17C), Color(0xFF0B8A54)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16B85C).withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD6FCE6), Color(0xFFB8F5D2)],
              ),
              border: Border.all(color: const Color(0xFF6CE29D)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              initials.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF0A7D43),
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
        SnackBar(
          content: Text(context.tr('dashboard.sync_no_internet')),
          backgroundColor: const Color(0xFFC0392B),
          duration: const Duration(seconds: 3),
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
              context.tr(
                'dashboard.sync_success_count',
                args: {'count': '$count'},
              ),
            ),
            backgroundColor: green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (remainingCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'dashboard.sync_partial_remaining',
                args: {'count': '$remainingCount'},
              ),
            ),
            backgroundColor: const Color(0xFFD9700C),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('dashboard.all_synced')),
            backgroundColor: green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('dashboard.sync_failed')}: $e'),
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

  Widget _buildHeaderSyncButton() {
    final hasPending = _offlinePendingCount > 0;
    final badgeText = _offlinePendingCount > 99 ? '99+' : '$_offlinePendingCount';

    return Tooltip(
      message: context.tr(
        'dashboard.sync_pending_tooltip',
        args: {'count': '$_offlinePendingCount'},
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSyncingOffline ? null : _handleManualSync,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 46,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Center(
                    child: _isSyncingOffline
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.sync_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 19,
                      minHeight: 19,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: hasPending
                          ? const Color(0xFFD9700C)
                          : const Color(0xFF168A53),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        items: [
          DropdownMenuItem(
            value: 'This Month',
            child: Text(context.tr('dashboard.this_month')),
          ),
          DropdownMenuItem(
            value: 'Last Month',
            child: Text(context.tr('dashboard.last_month')),
          ),
          DropdownMenuItem(
            value: 'This Year',
            child: Text(context.tr('dashboard.this_year')),
          ),
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
    required List<Color> iconGradientColors,
    required List<Color> gradientColors,
    required Color borderColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.68),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: iconGradientColors,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: iconColor.withValues(alpha: 0.30),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4A5B52),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onTap != null)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: iconColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // BOTTOM NAVIGATION
  // --------------------------------------------------

  Widget _buildBottomNavigation() {
    return AppBottomNavigationBar(
      currentIndex: _selectedTab,
      onTabSelected: (index) {
        _switchTab(index);
        AppNavigationController.activeTab.value = index;
      },
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFF3FBF6)],
      ),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFC5E8D2), width: 1.1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0B8A54).withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
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
  final List<Color> gradientColors;
  final Color glowColor;
  final Color borderColor;
  final String value;
  final String label;
  final Color valueColor;
  final Color labelColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.gradientColors,
    required this.glowColor,
    this.borderColor = const Color(0xFFEDF0EE),
    required this.value,
    required this.label,
    this.valueColor = Colors.white,
    this.labelColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.34),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.34),
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 0.8],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -18,
              right: -14,
              child: IgnorePointer(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: valueColor,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
