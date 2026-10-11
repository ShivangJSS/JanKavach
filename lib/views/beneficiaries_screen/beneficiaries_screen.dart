
import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/ beneficiary_model.dart';
import '../../viewmodels/beneficiary_viewmodel.dart';
import '../beneficiary_detail_screen/beneficiary_detail_screen.dart';


class BeneficiariesScreen extends StatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  State<BeneficiariesScreen> createState() =>
      _BeneficiariesScreenState();
}

class _BeneficiariesScreenState extends State<BeneficiariesScreen> {
  static const Color green = Color(0xFF087443);
  static const Color darkGreen = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  late final BeneficiaryViewModel _viewModel;
  final TextEditingController _searchController =
  TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounce;
  String _search = '';

  @override
  void initState() {
    super.initState();

    _viewModel = BeneficiaryViewModel();
    _viewModel.addListener(_refresh);
    _viewModel.loadBeneficiaries();

    _scrollController.addListener(_onScroll);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      _viewModel.loadBeneficiaries(search: _search);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
          () {
        if (!mounted) return;

        _search = value.trim();
        _viewModel.loadBeneficiaries(
          refresh: true,
          search: _search,
        );
      },
    );
  }

  Future<void> _refreshList() async {
    await _viewModel.loadBeneficiaries(
      refresh: true,
      search: _search,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading &&
        _viewModel.beneficiaries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
    }

    if (_viewModel.error != null &&
        _viewModel.beneficiaries.isEmpty) {
      return Center(
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
              const SizedBox(height: 14),
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshList,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: green,
      onRefresh: _refreshList,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [

          const SizedBox(height: 20),
          _buildSearchField(),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Registered Beneficiaries',
                  style: TextStyle(
                    color: Color(0xFF19392C),
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${_viewModel.total} records',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_viewModel.beneficiaries.isEmpty)
            _buildEmptyState()
          else
            ..._viewModel.beneficiaries.map(_buildBeneficiaryCard),
          if (_viewModel.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: green),
              ),
            ),
          if (_viewModel.error != null &&
              _viewModel.beneficiaries.isNotEmpty)
            TextButton.icon(
              onPressed: () => _viewModel.loadBeneficiaries(
                search: _search,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Failed to load more. Retry'),
            ),
        ],
      ),
    );
  }


  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search name or beneficiary code...',
        prefixIcon: const Icon(
          Icons.search,
          color: Colors.blueGrey,
        ),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            _searchController.clear();
            _onSearchChanged('');
            setState(() {});
          },
          icon: const Icon(Icons.close),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE1E8E4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Color(0xFFE1E8E4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard(BeneficiaryModel beneficiary) {
    final status = beneficiary.recordStatus ?? 'Unknown';
    final assessment = beneficiary.assessmentStatus ?? 'Unknown';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE3EAE6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BeneficiaryDetailScreen(
                beneficiary: beneficiary,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: const Color(0xFFE8F4EC),
                    child: Icon(
                      beneficiary.gender?.toLowerCase() == 'female'
                          ? Icons.person_2_outlined
                          : Icons.person_outline,
                      color: green,
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beneficiary.name,
                          style: const TextStyle(
                            color: Color(0xFF18372B),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          beneficiary.beneficiaryCode.isEmpty
                              ? 'Code unavailable'
                              : beneficiary.beneficiaryCode,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.blueGrey,
                    size: 27,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusBadge(status),
                  _statusBadge(assessment),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEDF0EE)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.cake_outlined,
                    size: 17,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      beneficiary.age != null
                          ? '${beneficiary.age} years'
                          : 'Age unavailable',
                      style: const TextStyle(
                        color: Color(0xFF5D6D64),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    beneficiary.mobile ?? 'No mobile',
                    style: const TextStyle(
                      color: Color(0xFF5D6D64),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (beneficiary.villageName != null &&
                  beneficiary.villageName!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        beneficiary.villageName!,
                        style: const TextStyle(
                          color: Color(0xFF5D6D64),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 17,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Applications: ${beneficiary.applicationCount}',
                      style: const TextStyle(
                        color: Color(0xFF5D6D64),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Text(
                    'View details',
                    style: TextStyle(
                      color: green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();

    final Color color;
    final Color fill;

    if (normalized.contains('completed') ||
        normalized == 'assessed' ||
        normalized == 'approved') {
      color = const Color(0xFF087443);
      fill = const Color(0xFFE5F5EA);
    } else if (normalized.contains('pending') ||
        normalized.contains('progress')) {
      color = const Color(0xFF996515);
      fill = const Color(0xFFFFF4D8);
    } else if (normalized == 'matched') {
      color = const Color(0xFF2457A7);
      fill = const Color(0xFFE8F0FF);
    } else {
      color = const Color(0xFF58665E);
      fill = const Color(0xFFF0F3F1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: 55,
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 12),
          const Text(
            'No beneficiaries found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _search.isEmpty
                ? 'Beneficiaries will appear here when available.'
                : 'Try searching with another name or code.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}
