import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
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

  // Current Address State Variables
  List<LocationModel> _currentDistricts = [];
  List<LocationModel> _currentBlocks = [];
  List<LocationModel> _currentGramPanchayats = [];
  List<LocationModel> _currentVillages = [];

  int? _currentSelectedStateId;
  int? _currentSelectedDistrictId;
  int? _currentSelectedBlockId;
  int? _currentSelectedGramPanchayatId;
  int? _currentSelectedVillageId;

  bool _loadingCurrentDistricts = false;
  bool _loadingCurrentBlocks = false;
  bool _loadingCurrentGramPanchayats = false;
  bool _loadingCurrentVillages = false;

  bool _sameAsPermanentAddress = false;

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
    'Permanent Address',
    'Current Address',
    'Identity & Citizenship',
    'Livelihood & Documents',
    'Financial Inclusion',
    'Review & Submit',
  ];


  final Map<String, List<String>> _options = {
    'Care Of (Relation)': ['Father', 'Mother', 'Spouse', 'Guardian', 'Other'],
    'Gender': ['Male', 'Female', 'Other'],

    'Rural / Urban': ['Rural', 'Urban'],
    'Current Rural / Urban': ['Rural', 'Urban'],
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
        _step = _step.clamp(0, _stepTitles.length - 1);

        _selectedStateId = readId('selected_state_id');
        _selectedDistrictId = readId('selected_district_id');
        _selectedBlockId = readId('selected_block_id');
        _selectedGramPanchayatId = readId('selected_gram_panchayat_id');
        _selectedVillageId = readId('selected_village_id');

        _sameAsPermanentAddress = formState['same_as_permanent_address'] == true;
        _currentSelectedStateId = readId('current_selected_state_id');
        _currentSelectedDistrictId = readId('current_selected_district_id');
        _currentSelectedBlockId = readId('current_selected_block_id');
        _currentSelectedGramPanchayatId = readId('current_selected_gram_panchayat_id');
        _currentSelectedVillageId = readId('current_selected_village_id');

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

      if (_currentSelectedStateId != null) {
        _currentDistricts = await _geographyService.getDistricts(_currentSelectedStateId!);
      }

      if (_currentSelectedDistrictId != null) {
        _currentBlocks = await _geographyService.getBlocks(_currentSelectedDistrictId!);
      }

      if (_currentSelectedBlockId != null) {
        _currentGramPanchayats = await _geographyService.getGramPanchayats(
          _currentSelectedBlockId!,
        );
      }

      if (_currentSelectedGramPanchayatId != null) {
        _currentVillages = await _geographyService.getVillages(
          _currentSelectedGramPanchayatId!,
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

  // Current Address Handlers
  Future<void> _onCurrentStateChanged(int? stateId) async {
    setState(() {
      _currentSelectedStateId = stateId;
      _currentSelectedDistrictId = null;
      _currentSelectedBlockId = null;
      _currentSelectedGramPanchayatId = null;
      _currentSelectedVillageId = null;

      _currentDistricts = [];
      _currentBlocks = [];
      _currentGramPanchayats = [];
      _currentVillages = [];
    });

    _scheduleDraftSave();

    if (stateId == null) return;

    setState(() => _loadingCurrentDistricts = true);

    try {
      final locations = await _geographyService.getDistricts(stateId);
      if (!mounted) return;
      setState(() => _currentDistricts = locations);
    } catch (e) {
      debugPrint('Loading current districts failed: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingCurrentDistricts = false);
      }
    }
  }

  Future<void> _onCurrentDistrictChanged(int? districtId) async {
    setState(() {
      _currentSelectedDistrictId = districtId;
      _currentSelectedBlockId = null;
      _currentSelectedGramPanchayatId = null;
      _currentSelectedVillageId = null;
      _currentBlocks = [];
      _currentGramPanchayats = [];
      _currentVillages = [];
    });

    _scheduleDraftSave();

    if (districtId == null) return;

    setState(() => _loadingCurrentBlocks = true);
    try {
      final locations = await _geographyService.getBlocks(districtId);
      if (!mounted) return;
      setState(() => _currentBlocks = locations);
    } catch (e) {
      debugPrint('Loading current blocks failed: $e');
    } finally {
      if (mounted) setState(() => _loadingCurrentBlocks = false);
    }
  }

  Future<void> _onCurrentBlockChanged(int? blockId) async {
    setState(() {
      _currentSelectedBlockId = blockId;
      _currentSelectedGramPanchayatId = null;
      _currentSelectedVillageId = null;
      _currentGramPanchayats = [];
      _currentVillages = [];
    });

    _scheduleDraftSave();

    if (blockId == null) return;

    setState(() => _loadingCurrentGramPanchayats = true);
    try {
      final locations = await _geographyService.getGramPanchayats(blockId);
      if (!mounted) return;
      setState(() => _currentGramPanchayats = locations);
      if (locations.isEmpty) {
        final vils = await _geographyService.getVillagesByBlock(blockId);
        if (mounted && vils.isNotEmpty) {
          setState(() => _currentVillages = vils);
        }
      }
    } catch (e) {
      debugPrint('Loading current gram panchayats failed: $e');
    } finally {
      if (mounted) setState(() => _loadingCurrentGramPanchayats = false);
    }
  }

  Future<void> _onCurrentGramPanchayatChanged(int? gpId) async {
    setState(() {
      _currentSelectedGramPanchayatId = gpId;
      _currentSelectedVillageId = null;
      _currentVillages = [];
    });

    _scheduleDraftSave();

    if (gpId == null) {
      if (_currentSelectedBlockId != null) {
        final vils = await _geographyService.getVillagesByBlock(_currentSelectedBlockId!);
        if (mounted && vils.isNotEmpty) {
          setState(() => _currentVillages = vils);
        }
      }
      return;
    }

    setState(() => _loadingCurrentVillages = true);
    try {
      final locations = await _geographyService.getVillages(gpId);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        setState(() => _currentVillages = locations);
      } else if (_currentSelectedBlockId != null) {
        final vils = await _geographyService.getVillagesByBlock(_currentSelectedBlockId!);
        if (mounted && vils.isNotEmpty) {
          setState(() => _currentVillages = vils);
        }
      }
    } catch (e) {
      debugPrint('Loading current villages failed: $e');
    } finally {
      if (mounted) setState(() => _loadingCurrentVillages = false);
    }
  }

  void _onCurrentVillageChanged(int? villageId) {
    setState(() {
      _currentSelectedVillageId = villageId;

      final village = _currentVillages
          .where((item) => item.id == villageId)
          .firstOrNull;

      if (village != null) {
        _values['Current Village'] = village.name;
        _values['Current Rural / Urban'] = village.areaType ?? 'Rural';

        if (village.pincode != null) {
          _values['Current PIN Code'] = village.pincode!;
          _controller('Current PIN Code').text = village.pincode!;
        }
      } else {
        _values.remove('Current Village');
      }
    });
    _scheduleDraftSave();
  }

  void _copyPermanentToCurrent() {
    _currentSelectedStateId = _selectedStateId;
    _currentDistricts = List.from(_districts);
    _currentSelectedDistrictId = _selectedDistrictId;
    _currentBlocks = List.from(_blocks);
    _currentSelectedBlockId = _selectedBlockId;
    _currentGramPanchayats = List.from(_gramPanchayats);
    _currentSelectedGramPanchayatId = _selectedGramPanchayatId;
    _currentVillages = List.from(_villages);
    _currentSelectedVillageId = _selectedVillageId;

    _values['Current Village'] = _value('Village');

    _controller('Current Village (if not listed)').text =
        _controller('Village (if not listed)').text;
    _values['Current Village (if not listed)'] =
        _value('Village (if not listed)');

    _controller('Current Post Office').text =
        _controller('Post Office').text;
    _values['Current Post Office'] = _value('Post Office');

    _controller('Current Address').text = _controller('Address').text;
    _values['Current Address'] = _value('Address');

    _controller('Current PIN Code').text = _controller('PIN Code').text;
    _values['Current PIN Code'] = _value('PIN Code');

    final ruralUrban = _values['Rural / Urban'];
    if (ruralUrban != null) {
      _values['Current Rural / Urban'] = ruralUrban;
    }
  }

  Future<void> _toggleSameAsPermanent(bool isSame) async {
    setState(() {
      _sameAsPermanentAddress = isSame;
    });

    if (isSame) {
      setState(() {
        _copyPermanentToCurrent();
      });

      // Ensure dependent lists are loaded if they weren't already
      if (_currentSelectedStateId != null && _currentDistricts.isEmpty) {
        final dists = await _geographyService.getDistricts(_currentSelectedStateId!);
        if (mounted && _sameAsPermanentAddress) {
          setState(() => _currentDistricts = dists);
        }
      }
      if (_currentSelectedDistrictId != null && _currentBlocks.isEmpty) {
        final blks = await _geographyService.getBlocks(_currentSelectedDistrictId!);
        if (mounted && _sameAsPermanentAddress) {
          setState(() => _currentBlocks = blks);
        }
      }
      if (_currentSelectedBlockId != null && _currentGramPanchayats.isEmpty) {
        final gps = await _geographyService.getGramPanchayats(_currentSelectedBlockId!);
        if (mounted && _sameAsPermanentAddress) {
          setState(() => _currentGramPanchayats = gps);
        }
      }
      if (_currentSelectedGramPanchayatId != null && _currentVillages.isEmpty) {
        final vils = await _geographyService.getVillages(_currentSelectedGramPanchayatId!);
        if (mounted && _sameAsPermanentAddress) {
          setState(() => _currentVillages = vils);
        }
      }
    }

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
    if (label == 'Same as permanent address') {
      return _sameAsPermanentAddress ? 'Yes' : 'No';
    }
    if (label == 'Current State') {
      final match = _states.where((item) => item.id == _currentSelectedStateId);
      if (match.isNotEmpty) return match.first.name;
      if (_currentSelectedStateId != null) return 'State #$_currentSelectedStateId';
    }
    if (label == 'Current District') {
      final match = _currentDistricts.where((item) => item.id == _currentSelectedDistrictId);
      if (match.isNotEmpty) return match.first.name;
      if (_currentSelectedDistrictId != null) return 'District #$_currentSelectedDistrictId';
    }
    if (label == 'Current Block') {
      final match = _currentBlocks.where((item) => item.id == _currentSelectedBlockId);
      if (match.isNotEmpty) return match.first.name;
      if (_currentSelectedBlockId != null) return 'Block #$_currentSelectedBlockId';
    }
    if (label == 'Current Gram Panchayat') {
      final match = _currentGramPanchayats.where((item) => item.id == _currentSelectedGramPanchayatId);
      if (match.isNotEmpty) return match.first.name;
      if (_currentSelectedGramPanchayatId != null) return 'GP #$_currentSelectedGramPanchayatId';
    }
    if (label == 'Current Village') {
      final match = _currentVillages.where((item) => item.id == _currentSelectedVillageId);
      if (match.isNotEmpty) return match.first.name;
      if (_currentSelectedVillageId != null) return 'Village #$_currentSelectedVillageId';
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
        'same_as_permanent_address': _sameAsPermanentAddress,
        'current_selected_state_id': _currentSelectedStateId,
        'current_selected_district_id': _currentSelectedDistrictId,
        'current_selected_block_id': _currentSelectedBlockId,
        'current_selected_gram_panchayat_id': _currentSelectedGramPanchayatId,
        'current_selected_village_id': _currentSelectedVillageId,
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
    String? displayLabel,
    bool required = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool onlyAlphabets = false,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    final effectiveLabel = displayLabel ?? label;
    final formatters = <TextInputFormatter>[
      if (onlyAlphabets)
        FilteringTextInputFormatter.allow(RegExp(r'[\p{L}\p{M}\s\.\-]', unicode: true)),
      if (inputFormatters != null) ...inputFormatters,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(effectiveLabel, required),
          const SizedBox(height: 6),
          TextFormField(
            controller: _controller(label),
            readOnly: readOnly,
            keyboardType: keyboardType,
            inputFormatters: formatters.isNotEmpty ? formatters : null,
            maxLength: maxLength,
            buildCounter: maxLength != null
                ? (context, {required currentLength, required isFocused, maxLength}) => null
                : null,
            decoration: _inputDecoration(
              hint ??
                  context.tr(
                    'registration.enter_field',
                    args: {'field': effectiveLabel},
                  ),
            ).copyWith(
              filled: readOnly,
              fillColor: readOnly ? const Color(0xFFF7FAF8) : Colors.white,
            ),
            onChanged: (_) => _scheduleDraftSave(),
            validator: validator ??
                (value) {
                  if (readOnly) return null;
                  final trimmed = value?.trim() ?? '';
                  if (required && trimmed.isEmpty) {
                    return context.tr(
                      'registration.please_enter_field',
                      args: {'field': effectiveLabel},
                    );
                  }
                  if (trimmed.isNotEmpty && onlyAlphabets) {
                    if (!RegExp(r'^[\p{L}\p{M}\s\.\-]+$', unicode: true).hasMatch(trimmed)) {
                      return context.tr(
                        'registration.val_alpha_only',
                        args: {'field': effectiveLabel},
                      );
                    }
                  }
                  return null;
                },
          ),
        ],
      ),
    );
  }

  String _getStepTitle(BuildContext context, int index) {
    switch (index) {
      case 0:
        return context.tr('registration.step1_title');
      case 1:
        return context.tr('registration.step2_title');
      case 2:
        return context.tr('registration.step3_title');
      case 3:
        return context.tr('registration.step4_title');
      case 4:
        return context.tr('registration.step5_title');
      case 5:
        return context.tr('registration.step6_title');
      case 6:
        return context.tr('registration.step7_title');
      default:
        return index < _stepTitles.length ? _stepTitles[index] : '';
    }
  }

  String _translateOption(BuildContext context, String item) {
    switch (item) {
      case 'Yes':
        return context.tr('common.yes');
      case 'No':
        return context.tr('common.no');
      case 'Not recorded':
        return context.tr('registration.not_recorded');
      case 'Father':
        return context.tr('registration.opt_father');
      case 'Mother':
        return context.tr('registration.opt_mother');
      case 'Spouse':
        return context.tr('registration.opt_spouse');
      case 'Guardian':
        return context.tr('registration.opt_guardian');
      case 'Male':
        return context.tr('registration.gender_male');
      case 'Female':
        return context.tr('registration.gender_female');
      case 'Other':
        return context.tr('registration.gender_other');
      case 'Rural':
        return context.tr('registration.rural');
      case 'Urban':
        return context.tr('registration.urban');
      case 'General':
        return context.tr('registration.category_gen');
      case 'OBC':
        return context.tr('registration.category_obc');
      case 'SC':
        return context.tr('registration.category_sc');
      case 'ST':
        return context.tr('registration.category_st');
      case 'Married':
        return context.tr('registration.status_married');
      case 'Unmarried':
        return context.tr('registration.status_unmarried');
      case 'Widowed':
        return context.tr('registration.status_widow');
      case 'Divorced':
        return context.tr('registration.status_divorced');
      case 'Separated':
        return context.tr('registration.opt_separated');
      case 'Agricultural Labourer':
        return context.tr('registration.occ_agri_labour');
      case 'Cultivator / Farmer':
        return context.tr('registration.occ_cultivator');
      case 'Daily Wage Labourer':
        return context.tr('registration.occ_daily_wage');
      case 'Construction Worker':
        return context.tr('registration.occ_construction');
      case 'Domestic Worker':
        return context.tr('registration.occ_domestic');
      case 'Street Vendor':
        return context.tr('registration.occ_street_vendor');
      case 'Artisan / Weaver':
        return context.tr('registration.occ_artisan');
      case 'Fisherman':
        return context.tr('registration.occ_fisherman');
      case 'Small Business / Shop':
        return context.tr('registration.occ_small_business');
      case 'Salaried - Private':
        return context.tr('registration.occ_salaried_private');
      case 'Salaried - Government':
        return context.tr('registration.occ_salaried_govt');
      case 'Self-employed / Own Account':
        return context.tr('registration.occ_self_employed');
      case 'Student':
        return context.tr('registration.occ_student');
      case 'Homemaker':
        return context.tr('registration.occ_homemaker');
      case 'Unemployed':
        return context.tr('registration.occ_unemployed');
      case 'Retired':
        return context.tr('registration.occ_retired');
      case 'Unable to Work':
        return context.tr('registration.occ_unable_work');
      case 'Trader':
        return context.tr('registration.occ_trader');
      case 'Weaver':
        return context.tr('registration.occ_weaver');
      case 'Unorganized Sector':
        return context.tr('registration.occ_unorganized');
      case 'Service':
        return context.tr('registration.occ_service');
      case 'No income':
        return context.tr('registration.inc_none');
      case 'Less than ₹25,000':
        return context.tr('registration.inc_lt_25k');
      case '₹25,000–₹50,000':
        return context.tr('registration.inc_25k_50k');
      case '₹50,000–₹75,000':
        return context.tr('registration.inc_50k_75k');
      case 'Less than ₹1,00,000':
        return context.tr('registration.inc_lt_1l');
      case 'More than ₹1,00,000':
        return context.tr('registration.inc_gt_1l');
      case 'Less than ₹8,00,000':
        return context.tr('registration.inc_lt_8l');
      default:
        return item;
    }
  }

  Widget _dateField(
    String label, {
    String? displayLabel,
    bool required = false,
    String? hint,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    final effectiveLabel = displayLabel ?? label;
    final controller = _controller(label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(effectiveLabel, required),
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
            decoration: _inputDecoration(
              hint ??
                  context.tr(
                    'registration.select_field',
                    args: {'field': effectiveLabel},
                  ),
            ).copyWith(
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
                      ? context.tr(
                          'registration.please_select_field',
                          args: {'field': effectiveLabel},
                        )
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
    String? displayLabel,
    bool required = false,
    List<String>? choices,
    bool disabled = false,
  }) {
    final effectiveLabel = displayLabel ?? label;
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
          _fieldLabel(effectiveLabel, required),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: validValue,
            isExpanded: true,
            decoration: _inputDecoration(
              context.tr(
                'registration.select_field',
                args: {'field': effectiveLabel},
              ),
            ).copyWith(
              filled: disabled,
              fillColor: disabled ? const Color(0xFFF7FAF8) : Colors.white,
            ),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      _translateOption(context, item),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: disabled ? FontWeight.w600 : FontWeight.normal,
                        color: disabled ? const Color(0xFF1E293B) : null,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: disabled
                ? null
                : (value) {
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
            validator: (value) {
              if (disabled) return null;
              if (required && value == null) {
                return context.tr(
                  'registration.please_select_field',
                  args: {'field': effectiveLabel},
                );
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _locationDropdown({
    required String label,
    String? displayLabel,
    required List<LocationModel> locations,
    required int? selectedId,
    required bool loading,
    required ValueChanged<int?> onChanged,
    bool required = false,
    bool isLocked = false,
    bool disabled = false,
  }) {
    final effectiveLabel = displayLabel ?? label;
    final validIds = locations.map((item) => item.id).toSet();
    final effectiveLocations = List<LocationModel>.from(locations);

    if (selectedId != null && !validIds.contains(selectedId)) {
      effectiveLocations.add(
        LocationModel(
          id: selectedId,
          name: isLocked
              ? '${context.tr('registration.assigned_jurisdiction')} ($effectiveLabel #$selectedId)'
              : '$effectiveLabel #$selectedId',
        ),
      );
    }

    final isActuallyLocked = isLocked && selectedId != null;
    final isActuallyDisabled = disabled || isActuallyLocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _fieldLabel(effectiveLabel, required),
              if (isActuallyLocked) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF81C784), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 10, color: Color(0xFF087443)),
                      const SizedBox(width: 3),
                      Text(
                        context.tr('registration.assigned_jurisdiction'),
                        style: const TextStyle(
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
              loading
                  ? context.tr(
                      'registration.loading_field',
                      args: {'field': effectiveLabel},
                    )
                  : context.tr(
                      'registration.select_field',
                      args: {'field': effectiveLabel},
                    ),
            ).copyWith(
              filled: isActuallyDisabled,
              fillColor: isActuallyDisabled ? const Color(0xFFF7FAF8) : null,
              suffixIcon: isActuallyLocked
                  ? Tooltip(
                      message: context.tr('registration.locked_jurisdiction_tooltip'),
                      child: const Icon(Icons.lock_outline, size: 18, color: Color(0xFF087443)),
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
                    fontWeight: isActuallyDisabled ? FontWeight.w600 : FontWeight.normal,
                    color: isActuallyDisabled ? const Color(0xFF1E293B) : null,
                  ),
                ),
              );
            }).toList(),
            onChanged: (loading || isActuallyDisabled) ? null : onChanged,
            validator: (value) {
              if (isActuallyDisabled) return null;
              if (required && value == null) {
                return context.tr(
                  'registration.please_select_field',
                  args: {'field': effectiveLabel},
                );
              }
              if (isActuallyLocked && value != selectedId) {
                return context.tr(
                  'registration.assigned_only_error',
                  args: {'field': effectiveLabel},
                );
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
    String? displayLabel,
    bool required = false,
    bool defaultYes = false,
  }) {
    final effectiveLabel = displayLabel ?? label;
    final value = _switches[label] ?? defaultYes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(effectiveLabel, required),
          Row(
            children: [
              Expanded(
                child: RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  activeColor: green,
                  title: Text(context.tr('common.yes'), style: const TextStyle(fontSize: 12)),
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
                  title: Text(context.tr('common.no'), style: const TextStyle(fontSize: 12)),
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
      context.tr('registration.step1_title'),
      Icons.person_outline,
      Column(
        children: [
          _dateField(
            'Registration Date',
            displayLabel: context.tr('registration.registration_date'),
            required: true,
            hint: 'DD-MM-YYYY',
            firstDate: DateTime(2000, 1, 1),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          ),
          _textField(
            'Beneficiary Name',
            displayLabel: context.tr('registration.beneficiary_name'),
            hint: context.tr('registration.beneficiary_name_hint'),
            required: true,
            onlyAlphabets: true,
          ),
          _textField(
            "Father's Name",
            displayLabel: context.tr('registration.father_name'),
            onlyAlphabets: true,
          ),
          _textField(
            "Mother's Name",
            displayLabel: context.tr('registration.mother_name'),
            onlyAlphabets: true,
          ),
          _textField(
            'Spouse Name',
            displayLabel: context.tr('registration.spouse_name'),
            onlyAlphabets: true,
          ),
          _dropdown(
            'Care Of (Relation)',
            displayLabel: context.tr('registration.relation_type'),
          ),
          _textField(
            'Care Of (Name)',
            displayLabel: context.tr('registration.relation_name'),
            onlyAlphabets: true,
          ),
          _dropdown(
            'Gender',
            displayLabel: context.tr('registration.gender'),
            required: true,
          ),
          _dateField(
            'Date of Birth',
            displayLabel: context.tr('registration.dob'),
            hint: 'DD-MM-YYYY',
            firstDate: DateTime(1900, 1, 1),
            lastDate: DateTime.now(),
          ),
          _textField(
            'Age',
            displayLabel: context.tr('registration.age'),
            hint: context.tr('registration.age_hint'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 3,
          ),
          _textField(
            'Mobile Number',
            displayLabel: context.tr('registration.mobile_number'),
            keyboardType: TextInputType.phone,
            hint: context.tr('registration.mobile_hint'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isNotEmpty && trimmed.length != 10) {
                return context.tr('registration.val_mobile_invalid');
              }
              return null;
            },
          ),
          _textField(
            'Alternate Mobile',
            displayLabel: context.tr('registration.alt_mobile'),
            keyboardType: TextInputType.phone,
            hint: context.tr('registration.mobile_hint'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isNotEmpty && trimmed.length != 10) {
                return context.tr('registration.val_mobile_invalid');
              }
              return null;
            },
          ),
          _textField(
            'Aadhaar Number',
            displayLabel: context.tr('registration.aadhaar_number'),
            keyboardType: TextInputType.number,
            hint: context.tr('registration.aadhaar_hint'),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 12,
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isNotEmpty && trimmed.length != 12) {
                return context.tr('registration.val_aadhaar_invalid');
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
      context.tr('registration.step2_title'),
      Icons.home_outlined,
      Column(
        children: [
          _locationDropdown(
            label: 'State',
            displayLabel: context.tr('registration.state'),
            locations: _states,
            selectedId: _selectedStateId,
            loading: _loadingStates,
            required: true,
            isLocked: _assignedLocation?.hasAssignedState == true,
            onChanged: _onStateChanged,
          ),
          _locationDropdown(
            label: 'District',
            displayLabel: context.tr('registration.district'),
            locations: _districts,
            selectedId: _selectedDistrictId,
            loading: _loadingDistricts,
            required: true,
            isLocked: _assignedLocation?.hasAssignedDistrict == true,
            onChanged: _onDistrictChanged,
          ),
          _locationDropdown(
            label: 'Block',
            displayLabel: context.tr('registration.block'),
            locations: _blocks,
            selectedId: _selectedBlockId,
            loading: _loadingBlocks,
            isLocked: _assignedLocation?.hasAssignedBlock == true,
            onChanged: _onBlockChanged,
          ),
          _locationDropdown(
            label: 'Gram Panchayat',
            displayLabel: context.tr('registration.gram_panchayat'),
            locations: _gramPanchayats,
            selectedId: _selectedGramPanchayatId,
            loading: _loadingGramPanchayats,
            onChanged: _onGramPanchayatChanged,
          ),
          _locationDropdown(
            label: 'Village',
            displayLabel: context.tr('registration.village'),
            locations: _villages,
            selectedId: _selectedVillageId,
            loading: _loadingVillages,
            onChanged: _onVillageChanged,
          ),

          _textField(
            'Village (if not listed)',
            displayLabel: context.tr('registration.village_not_listed'),
          ),
          _textField(
            'Post Office',
            displayLabel: context.tr('registration.post_office'),
          ),
          _textField(
            'Address',
            displayLabel: context.tr('registration.address_line'),
          ),
          _textField(
            'PIN Code',
            displayLabel: context.tr('registration.pincode'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
          ),
          _dropdown(
            'Rural / Urban',
            displayLabel: context.tr('registration.area_type'),
            required: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _sameAsPermanentAddress ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _sameAsPermanentAddress ? green : const Color(0xFFE5EEE8),
              width: _sameAsPermanentAddress ? 1.4 : 1.0,
            ),
          ),
          child: CheckboxListTile(
            value: _sameAsPermanentAddress,
            onChanged: (bool? checked) {
              _toggleSameAsPermanent(checked == true);
            },
            activeColor: green,
            checkColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              context.tr('registration.same_as_permanent'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF182E25),
              ),
            ),
            subtitle: Text(
              context.tr('registration.copy_perm_sub'),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF5A6B62),
              ),
            ),
          ),
        ),
        _section(
          context.tr('registration.step3_title'),
          Icons.pin_drop_outlined,
          Column(
            children: [
              _locationDropdown(
                label: 'Current State',
                displayLabel: context.tr('registration.state'),
                locations: _states,
                selectedId: _currentSelectedStateId,
                loading: _loadingStates,
                required: !_sameAsPermanentAddress,
                disabled: _sameAsPermanentAddress,
                onChanged: _onCurrentStateChanged,
              ),
              _locationDropdown(
                label: 'Current District',
                displayLabel: context.tr('registration.district'),
                locations: _currentDistricts,
                selectedId: _currentSelectedDistrictId,
                loading: _loadingCurrentDistricts,
                required: !_sameAsPermanentAddress,
                disabled: _sameAsPermanentAddress,
                onChanged: _onCurrentDistrictChanged,
              ),
              _locationDropdown(
                label: 'Current Block',
                displayLabel: context.tr('registration.block'),
                locations: _currentBlocks,
                selectedId: _currentSelectedBlockId,
                loading: _loadingCurrentBlocks,
                disabled: _sameAsPermanentAddress,
                onChanged: _onCurrentBlockChanged,
              ),
              _locationDropdown(
                label: 'Current Gram Panchayat',
                displayLabel: context.tr('registration.gram_panchayat'),
                locations: _currentGramPanchayats,
                selectedId: _currentSelectedGramPanchayatId,
                loading: _loadingCurrentGramPanchayats,
                disabled: _sameAsPermanentAddress,
                onChanged: _onCurrentGramPanchayatChanged,
              ),
              _locationDropdown(
                label: 'Current Village',
                displayLabel: context.tr('registration.village'),
                locations: _currentVillages,
                selectedId: _currentSelectedVillageId,
                loading: _loadingCurrentVillages,
                disabled: _sameAsPermanentAddress,
                onChanged: _onCurrentVillageChanged,
              ),
              _textField(
                'Current Village (if not listed)',
                displayLabel: context.tr('registration.village_not_listed'),
                readOnly: _sameAsPermanentAddress,
              ),
              _textField(
                'Current Post Office',
                displayLabel: context.tr('registration.post_office'),
                readOnly: _sameAsPermanentAddress,
              ),
              _textField(
                'Current Address',
                displayLabel: context.tr('registration.address_line'),
                readOnly: _sameAsPermanentAddress,
              ),
              _textField(
                'Current PIN Code',
                displayLabel: context.tr('registration.pincode'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                readOnly: _sameAsPermanentAddress,
              ),
              _dropdown(
                'Current Rural / Urban',
                displayLabel: context.tr('registration.area_type'),
                required: !_sameAsPermanentAddress,
                disabled: _sameAsPermanentAddress,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      children: [
        _section(
          context.tr('registration.step4_title'),
          Icons.person_outline,
          Column(
            children: [
              _yesNo(
                'Are you an Indian Citizen?',
                displayLabel: context.tr('registration.indian_citizen'),
                required: true,
                defaultYes: true,
              ),
              _dropdown(
                'Category',
                displayLabel: context.tr('registration.social_category'),
                required: true,
              ),
              _dropdown(
                'Marital Status',
                displayLabel: context.tr('registration.marital_status'),
                required: true,
              ),
            ],
          ),
        ),
        _section(
          context.tr('registration.household'),
          Icons.home_outlined,
          _yesNo(
            'Do you have any children?',
            displayLabel: context.tr('registration.has_children'),
            required: true,
            defaultYes: true,
          ),
        ),
      ],
    );
  }

  String _translateDocField(BuildContext context, String field) {
    switch (field) {
      case 'Aadhaar Card':
        return context.tr('registration.doc_aadhaar');
      case 'PAN Card':
        return context.tr('registration.doc_pan');
      case 'Birth Certificate':
        return context.tr('registration.doc_birth');
      case 'Voter ID Card':
        return context.tr('registration.doc_voter');
      case 'Death Certificate of Husband/Father/Primary Earner of Family':
        return context.tr('registration.doc_death');
      case 'Income Certificate':
        return context.tr('registration.doc_income_cert');
      case 'Caste Certificate':
        return context.tr('registration.doc_caste_cert');
      case 'Antyodaya Anna Yojana (AAY) ration card':
        return context.tr('registration.doc_ration_aay');
      case 'Priority Household (PHH) ration card':
        return context.tr('registration.doc_ration_phh');
      case 'Disability Card':
        return context.tr('registration.doc_disability_card');
      default:
        return field;
    }
  }

  String _translateVulnerability(BuildContext context, String option) {
    switch (option) {
      case 'Migrant Labor':
        return context.tr('registration.vuln_migrant');
      case 'Female Sex Workers (FSW)':
        return context.tr('registration.vuln_fsw');
      case 'Affected by Natural Calamities':
        return context.tr('registration.vuln_calamities');
      case 'Affected by Conflict':
        return context.tr('registration.vuln_conflict');
      case 'Victims/Survivors of Violence and Abuse':
        return context.tr('registration.vuln_violence');
      case 'Victims and Survivors of Trafficking':
        return context.tr('registration.vuln_trafficking');
      case 'Tribal Population':
        return context.tr('registration.vuln_tribal');
      case 'Minority Group':
        return context.tr('registration.vuln_minority');
      case 'Orphan Child':
        return context.tr('registration.vuln_orphan');
      case 'Single Parent':
        return context.tr('registration.vuln_single_parent');
      case 'Child in Need of Care and Protection':
        return context.tr('registration.vuln_cincp');
      case 'Displaced':
        return context.tr('registration.vuln_displaced');
      case 'Elderly':
        return context.tr('registration.vuln_elderly');
      case 'PWD/Chronic Diseases':
        return context.tr('registration.vuln_pwd');
      case 'LGBTQ+':
        return context.tr('registration.vuln_lgbtq');
      default:
        return option;
    }
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
          _translateDocField(context, field),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
            color: isChecked ? darkGreen : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          isChecked
              ? context.tr('registration.available')
              : context.tr('registration.not_available'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
            color: isChecked ? green : const Color(0xFF8C9B93),
          ),
        ),
      ),
    );
  }

  Widget _buildStep5() {
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
          context.tr('registration.livelihood'),
          Icons.work_outline,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dropdown(
                'Do you earn?',
                displayLabel: context.tr('registration.earning_status'),
                required: true,
              ),
              if (isEarning) ...[
                _dropdown(
                  'Occupation',
                  displayLabel: context.tr('registration.occupation'),
                  required: true,
                ),
                _dropdown(
                  'What is your monthly income?',
                  displayLabel: context.tr('registration.monthly_income'),
                  required: true,
                ),
              ],
            ],
          ),
        ),
        _section(
          context.tr('registration.document_checklist'),
          Icons.description_outlined,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  context.tr('registration.check_all_docs'),
                  style: const TextStyle(
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

  Widget _buildStep6() {
    return Column(
      children: [
        _section(
          context.tr('registration.step6_title'),
          Icons.account_balance_outlined,
          Column(
            children: [
              _yesNo(
                'Do you have a bank account?',
                displayLabel: context.tr('registration.has_bank_account'),
                required: true,
              ),
              _yesNo(
                'Is Phone Number Linked with Aadhaar Card?',
                displayLabel: context.tr('registration.phone_aadhaar_linked'),
                required: true,
              ),
            ],
          ),
        ),
        _section(
          context.tr('registration.vulnerability'),
          Icons.groups_outlined,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel(context.tr('registration.vulnerability_group'), true),
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
                  title: Text(
                    _translateVulnerability(context, option),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              Text(
                context.tr('registration.tick_every_group'),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _translateFieldName(BuildContext context, String field) {
    switch (field) {
      case 'Registration Date':
        return context.tr('registration.registration_date');
      case 'Beneficiary Name':
        return context.tr('registration.beneficiary_name');
      case "Father's Name":
        return context.tr('registration.father_name');
      case "Mother's Name":
        return context.tr('registration.mother_name');
      case 'Spouse Name':
        return context.tr('registration.spouse_name');
      case 'Care Of (Relation)':
        return context.tr('registration.relation_type');
      case 'Care Of (Name)':
        return context.tr('registration.relation_name');
      case 'Gender':
        return context.tr('registration.gender');
      case 'Date of Birth':
        return context.tr('registration.dob');
      case 'Age':
        return context.tr('registration.age');
      case 'Mobile Number':
        return context.tr('registration.mobile_number');
      case 'Alternate Mobile':
        return context.tr('registration.alt_mobile');
      case 'Aadhaar Number':
        return context.tr('registration.aadhaar_number');
      case 'State':
      case 'Current State':
        return context.tr('registration.state');
      case 'District':
      case 'Current District':
        return context.tr('registration.district');
      case 'Block':
      case 'Current Block':
        return context.tr('registration.block');
      case 'Gram Panchayat':
      case 'Current Gram Panchayat':
        return context.tr('registration.gram_panchayat');
      case 'Village':
      case 'Current Village':
        return context.tr('registration.village');
      case 'Village (if not listed)':
      case 'Current Village (if not listed)':
        return context.tr('registration.village_not_listed');
      case 'Post Office':
      case 'Current Post Office':
        return context.tr('registration.post_office');
      case 'Address':
      case 'Current Address':
        return context.tr('registration.address_line');
      case 'PIN Code':
      case 'Current PIN Code':
        return context.tr('registration.pincode');
      case 'Rural / Urban':
      case 'Current Rural / Urban':
        return context.tr('registration.area_type');
      case 'Same as permanent address':
        return context.tr('registration.same_as_permanent');
      case 'Are you an Indian Citizen?':
        return context.tr('registration.indian_citizen');
      case 'Category':
        return context.tr('registration.social_category');
      case 'Marital Status':
        return context.tr('registration.marital_status');
      case 'Do you have any children?':
        return context.tr('registration.has_children');
      case 'Do you earn?':
        return context.tr('registration.earning_status');
      case 'Occupation':
        return context.tr('registration.occupation');
      case 'What is your monthly income?':
        return context.tr('registration.monthly_income');
      case 'Do you have a bank account?':
        return context.tr('registration.has_bank_account');
      case 'Is Phone Number Linked with Aadhaar Card?':
        return context.tr('registration.phone_aadhaar_linked');
      default:
        return _translateDocField(context, field);
    }
  }

  Widget _reviewSection(String title, List<String> fields, IconData icon) {
    final stepIndex = _stepTitles.indexOf(title);
    final displayTitle = stepIndex >= 0 ? _getStepTitle(context, stepIndex) : title;

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
          displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        trailing: TextButton(
          onPressed: () {
            if (stepIndex >= 0) setState(() => _step = stepIndex);
          },
          child: Text(context.tr('registration.edit')),
        ),
        children: fields.map((field) {
          String value = _value(field);
          if (_switches.containsKey(field)) {
            final isYesNoQuestion = field.endsWith('?') ||
                field.toLowerCase().startsWith('is ') ||
                field.toLowerCase().startsWith('do ');
            value = _switches[field]!
                ? (isYesNoQuestion
                    ? context.tr('common.yes')
                    : context.tr('registration.available'))
                : (isYesNoQuestion
                    ? context.tr('common.no')
                    : context.tr('registration.not_available'));
          } else if (value.isNotEmpty) {
            value = _translateOption(context, value);
          }
          if (value.isEmpty) value = context.tr('registration.not_provided');

          return ListTile(
            dense: true,
            title: Text(
              _translateFieldName(context, field),
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(value, style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStep7() {
    return Column(
      children: [
        Text(
          context.tr('registration.review_prompt'),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        _reviewSection('Permanent Address', [
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
        ], Icons.home_outlined),
        _reviewSection('Current Address', [
          'Same as permanent address',
          'Current State',
          'Current District',
          'Current Block',
          'Current Gram Panchayat',
          'Current Village',
          'Current Village (if not listed)',
          'Current Post Office',
          'Current Address',
          'Current PIN Code',
          'Current Rural / Urban',
        ], Icons.pin_drop_outlined),
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
            title: Text(
              context.tr('registration.vulnerability_group'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              _vulnerabilities.isEmpty
                  ? context.tr('registration.not_provided')
                  : _vulnerabilities
                      .map((item) => _translateVulnerability(context, item))
                      .join(', '),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _step = 5),
              child: Text(context.tr('registration.edit')),
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
          title: Text(
            context.tr('registration.confirmation_declaration'),
            style: const TextStyle(fontSize: 11, height: 1.5),
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
          title: Text(
            context.tr('registration.privacy_consent'),
            style: const TextStyle(fontSize: 11, height: 1.5),
          ),
        ),
      ],
    );
  }

  bool _validateCurrentStep() {
    if (_step == 1) {
      if (_selectedStateId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'registration.please_select_field',
                args: {'field': context.tr('registration.state')},
              ),
            ),
          ),
        );
        return false;
      }
      if (_assignedLocation?.hasAssignedState == true &&
          _selectedStateId != _assignedLocation!.stateId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'registration.assigned_only_error',
                args: {'field': context.tr('registration.state')},
              ),
            ),
          ),
        );
        return false;
      }
      if (_selectedDistrictId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'registration.please_select_field',
                args: {'field': context.tr('registration.district')},
              ),
            ),
          ),
        );
        return false;
      }
      if (_assignedLocation?.hasAssignedDistrict == true &&
          _selectedDistrictId != _assignedLocation!.districtId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'registration.assigned_only_error',
                args: {'field': context.tr('registration.district')},
              ),
            ),
          ),
        );
        return false;
      }
      if (_assignedLocation?.hasAssignedBlock == true &&
          _selectedBlockId != null &&
          _selectedBlockId != _assignedLocation!.blockId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                'registration.assigned_only_error',
                args: {'field': context.tr('registration.block')},
              ),
            ),
          ),
        );
        return false;
      }
    }

    if (_step == 2) {
      if (!_sameAsPermanentAddress) {
        if (_currentSelectedStateId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'registration.please_select_field',
                  args: {'field': context.tr('registration.state')},
                ),
              ),
            ),
          );
          return false;
        }
        if (_currentSelectedDistrictId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'registration.please_select_field',
                  args: {'field': context.tr('registration.district')},
                ),
              ),
            ),
          );
          return false;
        }
      }
    }

    if (_step == 5 && _vulnerabilities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('registration.val_vulnerability_req')),
        ),
      );
      return false;
    }

    if (_step == 6) {
      if (!(_switches['Confirmation'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('registration.val_confirm_req')),
          ),
        );
        return false;
      }
      if (!(_switches['PrivacyConsent'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('registration.val_privacy_req')),
          ),
        );
        return false;
      }
      return true;
    }

    return _formKey.currentState?.validate() ?? true;
  }

  Future<void> _next() async {
    if (!_validateCurrentStep()) return;

    if (_step == 1 && _sameAsPermanentAddress) {
      _copyPermanentToCurrent();
    }

    if (_step < _stepTitles.length - 1) {
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
    final aadhaarClean = cleanDigits('Aadhaar Number');
    final hasAadhaar = (aadhaarClean != null && aadhaarClean.length == 12) || docAadhaar == 'Yes' ? 1 : 0;

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
      'has_income_certificate': docIncome == 'Yes' ? 1 : 0,
      'has_caste_certificate': docCaste == 'Yes' ? 1 : 0,
      'doc_ration_aay': docAay,
      'doc_ration_phh': docPhh,
      'doc_disability_card': docDisability,
      'has_bank_account': hasBank ? 1 : 0,
      'has_aadhaar': hasAadhaar,
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

      // Current Address in answers
      'same_as_permanent_address': _sameAsPermanentAddress ? 'Yes' : 'No',
      'current_state': _sameAsPermanentAddress ? _value('State') : _value('Current State'),
      'current_district': _sameAsPermanentAddress ? _value('District') : _value('Current District'),
      'current_block': _sameAsPermanentAddress ? _value('Block') : _value('Current Block'),
      'current_gram_panchayat': _sameAsPermanentAddress ? _value('Gram Panchayat') : _value('Current Gram Panchayat'),
      'current_village': _sameAsPermanentAddress ? _value('Village') : _value('Current Village'),
      'current_address_line': _sameAsPermanentAddress ? cleanString('Address') : cleanString('Current Address'),
      'current_pincode': _sameAsPermanentAddress ? cleanDigits('PIN Code') : cleanDigits('Current PIN Code'),
      'current_area_type': _sameAsPermanentAddress ? cleanString('Rural / Urban') : cleanString('Current Rural / Urban'),
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
      'aadhaar_number': aadhaarClean,
      'has_aadhaar': hasAadhaar,
      'has_bank_account': hasBank ? 1 : 0,

      // Permanent Location IDs & Details
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

      // Current Location IDs & Details
      'same_as_permanent_address': _sameAsPermanentAddress,
      'current_state_id': _sameAsPermanentAddress
          ? (_selectedStateId ?? _assignedLocation?.stateId)
          : _currentSelectedStateId,
      'current_district_id': _sameAsPermanentAddress
          ? (_selectedDistrictId ?? _assignedLocation?.districtId)
          : _currentSelectedDistrictId,
      'current_block_id': _sameAsPermanentAddress
          ? (_selectedBlockId ?? _assignedLocation?.blockId)
          : _currentSelectedBlockId,
      'current_gram_panchayat_id': _sameAsPermanentAddress
          ? _selectedGramPanchayatId
          : _currentSelectedGramPanchayatId,
      'current_village_id': _sameAsPermanentAddress
          ? _selectedVillageId
          : _currentSelectedVillageId,
      'current_village_name': _sameAsPermanentAddress
          ? (cleanString('Village (if not listed)') ?? cleanString('Village'))
          : (cleanString('Current Village (if not listed)') ?? cleanString('Current Village')),
      'current_post_office': _sameAsPermanentAddress
          ? cleanString('Post Office')
          : cleanString('Current Post Office'),
      'current_address_line': _sameAsPermanentAddress
          ? cleanString('Address')
          : cleanString('Current Address'),
      'current_pincode': _sameAsPermanentAddress
          ? cleanDigits('PIN Code')
          : cleanDigits('Current PIN Code'),
      'current_area_type': _sameAsPermanentAddress
          ? cleanString('Rural / Urban')
          : cleanString('Current Rural / Urban'),
      'current_address_details': {
        'same_as_permanent_address': _sameAsPermanentAddress,
        'state_id': _sameAsPermanentAddress
            ? (_selectedStateId ?? _assignedLocation?.stateId)
            : _currentSelectedStateId,
        'district_id': _sameAsPermanentAddress
            ? (_selectedDistrictId ?? _assignedLocation?.districtId)
            : _currentSelectedDistrictId,
        'block_id': _sameAsPermanentAddress
            ? (_selectedBlockId ?? _assignedLocation?.blockId)
            : _currentSelectedBlockId,
        'gram_panchayat_id': _sameAsPermanentAddress
            ? _selectedGramPanchayatId
            : _currentSelectedGramPanchayatId,
        'village_id': _sameAsPermanentAddress
            ? _selectedVillageId
            : _currentSelectedVillageId,
        'village_name': _sameAsPermanentAddress
            ? (cleanString('Village (if not listed)') ?? cleanString('Village'))
            : (cleanString('Current Village (if not listed)') ?? cleanString('Current Village')),
        'post_office': _sameAsPermanentAddress
            ? cleanString('Post Office')
            : cleanString('Current Post Office'),
        'address_line': _sameAsPermanentAddress
            ? cleanString('Address')
            : cleanString('Current Address'),
        'pincode': _sameAsPermanentAddress
            ? cleanDigits('PIN Code')
            : cleanDigits('Current PIN Code'),
        'area_type': _sameAsPermanentAddress
            ? cleanString('Rural / Urban')
            : cleanString('Current Rural / Urban'),
      },
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
            isSynced
                ? context.tr('registration.submit_success_title')
                : context.tr('registration.submit_offline_title'),
          ),
          content: Text(
            isSynced
                ? context.tr('registration.submit_success_msg')
                : context.tr('registration.submit_offline_msg'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(true);
              },
              child: Text(context.tr('common.ok')),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Local beneficiary submission failed: ${e.runtimeType}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('registration.save_error_msg')),
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
      return Text(
        context.tr('registration.draft_not_saved'),
        style: const TextStyle(color: Colors.red, fontSize: 11),
      );
    }

    if (_isSavingDraft) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(context.tr('common.saving_draft'), style: const TextStyle(fontSize: 11)),
        ],
      );
    }

    if (_localDraftId != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: green),
          const SizedBox(width: 4),
          Text(context.tr('registration.draft_saved_msg'), style: const TextStyle(fontSize: 11)),
        ],
      );
    }

    return Text(
      context.tr('registration.draft_not_saved'),
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    );
  }

  Widget _buildProgress() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Row(
            children: List.generate(_stepTitles.length, (index) {
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
                      context.tr('registration.step_short', args: {'num': '${index + 1}'}),
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
            '${context.tr('registration.step_indicator', args: {'current': '${_step + 1}', 'total': '${_stepTitles.length}'})} • ${_getStepTitle(context, _step)}',
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
      case 5:
        return _buildStep6();
      default:
        return _buildStep7();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        title: Text(
          context.tr('common.app_name'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              context.tr('dashboard.register_beneficiary'),
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
                        label: Text(context.tr('registration.reload_draft')),
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
                          label: Text(context.tr('common.back')),
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
                                    _step == _stepTitles.length - 1
                                        ? context.tr('registration.submit_beneficiary')
                                        : context.tr('common.next'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _step == _stepTitles.length - 1
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
