import 'package:flutter/material.dart';
import '../../data/models/followup_model.dart';
import '../../viewModels/followup_viewmodel.dart';
import 'beneficiary_followup_screen.dart';
import 'record_followup_sheet.dart';

class FollowupHubScreen extends StatefulWidget {
  final String? initialDueFilter;

  const FollowupHubScreen({
    super.key,
    this.initialDueFilter,
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
    _viewModel = FollowupViewModel();
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
        title: const Text(
          'Scheme Follow-ups',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                        const Text(
                          'Follow-up Register',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16231C),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_viewModel.totalItems} records',
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
                        const Text(
                          'No follow-up records found',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16231C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try clearing filters or search query.',
                          style: TextStyle(color: Colors.grey),
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
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.0,
      children: [
        _buildMetricCard(
          label: 'Registered\nBeneficiaries',
          value: data != null ? data.totalUsersRegistered.toString() : '...',
          icon: Icons.people_outline,
          cardColor: const Color(0xFFEDF7EE),
          borderColor: const Color(0xFFD2EBD9),
          accentColor: const Color(0xFF168A53),
        ),
        _buildMetricCard(
          label: 'Total Applied\nSubmitted',
          value: data != null ? data.totalApplied.toString() : '...',
          icon: Icons.description_outlined,
          cardColor: const Color(0xFFEEF6FF),
          borderColor: const Color(0xFFCCE2FE),
          accentColor: const Color(0xFF1377CC),
        ),
        _buildMetricCard(
          label: 'Pending\nFollow-ups',
          value: data != null ? data.pending.toString() : '...',
          icon: Icons.pending_actions_rounded,
          cardColor: const Color(0xFFFFF4E8),
          borderColor: const Color(0xFFFFE0BE),
          accentColor: const Color(0xFFD9700C),
        ),
        _buildMetricCard(
          label: 'Benefit\nCompleted',
          value: data != null ? data.complete.toString() : '...',
          icon: Icons.verified_outlined,
          cardColor: const Color(0xFFEDF7EE),
          borderColor: const Color(0xFFD2EBD9),
          accentColor: const Color(0xFF116B3F),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color cardColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.1,
                    color: Color(0xFF5A6860),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            label: 'All Status',
            isSelected: _viewModel.statusFilter == 'all',
            onTap: () => _viewModel.setStatusFilter('all'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Pending',
            isSelected: _viewModel.statusFilter == 'Pending',
            color: const Color(0xFFD9700C),
            onTap: () => _viewModel.setStatusFilter('Pending'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Applied',
            isSelected: _viewModel.statusFilter == 'Applied',
            color: const Color(0xFF1377CC),
            onTap: () => _viewModel.setStatusFilter('Applied'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Complete',
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
    final isDocIssue = (item.pendingReason?.toLowerCase().contains('doc') ?? false);

    final Color cardBg;
    final Color borderCol;
    final Color statusColor;
    final String statusLabel;

    if (status == 'Complete') {
      cardBg = const Color(0xFFEDF7EE);
      borderCol = const Color(0xFFD2EBD9);
      statusColor = const Color(0xFF168A53);
      statusLabel = 'Complete';
    } else if (status == 'Applied') {
      cardBg = const Color(0xFFEEF6FF);
      borderCol = const Color(0xFFCCE2FE);
      statusColor = const Color(0xFF1377CC);
      statusLabel = 'Applied (${item.applicationNumber ?? "CSC"})';
    } else if (isDocIssue) {
      cardBg = const Color(0xFFFFF4E8);
      borderCol = const Color(0xFFFFE0BE);
      statusColor = const Color(0xFFD9700C);
      statusLabel = 'Doc Issue: ${item.documentIssue ?? "Pending"}';
    } else {
      cardBg = Colors.white;
      borderCol = const Color(0xFFE2E8E4);
      statusColor = Colors.blueGrey;
      statusLabel = item.pendingReason ?? 'Not applied yet';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(
                      item.gender?.toLowerCase() == 'female'
                          ? Icons.person_2_outlined
                          : Icons.person_outline,
                      color: green,
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
                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
              const Divider(height: 1, color: Color(0xFFE2E8E4)),
              const SizedBox(height: 10),

              // Scheme Info
              Row(
                children: [
                  const Icon(Icons.account_balance_outlined, size: 16, color: green),
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
                    const Icon(Icons.event_outlined, size: 15, color: Color(0xFFD9700C)),
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
                            ),
                          ),
                        ).then((_) => _viewModel.loadRegister(refresh: true));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF16231C),
                        side: const BorderSide(color: Color(0xFFD8E2DC)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      child: const Text('All Schemes', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await RecordFollowupSheet.show(
                          context,
                          beneficiaryId: item.beneficiaryId,
                          beneficiaryName: item.beneficiaryName,
                          schemeId: item.schemeId,
                          schemeName: item.schemeName,
                          existingFollowup: SchemeFollowupDetail(
                            id: item.followupId,
                            status: item.status,
                            pendingReason: item.pendingReason,
                            documentIssueName: item.documentIssue,
                            applicationNumber: item.applicationNumber,
                            submissionDate: item.submissionDate,
                            benefitReceivedDate: item.benefitReceivedDate,
                            nextFollowupDate: item.nextFollowupDate,
                            notes: item.notes,
                          ),
                        );
                        if (updated == true) {
                          _viewModel.initialize();
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Take Follow-up', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
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
}
