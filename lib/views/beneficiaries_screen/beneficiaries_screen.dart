import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/beneficiary_local_dao.dart';
import '../../data/models/ beneficiary_model.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/localized_value_helper.dart';
import '../../viewModels/beneficiary_viewmodel.dart';
import '../beneficiary_detail_screen/beneficiary_detail_screen.dart';
import '../beneficiary_registration/beneficiary_registration_screen.dart';
import '../../data/services/beneficiary_sync_service.dart';

class BeneficiariesScreen extends StatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  State<BeneficiariesScreen> createState() => BeneficiariesScreenState();
}

class BeneficiariesScreenState extends State<BeneficiariesScreen> {
  final Set<int> _syncingBeneficiaryIds = <int>{};
  static const Color green = Color(0xFF087443);
  static const Color darkGreen = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  late final BeneficiaryViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final BeneficiaryLocalDao _localDao = BeneficiaryLocalDao();

  int _selectedTab = 0;

  List<Map<String, dynamic>> _drafts = [];
  bool _isLoadingDrafts = false;
  Timer? _searchDebounce;
  String _search = '';

  @override
  void initState() {
    super.initState();

    _viewModel = BeneficiaryViewModel();
    _viewModel.addListener(_refresh);
    _viewModel.loadBeneficiaries();
    _loadDrafts();
    _scrollController.addListener(_onScroll);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_selectedTab != 0) return;
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      _viewModel.loadBeneficiaries(search: _search);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;

