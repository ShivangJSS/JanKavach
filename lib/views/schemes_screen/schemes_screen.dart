
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 11),
          _buildSearch(),
          const SizedBox(height: 11),
          _buildFilters(),
          const SizedBox(height: 13),
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
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: green),
              ),
            ),
          if (!_viewModel.isLoading &&
              !_viewModel.isLoadingMore &&
              _viewModel.schemes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Text(
                  'Showing ${_viewModel.schemes.length} of ${_viewModel.total} schemes',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD9FDE7),
            Color(0xFFF4FFF8),
            Color(0xFFC8FAD9),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7BE3A6), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16B85C).withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 22,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.65),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF28D17C), Color(0xFF0B8A54)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Explore government welfare schemes and review their benefits and eligibility details.',
                      style: TextStyle(
                        color: Color(0xFF24473A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFCFE2D7), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _searchSchemes,
        style: const TextStyle(fontSize: 13, color: Color(0xFF162921)),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Search schemes...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6B7B73)),
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF547264),
            size: 19,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 38,
          ),
          suffixIcon: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF6B7B73),
            ),
            onPressed: () {
              _searchController.clear();
              _searchSchemes('');
            },
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: ['All', 'National', 'State'].asMap().entries.map((entry) {
        final index = entry.key;
        final filter = entry.value;
        final selected = _filter == filter;

        final List<Color> selectedGradient;
        final Color glowColor;
        if (filter == 'National') {
          selectedGradient = const [Color(0xFFFF9E1B), Color(0xFFE65C00)];
          glowColor = const Color(0xFFF57C00);
        } else if (filter == 'State') {
          selectedGradient = const [Color(0xFF33A3FF), Color(0xFF0B62D6)];
          glowColor = const Color(0xFF1D8BFF);
        } else {
          selectedGradient = const [Color(0xFF28D17C), Color(0xFF0B8A54)];
          glowColor = const Color(0xFF16B85C);
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _filter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 36,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: selectedGradient,
                        )
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white, Color(0xFFF5F9F6)],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? selectedGradient.first.withValues(alpha: 0.7)
                        : const Color(0xFFD0DFD6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: selected
                          ? glowColor.withValues(alpha: 0.28)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: selected ? 8 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: selected ? Colors.white : darkGreen,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  _SchemeCardPalette _schemePaletteForLevel(String level) {
    final isState = level.toLowerCase().contains('state');
    if (isState) {
      return const _SchemeCardPalette(
        cardGradient: [
          Color(0xFFC8E4FF),
          Color(0xFFF0F8FF),
          Color(0xFFB5DAFF),
        ],
        border: Color(0xFF66B5FF),
        iconGradient: [Color(0xFF33A3FF), Color(0xFF0B62D6)],
        accent: Color(0xFF0B62D6),
        badgeBorder: Color(0xFF8ECAFF),
        badgeText: Color(0xFF0952B5),
      );
    }

    // National schemes in tight bright light orange
    return const _SchemeCardPalette(
      cardGradient: [
        Color(0xFFFFDFB3),
        Color(0xFFFFF5E6),
        Color(0xFFFFCF91),
      ],
      border: Color(0xFFFFAD47),
      iconGradient: [Color(0xFFFF9E1B), Color(0xFFE65C00)],
      accent: Color(0xFFE65C00),
      badgeBorder: Color(0xFFFFBD70),
      badgeText: Color(0xFFC24C00),
    );
  }

  Widget _buildSchemeCard(SchemeModel scheme) {
    final subtitle = (scheme.description?.trim().isNotEmpty ?? false)
        ? scheme.description!.trim()
        : (scheme.benefitDescription?.trim().isNotEmpty ?? false)
        ? scheme.benefitDescription!.trim()
        : scheme.eligibilitySummary?.trim() ?? '';

    final palette = _schemePaletteForLevel(scheme.level);

    final stateName = scheme.stateName?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.65),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SchemeDetailScreen(scheme: scheme),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: palette.iconGradient,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: palette.accent.withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _iconForTheme(scheme.themeName),
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    scheme.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF142C25),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _levelBadge(
                                  scheme.level,
                                  palette.badgeBorder,
                                  palette.badgeText,
                                ),
                              ],
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF42544C),
                                  fontSize: 12,
                                  height: 1.32,
                                ),
                              ),
                            ],
                            if (stateName.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: palette.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      stateName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.accent,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: palette.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelBadge(String level, Color borderColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.9),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
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

class _SchemeCardPalette {
  final List<Color> cardGradient;
  final Color border;
  final List<Color> iconGradient;
  final Color accent;
  final Color badgeBorder;
  final Color badgeText;

  const _SchemeCardPalette({
    required this.cardGradient,
    required this.border,
    required this.iconGradient,
    required this.accent,
    required this.badgeBorder,
    required this.badgeText,
  });
}
