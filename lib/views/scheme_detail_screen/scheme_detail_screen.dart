
import 'package:flutter/material.dart';

import '../../data/services/api_service.dart';
import '../../data/models/scheme_model.dart';

class SchemeDetailScreen extends StatefulWidget {
  final SchemeModel scheme;

  const SchemeDetailScreen({
    super.key,
    required this.scheme,
  });

  @override
  State<SchemeDetailScreen> createState() =>
      _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<SchemeDetailScreen> {
  static const Color green = Color(0xFF087443);
  static const Color darkGreen = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  Map<String, dynamic>? _details;
  bool _isLoading = true;
  String? _error;

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
      final response = await ApiService().dio.get(
        '/schemes/${widget.scheme.id}',
      );

      final responseData =
      Map<String, dynamic>.from(response.data as Map);

      if (responseData['success'] != true) {
        throw Exception(
          responseData['message'] ?? 'Unable to load scheme details.',
        );
      }

      final data =
      Map<String, dynamic>.from(responseData['data'] as Map);

      if (!mounted) return;

      setState(() {
        _details = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Scheme details API failed: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Unable to load scheme details. Please try again.';
        _isLoading = false;
      });
    }
  }

  String _text(dynamic value, {String fallback = 'Not provided'}) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString().trim();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  List<dynamic> _list(dynamic value) {
    return value is List ? value : <dynamic>[];
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: green, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1EAE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, icon),
          child,
        ],
      ),
    );
  }

  Widget _valueText(String value) {
    return Text(
      value,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Color(0xFF53645B),
      ),
    );
  }

  Widget _bulletList(List<dynamic> values, String Function(dynamic) label) {
    if (values.isEmpty) {
      return _valueText('No information provided.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.circle, size: 6, color: green),
              ),
              const SizedBox(width: 10),
              Expanded(child: _valueText(label(item))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeader() {
    final classification = _map(_details?['classification']);
    final level = _text(
      classification['level'],
      fallback: widget.scheme.level,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [darkGreen, green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Scheme Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _text(_details?['name'], fallback: widget.scheme.name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerBadge(level),
              _headerBadge(
                _text(classification['status'], fallback: 'Status unknown'),
              ),
              if (classification['active_enrollment'] == true)
                _headerBadge('Enrollment active'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Code: ${_text(_details?['code'], fallback: widget.scheme.code)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _details!;
    final classification = _map(data['classification']);
    final geography = _map(data['geography']);
    final primaryState = _map(geography['primary_state']);
    final application = _map(data['application']);
    final source = _map(data['source']);
    final serviceApproach = _map(data['service_approach']);
    final themes = _list(data['themes']);
    final beneficiaryTypes = _list(data['beneficiary_types']);
    final targetGroups = _list(data['target_groups']);
    final benefits = _list(data['benefits']);
    final documents = _list(data['documents']);
    final eligibilityRules = _list(data['eligibility_rules']);
    final applicableStates = _list(geography['applicable_states']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
      children: [
        _card(
          title: 'Overview',
          icon: Icons.info_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _valueText(
                _text(data['description'], fallback: 'No description provided.'),
              ),
              const SizedBox(height: 12),
              _detailRow('Short name', _text(data['short_name'])),
              _detailRow(
                'Launch year',
                _text(classification['launch_year']),
              ),
              _detailRow(
                'Applicable state',
                _text(primaryState['name'], fallback: 'All applicable regions'),
              ),
              _detailRow(
                'Ministry',
                _text(data['ministry']),
              ),
              _detailRow(
                'Department',
                _text(data['department']),
              ),
              _detailRow(
                'Service approach',
                _text(serviceApproach['name']),
              ),
            ],
          ),
        ),

        _card(
          title: 'Themes',
          icon: Icons.category_outlined,
          child: _bulletList(
            themes,
                (item) => _text(_map(item)['name']),
          ),
        ),

        _card(
          title: 'Who can benefit?',
          icon: Icons.groups_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _valueText(
                _text(
                  data['target_group_summary'],
                  fallback: 'No target group summary provided.',
                ),
              ),
              if (beneficiaryTypes.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Beneficiary types',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _bulletList(
                  beneficiaryTypes,
                      (item) => _text(_map(item)['name']),
                ),
              ],
              if (targetGroups.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Target groups',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _bulletList(
                  targetGroups,
                      (item) => _text(
                    item is Map
                        ? (item['name'] ?? item['description'])
                        : item,
                  ),
                ),
              ],
            ],
          ),
        ),

        _card(
          title: 'Eligibility',
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _valueText(
                _text(
                  data['eligibility_summary'],
                  fallback: 'No eligibility summary provided.',
                ),
              ),
              if (eligibilityRules.isNotEmpty) ...[
                const SizedBox(height: 14),
                _bulletList(
                  eligibilityRules,
                      (item) => _text(
                    item is Map
                        ? (item['description'] ??
                        item['rule'] ??
                        item['name'])
                        : item,
                  ),
                ),
              ],
            ],
          ),
        ),

        _card(
          title: 'Benefits',
          icon: Icons.card_giftcard_outlined,
          child: benefits.isEmpty
              ? _valueText('No benefit details provided.')
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: benefits.map((item) {
              final benefit = _map(item);
              final amount = benefit['amount_text'] ??
                  benefit['amount'];

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(benefit['type'], fallback: 'Benefit'),
                      style: const TextStyle(
                        color: darkGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (amount != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        amount.toString(),
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _valueText(
                      _text(
                        benefit['description'],
                        fallback: 'No description provided.',
                      ),
                    ),
                    if (benefit['frequency'] != null)
                      _detailRow(
                        'Frequency',
                        _text(benefit['frequency']),
                      ),
                    if (benefit['mode'] != null)
                      _detailRow(
                        'Mode',
                        _text(benefit['mode']),
                      ),
                    if (benefit['conditions'] != null)
                      _detailRow(
                        'Conditions',
                        _text(benefit['conditions']),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        _card(
          title: 'Required Documents',
          icon: Icons.description_outlined,
          child: _bulletList(documents, (item) {
            final document = _map(item);
            final mandatory = document['mandatory'] == true;
            return '${_text(document['name'])}'
                '${mandatory ? ' • Mandatory' : ' • Optional'}';
          }),
        ),

        _card(
          title: 'How to Apply',
          icon: Icons.assignment_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                'Application mode',
                _text(application['mode']),
              ),
              const SizedBox(height: 10),
              _valueText(
                _text(
                  application['process'],
                  fallback: 'Application process not provided.',
                ),
              ),
              if (application['instructions'] != null) ...[
                const SizedBox(height: 10),
                _valueText(_text(application['instructions'])),
              ],
              _detailRow(
                'CSC available',
                application['csc_available'] == true ? 'Yes' : 'No',
              ),
              if (application['physical_office'] != null)
                _detailRow(
                  'Physical office',
                  _text(application['physical_office']),
                ),
              if (application['helpline'] != null)
                _detailRow(
                  'Helpline',
                  _text(application['helpline']),
                ),
              if (application['portal_url'] != null) ...[
                const SizedBox(height: 14),
                SelectableText(
                  application['portal_url'].toString(),
                  style: const TextStyle(
                    color: green,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (applicableStates.isNotEmpty)
          _card(
            title: 'Applicable States',
            icon: Icons.location_on_outlined,
            child: _bulletList(
              applicableStates,
                  (item) => _text(
                item is Map ? item['name'] : item,
              ),
            ),
          ),

        _card(
          title: 'Official Source',
          icon: Icons.verified_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Website', _text(source['website'])),
              _detailRow(
                'Last verified',
                _text(source['last_verified_date']),
              ),
              _detailRow(
                'Verified by',
                _text(source['verified_by']),
              ),
              _detailRow(
                'Keywords',
                _text(data['keywords']),
              ),
              _detailRow(
                'Last updated',
                _text(data['updated_at']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64756C),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _valueText(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: green),
        )
            : _error != null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 42,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadDetails,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        )
            : _details == null
            ? const Center(
          child: Text('No scheme details available.'),
        )
            : Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}