      _search = value.trim();
      _viewModel.loadBeneficiaries(refresh: true, search: _search);
    });
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoadingDrafts = true);

    try {
      final drafts = await _localDao.getDrafts();

      if (!mounted) return;

      setState(() {
        _drafts = drafts;
      });
    } catch (error) {
      debugPrint('Loading drafts failed: $error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('beneficiaries.drafts_load_error')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDrafts = false);
      }
    }
  }

  Future<void> _resumeDraft(int localId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BeneficiaryRegistrationScreen(localDraftId: localId),
      ),
    );

    if (!mounted) return;

    await _loadDrafts();
    if (result == true) {
      await _refreshList();
    }
  }

  Future<void> refreshBeneficiaries() async {
    if (!mounted) return;
    await _loadDrafts();
    await _refreshList();
  }

  Future<void> _refreshList() async {
    await _viewModel.loadBeneficiaries(refresh: true, search: _search);
  }

  Future<void> _syncBeneficiaryNow(BeneficiaryModel beneficiary) async {
    final localId = beneficiary.id.abs();
    if (_syncingBeneficiaryIds.contains(localId) ||
        BeneficiarySyncService.instance.isSyncingLocalId(localId)) {
      return;
    }

    setState(() => _syncingBeneficiaryIds.add(localId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(context.tr('beneficiaries.syncing_beneficiary')),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final success = await BeneficiarySyncService.instance
          .syncSingleBeneficiary(localId);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('beneficiaries.sync_beneficiary_success')),
            backgroundColor: green,
          ),
        );
        await refreshBeneficiaries();
      } else {
        final record = await _localDao.getRecord(localId);
        if (!mounted) return;
        final errorMsg = record?['sync_error']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg != null && errorMsg.isNotEmpty
                  ? context.tr(
                      'beneficiaries.sync_failed_reason',
                      args: {'error': errorMsg},
                    )
                  : context.tr('beneficiaries.sync_no_internet'),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        await refreshBeneficiaries();
      }
    } finally {
      if (mounted) {
        setState(() => _syncingBeneficiaryIds.remove(localId));
      }
    }
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
        child: Column(children: [Expanded(child: _buildBody())]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const BeneficiaryRegistrationScreen(),
            ),
          );
          if (!mounted) return;
          await _loadDrafts();
          if (result == true) {
            await _refreshList();
          }
        },
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(
          context.tr('beneficiaries.add_beneficiary'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedTab == 0 &&
        _viewModel.isLoading &&
        _viewModel.beneficiaries.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: green));
    }

    if (_selectedTab == 0 &&
        _viewModel.error != null &&
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
              Text(_viewModel.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshList,
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('common.retry')),
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
      onRefresh: () async {
        if (_selectedTab == 0) {
          await _refreshList();
        } else {
          await _loadDrafts();
        }
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 84),
        children: [
          const SizedBox(height: 0),

          // Registered / Drafts tab selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD5E3DB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: context.tr('beneficiaries.registered_tab'),
                    selected: _selectedTab == 0,
                    onTap: () {
                      setState(() => _selectedTab = 0);
                    },
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    label: context.tr(
                      'beneficiaries.drafts_tab',
                      args: {'count': '${_drafts.length}'},
                    ),
                    selected: _selectedTab == 1,
                    onTap: () {
                      setState(() => _selectedTab = 1);
                      _loadDrafts();
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 9),

          // Show the selected tab's content
          if (_selectedTab == 0) ...[
            _buildSearchField(),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('beneficiaries.title'),
                    style: const TextStyle(
                      color: Color(0xFF19392C),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  context.tr(
                    'beneficiaries.records_count',
                    args: {'count': '${_viewModel.total}'},
                  ),
                  style: const TextStyle(
                    color: Color(0xFF5A6E63),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (_viewModel.beneficiaries.isEmpty)
              _buildEmptyState()
            else
              ..._viewModel.beneficiaries.asMap().entries.map(
                (entry) => _buildBeneficiaryCard(entry.value, entry.key),
              ),

            if (_viewModel.isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: green)),
              ),

            if (_viewModel.error != null && _viewModel.beneficiaries.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _viewModel.loadBeneficiaries(search: _search);
                },
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('beneficiaries.load_more_retry')),
              ),
          ] else ...[
            _buildDraftsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF159957), Color(0xFF075832)],
                )
              : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: green.withValues(alpha: 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDraftsList() {
    if (_isLoadingDrafts && _drafts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: green)),
      );
    }

    if (_drafts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.drafts_outlined, size: 54, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(
              context.tr('beneficiaries.no_drafts'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('beneficiaries.no_drafts_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadDrafts,
              icon: const Icon(Icons.refresh),
              label: Text(context.tr('common.retry')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _drafts.map((draft) {
        final localId = draft['local_id'] as int;
        final formData = Map<String, dynamic>.from(draft['form_data'] as Map);
        final formState = Map<String, dynamic>.from(
          formData['form_state'] as Map? ?? {},
        );
        final controllers = Map<String, dynamic>.from(
          formState['controllers'] as Map? ?? {},
        );

        final name = controllers['Beneficiary Name']?.toString().trim();

        final currentStep = (draft['current_step'] as num?)?.toInt() ?? 0;

        return Card(
          color: const Color(0xFFFFF4E8),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFFFE0BE)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.edit_note, color: Color(0xFFD9700C)),
            ),
            title: Text(
              name == null || name.isEmpty
                  ? context.tr('beneficiaries.unnamed_beneficiary')
                  : name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF26352E),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                context.tr(
                  'beneficiaries.draft_step_device',
                  args: {'current': '${currentStep + 1}', 'total': '6'},
                ),
                style: const TextStyle(color: Color(0xFF5D6B64)),
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD9700C),
            ),
            onTap: () => _resumeDraft(localId),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchField() {
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
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, color: Color(0xFF162921)),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: context.tr('beneficiaries.search_hint'),
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
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF6B7B73),
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard(BeneficiaryModel beneficiary, int index) {
    final status = beneficiary.recordStatus ?? 'Unknown';
    final assessment = beneficiary.assessmentStatus ?? 'Unknown';
    final isAlt = index.isOdd;

    // Alternating two harmonious glossy palettes: Soft Mint Emerald <-> Soft Sky Blue
    final List<Color> cardGradient = isAlt
        ? const [Color(0xFFCDE7FF), Color(0xFFF3F9FF), Color(0xFFBDDEFF)]
        : const [Color(0xFFD6FCE5), Color(0xFFF4FFF9), Color(0xFFC4FBD9)];
    final List<Color> avatarGradient = isAlt
        ? const [Color(0xFF33A3FF), Color(0xFF0B62D6)]
        : const [Color(0xFF28D17C), Color(0xFF0B8A54)];
    final Color borderColor = isAlt
        ? const Color(0xFF6EB9FF)
        : const Color(0xFF6CE29D);
    final Color accentColor = isAlt
        ? const Color(0xFF0B62D6)
        : const Color(0xFF0B8A54);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardGradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.14),
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
                      builder: (_) =>
                          BeneficiaryDetailScreen(beneficiary: beneficiary),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: avatarGradient,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              beneficiary.gender?.toLowerCase() == 'female'
                                  ? Icons.person_2_outlined
                                  : Icons.person_outline,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  beneficiary.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF142C25),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  beneficiary.beneficiaryCode.isEmpty
                                      ? context.tr(
                                          'beneficiaries.code_unavailable',
                                        )
                                      : beneficiary.beneficiaryCode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF495C53),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              color: accentColor,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _statusBadge(status),
                          _statusBadge(assessment),
                          if (status.contains('Sync Failed') ||
                              status.contains('Pending Sync'))
                            Builder(
                              builder: (context) {
                                final isSyncing =
                                    _syncingBeneficiaryIds.contains(
                                      beneficiary.id.abs(),
                                    ) ||
                                    BeneficiarySyncService.instance
                                        .isSyncingLocalId(beneficiary.id.abs());

                                return InkWell(
                                  onTap: isSyncing
                                      ? null
                                      : () => _syncBeneficiaryNow(beneficiary),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSyncing
                                          ? const Color(0xFF06452D)
                                          : const Color(0xFF075832),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSyncing)
                                          const SizedBox(
                                            width: 11,
                                            height: 11,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.sync,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isSyncing
                                              ? context.tr('common.syncing')
                                              : context.tr(
                                                  'beneficiaries.sync_now',
                                                ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(
                        height: 1,
                        color: borderColor.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              LocalizedValueHelper.formatAge(
                                context,
                                beneficiary.age,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF42544C),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (beneficiary.mobile != null &&
                                    beneficiary.mobile!.trim().isNotEmpty)
                                ? beneficiary.mobile!
                                : context.tr('beneficiaries.no_mobile'),
                            style: const TextStyle(
                              color: Color(0xFF42544C),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            beneficiary.villageName != null &&
                                    beneficiary.villageName!.isNotEmpty
                                ? Icons.location_on_outlined
                                : Icons.description_outlined,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              beneficiary.villageName != null &&
                                      beneficiary.villageName!.isNotEmpty
                                  ? '${beneficiary.villageName!}  •  ${context.tr('beneficiaries.apps_short', args: {'count': '${beneficiary.applicationCount}'})}'
                                  : context.tr(
                                      'beneficiaries.applications_count',
                                      args: {
                                        'count':
                                            '${beneficiary.applicationCount}',
                                      },
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF42544C),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: borderColor.withValues(alpha: 0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              context.tr('beneficiaries.view_details'),
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();

    final Color color;
    final Color fill;
    final Color border;

    if (normalized.contains('completed') ||
        normalized == 'assessed' ||
        normalized == 'approved') {
      color = const Color(0xFF0A7D43);
      fill = Colors.white.withValues(alpha: 0.92);
      border = const Color(0xFF7BE3A6);
    } else if (normalized.contains('pending') ||
        normalized.contains('progress')) {
      color = const Color(0xFFC25E00);
      fill = Colors.white.withValues(alpha: 0.92);
      border = const Color(0xFFFFC178);
    } else if (normalized == 'matched') {
      color = const Color(0xFF0B62D6);
      fill = Colors.white.withValues(alpha: 0.92);
      border = const Color(0xFF8ECAFF);
    } else {
      color = const Color(0xFF4B5C53);
      fill = Colors.white.withValues(alpha: 0.9);
      border = const Color(0xFFD0DBD5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        LocalizedValueHelper.translateStatus(context, status),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 55, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(
            context.tr('beneficiaries.no_beneficiaries'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('beneficiaries.no_beneficiaries_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}
