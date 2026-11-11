
import 'package:flutter/material.dart';
import 'package:kavach/views/eligible_schemes_screen/scheme_details_screen.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/ beneficiary_model.dart';
import '../../data/models/eligible_scheme_model.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/whatsapp_share_service.dart';
import '../../viewModels/Eligible_Schemes_ViewModel.dart';
import '../followup/beneficiary_followup_screen.dart';

class EligibleSchemesScreen extends StatefulWidget {
  final int beneficiaryId;
  final String beneficiaryName;
  final BeneficiaryModel? beneficiary;
  final Map<String, dynamic>? beneficiaryDetails;

  const EligibleSchemesScreen({
    super.key,
    required this.beneficiaryId,
    required this.beneficiaryName,
    this.beneficiary,
    this.beneficiaryDetails,
  });

  @override
  State<EligibleSchemesScreen> createState() =>
      _EligibleSchemesScreenState();
}

class _EligibleSchemesScreenState
    extends State<EligibleSchemesScreen> {
  static const Color green = Color(0xFF087443);

  late final EligibleSchemesViewModel _viewModel;
  bool _isSurveySubmitted = false;
  final Set<String> _selectedAppliedCodes = {};

  Map<String, dynamic> _getBeneficiaryProfile() {
    final Map<String, dynamic> profile = {};
    if (widget.beneficiary != null) {
      profile.addAll(widget.beneficiary!.toJson());
    }
    if (widget.beneficiaryDetails != null) {
      profile.addAll(widget.beneficiaryDetails!);
    }
    profile['id'] = widget.beneficiaryId;
    profile['name'] = widget.beneficiaryName;
    return profile;
  }

  String? _getBeneficiaryMobile() {
    if (widget.beneficiary?.mobile != null && widget.beneficiary!.mobile!.trim().isNotEmpty) {
      return widget.beneficiary!.mobile;
    }
    final detailsMobile = widget.beneficiaryDetails?['mobile']?.toString();
    if (detailsMobile != null && detailsMobile.trim().isNotEmpty) {
      return detailsMobile;
    }
    final profile = _getBeneficiaryProfile();
    final profileMobile = profile['mobile']?.toString();
    if (profileMobile != null && profileMobile.trim().isNotEmpty) {
      return profileMobile;
    }
    return null;
  }

  String? _getBeneficiaryCode() {
    if (widget.beneficiary?.beneficiaryCode != null && widget.beneficiary!.beneficiaryCode.isNotEmpty) {
      return widget.beneficiary!.beneficiaryCode;
    }
    final detailsCode = widget.beneficiaryDetails?['beneficiary_code']?.toString();
    if (detailsCode != null && detailsCode.isNotEmpty) {
      return detailsCode;
    }
    final profile = _getBeneficiaryProfile();
    return profile['beneficiary_code']?.toString();
  }

  @override
  void initState() {
    super.initState();
    _viewModel = EligibleSchemesViewModel();
    _viewModel.addListener(_onChanged);

    _loadAppliedPreferences();

    // Evaluate eligibility for this beneficiary.
    _viewModel.checkEligibility(
      widget.beneficiaryId,
      beneficiaryProfile: _getBeneficiaryProfile(),
    );
  }

  Future<void> _loadAppliedPreferences() async {
    final codes = await StorageService.getAppliedSchemeCodes(
      widget.beneficiaryId,
      _getBeneficiaryCode(),
    );
    if (mounted) {
      setState(() {
        _selectedAppliedCodes.addAll(codes);
      });
    }
  }

  Widget _buildSchemesContent() {
    final eligible = _viewModel.eligibleSchemes;
    final potential = _viewModel.potentiallyEligibleSchemes;

    if (eligible.isEmpty && potential.isEmpty) {
      return _buildEmptyState();
    }

    if (!_isSurveySubmitted) {
      return _buildSurveyContent(eligible, potential);
    }

    return _buildFilteredSchemesContent();
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: green,
      onRefresh: () => _viewModel.checkEligibility(
        widget.beneficiaryId,
        beneficiaryProfile: _getBeneficiaryProfile(),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.search_off_outlined,
            size: 64,
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No eligible schemes found',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No eligible or potentially eligible schemes '
            'were returned for this beneficiary.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _viewModel.checkEligibility(
                widget.beneficiaryId,
                beneficiaryProfile: _getBeneficiaryProfile(),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Check Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyContent(
    List<EligibleSchemeModel> eligible,
    List<EligibleSchemeModel> potential,
  ) {
    final allSchemes = [...eligible, ...potential];

    return RefreshIndicator(
      color: green,
      onRefresh: () => _viewModel.checkEligibility(
        widget.beneficiaryId,
        beneficiaryProfile: _getBeneficiaryProfile(),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            widget.beneficiaryName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF19392C),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check which schemes have already been applied for',
            style: TextStyle(color: Colors.blueGrey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Question Banner Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF5EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7E4D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  color: green,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('eligibility.survey_question'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF13422C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('eligibility.survey_subtitle'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E5743),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Text(
                context.tr('eligibility.eligible_schemes_header', args: {'count': '${allSchemes.length}'}),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF19392C),
                ),
              ),
              const Spacer(),
              if (_selectedAppliedCodes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCE2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedAppliedCodes.length} marked applied',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF004085),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          ...allSchemes.map((scheme) {
            final isChecked = _selectedAppliedCodes.contains(scheme.schemeCode);
            final isEligible = scheme.eligibilityStatus.toLowerCase() == 'eligible';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: isChecked ? const Color(0xFFF3F8F5) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isChecked ? green : const Color(0xFFE1E8E4),
                  width: isChecked ? 1.5 : 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _selectedAppliedCodes.remove(scheme.schemeCode);
                    } else {
                      _selectedAppliedCodes.add(scheme.schemeCode);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: isChecked,
                        activeColor: green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedAppliedCodes.add(scheme.schemeCode);
                            } else {
                              _selectedAppliedCodes.remove(scheme.schemeCode);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scheme.schemeName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isChecked
                                    ? const Color(0xFF075832)
                                    : const Color(0xFF19392C),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _statusBadge(scheme.eligibilityStatus, isEligible),
                                _smallTag('${scheme.matchPercent}% match'),
                                if (isChecked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4EDDA),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFC3E6CB)),
                                    ),
                                    child: const Text(
                                      'Already Applied',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF155724),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (scheme.themeName != null && scheme.themeName!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Category: ${scheme.themeName}',
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilteredSchemesContent() {
    final eligible = _viewModel.eligibleSchemes
        .where((s) => !_selectedAppliedCodes.contains(s.schemeCode))
        .toList();
    final potential = _viewModel.potentiallyEligibleSchemes
        .where((s) => !_selectedAppliedCodes.contains(s.schemeCode))
        .toList();

    final summary = _viewModel.summary;

    if (eligible.isEmpty && potential.isEmpty) {
      return RefreshIndicator(
        color: green,
        onRefresh: () => _viewModel.checkEligibility(
          widget.beneficiaryId,
          beneficiaryProfile: _getBeneficiaryProfile(),
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E8E4)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: green,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'All Eligible Schemes Already Applied!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF19392C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The beneficiary has already applied for all ${_selectedAppliedCodes.length} matched schemes. '
                    'None require pending follow-up in this application.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isSurveySubmitted = false;
                      });
                    },
                    icon: const Icon(Icons.edit_note_outlined, color: green),
                    label: const Text(
                      'Modify Applied Schemes',
                      style: TextStyle(
                        color: green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: green,
      onRefresh: () => _viewModel.checkEligibility(
        widget.beneficiaryId,
        beneficiaryProfile: _getBeneficiaryProfile(),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.beneficiaryName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF19392C),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Government schemes matched for this beneficiary',
            style: TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 18),

          if (_selectedAppliedCodes.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC7E4D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.done_all_rounded, color: green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_selectedAppliedCodes.length} scheme(s) already applied (excluded from follow-up)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF06452D),
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      setState(() {
                        _isSurveySubmitted = false;
                      });
                    },
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: green,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_viewModel.isShowingCachedData) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE8C76A),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: Color(0xFF996515),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Showing previously saved eligibility results. '
                      'These results may be outdated. Connect to the internet '
                      'to check eligibility again.',
                      style: TextStyle(
                        color: Color(0xFF795313),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          Row(
            children: [
              Expanded(
                child: _buildCountCard(
                  'Evaluated',
                  summary['total_evaluated'] ??
                      (_viewModel.eligibleSchemes.length + _viewModel.potentiallyEligibleSchemes.length),
                  Icons.fact_check_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCountCard(
                  'Eligible',
                  eligible.length,
                  Icons.check_circle_outline,
                ),
              ),
              if (potential.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCountCard(
                    'Potential',
                    potential.length,
                    Icons.pending_actions_outlined,
                    iconColor: const Color(0xFFC78500),
                    textColor: const Color(0xFF996515),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          if (eligible.isNotEmpty) ...[
            _sectionHeading('Eligible Schemes', eligible.length),
            const SizedBox(height: 12),
            ...eligible.map(
              (scheme) => _buildSchemeCard(scheme),
            ),
            const SizedBox(height: 18),
          ],

          if (potential.isNotEmpty) ...[
            _sectionHeading(
              'Potentially Eligible Schemes',
              potential.length,
              isPotential: true,
            ),
            const SizedBox(height: 12),
            ...potential.map(
              (scheme) => _buildSchemeCard(scheme),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildCountCard(
      String label,
      dynamic count,
      IconData icon, {
      Color? iconColor,
      Color? textColor,
      }) {
    final effectiveIconColor = iconColor ?? green;
    final effectiveTextColor = textColor ?? green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: effectiveIconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: effectiveTextColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, int count, {bool isPotential = false}) {
    final bgColor =
        isPotential ? const Color(0xFFFFF4D8) : const Color(0xFFE5F5EA);
    final textColor = isPotential ? const Color(0xFF996515) : green;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF19392C),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchemeCard(EligibleSchemeModel scheme) {
    final isEligible =
        scheme.eligibilityStatus.toLowerCase() == 'eligible';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E8E4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE5F5EA),
                  child: Icon(
                    Icons.account_balance_outlined,
                    color: green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    scheme.schemeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF19392C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusBadge(
                  scheme.eligibilityStatus,
                  isEligible,
                ),
                _smallTag('${scheme.matchPercent}% match'),
              ],
            ),

            if (scheme.themeName != null) ...[
              const SizedBox(height: 12),
              Text(
                'Category: ${scheme.themeName}',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12,
                ),
              ),
            ],

            if (scheme.reasonText != null &&
                scheme.reasonText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                scheme.reasonText!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF52645A),
                ),
              ),
            ],

            if (scheme.missingDocuments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${scheme.missingDocuments.length} document(s) '
                    'to check',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF996515),
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFEDF0EE)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    WhatsAppShareService.shareScheme(
                      context: context,
                      scheme: scheme,
                      beneficiaryName: widget.beneficiaryName,
                      beneficiaryCode: _getBeneficiaryCode(),
                      beneficiaryMobile: _getBeneficiaryMobile(),
                    );
                  },
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 16,
                    color: Color(0xFF1B8749),
                  ),
                  label: const Text(
                    'Share on WhatsApp',
                    style: TextStyle(
                      color: Color(0xFF1B8749),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366)),
                    backgroundColor: const Color(0xFFE8F8EE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SchemeDetailsScreen(
                          scheme: scheme,
                          beneficiaryName: widget.beneficiaryName,
                          beneficiaryCode: _getBeneficiaryCode(),
                          beneficiaryMobile: _getBeneficiaryMobile(),
                        ),
                      ),
                    );
                  },
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String label, bool isEligible) {
    final color = isEligible
        ? green
        : const Color(0xFF996515);

    String displayLabel = label;
    if (label == 'Eligible') {
      displayLabel = context.tr('eligibility.eligible_badge');
    } else if (label == 'Potentially Eligible') {
      displayLabel = context.tr('eligibility.potentially_eligible_badge');
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isEligible
            ? const Color(0xFFE5F5EA)
            : const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _smallTag(String label) {
    String displayLabel = label;
    if (label.contains('% match')) {
      final percentVal = label.replaceAll('% match', '').trim();
      displayLabel = context.tr('eligibility.match_percentage', args: {'percent': percentVal});
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayLabel,
        style: const TextStyle(
          color: Color(0xFF2457A7),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }



  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSchemes = _viewModel.result != null &&
        (_viewModel.eligibleSchemes.isNotEmpty ||
            _viewModel.potentiallyEligibleSchemes.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        title: Text(
          _isSurveySubmitted
              ? context.tr(
                  'eligibility.eligible_schemes_header',
                  args: {
                    'count':
                        '${_viewModel.eligibleSchemes.length + _viewModel.potentiallyEligibleSchemes.length}',
                  },
                )
              : context.tr('eligibility.title'),
        ),
        actions: [
          if (_isSurveySubmitted && hasSchemes)
            IconButton(
              onPressed: () {
                setState(() {
                  _isSurveySubmitted = false;
                });
              },
              icon: const Icon(Icons.playlist_add_check, color: Colors.white),
              tooltip: 'Update Applied Schemes',
            ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BeneficiaryFollowupScreen(
                    beneficiaryId: widget.beneficiaryId,
                    beneficiaryName: widget.beneficiaryName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.track_changes_outlined, color: Colors.white, size: 18),
            label: const Text(
              'Follow-ups',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: (!_isSurveySubmitted && hasSchemes)
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFFE5EEE8)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await StorageService.saveAppliedSchemeCodes(
                        widget.beneficiaryId,
                        _selectedAppliedCodes,
                        _getBeneficiaryCode(),
                      );
                      if (!mounted) return;
                      setState(() {
                        _isSurveySubmitted = true;
                      });
                      final count = _selectedAppliedCodes.length;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: green,
                          content: Text(
                            count == 0
                                ? 'Showing all eligible schemes (none marked as applied).'
                                : '$count scheme(s) marked as already applied and excluded from follow-up.',
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    label: Text(
                      _selectedAppliedCodes.isEmpty
                          ? context.tr('eligibility.submit_none_applied')
                          : context.tr('eligibility.submit_selected', args: {'count': '${_selectedAppliedCodes.length}'}),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: _viewModel.isLoading && _viewModel.result == null
          ? const Center(
        child: CircularProgressIndicator(color: green),
      )
          : _viewModel.error != null && _viewModel.result == null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 12),
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    _viewModel.checkEligibility(
                      widget.beneficiaryId,
                    ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      )
          : Column(
        children: [
          if (_viewModel.isLoading)
            const LinearProgressIndicator(
              color: green,
              minHeight: 2,
            ),
          Expanded(
            child: _buildSchemesContent(),
          ),
        ],
      ),
    );
  }
}
