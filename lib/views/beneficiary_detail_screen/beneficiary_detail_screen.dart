
import 'package:flutter/material.dart';

import '../../data/models/ beneficiary_model.dart';
import '../../data/repository/beneficiary_repository.dart';


class BeneficiaryDetailScreen extends StatefulWidget {
  final BeneficiaryModel beneficiary;

  const BeneficiaryDetailScreen({
    super.key,
    required this.beneficiary,
  });

  @override
  State<BeneficiaryDetailScreen> createState() =>
      _BeneficiaryDetailScreenState();
}

class _BeneficiaryDetailScreenState
    extends State<BeneficiaryDetailScreen> {
  final BeneficiaryRepository _repository =
  BeneficiaryRepository();

  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  static const Color _green = Color(0xFF21834A);

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final details = await _repository.getBeneficiaryDetails(
        widget.beneficiary.id,
      );

      if (!mounted) return;

      setState(() {
        _details = details;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _value(String key, {String fallback = 'Not provided'}) {
    final value = _details?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  String _formatDate(String key) {
    final value = _details?[key];

    if (value == null || value.toString().isEmpty) {
      return 'Not provided';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
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
        title: const Text('Beneficiary Details'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadDetails,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: _green),
      )
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
              const Text(
                'Unable to load beneficiary details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      )
          : _buildDetails(),
    );
  }

  Widget _buildDetails() {
    final recordStatus = _value('record_status');
    final assessmentStatus = _value('assessment_status');

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
                      child: const Icon(
                        Icons.person,
                        color: _green,
                        size: 30,
                      ),
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
                    _statusChip(recordStatus, _green),
                    _statusChip(
                      assessmentStatus,
                      Colors.orange.shade800,
                    ),
                  ],
                ),
              ],
            ),
          ),

          _sectionTitle(
            'Personal Information',
            Icons.person_outline,
          ),
          _infoCard([
            MapEntry('Gender', _value('gender')),
            MapEntry('Date of birth', _formatDate('dob')),
            MapEntry('Age', '${_value('age')} years'),
            MapEntry(
              'Registration date',
              _formatDate('registration_date'),
            ),
          ]),

          _sectionTitle('Family Details', Icons.family_restroom),
          _infoCard([
            MapEntry('Relationship', _value('relation_type')),
            MapEntry('Relationship name', _value('relation_name')),
            MapEntry('Father name', _value('father_name')),
            MapEntry('Mother name', _value('mother_name')),
            MapEntry('Spouse name', _value('spouse_name')),
          ]),

          _sectionTitle('Contact Details', Icons.call_outlined),
          _infoCard([
            MapEntry('Mobile', _value('mobile')),
            MapEntry('Alternate mobile', _value('alt_mobile')),
            MapEntry(
              'Aadhaar available',
              _value('has_aadhaar') == '1' ? 'Yes' : 'No',
            ),
            MapEntry(
              'Aadhaar last 4 digits',
              _value('aadhaar_last4'),
            ),
          ]),

          _sectionTitle('Address Details', Icons.location_on_outlined),
          _infoCard([
            MapEntry('Village', _value('village_name')),
            MapEntry('Post office', _value('post_office')),
            MapEntry('Address', _value('address_line')),
            MapEntry('Pincode', _value('pincode')),
            MapEntry('Area type', _value('area_type')),
            MapEntry('State ID', _value('state_id')),
            MapEntry('District ID', _value('district_id')),
            MapEntry('Block ID', _value('block_id')),
            MapEntry('Gram Panchayat ID', _value('gram_panchayat_id')),
            MapEntry('Village ID', _value('village_id')),
          ]),

          _sectionTitle('Consent & Remarks', Icons.verified_user_outlined),
          _infoCard([
            MapEntry(
              'Consent given',
              _value('consent_given') == '1' ? 'Yes' : 'No',
            ),
            MapEntry(
              'Consent date',
              _formatDate('consent_date'),
            ),
            MapEntry('Remarks', _value('remarks')),
            MapEntry(
              'Last assessed',
              _value('last_assessed_at'),
            ),
            MapEntry(
              'Last matched',
              _value('last_matched_at'),
            ),
          ]),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
