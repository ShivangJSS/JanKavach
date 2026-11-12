import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/localization/localized_value_helper.dart';
import '../../data/models/ beneficiary_model.dart';
import '../../data/repository/beneficiary_repository.dart';
import '../eligible_schemes_screen/eligible_schemes_screen.dart';
import '../followup/beneficiary_followup_screen.dart';

class BeneficiaryDetailScreen extends StatefulWidget {
  final BeneficiaryModel beneficiary;
  final Future<Map<String, dynamic>> Function(int id)? detailsLoader;

  const BeneficiaryDetailScreen({
    super.key,
    required this.beneficiary,
    this.detailsLoader,
  });

  @override
  State<BeneficiaryDetailScreen> createState() =>
      _BeneficiaryDetailScreenState();
}

class _BeneficiaryDetailScreenState extends State<BeneficiaryDetailScreen> {
  final BeneficiaryRepository _repository = BeneficiaryRepository();

  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  static const Color _green = Color(0xFF21834A);

  @override
  void initState() {
    super.initState();
    _details = widget.beneficiary.toJson();
    _isLoading = false;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final details =
          await (widget.detailsLoader?.call(widget.beneficiary.id) ??
              _repository.getBeneficiaryDetails(widget.beneficiary.id));

      if (!mounted) return;

      setState(() {
        _details = details;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (_details == null || _details!.isEmpty) {
          _error = e.toString();
        }
      });
    }
  }

  String _value(String key, {String? fallback}) {
    final value = _details?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback ?? context.tr('registration.not_provided');
    }

    return value.toString();
  }

  String _translatedValue(String key, {String? fallback}) {
    final value = _details?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback ?? context.tr('registration.not_provided');
    }

    return LocalizedValueHelper.translateOption(context, value.toString());
  }

  String _formatDate(String key) {
    return LocalizedValueHelper.formatDate(context, _details?[key]);
  }

  String _formatAge() {
    return LocalizedValueHelper.formatAge(
      context,
      _details?['age'],
      fallback: context.tr('registration.not_provided'),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 21),
          const SizedBox(width: 9),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<MapEntry<String, String>> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    item.key,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: Text(
                    item.value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      appBar: AppBar(
        title: Text(context.tr('beneficiary_detail.title')),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadDetails,
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('beneficiary_detail.refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('beneficiary_detail.load_error'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadDetails,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.tr('beneficiary_detail.try_again')),
                    ),
                  ],
                ),
              ),
            )
          : _buildDetails(),
    );
  }

  Widget _buildDetails() {
    final recordStatus = _details?['record_status']?.toString();
    final assessmentStatus = _details?['assessment_status']?.toString();

    return RefreshIndicator(
      onRefresh: _loadDetails,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFE3F3E8),
                      child: const Icon(Icons.person, color: _green, size: 30),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _value('name'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _value('beneficiary_code'),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(
                      LocalizedValueHelper.translateStatus(
                        context,
                        recordStatus,
                      ),
                      _green,
                    ),
                    _statusChip(
                      LocalizedValueHelper.translateStatus(
                        context,
                        assessmentStatus,
                      ),
                      Colors.orange.shade800,
                    ),
                  ],
                ),
              ],
            ),
          ),

          _sectionTitle(
            context.tr('beneficiary_detail.section_personal'),
            Icons.person_outline,
          ),
          _infoCard([
            MapEntry(
              context.tr('registration.gender'),
              LocalizedValueHelper.translateGender(
                context,
                _details?['gender'],
              ),
            ),
            MapEntry(context.tr('registration.dob'), _formatDate('dob')),
            MapEntry(context.tr('registration.age'), _formatAge()),
            MapEntry(
              context.tr('registration.registration_date'),
              _formatDate('registration_date'),
            ),
          ]),

          _sectionTitle(
            context.tr('beneficiary_detail.section_family'),
            Icons.family_restroom,
          ),
          _infoCard([
            MapEntry(
              context.tr('registration.relation_type'),
              _translatedValue('relation_type'),
            ),
            MapEntry(
              context.tr('registration.relation_name'),
              _value('relation_name'),
            ),
            MapEntry(
              context.tr('registration.father_name'),
              _value('father_name'),
            ),
            MapEntry(
              context.tr('registration.mother_name'),
              _value('mother_name'),
            ),
            MapEntry(
              context.tr('registration.spouse_name'),
              _value('spouse_name'),
            ),
          ]),

          _sectionTitle(
            context.tr('beneficiary_detail.section_contact'),
            Icons.call_outlined,
          ),
          _infoCard([
            MapEntry(
              context.tr('registration.mobile_number'),
              _value('mobile'),
            ),
            MapEntry(
              context.tr('registration.alt_mobile'),
              _value('alt_mobile'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.aadhaar_available'),
              LocalizedValueHelper.formatBool(
                context,
                _details?['has_aadhaar'],
              ),
            ),
            MapEntry(
              context.tr('beneficiary_detail.aadhaar_last4'),
              _value('aadhaar_last4'),
            ),
          ]),

          _sectionTitle(
            context.tr('beneficiary_detail.section_address'),
            Icons.location_on_outlined,
          ),
          _infoCard([
            MapEntry(
              context.tr('registration.village'),
              _value('village_name'),
            ),
            MapEntry(
              context.tr('registration.post_office'),
              _value('post_office'),
            ),
            MapEntry(
              context.tr('registration.address_line'),
              _value('address_line'),
            ),
            MapEntry(
              context.tr('registration.pincode'),
              _value('pincode'),
            ),
            MapEntry(
              context.tr('registration.area_type'),
              _translatedValue('area_type'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.state_id'),
              _value('state_id'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.district_id'),
              _value('district_id'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.block_id'),
              _value('block_id'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.gp_id'),
              _value('gram_panchayat_id'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.village_id'),
              _value('village_id'),
            ),
          ]),

          _sectionTitle(
            context.tr('beneficiary_detail.section_consent'),
            Icons.verified_user_outlined,
          ),
          _infoCard([
            MapEntry(
              context.tr('beneficiary_detail.consent_given'),
              LocalizedValueHelper.formatBool(
                context,
                _details?['consent_given'],
              ),
            ),
            MapEntry(
              context.tr('beneficiary_detail.privacy_accepted'),
              LocalizedValueHelper.formatBool(
                context,
                _details?['privacy_consent'],
              ),
            ),
            MapEntry(
              context.tr('beneficiary_detail.consent_date'),
              _formatDate('consent_date'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.remarks'),
              _value('remarks'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.last_assessed'),
              _formatDate('last_assessed_at'),
            ),
            MapEntry(
              context.tr('beneficiary_detail.last_matched'),
              _formatDate('last_matched_at'),
            ),
          ]),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EligibleSchemesScreen(
                      beneficiaryId: widget.beneficiary.id,
                      beneficiaryName: widget.beneficiary.name,
                      beneficiary: widget.beneficiary,
                      beneficiaryDetails: _details,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(context.tr('dashboard.check_eligibility')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BeneficiaryFollowupScreen(
                      beneficiaryId: widget.beneficiary.id,
                      beneficiaryName: widget.beneficiary.name,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.track_changes_outlined, color: _green),
              label: Text(
                context.tr('beneficiary_detail.track_followups'),
                style: const TextStyle(
                  color: _green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _green, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
