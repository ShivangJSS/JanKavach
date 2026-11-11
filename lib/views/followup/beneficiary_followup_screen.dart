import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/followup_model.dart';
import '../../data/repository/followup_repository.dart';
import '../../data/services/storage_service.dart';
import 'record_followup_sheet.dart';

class BeneficiaryFollowupScreen extends StatefulWidget {
  final int beneficiaryId;
  final String? beneficiaryName;

  const BeneficiaryFollowupScreen({
    super.key,
    required this.beneficiaryId,
    this.beneficiaryName,
  });

  @override
  State<BeneficiaryFollowupScreen> createState() => _BeneficiaryFollowupScreenState();
}

class _BeneficiaryFollowupScreenState extends State<BeneficiaryFollowupScreen> {
  static const Color green = Color(0xFF075832);
  static const Color darkGreen = Color(0xFF06452D);
  static const Color background = Color(0xFFF4F7F5);

  final FollowupRepository _repository = FollowupRepository();

  BeneficiaryFollowupProfile? _profile;
  Set<String> _appliedSchemeCodes = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repository.getBeneficiaryFollowup(widget.beneficiaryId);
      final applied = await StorageService.getAppliedSchemeCodes(
        widget.beneficiaryId,
        data.beneficiaryCode,
      );
      if (mounted) {
        setState(() {
          _profile = data;
          _appliedSchemeCodes = applied;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String get _beneficiaryDisplayName {
    if (_profile != null &&
        _profile!.fullName.trim().isNotEmpty &&
        _profile!.fullName.trim() != 'Unnamed Beneficiary') {
      return _profile!.fullName.trim();
    }
    if (widget.beneficiaryName != null &&
        widget.beneficiaryName!.trim().isNotEmpty &&
        widget.beneficiaryName!.trim() != 'Unnamed Beneficiary') {
      return widget.beneficiaryName!.trim();
    }
    return _profile?.fullName ?? 'Unnamed Beneficiary';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          _beneficiaryDisplayName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load follow-up profile',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('common.retry')),
                style: ElevatedButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final activeSchemes = (_profile?.eligibleSchemes ?? [])
        .where((s) => !_appliedSchemeCodes.contains(s.schemeCode))
        .toList();

    if (_profile == null || activeSchemes.isEmpty) {
      final bool hadApplied = _profile != null &&
          _profile!.eligibleSchemes.isNotEmpty &&
          _appliedSchemeCodes.isNotEmpty;

      return RefreshIndicator(
        onRefresh: _loadProfile,
        color: green,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Icon(
              hadApplied ? Icons.task_alt_outlined : Icons.assignment_turned_in_outlined,
              size: 64,
              color: hadApplied ? green : Colors.blueGrey,
            ),
            const SizedBox(height: 16),
            Text(
              hadApplied
                  ? 'All eligible schemes already applied'
                  : 'No eligible schemes under follow-up',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              hadApplied
                  ? 'The beneficiary has already applied for all matched eligible schemes. None require follow-up in this application.'
                  : 'Check eligibility for this beneficiary first to discover and track welfare schemes.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: green,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Beneficiary Header Card
          _buildBeneficiaryHeaderCard(),

          const SizedBox(height: 18),

          Row(
            children: [
              Text(
                context.tr('followup.eligible_for_followup'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16231C),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF7EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.tr('followup.schemes_count', args: {'count': '${activeSchemes.length}'}),
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...activeSchemes.map(_buildSchemeCard),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEDF7EE),
            child: Icon(
              _profile!.gender?.toLowerCase() == 'female'
                  ? Icons.person_2_outlined
                  : Icons.person_outline,
              color: green,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _beneficiaryDisplayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16231C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profile!.beneficiaryCode,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1377CC),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_profile!.age != null) ...[
                      Text(
                        '${_profile!.age} yrs',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF627065)),
                      ),
                      const Text(' · ', style: TextStyle(color: Colors.grey)),
                    ],
                    if (_profile!.villageName != null) ...[
                      Expanded(
                        child: Text(
                          _profile!.villageName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF627065)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeCard(BeneficiaryEligibleSchemeFollowup item) {
    final followup = item.followup;
    final status = followup?.status ?? 'Pending';
    final pendingReason = followup?.pendingReason ?? 'Not applied yet';

    // Status theme colors
    final Color cardBg;
    final Color borderCol;
    final Color statusColor;
    final String statusLabel;

    if (status == 'Complete') {
      cardBg = const Color(0xFFEDF7EE);
      borderCol = const Color(0xFFD2EBD9);
      statusColor = const Color(0xFF168A53);
      statusLabel = 'Complete: Benefit Received';
    } else if (status == 'Applied') {
      cardBg = const Color(0xFFEEF6FF);
      borderCol = const Color(0xFFCCE2FE);
      statusColor = const Color(0xFF1377CC);
      final appNum = followup?.applicationNumber;
      statusLabel = (appNum != null && appNum.trim().isNotEmpty)
          ? 'Applied ($appNum)'
          : 'Applied';
    } else if (pendingReason.toLowerCase().contains('doc')) {
      cardBg = const Color(0xFFFFF4E8);
      borderCol = const Color(0xFFFFE0BE);
      statusColor = const Color(0xFFD9700C);
      statusLabel = 'Pending: Document Issue';
    } else {
      cardBg = const Color(0xFFF9FBF9);
      borderCol = const Color(0xFFE2E8E4);
      statusColor = Colors.blueGrey;
      statusLabel = 'Pending: Not Applied Yet';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Tag & Scheme Code
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  item.schemeCode,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Scheme Name
            Text(
              item.schemeName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF16231C),
                height: 1.3,
              ),
            ),

            if (item.benefitSummary != null && item.benefitSummary!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.benefitSummary!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF627065)),
              ),
            ],

            // Active document issue banner if present
            if (followup?.documentIssueName != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE0BE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD9700C)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Missing/Issue: ${followup!.documentIssueName}'
                        '${followup.documentIssueType != null ? " (${followup.documentIssueType})" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB85900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Next follow-up due date
            if (followup?.nextFollowupDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    'Next Follow-up Due: ${followup!.nextFollowupDate}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF26352E), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8E4)),
            const SizedBox(height: 10),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final updated = await RecordFollowupSheet.show(
                    context,
                    beneficiaryId: _profile!.id,
                    beneficiaryName: _beneficiaryDisplayName,
                    schemeId: item.schemeId,
                    schemeName: item.schemeName,
                    existingFollowup: item.followup,
                    requiredDocuments: item.requiredDocuments,
                  );

                  if (updated == true) {
                    _loadProfile();
                  }
                },
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: Text(
                  status == 'Complete'
                      ? context.tr('followup.update_details')
                      : status == 'Applied'
                          ? context.tr('followup.track_benefit')
                          : context.tr('followup.take_followup'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
