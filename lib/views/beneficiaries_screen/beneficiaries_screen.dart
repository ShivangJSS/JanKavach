
import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/beneficiary_local_dao.dart';
import '../../data/models/ beneficiary_model.dart';
import '../../core/localization/app_localizations.dart';
import '../../viewModels/beneficiary_viewmodel.dart';
import '../beneficiary_detail_screen/beneficiary_detail_screen.dart';
import '../beneficiary_registration/beneficiary_registration_screen.dart';
import '../../data/services/beneficiary_sync_service.dart';


class BeneficiariesScreen extends StatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  State<BeneficiariesScreen> createState() =>
      BeneficiariesScreenState();
}

class BeneficiariesScreenState extends State<BeneficiariesScreen> {
  final Set<int> _syncingBeneficiaryIds = <int>{};
  static const Color green = Color(0xFF087443);
  static const Color darkGreen = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  late final BeneficiaryViewModel _viewModel;
  final TextEditingController _searchController =
  TextEditingController();
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
          const SnackBar(
            content: Text('Unable to load saved drafts.'),
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


        builder: (_) => BeneficiaryRegistrationScreen(
          localDraftId: localId,
        ),
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
    await _viewModel.loadBeneficiaries(
      refresh: true,
      search: _search,
    );
  }

  Future<void> _syncBeneficiaryNow(BeneficiaryModel beneficiary) async {
    final localId = beneficiary.id.abs();
    if (_syncingBeneficiaryIds.contains(localId) ||
        BeneficiarySyncService.instance.isSyncingLocalId(localId)) {
      return;
    }

    setState(() => _syncingBeneficiaryIds.add(localId));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Syncing beneficiary with server...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final success = await BeneficiarySyncService.instance.syncSingleBeneficiary(localId);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beneficiary synced with server successfully!'),
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
                  ? 'Sync failed: $errorMsg'
                  : 'Unable to sync. Please ensure internet is connected.',
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
        child: Column(
          children: [
            Expanded(child: _buildBody()),
          ],
        ),
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
      return const Center(
        child: CircularProgressIndicator(color: green),
      );
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
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
              ),
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const SizedBox(height: 4),

          // Registered / Drafts tab selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFE1E8E4),
              ),
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
                    label: context.tr('beneficiaries.drafts_tab', args: {'count': '${_drafts.length}'}),
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

          const SizedBox(height: 18),

          // Show the selected tab's content
          if (_selectedTab == 0) ...[
            _buildSearchField(),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('beneficiaries.title'),
                    style: const TextStyle(
                      color: Color(0xFF19392C),
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  context.tr('beneficiaries.records_count', args: {'count': '${_viewModel.total}'}),
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
              ..._viewModel.beneficiaries
                  .map(_buildBeneficiaryCard),

            if (_viewModel.isLoadingMore)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: green,
                  ),
                ),
              ),

            if (_viewModel.error != null &&
                _viewModel.beneficiaries.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _viewModel.loadBeneficiaries(
                    search: _search,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Failed to load more. Retry',
                ),
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
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? green : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : darkGreen,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }



  Widget _buildDraftsList() {
    if (_isLoadingDrafts && _drafts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: green),
        ),
      );
    }

    if (_drafts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(
              Icons.drafts_outlined,
              size: 54,
              color: Colors.blueGrey,
            ),
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
        final formData = Map<String, dynamic>.from(
          draft['form_data'] as Map,
        );
        final formState = Map<String, dynamic>.from(
          formData['form_state'] as Map? ?? {},
        );
        final controllers = Map<String, dynamic>.from(
          formState['controllers'] as Map? ?? {},
        );

        final name = controllers['Beneficiary Name']
            ?.toString()
            .trim();

        final currentStep =
            (draft['current_step'] as num?)?.toInt() ?? 0;

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
              child: Icon(
                Icons.edit_note,
                color: Color(0xFFD9700C),
              ),
            ),
            title: Text(
              name == null || name.isEmpty
                  ? 'Unnamed beneficiary'
                  : name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF26352E),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Step ${currentStep + 1} of 6 · Saved on this device',
                style: const TextStyle(
                  color: Color(0xFF5D6B64),
                ),
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
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: context.tr('beneficiaries.search_hint'),
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
      color: const Color(0xFFEDF7EE),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD2EBD9)),
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
                    backgroundColor: Colors.white,
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
                            color: Color(0xFF5A6E63),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: green.withValues(alpha: 0.7),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _statusBadge(status),
                  _statusBadge(assessment),
                  if (status.contains('Sync Failed') || status.contains('Pending Sync'))
                    Builder(
                      builder: (context) {
                        final isSyncing = _syncingBeneficiaryIds.contains(beneficiary.id.abs()) ||
                            BeneficiarySyncService.instance.isSyncingLocalId(beneficiary.id.abs());

                        return InkWell(
                          onTap: isSyncing ? null : () => _syncBeneficiaryNow(beneficiary),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSyncing ? const Color(0xFF06452D) : const Color(0xFF075832),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSyncing)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                else
                                  const Icon(Icons.sync, color: Colors.white, size: 13),
                                const SizedBox(width: 5),
                                Text(
                                  isSyncing ? 'Syncing...' : 'Sync Now',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
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
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFD2EBD9)),
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
                      fontWeight: FontWeight.w700,
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
