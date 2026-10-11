
import 'package:flutter/material.dart';

import '../../data/models/scheme_model.dart';
import '../../viewmodels/scheme_viewmodel.dart';
import '../scheme_detail_screen/scheme_detail_screen.dart';


class SchemesScreen extends StatefulWidget {
  const SchemesScreen({super.key});

  @override
  State<SchemesScreen> createState() => _SchemesScreenState();
}

class _SchemesScreenState extends State<SchemesScreen> {
  static const Color green = Color(0xFF087443);
  static const Color darkGreen = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  late final SchemeViewModel _viewModel;
  final TextEditingController _searchController =
  TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _filter = 'All';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _viewModel = SchemeViewModel();
    _viewModel.addListener(_refresh);
    _viewModel.loadSchemes();

    _scrollController.addListener(_onScroll);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      _viewModel.loadSchemes(search: _search);
    }
  }

  Future<void> _searchSchemes(String value) async {
    _search = value.trim();
    await _viewModel.loadSchemes(
      refresh: true,
      search: _search,
    );
  }

  List<SchemeModel> get _filteredSchemes {
    return _viewModel.schemes.where((scheme) {
      if (_filter == 'National') {
        return scheme.level.toLowerCase() == 'national';
      }

      if (_filter == 'State') {
        return scheme.level.toLowerCase() == 'state' ||
            scheme.level.toLowerCase() == 'national+state';
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
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

            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.schemes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
    }

    if (_viewModel.error != null && _viewModel.schemes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 42, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _viewModel.loadSchemes(
                  refresh: true,
                  search: _search,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final schemes = _filteredSchemes;

    return RefreshIndicator(
      color: green,
      onRefresh: () => _viewModel.loadSchemes(
        refresh: true,
        search: _search,
      ),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 18),
          _buildSearch(),
          const SizedBox(height: 16),
          _buildFilters(),
          const SizedBox(height: 20),
          if (schemes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('No schemes found.'),
              ),
            )
          else
            ...schemes.map(_buildSchemeCard),
          if (_viewModel.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Center(
                child: CircularProgressIndicator(color: green),
              ),
            ),
          if (!_viewModel.isLoading &&
              !_viewModel.isLoadingMore &&
              _viewModel.schemes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Showing ${_viewModel.schemes.length} of ${_viewModel.total} schemes',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD3E9DC)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: green, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Explore government welfare schemes and review their benefits and eligibility details.',
              style: TextStyle(
                color: Color(0xFF35564A),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: _searchSchemes,
      decoration: InputDecoration(
        hintText: 'Search schemes...',
        prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _searchController.clear();
            _searchSchemes('');
          },
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE0E5E2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE0E5E2)),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: ['All', 'National', 'State'].map((filter) {
        final selected = _filter == filter;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Center(child: Text(filter)),
              selected: selected,
              showCheckmark: false,
              selectedColor: green,
              backgroundColor: Colors.transparent,
              side: BorderSide(
                color: selected ? green : const Color(0xFFDCE4DF),
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.white : darkGreen,
                fontWeight: FontWeight.w600,
              ),
              shape: const StadiumBorder(),
              onSelected: (_) {
                setState(() => _filter = filter);
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSchemeCard(SchemeModel scheme) {
    final subtitle = (scheme.description?.trim().isNotEmpty ?? false)
        ? scheme.description!.trim()
        : (scheme.benefitDescription?.trim().isNotEmpty ?? false)
        ? scheme.benefitDescription!.trim()
        : scheme.eligibilitySummary?.trim() ?? '';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE4EBE7)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SchemeDetailScreen(scheme: scheme),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForTheme(scheme.themeName),
                  color: green,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Text(
                          scheme.name,
                          style: const TextStyle(
                            color: Color(0xFF142C25),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        _levelBadge(scheme.level),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6D7B75),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (scheme.stateName != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        scheme.stateName!,
                        style: const TextStyle(
                          color: green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 28,
                color: Colors.blueGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelBadge(String level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        level,
        style: const TextStyle(
          color: darkGreen,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _iconForTheme(String? theme) {
    switch (theme?.toLowerCase()) {
      case 'health':
        return Icons.health_and_safety_outlined;
      case 'education':
      case 'scholarship / fee support':
        return Icons.school_outlined;
      case 'housing':
        return Icons.home_outlined;
      case 'livelihood':
        return Icons.work_outline;
      case 'financial assistance':
      case 'financial inclusion':
        return Icons.account_balance_wallet_outlined;
      case 'insurance':
        return Icons.verified_user_outlined;
      case 'old age protection':
      case 'pension':
        return Icons.elderly_outlined;
      default:
        return Icons.account_balance_outlined;
    }
  }
}
