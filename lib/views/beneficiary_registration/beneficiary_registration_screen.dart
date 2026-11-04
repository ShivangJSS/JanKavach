import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/local/beneficiary_local_dao.dart';
import '../../data/models/location_model.dart';
import '../../data/services/beneficiary_sync_service.dart';
import '../../data/services/geography_service.dart';
import '../../data/services/storage_service.dart';

class BeneficiaryRegistrationScreen extends StatefulWidget {
  final int? localDraftId;

  const BeneficiaryRegistrationScreen({super.key, this.localDraftId});

  @override
  State<BeneficiaryRegistrationScreen> createState() =>
      _BeneficiaryRegistrationScreenState();
}

class _BeneficiaryRegistrationScreenState
    extends State<BeneficiaryRegistrationScreen> {
  final GeographyService _geographyService = GeographyService();

  UserAssignedLocation? _assignedLocation;

  List<LocationModel> _states = [];
  List<LocationModel> _districts = [];
  List<LocationModel> _blocks = [];
  List<LocationModel> _gramPanchayats = [];
  List<LocationModel> _villages = [];

  int? _selectedStateId;
  int? _selectedDistrictId;
  int? _selectedBlockId;
  int? _selectedGramPanchayatId;
  int? _selectedVillageId;

  bool _loadingStates = false;
  bool _loadingDistricts = false;
  bool _loadingBlocks = false;
  bool _loadingGramPanchayats = false;
  bool _loadingVillages = false;

  bool _isSubmitting = false;
  final BeneficiaryLocalDao _localDao = BeneficiaryLocalDao();

  int? _localDraftId;
  Timer? _draftSaveTimer;

  bool _isSavingDraft = false;
  bool _isRestoringDraft = false;
  String? _draftSaveError;
  static const Color green = Color(0xFF087443);
  static const Color darkGreen = Color(0xFF06452D);
  static const Color background = Color(0xFFF2F8F4);

  int _step = 0;

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _values = {};
  final Map<String, bool> _switches = {};
  final Set<String> _vulnerabilities = {};

  final List<String> _stepTitles = [
    'Beneficiary Details',
    'Address',
    'Identity & Citizenship',
    'Livelihood & Documents',
    'Financial Inclusion',
    'Review & Submit',
  ];


  final Map<String, List<String>> _options = {
    'Care Of (Relation)': ['Father', 'Mother', 'Spouse', 'Guardian', 'Other'],
    'Gender': ['Male', 'Female', 'Other'],

    'Rural / Urban': ['Rural', 'Urban'],
    'Category': ['Not recorded', 'General', 'SC', 'ST', 'OBC', 'Other'],
    'Marital Status': [
      'Not recorded',
      'Unmarried',
      'Married',
      'Widowed',
      'Divorced',
      'Separated',
    ],
    'Do you earn?': ['Not recorded', 'Yes', 'No'],
    'Occupation': [
      'Not recorded',
      'Agricultural Labourer',
      'Cultivator / Farmer',
      'Daily Wage Labourer',
      'Construction Worker',
      'Domestic Worker',
      'Street Vendor',
      'Artisan / Weaver',
      'Fisherman',
      'Small Business / Shop',
      'Salaried - Private',
      'Salaried - Government',
      'Self-employed / Own Account',
      'Student',
      'Homemaker',
      'Unemployed',
      'Retired',
      'Unable to Work',
      'Other',
      'Trader',
      'Weaver',
      'Unorganized Sector',
      'Service',
    ],
    'What is your monthly income?': [
      'Not recorded',
      'No income',
      'Less than ₹25,000',
      '₹25,000–₹50,000',
      '₹50,000–₹75,000',
      'Less than ₹1,00,000',
      'More than ₹1,00,000',
      'Less than ₹8,00,000',
    ],
  };

  final List<String> _vulnerabilityOptions = [
    'Migrant Labor',
    'Female Sex Workers (FSW)',
    'Affected by Natural Calamities',
    'Affected by Conflict',
    'Victims/Survivors of Violence and Abuse',
    'Victims and Survivors of Trafficking',
    'Tribal Population',
    'Minority Group',
    'Orphan Child',
    'Single Parent',
    'Child in Need of Care and Protection',
    'Displaced',
    'Elderly',
    'PWD/Chronic Diseases',
    'LGBTQ+',
  ];

  Future<void> _restoreDraft(int localId) async {
    try {
      final record = await _localDao.getRecord(localId);

      if (!mounted || record == null) return;

      final formData = Map<String, dynamic>.from(record['form_data'] as Map);

      final formState = Map<String, dynamic>.from(
        formData['form_state'] as Map,
      );

      final controllers = Map<String, dynamic>.from(
        formState['controllers'] as Map? ?? {},
      );

      final values = Map<String, dynamic>.from(
        formState['values'] as Map? ?? {},
      );

      final switches = Map<String, dynamic>.from(
        formState['switches'] as Map? ?? {},
      );

      final vulnerabilities = (formState['vulnerabilities'] as List? ?? [])
          .map((item) => item.toString())
          .toSet();

      int? readId(String key) {
        final value = formState[key];
        if (value == null) return null;
        return int.tryParse(value.toString());
      }

      setState(() {
        _isRestoringDraft = true;
        _localDraftId = localId;

        for (final entry in controllers.entries) {
          _controller(entry.key).text = entry.value.toString();
        }

        _values
          ..clear()
          ..addAll(values.map((key, value) => MapEntry(key, value.toString())));

        _switches
          ..clear()
          ..addAll(switches.map((key, value) => MapEntry(key, value == true)));

        _vulnerabilities
          ..clear()
          ..addAll(vulnerabilities);

        _step = (formState['current_step'] as num?)?.toInt() ?? 0;
        _step = _step.clamp(0, 5);

        _selectedStateId = readId('selected_state_id');
        _selectedDistrictId = readId('selected_district_id');
        _selectedBlockId = readId('selected_block_id');
        _selectedGramPanchayatId = readId('selected_gram_panchayat_id');
        _selectedVillageId = readId('selected_village_id');

        // Enforce user assigned jurisdiction if available
        if (_assignedLocation?.hasAssignedState == true) {
          _selectedStateId = _assignedLocation!.stateId;
        }
        if (_assignedLocation?.hasAssignedDistrict == true) {
          _selectedDistrictId = _assignedLocation!.districtId;
        }
        if (_assignedLocation?.hasAssignedBlock == true) {
          _selectedBlockId = _assignedLocation!.blockId;
        }
      });

      // Load dependent dropdown options before displaying selections.
      if (_selectedStateId != null) {
        _districts = await _geographyService.getDistricts(_selectedStateId!);
      }

      if (_selectedDistrictId != null) {
        _blocks = await _geographyService.getBlocks(_selectedDistrictId!);
      }

      if (_selectedBlockId != null) {
        _gramPanchayats = await _geographyService.getGramPanchayats(
          _selectedBlockId!,
        );
      }

      if (_selectedGramPanchayatId != null) {
        _villages = await _geographyService.getVillages(
          _selectedGramPanchayatId!,
        );
      }

      if (!mounted) return;

      setState(() {
        _isRestoringDraft = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Draft restoration failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() => _isRestoringDraft = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to restore this draft.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initGeographyAndDefaults();

    if (widget.localDraftId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreDraft(widget.localDraftId!);
      });
    } else {
      final now = DateTime.now();
      final day = now.day.toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final todayFormatted = '$day-$month-${now.year}';
      _controller('Registration Date').text = todayFormatted;
      _values['Registration Date'] = todayFormatted;
    }
  }

  Future<void> _initGeographyAndDefaults() async {
    _assignedLocation = await StorageService.getUserAssignedLocation();
    await _loadStates();

    // If new registration, pre-fill assigned geography
    if (widget.localDraftId == null && _assignedLocation != null) {
      if (_assignedLocation!.hasAssignedState) {
        if (mounted) {
          setState(() {
            _selectedStateId = _assignedLocation!.stateId;
          });
        }

        // Load districts for assigned state
        if (mounted) setState(() => _loadingDistricts = true);
        try {
          final dists = await _geographyService.getDistricts(_assignedLocation!.stateId!);
          if (mounted) setState(() => _districts = dists);
        } catch (e) {
          debugPrint('Loading assigned districts failed: $e');
        } finally {
          if (mounted) setState(() => _loadingDistricts = false);
        }

        if (_assignedLocation!.hasAssignedDistrict) {
          if (mounted) {
            setState(() {
              _selectedDistrictId = _assignedLocation!.districtId;
            });
          }

          // Load blocks for assigned district
          if (mounted) setState(() => _loadingBlocks = true);
          try {
            final blks = await _geographyService.getBlocks(_assignedLocation!.districtId!);
            if (mounted) setState(() => _blocks = blks);
          } catch (e) {
            debugPrint('Loading assigned blocks failed: $e');
          } finally {
            if (mounted) setState(() => _loadingBlocks = false);
          }

          if (_assignedLocation!.hasAssignedBlock) {
            if (mounted) {
              setState(() {
                _selectedBlockId = _assignedLocation!.blockId;
              });
            }

            // Load gram panchayats for assigned block
            if (mounted) setState(() => _loadingGramPanchayats = true);
            try {
              final gps = await _geographyService.getGramPanchayats(_assignedLocation!.blockId!);
              if (mounted) {
                setState(() => _gramPanchayats = gps);
                if (gps.isEmpty) {
                  final vils = await _geographyService.getVillagesByBlock(_assignedLocation!.blockId!);
                  if (mounted && vils.isNotEmpty) {
                    setState(() => _villages = vils);
                  }
                }
              }
            } catch (e) {
              debugPrint('Loading assigned GPs failed: $e');
            } finally {
              if (mounted) setState(() => _loadingGramPanchayats = false);
            }
          }
        }
      }
    }
  }

  Future<void> _loadStates() async {
    setState(() => _loadingStates = true);

    try {
      final locations = await _geographyService.getStates();

      if (!mounted) return;
      setState(() => _states = locations);
    } catch (e) {
      debugPrint('Loading states failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingStates = false);
      }
    }
  }

  Future<void> _onStateChanged(int? stateId) async {
    setState(() {
      _selectedStateId = stateId;
      _selectedDistrictId = null;
      _selectedBlockId = null;
      _selectedGramPanchayatId = null;
      _selectedVillageId = null;

      _districts = [];
      _blocks = [];
      _gramPanchayats = [];
      _villages = [];
    });

    _scheduleDraftSave();

    if (stateId == null) return;

    setState(() => _loadingDistricts = true);

    try {
      final locations = await _geographyService.getDistricts(stateId);

      if (!mounted) return;
      setState(() => _districts = locations);
    } catch (e) {
      debugPrint('Loading districts failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingDistricts = false);
      }
    }
  }

  Future<void> _onDistrictChanged(int? districtId) async {
    setState(() {
      _selectedDistrictId = districtId;
      _selectedBlockId = null;
      _selectedGramPanchayatId = null;
      _selectedVillageId = null;
      _blocks = [];
      _gramPanchayats = [];
      _villages = [];
    });

    _scheduleDraftSave();

    if (districtId == null) return;

    setState(() => _loadingBlocks = true);
    try {
      final locations = await _geographyService.getBlocks(districtId);
      if (!mounted) return;
      setState(() => _blocks = locations);
    } catch (e) {
      debugPrint('Loading blocks failed: $e');
    } finally {
      if (mounted) setState(() => _loadingBlocks = false);
    }
  }

  Future<void> _onBlockChanged(int? blockId) async {
    setState(() {
      _selectedBlockId = blockId;
      _selectedGramPanchayatId = null;
      _selectedVillageId = null;
      _gramPanchayats = [];
      _villages = [];
    });

    _scheduleDraftSave();

    if (blockId == null) return;

    setState(() => _loadingGramPanchayats = true);
    try {
      final locations = await _geographyService.getGramPanchayats(blockId);
      if (!mounted) return;
      setState(() => _gramPanchayats = locations);
      if (locations.isEmpty) {
        final vils = await _geographyService.getVillagesByBlock(blockId);
        if (mounted && vils.isNotEmpty) {
          setState(() => _villages = vils);
        }
      }
    } catch (e) {
      debugPrint('Loading Gram Panchayats failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingGramPanchayats = false);
      }
    }
  }

  Future<void> _onGramPanchayatChanged(int? gpId) async {
    setState(() {
      _selectedGramPanchayatId = gpId;
      _selectedVillageId = null;
      _villages = [];
    });

    _scheduleDraftSave();

    if (gpId == null) {
      if (_selectedBlockId != null) {
        final vils = await _geographyService.getVillagesByBlock(_selectedBlockId!);
        if (mounted && vils.isNotEmpty) {
          setState(() => _villages = vils);
        }
      }
      return;
    }

    setState(() => _loadingVillages = true);
    try {
      final locations = await _geographyService.getVillages(gpId);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        setState(() => _villages = locations);
      } else if (_selectedBlockId != null) {
        final vils = await _geographyService.getVillagesByBlock(_selectedBlockId!);
        if (mounted && vils.isNotEmpty) {
          setState(() => _villages = vils);
        }
      }
    } catch (e) {
      debugPrint('Loading villages failed: $e');
    } finally {
      if (mounted) setState(() => _loadingVillages = false);
    }
  }

  void _onVillageChanged(int? villageId) {
    setState(() {
      _selectedVillageId = villageId;

      final village = _villages
          .where((item) => item.id == villageId)
          .firstOrNull;

      if (village != null) {
        _values['Village'] = village.name;
        _values['Rural / Urban'] = village.areaType ?? 'Rural';

        if (village.pincode != null) {
          _values['PIN Code'] = village.pincode!;
          _controller('PIN Code').text = village.pincode!;
        }
      } else {
        _values.remove('Village');
      }
    });
    _scheduleDraftSave();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();

    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  TextEditingController _controller(String label) {
    return _controllers.putIfAbsent(label, () => TextEditingController());
  }

  String _value(String label) {
    if (label == 'State') {
      final match = _states.where((item) => item.id == _selectedStateId);
      if (match.isNotEmpty) return match.first.name;
      if (_selectedStateId != null) return 'State #$_selectedStateId';
    }
    if (label == 'District') {
      final match = _districts.where((item) => item.id == _selectedDistrictId);
      if (match.isNotEmpty) return match.first.name;
      if (_selectedDistrictId != null) return 'District #$_selectedDistrictId';
    }
    if (label == 'Block') {
      final match = _blocks.where((item) => item.id == _selectedBlockId);
      if (match.isNotEmpty) return match.first.name;
      if (_selectedBlockId != null) return 'Block #$_selectedBlockId';
    }
    if (label == 'Gram Panchayat') {
      final match = _gramPanchayats.where((item) => item.id == _selectedGramPanchayatId);
      if (match.isNotEmpty) return match.first.name;
      if (_selectedGramPanchayatId != null) return 'GP #$_selectedGramPanchayatId';
    }
    if (label == 'Village') {
      final match = _villages.where((item) => item.id == _selectedVillageId);
      if (match.isNotEmpty) return match.first.name;
      if (_selectedVillageId != null) return 'Village #$_selectedVillageId';
    }
    return _values[label] ?? _controllers[label]?.text ?? '';
  }

  // ADD THIS METHOD BELOW _value()

  String? _toApiDate(String value) {
    final input = value.trim();

    if (input.isEmpty) return null;

    // Already in YYYY-MM-DD format.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) {
      return input;
    }

    // Convert DD/MM/YYYY or DD-MM-YYYY to YYYY-MM-DD.
    final match = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})$').firstMatch(input);

    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      // Validate the calendar date.
      final date = DateTime(year, month, day);

      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }

      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    }

    return null;
  }

  Map<String, dynamic> _serializeDraft() {
    return {
      'form_state': {
        'controllers': {
          for (final entry in _controllers.entries) entry.key: entry.value.text,
        },
        'values': Map<String, String>.from(_values),
        'switches': Map<String, bool>.from(_switches),
        'vulnerabilities': _vulnerabilities.toList(),
        'selected_state_id': _selectedStateId,
        'selected_district_id': _selectedDistrictId,
        'selected_block_id': _selectedBlockId,
        'selected_gram_panchayat_id': _selectedGramPanchayatId,
        'selected_village_id': _selectedVillageId,
        'current_step': _step,
      },
      // Keep the final API payload alongside the editable form state.
      'payload': _buildBeneficiaryPayload(),
    };
  }

  Future<void> _saveDraftNow({bool throwOnError = false}) async {
    if (_isRestoringDraft || !mounted) return;

    _draftSaveTimer?.cancel();

    setState(() => _isSavingDraft = true);

    try {
      final id = await _localDao.saveDraft(
        localId: _localDraftId,
        formData: _serializeDraft(),
        currentStep: _step,
      );

      if (!mounted) return;

      setState(() {
        _localDraftId = id;
        _draftSaveError = null;
      });
    } catch (e) {
      debugPrint('Local draft save failed: ${e.runtimeType}');

      if (mounted) {
        setState(() => _draftSaveError = 'Unable to save draft locally.');
      }
      if (throwOnError) rethrow;
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }
  }

  void _scheduleDraftSave() {
    if (_isRestoringDraft) return;

    _draftSaveTimer?.cancel();

    _draftSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => _saveDraftNow(),
    );
  }

  Widget _textField(
    String label, {
    bool required = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool onlyAlphabets = false,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final formatters = <TextInputFormatter>[
      if (onlyAlphabets)
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zs]')),
      if (inputFormatters != null) ...inputFormatters,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, required),
          const SizedBox(height: 6),
          TextFormField(
            controller: _controller(label),
            keyboardType: keyboardType,
            inputFormatters: formatters.isNotEmpty ? formatters : null,
            maxLength: maxLength,
            buildCounter: maxLength != null
                ? (context, {required currentLength, required isFocused, maxLength}) => null
                : null,
            decoration: _inputDecoration(hint ?? 'Enter $label'),
            onChanged: (_) => _scheduleDraftSave(),
            validator: validator ??
                (value) {
                  final trimmed = value?.trim() ?? '';
                  if (required && trimmed.isEmpty) {
                    return 'Please enter $label';
                  }
                  if (trimmed.isNotEmpty && onlyAlphabets) {
                    if (!RegExp(r'^[a-zA-Zs]+$').hasMatch(trimmed)) {
                      return '$label must contain only alphabetical characters';
                    }
                  }
                  return null;
                },
          ),
        ],
      ),
    );
  }

  Widget _dateField(
    String label, {
    bool required = false,
    String? hint,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final controller = _controller(label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, required),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            readOnly: true,
            onTap: () async {
              await _pickDate(
                label: label,
                firstDate: firstDate,
                lastDate: lastDate,
              );
            },
            decoration: _inputDecoration(hint ?? 'Select $label').copyWith(
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: green,
                  size: 20,
                ),
                onPressed: () async {
                  await _pickDate(
                    label: label,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                },
              ),
            ),
            validator: required
                ? (value) => value == null || value.trim().isEmpty
                      ? 'Please select $label'
                      : null
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({
    required String label,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final controller = _controller(label);
    final now = DateTime.now();

    DateTime initialDate = now;
    final currentText = controller.text.trim();

    if (currentText.isNotEmpty) {
      final dmyMatch = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$')
          .firstMatch(currentText);
      if (dmyMatch != null) {
        final d = int.tryParse(dmyMatch.group(1)!);
        final m = int.tryParse(dmyMatch.group(2)!);
        final y = int.tryParse(dmyMatch.group(3)!);
        if (d != null && m != null && y != null) {
          final parsed = DateTime(y, m, d);
          if (parsed.year == y && parsed.month == m && parsed.day == d) {
            initialDate = parsed;
          }
        }
      } else {
        final ymdMatch = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$')
            .firstMatch(currentText);
        if (ymdMatch != null) {
          final y = int.tryParse(ymdMatch.group(1)!);
          final m = int.tryParse(ymdMatch.group(2)!);
          final d = int.tryParse(ymdMatch.group(3)!);
          if (d != null && m != null && y != null) {
            final parsed = DateTime(y, m, d);
            if (parsed.year == y && parsed.month == m && parsed.day == d) {
              initialDate = parsed;
            }
          }
        }
      }
    } else if (label.toLowerCase().contains('birth') ||
        label.toLowerCase().contains('dob')) {
      initialDate = DateTime(now.year - 25, now.month, now.day);
    }

    final effectiveFirstDate = firstDate ?? DateTime(1900, 1, 1);
    final effectiveLastDate = lastDate ?? now.add(const Duration(days: 365));

    if (initialDate.isBefore(effectiveFirstDate)) {
      initialDate = effectiveFirstDate;
    } else if (initialDate.isAfter(effectiveLastDate)) {
      initialDate = effectiveLastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
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
      final formattedDay = picked.day.toString().padLeft(2, '0');
      final formattedMonth = picked.month.toString().padLeft(2, '0');
      final formattedDate = '$formattedDay-$formattedMonth-${picked.year}';

      setState(() {
        controller.text = formattedDate;
        _values[label] = formattedDate;

        if (label.toLowerCase().contains('birth') ||
            label.toLowerCase().contains('dob')) {
          int age = now.year - picked.year;
          if (now.month < picked.month ||
              (now.month == picked.month && now.day < picked.day)) {
            age--;
          }
          if (age >= 0) {
            _controller('Age').text = age.toString();
            _values['Age'] = age.toString();
          }
        }
      });

      _scheduleDraftSave();
    }
  }

  Widget _fieldLabel(String label, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF26352E),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          children: [
            TextSpan(text: label),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA8A1), fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDCE6E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDCE6E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: green, width: 1.3),
      ),
    );
  }

  Widget _dropdown(
    String label, {
    bool required = false,
    List<String>? choices,
  }) {
    final items = choices ?? _options[label] ?? [];
    final selected = _values[label];
    final validValue = selected != null && items.contains(selected)
        ? selected
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, required),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: validValue,
            isExpanded: true,
            decoration: _inputDecoration('Select $label'),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                if (value == null) {
                  _values.remove(label);
                } else {
                  _values[label] = value;
                  if (label == 'Do you earn?' && value != 'Yes') {
                    _values.remove('Occupation');
                    _values.remove('What is your monthly income?');
                  }
                }
              });

              _scheduleDraftSave();
            },
            validator: required
                ? (value) => value == null ? 'Please select $label' : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget _locationDropdown({
    required String label,
    required List<LocationModel> locations,
    required int? selectedId,
    required bool loading,
    required ValueChanged<int?> onChanged,
    bool required = false,
    bool isLocked = false,
  }) {
    final validIds = locations.map((item) => item.id).toSet();
    final effectiveLocations = List<LocationModel>.from(locations);

    if (selectedId != null && !validIds.contains(selectedId)) {
      effectiveLocations.add(
        LocationModel(
          id: selectedId,
          name: isLocked ? 'Assigned $label (ID: $selectedId)' : 'Location #$selectedId',
        ),
      );
    }

    final isActuallyLocked = isLocked && selectedId != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _fieldLabel(label, required),
              if (isActuallyLocked) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF81C784), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 10, color: Color(0xFF087443)),
                      SizedBox(width: 3),
                      Text(
                        'Assigned Jurisdiction',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF087443),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: effectiveLocations.any((item) => item.id == selectedId) ? selectedId : null,
            isExpanded: true,
            decoration: _inputDecoration(
              loading ? 'Loading $label...' : 'Select $label',
            ).copyWith(
              filled: isActuallyLocked,
              fillColor: isActuallyLocked ? const Color(0xFFF9FDF9) : null,
              suffixIcon: isActuallyLocked
                  ? const Tooltip(
                      message: 'This field is locked to your allocated jurisdiction',
                      child: Icon(Icons.lock_outline, size: 18, color: Color(0xFF087443)),
                    )
                  : null,
            ),
            items: effectiveLocations.map((item) {
              return DropdownMenuItem<int>(
                value: item.id,
                child: Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActuallyLocked ? FontWeight.w600 : FontWeight.normal,
                    color: isActuallyLocked ? const Color(0xFF1E293B) : null,
                  ),
                ),
              );
            }).toList(),
            onChanged: (loading || isActuallyLocked) ? null : onChanged,
            validator: (value) {
              if (required && value == null) {
                return 'Please select $label';
              }
              if (isActuallyLocked && value != selectedId) {
                return 'You can only register beneficiaries in your assigned $label';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _yesNo(
    String label, {
    bool required = false,
    bool defaultYes = false,
  }) {
    final value = _switches[label] ?? defaultYes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, required),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  activeColor: green,
                  title: const Text('Yes', style: TextStyle(fontSize: 12)),
                  value: true,
                  groupValue: value,
                  onChanged: (v) {
                    setState(() => _switches[label] = v!);
                    _scheduleDraftSave();
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  activeColor: green,
                  title: const Text('No', style: TextStyle(fontSize: 12)),
                  value: false,
                  groupValue: value,
                  onChanged: (v) {
                    setState(() => _switches[label] = v!);
                    _scheduleDraftSave();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, Widget child) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5F6EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: green, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF182E25),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return _section(
      'Beneficiary Details',
      Icons.person_outline,
      Column(
        children: [
          _dateField(
            'Registration Date',
            required: true,
            hint: 'DD-MM-YYYY',
            firstDate: DateTime(2000, 1, 1),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          ),
          _textField('Beneficiary Name', required: true, onlyAlphabets: true),
          _textField("Father's Name", onlyAlphabets: true),
          _textField("Mother's Name", onlyAlphabets: true),
          _textField('Spouse Name', onlyAlphabets: true),
          _dropdown('Care Of (Relation)'),
          _textField('Care Of (Name)', onlyAlphabets: true),
          _dropdown('Gender', required: true),
          _dateField(
            'Date of Birth',
            hint: 'DD-MM-YYYY',
            firstDate: DateTime(1900, 1, 1),
            lastDate: DateTime.now(),
          ),
          _textField('Age', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLength: 3),
          _textField(
            'Mobile Number',
            keyboardType: TextInputType.phone,
            hint: '10-digit number',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isNotEmpty && trimmed.length != 10) {
                return 'Mobile Number must be 10 digits';
              }
              return null;
            },
          ),
          _textField(
            'Alternate Mobile',
            keyboardType: TextInputType.phone,
            hint: '10-digit number',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isNotEmpty && trimmed.length != 10) {
                return 'Alternate Mobile must be 10 digits';
              }
              return null;
            },
          ),
          _textField(
            'Aadhaar Number',
            keyboardType: TextInputType.number,
            hint: '12-digit number',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 12,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isNotEmpty && trimmed.length != 12) {
                return 'Aadhaar Number must be 12 digits';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return _section(
      'Address',
      Icons.location_on_outlined,
      Column(
        children: [
          _locationDropdown(
            label: 'State',
            locations: _states,
            selectedId: _selectedStateId,
            loading: _loadingStates,
            required: true,
            isLocked: _assignedLocation?.hasAssignedState == true,
            onChanged: _onStateChanged,
          ),
          _locationDropdown(
            label: 'District',
            locations: _districts,
            selectedId: _selectedDistrictId,
            loading: _loadingDistricts,
            required: true,
            isLocked: _assignedLocation?.hasAssignedDistrict == true,
            onChanged: _onDistrictChanged,
          ),
          _locationDropdown(
            label: 'Block',
            locations: _blocks,
            selectedId: _selectedBlockId,
            loading: _loadingBlocks,
            isLocked: _assignedLocation?.hasAssignedBlock == true,
            onChanged: _onBlockChanged,
          ),
          _locationDropdown(
            label: 'Gram Panchayat',
            locations: _gramPanchayats,
            selectedId: _selectedGramPanchayatId,
            loading: _loadingGramPanchayats,
            onChanged: _onGramPanchayatChanged,
          ),
          _locationDropdown(
            label: 'Village',
            locations: _villages,
            selectedId: _selectedVillageId,
            loading: _loadingVillages,
            onChanged: _onVillageChanged,
          ),

          _textField('Village (if not listed)'),
          _textField('Post Office'),
          _textField('Address', hint: 'Enter full address'),
          _textField('PIN Code', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLength: 6),
          _dropdown('Rural / Urban', required: true),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        _section(
          'Identity & Citizenship',
          Icons.person_outline,
          Column(
            children: [
              _yesNo(
                'Are you an Indian Citizen?',
                required: true,
                defaultYes: true,
              ),
              _dropdown('Category', required: true),
              _dropdown('Marital Status', required: true),
            ],
          ),
        ),
        _section(
          'Household',
          Icons.home_outlined,
          _yesNo('Do you have any children?', required: true, defaultYes: true),
        ),
      ],
    );
  }

  Widget _documentCheckbox(String field) {
    final isChecked = _switches[field] ?? (_values[field] == 'Available');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isChecked ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked ? green : const Color(0xFFDCE6E0),
          width: isChecked ? 1.2 : 1.0,
        ),
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (bool? checked) {
          setState(() {
            final val = checked == true;
            _switches[field] = val;
            _values[field] = val ? 'Available' : 'Not available';
          });
          _scheduleDraftSave();
        },
        activeColor: green,
        checkColor: Colors.white,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          field,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
            color: isChecked ? darkGreen : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          isChecked ? 'Available' : 'Not available',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
            color: isChecked ? green : const Color(0xFF8C9B93),
          ),
        ),
      ),
    );
  }

  Widget _buildStep4() {
    const documentFields = [
      'Aadhaar Card',
      'PAN Card',
      'Birth Certificate',
      'Voter ID Card',
      'Death Certificate of Husband/Father/Primary Earner of Family',
      'Income Certificate',
      'Caste Certificate',
      'Antyodaya Anna Yojana (AAY) ration card',
      'Priority Household (PHH) ration card',
      'Disability Card',
    ];

    final isEarning = _value('Do you earn?') == 'Yes';

    return Column(
      children: [
        _section(
          'Livelihood',
          Icons.work_outline,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dropdown('Do you earn?', required: true),
              if (isEarning) ...[
                _dropdown('Occupation', required: true),
                _dropdown('What is your monthly income?', required: true),
              ],
            ],
          ),
        ),
        _section(
          'Document Checklist',
          Icons.description_outlined,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Check all documents available with the beneficiary:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5A6B62),
                  ),
                ),
              ),
              ...documentFields.map((field) => _documentCheckbox(field)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep5() {
    return Column(
      children: [
        _section(
          'Financial Inclusion',
          Icons.account_balance_outlined,
          Column(
            children: [
              _yesNo('Do you have a bank account?', required: true),
              _yesNo(
                'Is Phone Number Linked with Aadhaar Card?',
                required: true,
              ),
            ],
          ),
        ),
        _section(
          'Vulnerability',
          Icons.groups_outlined,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Vulnerability Group', true),
              const SizedBox(height: 8),
              ..._vulnerabilityOptions.map(
                (option) => CheckboxListTile(
                  value: _vulnerabilities.contains(option),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _vulnerabilities.add(option);
                      } else {
                        _vulnerabilities.remove(option);
                      }
                    });

                    _scheduleDraftSave();
                  },
                  activeColor: green,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(option, style: const TextStyle(fontSize: 12)),
                ),
              ),
              const Text(
                'Tick every group that applies.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewSection(String title, List<String> fields, IconData icon) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5EEE8)),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: green),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        trailing: TextButton(
          onPressed: () {
            final index = _stepTitles.indexOf(title);
            if (index >= 0) setState(() => _step = index);
          },
          child: const Text('Edit'),
        ),
        children: fields.map((field) {
          String value = _value(field);
          if (_switches.containsKey(field)) {
            final isYesNoQuestion = field.endsWith('?') ||
                field.toLowerCase().startsWith('is ') ||
                field.toLowerCase().startsWith('do ');
            value = _switches[field]!
                ? (isYesNoQuestion ? 'Yes' : 'Available')
                : (isYesNoQuestion ? 'No' : 'Not available');
          }
          if (value.isEmpty) value = 'Not provided';

          return ListTile(
            dense: true,
            title: Text(field, style: const TextStyle(fontSize: 12)),
            subtitle: Text(value, style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep6() {
    return Column(
      children: [
        const Text(
          'Please review the information before submitting.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 14),
        _reviewSection('Beneficiary Details', [
          'Registration Date',
          'Beneficiary Name',
          "Father's Name",
          "Mother's Name",
          'Spouse Name',
          'Care Of (Relation)',
          'Care Of (Name)',
          'Gender',
          'Date of Birth',
          'Age',
          'Mobile Number',
          'Alternate Mobile',
          'Aadhaar Number',
        ], Icons.person_outline),
        _reviewSection('Address', [
          'State',
          'District',
          'Block',
          'Gram Panchayat',
          'Village',
          'Village (if not listed)',
          'Post Office',
          'Address',
          'PIN Code',
          'Rural / Urban',
        ], Icons.location_on_outlined),
        _reviewSection('Identity & Citizenship', [
          'Are you an Indian Citizen?',
          'Category',
          'Marital Status',
          'Do you have any children?',
        ], Icons.person_outline),
        _reviewSection('Livelihood & Documents', [
          'Do you earn?',
          if (_value('Do you earn?') == 'Yes') ...[
            'Occupation',
            'What is your monthly income?',
          ],
          'Aadhaar Card',
          'PAN Card',
          'Birth Certificate',
          'Voter ID Card',
          'Death Certificate of Husband/Father/Primary Earner of Family',
          'Income Certificate',
          'Caste Certificate',
          'Antyodaya Anna Yojana (AAY) ration card',
          'Priority Household (PHH) ration card',
          'Disability Card',
        ], Icons.description_outlined),
        _reviewSection('Financial Inclusion', [
          'Do you have a bank account?',
          'Is Phone Number Linked with Aadhaar Card?',
        ], Icons.account_balance_outlined),
        Card(
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.groups_outlined, color: green),
            title: const Text(
              'Vulnerability Groups',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              _vulnerabilities.isEmpty
                  ? 'None selected'
                  : _vulnerabilities.join(', '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _step = 4),
              child: const Text('Edit'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _switches['Confirmation'] ?? false,
          onChanged: (value) {
            setState(() {
              _switches['Confirmation'] = value ?? false;
            });

            _scheduleDraftSave();
          },
          activeColor: green,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I confirm that the information provided is correct to the best '
            'of my knowledge. I understand that this data will be used for '
            'identifying eligible social security schemes.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ),
        const SizedBox(height: 6),
        CheckboxListTile(
          value: _switches['PrivacyConsent'] ?? false,
          onChanged: (value) {
            setState(() {
              _switches['PrivacyConsent'] = value ?? false;
            });

            _scheduleDraftSave();
          },
          activeColor: green,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I confirm that the data provided will be kept private and confidential, '
            'will only be utilized for checking eligibility for schemes, '
            'and personal data will not be disclosed to anyone else.',
            style: TextStyle(fontSize: 11, height: 1.5),
          ),
        ),
      ],
    );
  }

  bool _validateCurrentStep() {
    if (_step == 1) {
      if (_selectedStateId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select State.')),
        );
        return false;
      }
      if (_assignedLocation?.hasAssignedState == true &&
          _selectedStateId != _assignedLocation!.stateId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only register beneficiaries in your assigned state.'),
          ),
        );
        return false;
      }
      if (_selectedDistrictId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select District.')),
        );
        return false;
      }
      if (_assignedLocation?.hasAssignedDistrict == true &&
          _selectedDistrictId != _assignedLocation!.districtId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only register beneficiaries in your assigned district.'),
          ),
        );
        return false;
      }
      if (_assignedLocation?.hasAssignedBlock == true &&
          _selectedBlockId != null &&
          _selectedBlockId != _assignedLocation!.blockId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only register beneficiaries in your assigned block.'),
          ),
        );
        return false;
      }
    }

    if (_step == 5) {
      if (!(_switches['Confirmation'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please confirm the information before submitting.'),
          ),
        );
        return false;
      }
      if (!(_switches['PrivacyConsent'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please confirm the data privacy declaration before submitting.'),
          ),
        );
        return false;
      }
      return true;
    }

    if (_step == 4 && _vulnerabilities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one vulnerability group.'),
        ),
      );
      return false;
    }

    return _formKey.currentState?.validate() ?? true;
  }

  Future<void> _next() async {
    if (!_validateCurrentStep()) return;

    if (_step < 5) {
      setState(() => _step++);

      await _saveDraftNow();
      return;
    }

    await _submitBeneficiary();
  }

  Map<String, dynamic> _buildBeneficiaryPayload() {
    String? cleanString(String label) {
      final value = _value(label).trim();
      return value.isEmpty ? null : value;
    }

    String? cleanDigits(String label) {
      final value = _value(label).replaceAll(RegExp(r'\s+|-'), '').trim();
      return value.isEmpty ? null : value;
    }

    String? mapCategory(String? cat) {
      if (cat == null || cat.isEmpty || cat == 'Not recorded') return null;
      switch (cat.toUpperCase()) {
        case 'GENERAL':
          return 'GEN';
        case 'SC':
          return 'SC';
        case 'ST':
          return 'ST';
        case 'OBC':
          return 'OBC';
        default:
          return 'OTHER';
      }
    }

    String? mapMaritalStatus(String? status) {
      if (status == null || status.isEmpty || status == 'Not recorded') return null;
      switch (status.toUpperCase()) {
        case 'UNMARRIED':
          return 'UNMARRIED';
        case 'MARRIED':
          return 'MARRIED';
        case 'WIDOWED':
          return 'WIDOWED';
        case 'DIVORCED':
          return 'DIVORCED';
        case 'SEPARATED':
          return 'SEPARATED';
        default:
          return status.toUpperCase();
      }
    }

    String? mapEarningStatus(String? status) {
      if (status == null || status.isEmpty || status == 'Not recorded') return null;
      return status.toUpperCase() == 'YES' ? 'YES' : 'NO';
    }

    String? mapOccupation(String? occ) {
      if (occ == null || occ.isEmpty || occ == 'Not recorded') return null;
      switch (occ) {
        case 'Agricultural Labourer':
          return 'AGRI_LABOUR';
        case 'Cultivator / Farmer':
          return 'CULTIVATOR';
        case 'Daily Wage Labourer':
          return 'DAILY_WAGE';
        case 'Construction Worker':
          return 'CONSTRUCTION';
        case 'Domestic Worker':
          return 'DOMESTIC';
        case 'Street Vendor':
          return 'STREET_VENDOR';
        case 'Artisan / Weaver':
          return 'ARTISAN';
        case 'Fisherman':
          return 'FISHERMAN';
        case 'Small Business / Shop':
          return 'SMALL_BUSINESS';
        case 'Salaried - Private':
          return 'PRIVATE_JOB';
        case 'Salaried - Government':
          return 'GOVT_JOB';
        case 'Self-employed / Own Account':
          return 'SELF_EMPLOYED';
        case 'Student':
          return 'STUDENT';
        case 'Homemaker':
          return 'HOMEMAKER';
        case 'Unemployed':
          return 'UNEMPLOYED';
        case 'Retired':
          return 'RETIRED';
        case 'Unable to Work':
          return 'UNABLE';
        case 'Other':
          return 'OTHER';
        case 'Trader':
          return 'TRADER';
        case 'Weaver':
          return 'WEAVER';
        case 'Unorganized Sector':
          return 'UNORGANIZED';
        case 'Service':
          return 'SERVICE';
        default:
          return occ.toUpperCase().replaceAll(' ', '_');
      }
    }

    String? mapMonthlyIncomeBand(String? inc) {
      if (inc == null || inc.isEmpty || inc == 'Not recorded') return null;
      switch (inc) {
        case 'No income':
          return 'NO_INCOME';
        case 'Less than ₹25,000':
        case 'Less than Rs 25,000':
          return 'BELOW_25K';
        case '₹25,000–₹50,000':
        case '₹25,000-₹50,000':
        case 'Rs 25,000-50,000':
          return '25K_50K';
        case '₹50,000–₹75,000':
        case '₹50,000-₹75,000':
        case 'Rs 50,000-75,000':
          return '50K_75K';
        case 'Less than ₹1,00,000':
        case 'Less than Rs 1,00,000':
          return 'BELOW_1L';
        case 'More than ₹1,00,000':
        case 'More than Rs 1,00,000':
          return 'ABOVE_1L';
        case 'Less than ₹8,00,000':
        case 'Less than Rs 8,00,000':
          return 'BELOW_8L';
        default:
          return inc;
      }
    }

    List<String> mapVulnerabilities(Set<String> vulns) {
      const Map<String, String> mapping = {
        'Migrant Labor': 'MIGRANT',
        'Female Sex Workers (FSW)': 'FSW',
        'Affected by Natural Calamities': 'CALAMITY',
        'Affected by Conflict': 'CONFLICT',
        'Victims/Survivors of Violence and Abuse': 'VIOLENCE',
        'Victims and Survivors of Trafficking': 'TRAFFICKING',
        'Tribal Population': 'TRIBAL',
        'Minority Group': 'MINORITY',
        'Orphan Child': 'ORPHAN',
        'Single Parent': 'SINGLE_PARENT',
        'Child in Need of Care and Protection': 'CNCP',
        'Displaced': 'DISPLACED',
        'Elderly': 'ELDERLY',
        'PWD/Chronic Diseases': 'PWD_CHRONIC',
        'LGBTQ+': 'LGBTQ',
      };
      return vulns.map((v) => mapping[v] ?? v).toList();
    }

    final categoryCode = mapCategory(cleanString('Category'));
    final maritalStatusCode = mapMaritalStatus(cleanString('Marital Status'));
    final earningStatusCode = mapEarningStatus(cleanString('Do you earn?'));
    final vulnCodes = mapVulnerabilities(_vulnerabilities);

    final rawOccupation = cleanString('Occupation');
    final rawMonthlyIncome = cleanString('What is your monthly income?');
    final occupationCode = (earningStatusCode == 'YES') ? mapOccupation(rawOccupation) : null;
    final monthlyIncomeBand = (earningStatusCode == 'NO')
        ? 'NO_INCOME'
        : ((earningStatusCode == 'YES') ? mapMonthlyIncomeBand(rawMonthlyIncome) : null);

    final bool isIndian = _switches['Are you an Indian Citizen?'] ?? true;
    final bool hasChildren = _switches['Do you have any children?'] ?? false;
    final bool hasBank = _switches['Do you have a bank account?'] ?? false;
    final bool aadhaarLinked = _switches['Is Phone Number Linked with Aadhaar Card?'] ?? false;

    bool isDocAvailable(String docName) {
      if (_switches.containsKey(docName)) {
        return _switches[docName] == true;
      }
      final str = cleanString(docName);
      return str == 'Available' || str == 'Yes';
    }

    final docAadhaar = isDocAvailable('Aadhaar Card') ? 'Yes' : 'No';
    final docPan = isDocAvailable('PAN Card') ? 'Yes' : 'No';
    final docBirth = isDocAvailable('Birth Certificate') ? 'Yes' : 'No';
    final docVoter = isDocAvailable('Voter ID Card') ? 'Yes' : 'No';
    final docDeath = isDocAvailable('Death Certificate of Husband/Father/Primary Earner of Family') ? 'Yes' : 'No';
    final docIncome = isDocAvailable('Income Certificate') ? 'Yes' : 'No';
    final docCaste = isDocAvailable('Caste Certificate') ? 'Yes' : 'No';
    final docAay = isDocAvailable('Antyodaya Anna Yojana (AAY) ration card') ? 'Yes' : 'No';
    final docPhh = isDocAvailable('Priority Household (PHH) ration card') ? 'Yes' : 'No';
    final docDisability = isDocAvailable('Disability Card') ? 'Yes' : 'No';

    final answers = <String, dynamic>{
      'is_indian_citizen': isIndian ? 'Yes' : 'No',
      if (categoryCode != null) 'social_category': categoryCode,
      if (categoryCode == 'OTHER' && cleanString('If Other, please mention') != null)
        'social_category_other': cleanString('If Other, please mention'),
      if (maritalStatusCode != null) 'marital_status': maritalStatusCode,
      'has_children': hasChildren ? 'Yes' : 'No',
      if (hasChildren) ...{
        if (_values['No. of girl child'] != null)
          'girl_child_count': int.tryParse(_values['No. of girl child']!) ?? 0,
        if (_values['No. of boy child'] != null)
          'boy_child_count': int.tryParse(_values['No. of boy child']!) ?? 0,
      },
      if (earningStatusCode != null) 'earning_status': earningStatusCode,
      if (occupationCode != null) 'occupation': occupationCode,
      if (rawOccupation != null && rawOccupation != 'Not recorded') 'occupation_name': rawOccupation,
      if (monthlyIncomeBand != null) 'monthly_income_band': monthlyIncomeBand,
      if (rawMonthlyIncome != null && rawMonthlyIncome != 'Not recorded') 'monthly_income': rawMonthlyIncome,
      if (occupationCode == 'CULTIVATOR' || occupationCode == 'AGRI_LABOUR') ...{
        'is_farmer': 1,
        'farmer_category': occupationCode == 'CULTIVATOR' ? 'SMALL_MARGINAL' : 'LABOUR',
      },
      'doc_aadhaar': docAadhaar,
      'doc_pan': docPan,
      'doc_birth_certificate': docBirth,
      'doc_voter_id': docVoter,
      'doc_death_certificate': docDeath,
      'has_income_certificate': docIncome,
      'has_caste_certificate': docCaste,
      'doc_ration_aay': docAay,
      'doc_ration_phh': docPhh,
      'doc_disability_card': docDisability,
      'has_bank_account': hasBank ? 'Yes' : 'No',
      'phone_aadhaar_linked': aadhaarLinked ? 'Yes' : 'No',
      'consent_given': ((_switches['Confirmation'] ?? true) && (_switches['PrivacyConsent'] ?? true)) ? 'Yes' : 'No',
      'privacy_consent_given': (_switches['PrivacyConsent'] ?? true) ? 'Yes' : 'No',
      if (vulnCodes.isNotEmpty) 'vulnerability_group': vulnCodes.join(','),
      // Derived profile helpers for offline matching engine
      if (docAay == 'Yes' || docPhh == 'Yes') ...{
        'has_ration_card': 1,
        'bpl_status': 'Yes',
        'ration_card_type': docAay == 'Yes' ? 'AAY' : 'PHH',
      },
      if (vulnCodes.contains('ELDERLY')) 'senior_citizen': 1,
      if (vulnCodes.contains('PWD_CHRONIC') || docDisability == 'Yes') 'has_disability': 1,
      if (vulnCodes.contains('TRIBAL')) 'social_category': 'ST',
      if (vulnCodes.contains('MINORITY')) 'is_minority': 1,
      if (vulnCodes.contains('MIGRANT')) 'is_migrant': 1,
      if (earningStatusCode == 'NO' || monthlyIncomeBand == 'NO_INCOME') 'annual_income': 0,
    };

    final regDate = _toApiDate(_value('Registration Date')) ??
        DateTime.now().toIso8601String().split('T').first;

    String? relationType = cleanString('Care Of (Relation)');
    if (relationType == 'Spouse') {
      relationType = 'Husband';
    }

    return {
      'registration_date': regDate,
      'name': _value('Beneficiary Name').trim(),
      'relation_type': relationType,
      'relation_name': cleanString('Care Of (Name)'),
      'father_name': cleanString("Father's Name"),
      'mother_name': cleanString("Mother's Name"),
      'spouse_name': cleanString('Spouse Name'),
      'gender': cleanString('Gender'),
      'dob': _toApiDate(_value('Date of Birth')),
      'age': int.tryParse(_value('Age').trim()),
      'mobile': cleanDigits('Mobile Number'),
      'alt_mobile': cleanDigits('Alternate Mobile'),
      'aadhaar_number': cleanDigits('Aadhaar Number'),

      // Location IDs
      'state_id': _selectedStateId ?? _assignedLocation?.stateId,
      'district_id': _selectedDistrictId ?? _assignedLocation?.districtId,
      'block_id': _selectedBlockId ?? _assignedLocation?.blockId,
      'gram_panchayat_id': _selectedGramPanchayatId,
      'village_id': _selectedVillageId,

      'village_name':
          cleanString('Village (if not listed)') ?? cleanString('Village'),
      'post_office': cleanString('Post Office'),
      'address_line': cleanString('Address'),
      'pincode': cleanDigits('PIN Code'),
      'area_type': cleanString('Rural / Urban'),
      if (occupationCode != null) 'occupation': occupationCode,
      if (rawOccupation != null && rawOccupation != 'Not recorded') 'occupation_name': rawOccupation,
      if (monthlyIncomeBand != null) 'monthly_income_band': monthlyIncomeBand,
      if (rawMonthlyIncome != null && rawMonthlyIncome != 'Not recorded') 'monthly_income': rawMonthlyIncome,
      if (earningStatusCode == 'NO' || monthlyIncomeBand == 'NO_INCOME') 'annual_income': 0,
      'consent_given': (_switches['Confirmation'] ?? true) && (_switches['PrivacyConsent'] ?? true),
      'privacy_consent': _switches['PrivacyConsent'] ?? false,
      'remarks': '',
      'confirm_duplicate': false,
      'answers': answers,
      'complete': true,
    };
  }

  Future<void> _submitBeneficiary() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // Save the latest form values before queueing.
      await _saveDraftNow(throwOnError: true);

      if (!mounted) return;

      if (_localDraftId == null) {
        throw Exception('The draft could not be saved.');
      }

      // Mark this registration as waiting for server sync.
      await _localDao.submitLocally(_localDraftId!);

      // Try uploading queued registrations immediately.
      // If offline, the service records the failure for retry.
      await BeneficiarySyncService.instance.syncPendingRegistrations();

      final savedRecord = await _localDao.getRecord(_localDraftId!);
      final isSynced = savedRecord?['record_state'] == 'synced';

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            isSynced ? Icons.check_circle_outline : Icons.cloud_done_outlined,
            color: green,
            size: 48,
          ),
          title: Text(
            isSynced ? 'Beneficiary Registered' : 'Beneficiary Registered Offline',
          ),
          content: Text(
            isSynced
                ? 'The beneficiary was successfully registered and synced with the server.'
                : 'The beneficiary is registered and saved locally on this device.\n\nIt is now visible in your beneficiary list and can be synced using the Sync button on your Dashboard when connected to the internet.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Local beneficiary submission failed: ${e.runtimeType}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the beneficiary locally. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildDraftStatus() {
    if (_draftSaveError != null) {
      return const Text(
        'Draft could not be saved',
        style: TextStyle(color: Colors.red, fontSize: 11),
      );
    }

    if (_isSavingDraft) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 6),
          Text('Saving draft...', style: TextStyle(fontSize: 11)),
        ],
      );
    }

    if (_localDraftId != null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: green),
          SizedBox(width: 4),
          Text('Draft saved on device', style: TextStyle(fontSize: 11)),
        ],
      );
    }

    return const Text(
      'Draft not saved yet',
      style: TextStyle(fontSize: 11, color: Colors.grey),
    );
  }

  Widget _buildProgress() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: List.generate(6, (index) {
              final active = index == _step;
              final completed = index < _step;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active || completed
                            ? green
                            : const Color(0xFFE2EBE6),
                      ),
                      alignment: Alignment.center,
                      child: completed
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: active ? Colors.white : darkGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Step ${index + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        color: active ? green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 9),
          Text(
            '${_step + 1} of 6 • ${_stepTitles[_step]}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: darkGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentStep() {
    switch (_step) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      default:
        return _buildStep6();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Jan Kavach',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Register Beneficiary',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProgress(),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDraftStatus(),
                    if (_localDraftId != null)
                      OutlinedButton.icon(
                        onPressed: () => _restoreDraft(_localDraftId!),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reload saved draft'),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  child: _currentStep(),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5EEE8))),
                ),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            setState(() => _step--);
                            await _saveDraftNow();
                          },
                          icon: const Icon(Icons.arrow_back, size: 17),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: darkGreen,
                            side: const BorderSide(color: Color(0xFFB8D3C4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _step == 5 ? 'Submit Beneficiary' : 'Next',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _step == 5
                                        ? Icons.check_circle_outline
                                        : Icons.arrow_forward,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
