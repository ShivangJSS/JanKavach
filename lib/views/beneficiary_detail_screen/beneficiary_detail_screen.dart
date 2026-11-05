import 'package:flutter/material.dart';

import '../../data/models/ beneficiary_model.dart';
import '../../data/models/beneficiary_document_model.dart';
import '../../data/repository/beneficiary_repository.dart';
import '../eligible_schemes_screen/eligible_schemes_screen.dart';
import '../followup/beneficiary_followup_screen.dart';
import 'document_preview_screen.dart';

class BeneficiaryDetailScreen extends StatefulWidget {
  final BeneficiaryModel beneficiary;

  const BeneficiaryDetailScreen({super.key, required this.beneficiary});

  @override
  State<BeneficiaryDetailScreen> createState() =>
      _BeneficiaryDetailScreenState();
}

class _BeneficiaryDetailScreenState extends State<BeneficiaryDetailScreen> {
  final BeneficiaryRepository _repository = BeneficiaryRepository();

  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

  // Documents state
  List<BeneficiaryDocumentModel> _documents = [];
  bool _loadingDocuments = true;
  String? _documentsError;

  static const Color _green = Color(0xFF21834A);

  @override
  void initState() {
    super.initState();
    _details = widget.beneficiary.toJson();
    _isLoading = false;
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadDetails(),
      _loadDocuments(),
    ]);
  }

  Future<void> _loadDetails() async {
    try {
      final details = await _repository.getBeneficiaryDetails(
        widget.beneficiary.id,
      );

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

  Future<void> _loadDocuments() async {
    setState(() {
      _loadingDocuments = true;
      _documentsError = null;
    });

    try {
      final docs = await _repository.getBeneficiaryDocuments(
        widget.beneficiary.id,
      );

      if (!mounted) return;

      setState(() {
        _documents = docs;
        _loadingDocuments = false;
        _documentsError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingDocuments = false;
        _documentsError =
            e.toString().replaceAll('Exception: ', '').trim();
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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

  void _openDocumentPreview(BeneficiaryDocumentModel doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPreviewScreen(
          document: doc,
          beneficiaryName: widget.beneficiary.name,
        ),
      ),
    );
  }

  Widget _buildDocumentIcon(BeneficiaryDocumentModel doc) {
    if (doc.isPdf) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFDE8E8),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.picture_as_pdf_rounded,
          color: Color(0xFFD32F2F),
          size: 24,
        ),
      );
    }
    if (doc.isImage) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F1FC),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.image_rounded,
          color: Color(0xFF1976D2),
          size: 24,
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE3F3E8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(
        Icons.insert_drive_file_rounded,
        color: _green,
        size: 24,
      ),
    );
  }

  Widget _buildDocumentsSection() {
    if (_loadingDocuments && _documents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: _green,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading documents...',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF556059),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_documentsError != null && _documents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade400,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              _documentsError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadDocuments,
              icon: const Icon(Icons.refresh, size: 16, color: _green),
              label: const Text(
                'Retry',
                style: TextStyle(
                  color: _green,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_documents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                color: _green,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Documents Uploaded',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16231C),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No documents have been uploaded for this beneficiary yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _documents.map((doc) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDocumentIcon(doc),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            doc.documentName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16231C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _statusChip(doc.verificationStatus, doc.statusColor),
                      ],
                    ),
                    if (doc.documentNumber != null &&
                        doc.documentNumber!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Doc No: ${doc.documentNumber!}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          doc.fileFormatLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: doc.isPdf
                                ? const Color(0xFFD32F2F)
                                : (doc.isImage
                                    ? const Color(0xFF1976D2)
                                    : _green),
                          ),
                        ),
                        if (doc.fileSize != null && doc.fileSize!.isNotEmpty)
                          Text(
                            '• ${doc.fileSize!}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        if (doc.formattedUploadDate != null)
                          Text(
                            '• ${doc.formattedUploadDate!}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Preview Document',
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: _green,
                  size: 22,
                ),
                onPressed: () => _openDocumentPreview(doc),
              ),
            ],
          ),
        );
      }).toList(),
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
            onPressed: (_isLoading || _loadingDocuments) ? null : _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
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
                        const Text(
                          'Unable to load beneficiary details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAll,
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
      onRefresh: _loadAll,
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
                    _statusChip(recordStatus, _green),
                    _statusChip(assessmentStatus, Colors.orange.shade800),
                  ],
                ),
              ],
            ),
          ),

          _sectionTitle('Personal Information', Icons.person_outline),
          _infoCard([
            MapEntry('Gender', _value('gender')),
            MapEntry('Date of birth', _formatDate('dob')),
            MapEntry('Age', '${_value('age')} years'),
            MapEntry('Registration date', _formatDate('registration_date')),
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
            MapEntry('Aadhaar last 4 digits', _value('aadhaar_last4')),
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
              _value('consent_given') == '1' ||
                      _value('consent_given') == 'true'
                  ? 'Yes'
                  : 'No',
            ),
            MapEntry(
              'Privacy declaration accepted',
              _value('privacy_consent') == '1' ||
                      _value('privacy_consent') == 'true'
                  ? 'Yes'
                  : 'No',
            ),
            MapEntry('Consent date', _formatDate('consent_date')),
            MapEntry('Remarks', _value('remarks')),
            MapEntry('Last assessed', _value('last_assessed_at')),
            MapEntry('Last matched', _value('last_matched_at')),
          ]),

          // Existing Documents Section
          _sectionTitle('Existing Documents', Icons.folder_shared_outlined),
          _buildDocumentsSection(),

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
              label: const Text('Check Eligibility'),
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
              label: const Text(
                'Track Scheme Follow-ups',
                style: TextStyle(color: _green, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }
}
