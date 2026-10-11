
import 'package:flutter/material.dart';
import '../../data/models/dashboard_response.dart';
import '../../data/services/api_service.dart';
import '../../data/services/storage_service.dart';
import '../beneficiaries_screen/beneficiaries_screen.dart';
import '../schemes_screen/schemes_screen.dart';
import '../settings_screen/settings_screen.dart';
import '../beneficiary_registration/beneficiary_registration_screen.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  DashboardSummary _summary = const DashboardSummary();
  bool _isDashboardLoading = true;
  String? _dashboardError;

  Map<String, dynamic>? _userProfile;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDashboardData();
  }
  Future<void> _loadDashboardData() async {
    try {
      final response = await ApiService().dio.get('/dashboard');

      final responseData =
      Map<String, dynamic>.from(response.data as Map);

      final data =
      Map<String, dynamic>.from(responseData['data'] as Map);

      final summaryJson =
      Map<String, dynamic>.from(data['summary'] as Map);

      if (!mounted) return;

      setState(() {
        _summary = DashboardSummary.fromJson(summaryJson);
        _isDashboardLoading = false;
        _dashboardError = null;
      });
    } catch (e) {
      debugPrint('Dashboard API error: $e');

      if (!mounted) return;

      setState(() {
        _isDashboardLoading = false;
        _dashboardError = 'Unable to load dashboard data';
      });
    }
  }

  Future<void> _loadUserProfile() async {
    final profile = await StorageService.getUserProfile();

    if (!mounted) return;

    setState(() {
      _userProfile = profile;
      _profileLoading = false;
    });
  }

  String _profileValue(String key) {
    final value = _userProfile?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return '';
    }

    return value.toString();
  }
  static const Color green = Color(0xFF075832);
  static const Color darkGreen = Color(0xFF06452D);
  static const Color background = Color(0xFFF4F7F5);
  static const Color textColor = Color(0xFF26352E);
  static const Color muted = Color(0xFF78847E);

  int _selectedTab = 0;
  String _selectedPeriod = 'This Month';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  _buildHomeContent(),
                  const BeneficiariesScreen(),
                  const SchemesScreen(),
                  _buildPlaceholder(
                    Icons.grid_view_rounded,
                    'More',
                    'More Jan Kavach features will appear here.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Image.asset(
              'lib/assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.shield_outlined,
                color: green,
                size: 27,
              ),
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'Jan Kavach',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),


          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // HOME DASHBOARD
  // --------------------------------------------------

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(),

          const SizedBox(height: 18),

          _buildSectionHeading(
            'Overview',
            trailing: _buildPeriodDropdown(),
          ),

          const SizedBox(height: 10),

          // Overview statistics
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.8,
            children: [
              _StatCard(
                icon: Icons.groups_rounded,
                iconColor: Color(0xFF168A53),
                iconBackground: Color(0xFFE1F5E8),
                value: _summary.beneficiariesRegistered.toString(),
                label: 'Beneficiaries\nregistered',
              ),
              _StatCard(
                icon: Icons.description_outlined,
                iconColor: Color(0xFFFF8A18),
                iconBackground: Color(0xFFFFF0DF),
                value: _summary.applicationsSubmitted.toString(),
                label: 'Applications\nsubmitted',
              ),
              _StatCard(
                icon: Icons.check_circle_rounded,
                iconColor: Color(0xFF1688E8),
                iconBackground: Color(0xFFE1F1FF),
                value: _summary.applicationsApproved.toString(),
                label: 'Applications\napproved',
              ),
              _StatCard(
                icon: Icons.access_time_rounded,
                iconColor: Color(0xFFFF5B63),
                iconBackground: Color(0xFFFFE9E9),
                  value: _summary.followupsDone.toString(),
                label: 'Follow-ups\ndue',
                valueColor: Color(0xFFFF4545),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _buildSectionHeading('Quick Actions'),

          const SizedBox(height: 10),

          _buildActionCard(
            icon: Icons.person_add_alt_1_rounded,
            iconColor: const Color(0xFF168A53),
            iconBackground: const Color(0xFFE1F5E8),
            title: 'Add a Beneficiary',
            subtitle: 'Six-step questionnaire',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BeneficiaryRegistrationScreen(),
                ),
              );
            },
          ),

          _buildActionCard(
            icon: Icons.search_rounded,
            iconColor: const Color(0xFF1688E8),
            iconBackground: const Color(0xFFE1F1FF),
            title: 'Check Eligibility',
            subtitle: 'Find matching schemes',
            onTap: () {
              setState(() => _selectedTab = 2);
            },
          ),

          _buildActionCard(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFFFF8A18),
            iconBackground: const Color(0xFFFFF0DF),
            title: 'Record a Follow-up',
            subtitle: 'Track application status',
            onTap: () => _showMessage(
              'Follow-up tracking will be connected next.',
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // PROFILE CARD
  // --------------------------------------------------


  Widget _buildProfileCard() {
    final name = _profileValue('name');
    final userCode = _profileValue('user_code');

    // Use the actual address/location fields returned by your API.
    final addressParts = [
      _profileValue('address'),
      _profileValue('city'),
      _profileValue('state'),
    ].where((value) => value.isNotEmpty).toList();

    final address = addressParts.isNotEmpty
        ? addressParts.join(', ')
        : 'Location not provided';

    final displayName = _profileLoading
        ? 'Loading profile...'
        : name.isNotEmpty
        ? name
        : 'User';

    final initials = name.trim().isEmpty
        ? 'U'
        : name.trim().split(RegExp(r'\s+')).length > 1
        ? '${name.trim().split(RegExp(r'\s+')).first[0]}'
        '${name.trim().split(RegExp(r'\s+')).last[0]}'
        : name.trim()[0];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F0E5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials.toUpperCase(),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D9566),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: muted,
                  ),
                ),
                if (userCode.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    userCode,
                    style: const TextStyle(
                      fontSize: 10,
                      color: muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F7E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              initials.toUpperCase(),
              style: const TextStyle(
                color: green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // --------------------------------------------------
  // SECTION HEADING AND PERIOD DROPDOWN
  // --------------------------------------------------

  Widget _buildSectionHeading(
      String title, {
        Widget? trailing,
      }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildPeriodDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedPeriod,
        isDense: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 17,
          color: muted,
        ),
        style: const TextStyle(
          color: muted,
          fontSize: 11,
        ),
        items: const [
          DropdownMenuItem(
            value: 'This Month',
            child: Text('This Month'),
          ),
          DropdownMenuItem(
            value: 'Last Month',
            child: Text('Last Month'),
          ),
          DropdownMenuItem(
            value: 'This Year',
            child: Text('This Year'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedPeriod = value);
          }
        },
      ),
    );
  }

  // --------------------------------------------------
  // QUICK ACTIONS
  // --------------------------------------------------

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFFEDF0EE),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  size: 21,
                  color: muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // BOTTOM NAVIGATION
  // --------------------------------------------------

  Widget _buildBottomNavigation() {
    const labels = [
      'Home',
      'Beneficiaries',
      'Schemes',
      'More',
    ];

    const icons = [
      Icons.home_rounded,
      Icons.people_outline_rounded,
      Icons.account_balance_outlined,
      Icons.more_horiz_rounded,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = _selectedTab == index;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedTab = index);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 17,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? green : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          icons[index],
                          size: 21,
                          color: selected ? Colors.white : muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[index],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected ? green : muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PLACEHOLDER TABS
  // --------------------------------------------------

  Widget _buildPlaceholder(
      IconData icon,
      String title,
      String description,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F3E8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 42,
                color: green,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: muted,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => setState(() => _selectedTab = 0),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
              style: OutlinedButton.styleFrom(
                foregroundColor: green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: const Color(0xFFEDF0EE),
      ),
    );
  }
}



// --------------------------------------------------
// STATISTICS CARD
// --------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String value;
  final String label;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
    this.valueColor = const Color(0xFF26352E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDF0EE),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 19,
            ),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    color: Color(0xFF78847E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
