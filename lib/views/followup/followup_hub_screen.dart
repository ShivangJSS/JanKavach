import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/followup_model.dart';
import '../../data/repository/followup_repository.dart';
import '../../viewModels/followup_viewmodel.dart';
import 'beneficiary_followup_screen.dart';
import 'record_followup_sheet.dart';

class FollowupHubScreen extends StatefulWidget {
  final String? initialDueFilter;
  final FollowupRepository? repository;

  const FollowupHubScreen({
    super.key,
    this.initialDueFilter,
    this.repository,
  });

  @override
  State<FollowupHubScreen> createState() => _FollowupHubScreenState();
}

class _FollowupHubScreenState extends State<FollowupHubScreen> {
  static const Color green = Color(0xFF075832);
  static const Color darkGreen = Color(0xFF06452D);
  static const Color background = Color(0xFFF4F7F5);

  late final FollowupViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = FollowupViewModel(repository: widget.repository);
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.initialize(initialDueFilter: widget.initialDueFilter);

    _scrollController.addListener(_onScroll);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      _viewModel.loadNextPage();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          context.tr('followup.scheme_followups'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _viewModel.initialize(),
        color: green,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Top Summary Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryMetrics(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 14),
                    _buildStatusFilterChips(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          context.tr('followup.register_title'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16231C),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.tr('beneficiaries.records_count', args: {'count': '${_viewModel.totalItems}'}),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Register Items List
            if (_viewModel.isLoadingRegister)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: green),
                ),
              )
            else if (_viewModel.registerItems.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 60,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('followup.no_records'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16231C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('followup.no_records_sub'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _viewModel.registerItems[index];
                      return _buildFollowupCard(item);
                    },
                    childCount: _viewModel.registerItems.length,
                  ),
                ),
              ),

            // Pagination loader
            if (_viewModel.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: green,
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    final data = _viewModel.dashboardData;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.85,
      children: [
        _buildMetricCard(
          label: 'Registered\nBeneficiaries',
          value: data != null ? data.totalUsersRegistered.toString() : '...',
          icon: Icons.people_outline,
          gradientColors: const [Color(0xFF28D17C), Color(0xFF0B8A54)],
          glowColor: const Color(0xFF16B85C),
          accentColor: const Color(0xFF0A8754),
        ),
        _buildMetricCard(
          label: 'Total Applied\nSubmitted',
          value: data != null ? data.totalApplied.toString() : '...',
          icon: Icons.description_outlined,
          gradientColors: const [Color(0xFF33A3FF), Color(0xFF0B62D6)],
          glowColor: const Color(0xFF1D8BFF),
          accentColor: const Color(0xFF0B62D6),
        ),
        _buildMetricCard(
          label: 'Pending\nFollow-ups',
          value: data != null ? data.pending.toString() : '...',
          icon: Icons.pending_actions_rounded,
          gradientColors: const [Color(0xFFFFA726), Color(0xFFE65C00)],
          glowColor: const Color(0xFFF57C00),
          accentColor: const Color(0xFFE65C00),
        ),
        _buildMetricCard(
          label: 'Benefit\nCompleted',
          value: data != null ? data.complete.toString() : '...',
          icon: Icons.verified_outlined,
          gradientColors: const [Color(0xFF14CFA8), Color(0xFF06846C)],
          glowColor: const Color(0xFF0D9488),
          accentColor: const Color(0xFF06846C),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    required Color glowColor,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.48),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.34),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.34),
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 0.8],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -18,
              right: -14,
              child: IgnorePointer(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: accentColor, size: 19),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.94),
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            label: context.tr('followup.all_status'),
            isSelected: _viewModel.statusFilter == 'all',
            onTap: () => _viewModel.setStatusFilter('all'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: context.tr('followup.pending_tab'),
            isSelected: _viewModel.statusFilter == 'Pending',
            color: const Color(0xFFD9700C),
            onTap: () => _viewModel.setStatusFilter('Pending'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: context.tr('followup.status_applied'),
            isSelected: _viewModel.statusFilter == 'Applied',
            color: const Color(0xFF1377CC),
            onTap: () => _viewModel.setStatusFilter('Applied'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: context.tr('followup.status_complete'),
            isSelected: _viewModel.statusFilter == 'Complete',
            color: const Color(0xFF168A53),
            onTap: () => _viewModel.setStatusFilter('Complete'),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    Color color = green,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFD8E2DC),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF26352E),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (val) => _viewModel.setSearch(val),
      decoration: InputDecoration(
        hintText: 'Search beneficiary, mobile, scheme...',
        prefixIcon: const Icon(Icons.search, color: Colors.blueGrey, size: 22),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _viewModel.setSearch('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8E2DC)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8E2DC)),
        ),
      ),
    );
  }

  Widget _buildFollowupCard(FollowupRegisterItem item) {
    final status = item.status;
    final normalizedStatus = status.trim().toLowerCase();
    final isComplete =
        normalizedStatus == 'complete' || normalizedStatus == 'completed';
    final isApplied = normalizedStatus == 'applied';
    final isDocIssue = (item.pendingReason?.toLowerCase().contains('doc') ?? false);

    final List<Color> gradientColors;
    final List<Color> avatarGradient;
    final Color borderCol;
    final Color statusColor;
    final String statusLabel;

    if (isComplete) {
      gradientColors = const [
        Color(0xFFD5FDE4),
        Color(0xFFF5FFF9),
        Color(0xFFC4FBD9),
      ];
      avatarGradient = const [Color(0xFF28D17C), Color(0xFF0B8A54)];
      borderCol = const Color(0xFF6CE29D);
      statusColor = const Color(0xFF0B8A54);
      statusLabel = 'Complete';
    } else if (isApplied) {
      gradientColors = const [
        Color(0xFFD1EBFF),
        Color(0xFFF4FAFF),
        Color(0xFFBEE2FF),
      ];
      avatarGradient = const [Color(0xFF33A3FF), Color(0xFF0B62D6)];
      borderCol = const Color(0xFF6CB9FF);
      statusColor = const Color(0xFF0B62D6);
      statusLabel = 'Applied (${item.applicationNumber ?? "CSC"})';
    } else if (isDocIssue) {
      gradientColors = const [
        Color(0xFFFFE2BA),
        Color(0xFFFFF8EE),
        Color(0xFFFFD49C),
      ];
      avatarGradient = const [Color(0xFFFFA726), Color(0xFFE65C00)];
      borderCol = const Color(0xFFFFB24D);
      statusColor = const Color(0xFFE65C00);
      statusLabel = 'Doc Issue: ${item.documentIssue ?? "Pending"}';
    } else {
      gradientColors = const [
        Color(0xFFFFFAF2),
        Colors.white,
        Color(0xFFFFEED9),
      ];
      avatarGradient = const [Color(0xFF28D17C), Color(0xFF0B8A54)];
      borderCol = const Color(0xFFFFCB8A);
      statusColor = const Color(0xFFD9700C);
      statusLabel = item.pendingReason ?? 'Not applied yet';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
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
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  // Open beneficiary profile to see all schemes
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BeneficiaryFollowupScreen(
                        beneficiaryId: item.beneficiaryId,
                        beneficiaryName: item.beneficiaryName,
                        repository: widget.repository,
                      ),
                    ),
                  ).then((_) => _viewModel.loadRegister(refresh: true));
                },
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Beneficiary Name & Status Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: avatarGradient.last.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              item.gender?.toLowerCase() == 'female'
                                  ? Icons.person_2_outlined
                                  : Icons.person_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.beneficiaryName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16231C),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.beneficiaryCode} · ${item.village ?? "Village not set"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4A5B52),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderCol),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: borderCol.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 10),

                      // Scheme Info
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_outlined,
                            size: 16,
                            color: green,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.schemeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16231C),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (item.nextFollowupDate != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              size: 15,
                              color: Color(0xFFD9700C),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Next Follow-up Due: ${item.nextFollowupDate}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB85900),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BeneficiaryFollowupScreen(
                                      beneficiaryId: item.beneficiaryId,
                                      beneficiaryName: item.beneficiaryName,
                                      repository: widget.repository,
                                    ),
                                  ),
                                ).then(
                                  (_) => _viewModel.loadRegister(refresh: true),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.85,
                                ),
                                foregroundColor: const Color(0xFF16231C),
                                side: BorderSide(color: borderCol),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 9),
                              ),
                              child: const Text(
                                'All Schemes',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AbsorbPointer(
                              absorbing: isComplete,
                              child: ElevatedButton.icon(
                                onPressed: isComplete
                                    ? null
                                    : () async {
                                        final updated =
                                            await RecordFollowupSheet.show(
                                          context,
                                          beneficiaryId: item.beneficiaryId,
                                          beneficiaryName: item.beneficiaryName,
                                          schemeId: item.schemeId,
                                          schemeName: item.schemeName,
                                          repository: widget.repository,
                                          existingFollowup: SchemeFollowupDetail(
                                            id: item.followupId,
                                            status: item.status,
                                            pendingReason: item.pendingReason,
                                            documentIssueName:
                                                item.documentIssue,
                                            applicationNumber:
                                                item.applicationNumber,
                                            submissionDate: item.submissionDate,
                                            benefitReceivedDate:
                                                item.benefitReceivedDate,
                                            nextFollowupDate:
                                                item.nextFollowupDate,
                                            notes: item.notes,
                                          ),
                                        );
                                        if (updated == true) {
                                          _viewModel.initialize();
                                        }
                                      },
                                icon: Icon(
                                  isComplete
                                      ? Icons.verified_rounded
                                      : Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: Text(
                                  isComplete ? 'Completed' : 'Take Follow-up',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: statusColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFFD2F5DF),
                                  disabledForegroundColor:
                                      const Color(0xFF0B8A54),
                                  elevation: isComplete ? 0 : 2,
                                  shadowColor:
                                      statusColor.withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                ),
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
}
