import 'package:flutter/material.dart';
import '../../data/models/followup_model.dart';
import '../../data/repository/followup_repository.dart';

class RecordFollowupSheet extends StatefulWidget {
  final int beneficiaryId;
  final String beneficiaryName;
  final int schemeId;
  final String schemeName;
  final SchemeFollowupDetail? existingFollowup;
  final List<RequiredDocumentItem>? requiredDocuments;
  final FollowupRepository? repository;

  const RecordFollowupSheet({
    super.key,
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.schemeId,
    required this.schemeName,
    this.existingFollowup,
    this.requiredDocuments,
    this.repository,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int beneficiaryId,
    required String beneficiaryName,
    required int schemeId,
    required String schemeName,
    SchemeFollowupDetail? existingFollowup,
    List<RequiredDocumentItem>? requiredDocuments,
    FollowupRepository? repository,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordFollowupSheet(
        beneficiaryId: beneficiaryId,
        beneficiaryName: beneficiaryName,
        schemeId: schemeId,
        schemeName: schemeName,
        existingFollowup: existingFollowup,
        requiredDocuments: requiredDocuments,
        repository: repository,
      ),
    );
  }

  @override
  State<RecordFollowupSheet> createState() => _RecordFollowupSheetState();
}

class _RecordFollowupSheetState extends State<RecordFollowupSheet> {
  static const Color green = Color(0xFF075832);

  late final FollowupRepository _repository;
  final _formKey = GlobalKey<FormState>();

  String get _existingStatusNormalized =>
      (widget.existingFollowup?.status ?? '').trim().toLowerCase();

  bool get _isExistingApplied => _existingStatusNormalized == 'applied';

  bool get _isExistingComplete =>
      _existingStatusNormalized == 'complete' ||
      _existingStatusNormalized == 'completed';

  // Selected Status: 'Applied', 'Pending', 'Complete'
  String _selectedStatus = 'Pending';

  // For 'Pending'
  String _pendingReason = 'Document issue'; // 'Document issue', 'Not applied yet', 'Application pending', 'Verification pending'
  int? _selectedDocTypeId;
  String _issueType = 'Missing'; // 'Missing', 'Expired', 'Invalid'
  final TextEditingController _docNotesController = TextEditingController();
  DateTime? _nextFollowupDate;

  // For 'Applied'
  DateTime? _submissionDate;

  // For 'Complete'
  DateTime? _benefitReceivedDate;

  // Common
  final TextEditingController _notesController = TextEditingController();

  static const List<FollowupDocumentType> _fallbackDocumentTypes = [
    FollowupDocumentType(id: 1, documentName: 'Aadhaar Card', documentCode: 'DOC_AADHAAR', category: 'Identity'),
    FollowupDocumentType(id: 4, documentName: 'Income Certificate', documentCode: 'DOC_INCOME', category: 'Income'),
    FollowupDocumentType(id: 5, documentName: 'BPL Ration Card', documentCode: 'DOC_BPL_CARD', category: 'Income'),
    FollowupDocumentType(id: 8, documentName: 'Bank Passbook', documentCode: 'DOC_BANK_PASSBOOK', category: 'Financial'),
    FollowupDocumentType(id: 2, documentName: 'Voter ID Card', documentCode: 'DOC_VOTER_ID', category: 'Identity'),
    FollowupDocumentType(id: 3, documentName: 'PAN Card', documentCode: 'DOC_PAN', category: 'Identity'),
    FollowupDocumentType(id: 6, documentName: 'Caste Certificate', documentCode: 'DOC_CASTE', category: 'Social'),
    FollowupDocumentType(id: 7, documentName: 'Domicile / Residence Certificate', documentCode: 'DOC_DOMICILE', category: 'Address'),
    FollowupDocumentType(id: 9, documentName: 'Birth Certificate', documentCode: 'DOC_BIRTH_CERT', category: 'Identity'),
    FollowupDocumentType(id: 10, documentName: 'Disability Certificate', documentCode: 'DOC_DISABILITY', category: 'Health'),
    FollowupDocumentType(id: 26, documentName: 'Death Certificate of Breadwinner', documentCode: 'DOC_DEATH_CERT', category: 'General'),
  ];

