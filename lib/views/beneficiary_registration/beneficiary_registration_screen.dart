import '../../data/models/location_model.dart';
import '../../data/services/geography_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../data/services/api_service.dart';
class BeneficiaryRegistrationScreen extends StatefulWidget {
  const BeneficiaryRegistrationScreen({super.key});

  @override
  State<BeneficiaryRegistrationScreen> createState() =>
      _BeneficiaryRegistrationScreenState();
}

class _BeneficiaryRegistrationScreenState extends State<BeneficiaryRegistrationScreen> {

  final GeographyService _geographyService = GeographyService();

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

  final List<IconData> _stepIcons = [
    Icons.person_outline,
    Icons.location_on_outlined,
    Icons.person_pin_outlined,
    Icons.work_outline,
    Icons.account_balance_outlined,
    Icons.description_outlined,
  ];

  final Map<String, List<String>> _options = {
    'Care Of (Relation)': [
      'Father', 'Mother', 'Spouse', 'Guardian', 'Other'
    ],
    'Gender': ['Male', 'Female', 'Other'],


    'Rural / Urban': ['Rural', 'Urban'],
    'Category': [
      'Not recorded', 'General', 'SC', 'ST', 'OBC', 'Other'
    ],
    'Marital Status': [
      'Not recorded', 'Unmarried', 'Married',
      'Widowed', 'Divorced', 'Separated'
    ],
    'Do you earn?': ['Not recorded', 'Yes', 'No'],
    'Aadhaar Card': ['Not recorded', 'Available', 'Not available'],
    'PAN Card': ['Not recorded', 'Available', 'Not available'],
    'Birth Certificate': ['Not recorded', 'Available', 'Not available'],
    'Voter ID Card': ['Not recorded', 'Available', 'Not available'],
    'Death Certificate of Husband/Father/Primary Earner of Family': [
      'Not recorded', 'Available', 'Not available'
    ],
    'Income Certificate': ['Not recorded', 'Available', 'Not available'],
    'Caste Certificate': ['Not recorded', 'Available', 'Not available'],
    'Antyodaya Anna Yojana (AAY) ration card': [
      'Not recorded', 'Available', 'Not available'
    ],
    'Priority Household (PHH) ration card': [
      'Not recorded', 'Available', 'Not available'
    ],
    'Disability Card': ['Not recorded', 'Available', 'Not available'],
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

  @override
  void initState() {
    super.initState();
    _loadStates();
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

    if (blockId == null) return;

    setState(() => _loadingGramPanchayats = true);
    try {
      final locations =
      await _geographyService.getGramPanchayats(blockId);
      if (!mounted) return;
      setState(() => _gramPanchayats = locations);
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

    if (gpId == null) return;

    setState(() => _loadingVillages = true);
    try {
      final locations = await _geographyService.getVillages(gpId);
      if (!mounted) return;
      setState(() => _villages = locations);
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
  }


  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String label) {
    return _controllers.putIfAbsent(
      label,
          () => TextEditingController(),
    );
  }


  String _value(String label) {
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
    final match = RegExp(r'^(\d{2})[-/](\d{2})[-/](\d{4})$')
        .firstMatch(input);

    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      // Validate the calendar date.
      final date = DateTime(year, month, day);

      if (date.day != day ||
          date.month != month ||
          date.year != year) {
        return null;
      }

      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    }

    return null;
  }


  Widget _textField(
      String label, {
        bool required = false,
        String? hint,
        TextInputType keyboardType = TextInputType.text,
      }) {
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
            decoration: _inputDecoration(hint ?? 'Enter $label'),
            validator: required
                ? (value) => value == null || value.trim().isEmpty
                ? 'Please enter $label'
                : null
                : null,
          ),
        ],
      ),
    );
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
      hintStyle: const TextStyle(
        color: Color(0xFF9AA8A1),
        fontSize: 12,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
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
    final validValue =
    selected != null && items.contains(selected) ? selected : null;

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
                }
              });
            },
            validator: required
                ? (value) =>
            value == null ? 'Please select $label' : null
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
  }) {
    final validIds = locations.map((item) => item.id).toSet();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label, required),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: validIds.contains(selectedId) ? selectedId : null,
            isExpanded: true,
            decoration: _inputDecoration(
              loading ? 'Loading $label...' : 'Select $label',
            ),
            items: locations.map((item) {
              return DropdownMenuItem<int>(
                value: item.id,
                child: Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: loading ? null : onChanged,
            validator: required
                ? (value) => value == null ? 'Please select $label' : null
                : null,
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
                  onChanged: (v) =>
                      setState(() => _switches[label] = v!),
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
                  onChanged: (v) =>
                      setState(() => _switches[label] = v!),
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
          _textField(
            'Registration Date',
            required: true,
            hint: 'DD-MM-YYYY',
          ),
          _textField('Beneficiary Name', required: true),
          _textField("Father's Name"),
          _textField("Mother's Name"),
          _textField('Spouse Name'),
          _dropdown('Care Of (Relation)'),
          _textField('Care Of (Name)'),
          _dropdown('Gender', required: true),
          _textField('Date of Birth', hint: 'DD-MM-YYYY'),
          _textField(
            'Age',
            keyboardType: TextInputType.number,
          ),
          _textField(
            'Mobile Number',
            keyboardType: TextInputType.phone,
            hint: '10-digit number',
          ),
          _textField(
            'Alternate Mobile',
            keyboardType: TextInputType.phone,
            hint: '10-digit number',
          ),
          _textField(
            'Aadhaar Number',
            keyboardType: TextInputType.number,
            hint: '12-digit number',
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
            onChanged: _onStateChanged,
          ),
          _locationDropdown(
            label: 'District',
            locations: _districts,
            selectedId: _selectedDistrictId,
            loading: _loadingDistricts,
            required: true,
            onChanged: _onDistrictChanged,
          ),
          _locationDropdown(
            label: 'Block',
            locations: _blocks,
            selectedId: _selectedBlockId,
            loading: _loadingBlocks,
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
          _textField(
            'PIN Code',
            keyboardType: TextInputType.number,
          ),
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
              _yesNo('Are you an Indian Citizen?', required: true,
                  defaultYes: true),
              _dropdown('Category', required: true),
              _dropdown('Marital Status', required: true),
            ],
          ),
        ),
        _section(
          'Household',
          Icons.home_outlined,
          _yesNo('Do you have any children?', required: true,
              defaultYes: true),
        ),
      ],
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

    return Column(
      children: [
        _section(
          'Livelihood',
          Icons.work_outline,
          _dropdown('Do you earn?', required: true),
        ),
        _section(
          'Document Checklist',
          Icons.description_outlined,
          Column(
            children: documentFields
                .map((field) => _dropdown(field, required: true))
                .toList(),
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
                  },
                  activeColor: green,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    option,
                    style: const TextStyle(fontSize: 12),
                  ),
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

  Widget _reviewSection(
      String title,
      List<String> fields,
      IconData icon,
      ) {
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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
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
          if (value.isEmpty && _switches.containsKey(field)) {
            value = _switches[field]! ? 'Yes' : 'No';
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
        _reviewSection(
          'Beneficiary Details',
          [
            'Registration Date', 'Beneficiary Name', "Father's Name",
            "Mother's Name", 'Spouse Name', 'Care Of (Relation)',
            'Care Of (Name)', 'Gender', 'Date of Birth', 'Age',
            'Mobile Number', 'Alternate Mobile', 'Aadhaar Number',
          ],
          Icons.person_outline,
        ),
        _reviewSection(
          'Address',
          [
            'State', 'District', 'Block', 'Gram Panchayat',
            'Village', 'Village (if not listed)', 'Post Office',
            'Address', 'PIN Code', 'Rural / Urban',
          ],
          Icons.location_on_outlined,
        ),
        _reviewSection(
          'Identity & Citizenship',
          [
            'Are you an Indian Citizen?', 'Category', 'Marital Status',
            'Do you have any children?',
          ],
          Icons.person_outline,
        ),
        _reviewSection(
          'Livelihood & Documents',
          [
            'Do you earn?', 'Aadhaar Card', 'PAN Card',
            'Birth Certificate', 'Voter ID Card',
            'Death Certificate of Husband/Father/Primary Earner of Family',
            'Income Certificate', 'Caste Certificate',
            'Antyodaya Anna Yojana (AAY) ration card',
            'Priority Household (PHH) ration card', 'Disability Card',
          ],
          Icons.description_outlined,
        ),
        _reviewSection(
          'Financial Inclusion',
          [
            'Do you have a bank account?',
            'Is Phone Number Linked with Aadhaar Card?',
          ],
          Icons.account_balance_outlined,
        ),
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
          onChanged: (value) =>
              setState(() => _switches['Confirmation'] = value ?? false),
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
      ],
    );
  }

  bool _validateCurrentStep() {
    if (_step == 5) {
      if (!(_switches['Confirmation'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please confirm the information before submitting.'),
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
      return;
    }

    await _submitBeneficiary();
  }


  Map<String, dynamic> _buildBeneficiaryPayload() {
    String? optional(String label) {
      final value = _value(label).trim();
      return value.isEmpty ? null : value;
    }

    final documentFields = [
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

    final answers = <String, dynamic>{
      'citizenship':
      _switches['Are you an Indian Citizen?'] ?? true,
      'category': optional('Category'),
      'marital_status': optional('Marital Status'),
      'has_children':
      _switches['Do you have any children?'] ?? true,
      'earns_income': optional('Do you earn?'),
      'documents': {
        for (final field in documentFields)
          field: optional(field),
      },
      'has_bank_account':
      _switches['Do you have a bank account?'] ?? false,
      'aadhaar_linked_mobile':
      _switches['Is Phone Number Linked with Aadhaar Card?'] ?? false,
      'vulnerability_groups': _vulnerabilities.toList(),
    };

    return {
      'registration_date':
      _toApiDate(_value('Registration Date')),
      'name': _value('Beneficiary Name').trim(),
      'relation_type': optional('Care Of (Relation)'),
      'relation_name': optional('Care Of (Name)'),
      'father_name': optional("Father's Name"),
      'mother_name': optional("Mother's Name"),
      'spouse_name': optional('Spouse Name'),
      'gender': optional('Gender'),
      'dob': _toApiDate(_value('Date of Birth')),
      'age': int.tryParse(_value('Age').trim()),
      'mobile': optional('Mobile Number'),
      'alt_mobile': optional('Alternate Mobile'),
      'aadhaar_number': _value('Aadhaar Number').trim(),

      // These must be replaced with actual backend IDs.
      'state_id': _selectedStateId,
      'district_id': _selectedDistrictId,
      'block_id': _selectedBlockId,
      'gram_panchayat_id': _selectedGramPanchayatId,
      'village_id': _selectedVillageId,

      'village_name':
      optional('Village (if not listed)') ??
          optional('Village'),
      'post_office': optional('Post Office'),
      'address_line': optional('Address'),
      'pincode': optional('PIN Code'),
      'area_type': optional('Rural / Urban'),
      'consent_given': _switches['Confirmation'] ?? false,
      'remarks': '',
      'confirm_duplicate': false,
      'answers': answers,
      'complete': true,
    };
  }
  Future<void> _submitBeneficiary() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final payload = _buildBeneficiaryPayload();

      final response = await ApiService().dio.post(
        '/beneficiaries',
        data: payload,
      );

      final responseData =
      Map<String, dynamic>.from(response.data as Map);

      if (responseData['success'] == true) {
        final data = responseData['data'] is Map
            ? Map<String, dynamic>.from(responseData['data'] as Map)
            : <String, dynamic>{};

        if (!mounted) return;

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.check_circle,
              color: Color(0xFF087443),
              size: 48,
            ),
            title: const Text('Beneficiary Registered'),
            content: Text(
              'Beneficiary code: ${data['code'] ?? 'Not provided'}\n'
                  'Status: ${data['record_status'] ?? 'Registered'}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message']?.toString() ??
                  'Beneficiary registration failed.',
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;

      final body = e.response?.data;
      String message = 'Registration failed. Please try again.';

      if (body is Map) {
        message = (body['message'] ?? body['detail'] ?? message).toString();
      } else if (e.response == null) {
        message = 'Network error. Check your internet connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('Beneficiary registration failed: ${e.runtimeType}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while registering.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
                          ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
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
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5EEE8)),
                  ),
                ),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _step--),
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