  List<FollowupDocumentType> _documentTypes = List.from(_fallbackDocumentTypes);
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FollowupRepository();
    _selectedDocTypeId = _fallbackDocumentTypes.first.id;
    _initValuesFromExisting();
    _loadDocumentTypes();
  }

  void _initValuesFromExisting() {
    final existing = widget.existingFollowup;
    if (existing != null) {
      if (_isExistingApplied || _isExistingComplete) {
        // After 'Yes, Applied', the second follow-up only allows marking Complete.
        _selectedStatus = 'Complete';
      } else {
        _selectedStatus = existing.status;
      }
      if (existing.pendingReason != null) {
        _pendingReason = existing.pendingReason!;
      }
      if (existing.documentIssueType != null) {
        _issueType = existing.documentIssueType!;
      }
      if (existing.documentNotes != null) {
        _docNotesController.text = existing.documentNotes!;
      }
      if (existing.notes != null) {
        _notesController.text = existing.notes!;
      }
      if (existing.nextFollowupDate != null) {
        try {
          _nextFollowupDate = DateTime.parse(existing.nextFollowupDate!);
        } catch (_) {}
      }
      if (existing.submissionDate != null) {
        try {
          _submissionDate = DateTime.parse(existing.submissionDate!);
        } catch (_) {}
      }
      if (existing.benefitReceivedDate != null) {
        try {
          _benefitReceivedDate = DateTime.parse(existing.benefitReceivedDate!);
        } catch (_) {}
      }
    }

    // Always ensure non-null default dates for active statuses
    _submissionDate ??= DateTime.now();
    _benefitReceivedDate ??= DateTime.now();
    _nextFollowupDate ??= DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _loadDocumentTypes() async {
    try {
      final list = await _repository.getDocumentTypes();
      List<FollowupDocumentType> docs = list;
      if (docs.isEmpty) {
        if (widget.requiredDocuments != null && widget.requiredDocuments!.isNotEmpty) {
          docs = widget.requiredDocuments!
              .where((r) => r.name.isNotEmpty)
              .map((r) => FollowupDocumentType(
                    id: r.id > 0 ? r.id : 1,
                    documentName: r.name,
                    documentCode: r.code,
                  ))
              .toList();
        }
        if (docs.isEmpty) {
          docs = _fallbackDocumentTypes;
        }
      }

      if (mounted) {
        setState(() {
          _documentTypes = docs;
          int? matchedId;
          if (widget.requiredDocuments != null && widget.requiredDocuments!.isNotEmpty) {
            for (final req in widget.requiredDocuments!) {
              if (req.id > 0 && _documentTypes.any((d) => d.id == req.id)) {
                matchedId = req.id;
                break;
              }
            }
          }
          if (_selectedDocTypeId == null || !_documentTypes.any((d) => d.id == _selectedDocTypeId)) {
            _selectedDocTypeId = matchedId ?? _documentTypes.first.id;
          }
        });
      }
    } catch (_) {
      // Graceful fallback already populated with _fallbackDocumentTypes
    } finally {
    }
  }

  @override
  void dispose() {
    _docNotesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required Function(DateTime) onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final effectiveLast = lastDate ?? DateTime(2035);
    final effectiveFirst = firstDate ?? DateTime(2020);
    final safeInitial = initialDate.isAfter(effectiveLast)
        ? effectiveLast
        : (initialDate.isBefore(effectiveFirst) ? effectiveFirst : initialDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: green,
              onPrimary: Colors.white,
              onSurface: Color(0xFF26352E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _submit() async {
    if (_isExistingComplete) return;
    if (_isExistingApplied && _selectedStatus != 'Complete') return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStatus == 'Applied') {
      _submissionDate ??= DateTime.now();
    }
    if (_selectedStatus == 'Complete') {
      _benefitReceivedDate ??= DateTime.now();
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = RecordFollowupPayload(
        beneficiaryId: widget.beneficiaryId,
        schemeId: widget.schemeId,
        status: _selectedStatus,
        pendingReason: _selectedStatus == 'Pending' ? _pendingReason : null,
        documentTypeId: (_selectedStatus == 'Pending' && _pendingReason == 'Document issue')
            ? (_selectedDocTypeId ?? (_documentTypes.isNotEmpty ? _documentTypes.first.id : null))
            : null,
        issueType: (_selectedStatus == 'Pending' && _pendingReason == 'Document issue')
            ? _issueType
            : null,
        documentNotes: (_selectedStatus == 'Pending' && _pendingReason == 'Document issue')
            ? _docNotesController.text.trim()
            : null,
        applicationNumber: null,
        submissionDate: _selectedStatus == 'Applied'
            ? _formatDate(_submissionDate ?? DateTime.now())
            : (_selectedStatus == 'Complete' && widget.existingFollowup?.submissionDate != null
                ? _formatDate(_submissionDate ?? DateTime.now())
                : null),
        benefitReceivedDate: _selectedStatus == 'Complete'
            ? _formatDate(_benefitReceivedDate ?? DateTime.now())
            : null,
        nextFollowupDate: (_selectedStatus == 'Pending' && _nextFollowupDate != null)
            ? _formatDate(_nextFollowupDate!)
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      await _repository.recordFollowup(payload);

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedStatus == 'Applied'
                ? 'Scheme marked as Applied successfully!'
                : _selectedStatus == 'Complete'
                    ? 'Benefit marked as Complete!'
                    : 'Follow-up visit and status recorded.',
          ),
          backgroundColor: green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save follow-up: $msg'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF7EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.track_changes_rounded,
                        color: green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.schemeName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF16231C),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Beneficiary: ${widget.beneficiaryName}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF627065),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8E4)),
                const SizedBox(height: 18),

                // Core Question: Has beneficiary applied?
                const Text(
                  'Has the beneficiary applied for this scheme?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16231C),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Choice Pills
                Builder(
                  builder: (context) {
                    final canSelectApplied =
                        !_isExistingApplied && !_isExistingComplete;
                    final canSelectPending =
                        !_isExistingApplied && !_isExistingComplete;
                    final canSelectComplete = !_isExistingComplete;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildChoiceCard(
                            title: 'Yes, Applied',
                            subtitle: 'Application lodged',
                            icon: Icons.check_circle_outline_rounded,
                            isSelected: _selectedStatus == 'Applied',
                            isEnabled: canSelectApplied,
                            color: const Color(0xFF1377CC),
                            onTap: canSelectApplied
                                ? () => setState(() {
                                    _selectedStatus = 'Applied';
                                    _submissionDate ??= DateTime.now();
                                  })
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildChoiceCard(
                            title: 'Not Applied',
                            subtitle: 'Pending / Doc issue',
                            icon: Icons.pending_actions_rounded,
                            isSelected: _selectedStatus == 'Pending',
                            isEnabled: canSelectPending,
                            color: const Color(0xFFD9700C),
                            onTap: canSelectPending
                                ? () => setState(
                                    () => _selectedStatus = 'Pending',
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildChoiceCard(
                            title: 'Complete',
                            subtitle: 'Benefit received',
                            icon: Icons.verified_outlined,
                            isSelected: _selectedStatus == 'Complete',
                            isEnabled: canSelectComplete,
                            color: const Color(0xFF168A53),
                            onTap: canSelectComplete
                                ? () => setState(() {
                                    _selectedStatus = 'Complete';
                                    _benefitReceivedDate ??= DateTime.now();
                                  })
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),

                if (_isExistingApplied) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCCE2FE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFF0F60A5),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Application already submitted. Only Complete can be selected now.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F60A5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Conditional Form Content based on status
                if (_selectedStatus == 'Applied') ...[
                  _buildAppliedSection(),
                ] else if (_selectedStatus == 'Pending') ...[
                  _buildPendingSection(),
                ] else ...[
                  _buildCompleteSection(),
                ],

                const SizedBox(height: 20),

                // Common Notes Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Visit Notes / Remarks',
                    hintText: 'Add remarks from interaction with beneficiary...',
                    filled: true,
                    fillColor: const Color(0xFFF7FAF8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD9E2DC)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFD9E2DC)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        (_isSubmitting || _isExistingComplete) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isExistingComplete
                                ? 'Completed'
                                : _selectedStatus == 'Applied'
                                    ? 'Save & Mark as Applied'
                                    : _selectedStatus == 'Complete'
                                        ? 'Mark Scheme as Complete'
                                        : 'Save Follow-up Progress',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
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

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    final Color cardBg = !isEnabled
        ? const Color(0xFFF3F5F4)
        : isSelected
            ? color.withValues(alpha: 0.1)
            : Colors.white;
    final Color borderCol = !isEnabled
        ? const Color(0xFFE4E8E6)
        : isSelected
            ? color
            : const Color(0xFFE2E8E4);
    final Color iconColor = !isEnabled
        ? Colors.grey.shade400
        : isSelected
            ? color
            : Colors.blueGrey;
    final Color titleColor = !isEnabled
        ? Colors.grey.shade400
        : isSelected
            ? color
            : const Color(0xFF26352E);
    final Color subtitleColor = !isEnabled
        ? Colors.grey.shade400
        : isSelected
            ? color.withValues(alpha: 0.85)
            : Colors.grey;

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(
            color: borderCol,
            width: isSelected && isEnabled ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: subtitleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppliedSection() {
    final displayDate = _submissionDate ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCCE2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Submission Details',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F60A5),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              _pickDate(
                context: context,
                initialDate: displayDate,
                lastDate: DateTime.now(),
                onPicked: (d) => _submissionDate = d,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCE2FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF1377CC)),
                  const SizedBox(width: 10),
                  Text(
                    'Submission Date: ${_formatDate(displayDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF26352E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0BE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reason for Delay / Not Applied',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB85900),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF16231C),
            ),
            value: const [
              'Document issue',
              'Not applied yet',
              'Application pending',
              'Verification pending',
            ].contains(_pendingReason)
                ? _pendingReason
                : 'Document issue',
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFFE0BE)),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Document issue',
                child: Text(
                  'Document Issue (Missing / Expired / Incomplete)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Color(0xFF16231C)),
                ),
              ),
              DropdownMenuItem(
                value: 'Not applied yet',
                child: Text(
                  'Not applied yet (General delay / Scheduled)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Color(0xFF16231C)),
                ),
              ),
              DropdownMenuItem(
                value: 'Application pending',
                child: Text(
                  'Application pending at CSC or Tehsil',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Color(0xFF16231C)),
                ),
              ),
              DropdownMenuItem(
                value: 'Verification pending',
                child: Text(
                  'Verification pending with authorities',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Color(0xFF16231C)),
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _pendingReason = val);
            },
          ),

          if (_pendingReason == 'Document issue') ...[
            const SizedBox(height: 14),
            const Text(
              'Which document is blocking the application?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF26352E),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16231C),
              ),
              value: _documentTypes.any((d) => d.id == _selectedDocTypeId)
                  ? _selectedDocTypeId
                  : _documentTypes.first.id,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFE0BE)),
                ),
              ),
              items: _documentTypes.map((doc) {
                return DropdownMenuItem<int>(
                  value: doc.id,
                  child: Text(
                    doc.documentName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16231C),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDocTypeId = val);
              },
            ),

            const SizedBox(height: 12),
            const Text(
              'Document Issue Type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF26352E),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: ['Missing', 'Expired', 'Invalid'].map((type) {
                final selected = _issueType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: selected,
                    selectedColor: const Color(0xFFD9700C),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF26352E),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => setState(() => _issueType = type),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _docNotesController,
              decoration: InputDecoration(
                labelText: 'Document Details / Bottleneck',
                hintText: 'e.g. Income certificate expired, applying at Tehsil',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFE0BE)),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              _pickDate(
                context: context,
                initialDate: _nextFollowupDate ?? DateTime.now().add(const Duration(days: 7)),
                onPicked: (d) => _nextFollowupDate = d,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE0BE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, size: 18, color: Color(0xFFD9700C)),
                  const SizedBox(width: 10),
                  Text(
                    _nextFollowupDate == null
                        ? 'Set Next Follow-up Date'
                        : 'Next Visit Due: ${_formatDate(_nextFollowupDate!)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF26352E)),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteSection() {
    final displayDate = _benefitReceivedDate ?? DateTime.now();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF7EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD2EBD9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Benefit Disbursement Confirmation',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF116B3F),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              _pickDate(
                context: context,
                initialDate: displayDate,
                lastDate: DateTime.now(),
                onPicked: (d) => _benefitReceivedDate = d,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD2EBD9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 18, color: green),
                  const SizedBox(width: 10),
                  Text(
                    'Benefit Received Date: ${_formatDate(displayDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF26352E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
