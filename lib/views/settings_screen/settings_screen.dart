import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../data/models/master_data_download_result.dart';
import '../../data/providers/language_provider.dart';
import '../../data/services/connectivity_sync_service.dart';
import '../../data/services/geography_service.dart';
import '../../data/services/storage_service.dart';
import '../profile_screen/profile_screen.dart';
import '../welcome_screen/welcome_screen.dart';
import '../widgets/language_selector_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color green = Color(0xFF075832);
  static const Color background = Color(0xFFF2F7F4);
  static const Color textColor = Color(0xFF1E2D25);
  static const Color muted = Color(0xFF62726A);
  static const String fontFamily = 'sans-serif-condensed';
  static const List<String> fontFallback = ['Noto Sans', 'Roboto', 'sans-serif'];

  bool _isDownloadingMasterData = false;
  MasterDataDownloadResult? _masterDataSummary;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadMasterDataSummary();
    _loadUserProfile();
  }

  TextStyle _textStyle({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color color = textColor,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  Future<void> _loadUserProfile() async {
    final profile = await StorageService.getUserProfile();
    if (!mounted || profile == null) return;
    setState(() => _userProfile = profile);
  }

  Future<void> _loadMasterDataSummary() async {
    final summary = await StorageService.getMasterDataDownloadSummary();
    if (!mounted) return;
    setState(() => _masterDataSummary = summary);
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $ampm';
  }

  String _getMasterDataSubtitle(BuildContext context) {
    if (_isDownloadingMasterData) {
      return context.tr('settings.master_data_downloading');
    }

    if (_masterDataSummary != null) {
      final summary = _masterDataSummary!;
      return context.tr(
        'settings.master_data_stats',
        args: {
          'date': _formatDate(summary.downloadedAt),
          'states': '${summary.stateCount}',
          'districts': '${summary.districtCount}',
          'blocks': '${summary.blockCount}',
          'villages': '${summary.villageCount}',
        },
      );
    }

    return context.tr('settings.master_data_prompt');
  }

  Future<void> _handleDownloadMasterData() async {
    if (_isDownloadingMasterData) return;

    final isOnline = await ConnectivitySyncService.instance.isConnected();
    if (!isOnline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('settings.master_data_internet_req'),
                  style: _textStyle(
                    size: 12,
                    weight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _isDownloadingMasterData = true);

    try {
      final result = await GeographyService().downloadMasterData();
      if (!mounted) return;

      setState(() {
        _masterDataSummary = result;
        _isDownloadingMasterData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    'settings.master_data_success',
                    args: {
                      'states': '${result.stateCount}',
                      'districts': '${result.districtCount}',
                      'blocks': '${result.blockCount}',
                      'villages': '${result.villageCount}',
                    },
                  ),
                  style: _textStyle(
                    size: 12,
                    weight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDownloadingMasterData = false);

      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          errorMsg = context.tr('settings.err_no_server');
        } else if (e.response?.statusCode == 401) {
          errorMsg = context.tr('settings.err_session_expired');
        } else if (e.response?.data is Map &&
            e.response?.data['message'] != null) {
          errorMsg = e.response!.data['message'].toString();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(
                    'settings.master_data_failed',
                    args: {'error': errorMsg},
                  ),
                  style: _textStyle(
                    size: 12,
                    weight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          context.tr('profile.logout'),
          style: _textStyle(size: 16, weight: FontWeight.w700),
        ),
        content: Text(
          context.tr('profile.logout_confirm'),
          style: _textStyle(size: 13, color: muted, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              context.tr('common.cancel'),
              style: _textStyle(size: 12.5, weight: FontWeight.w600, color: muted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD61F45),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr('profile.logout'),
              style: _textStyle(
                size: 12.5,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await StorageService.clearSession();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  String _userName(BuildContext context) {
    final raw = _userProfile?['name']?.toString().trim() ?? '';
    return raw.isNotEmpty ? raw : context.tr('dashboard.user_fallback');
  }

  String _userCode() {
    return _userProfile?['user_code']?.toString().trim() ?? '';
  }

  String _userInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length > 1 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final languageOption = Provider.of<LanguageProvider>(
      context,
    ).currentLanguageOption;
    final displayName = _userName(context);
    final userCode = _userCode();
    final initials = _userInitials(displayName);

    final baseTheme = Theme.of(context);

    return Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFallback,
        ),
      ),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          toolbarHeight: 54,
          elevation: 0,
          backgroundColor: green,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
          title: Text(
            context.tr('profile.app_settings'),
            style: _textStyle(
              size: 16.5,
              weight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            _buildAccountCard(context, displayName, userCode, initials),
            const SizedBox(height: 16),
            _sectionLabel(context.tr('settings.section_preferences')),
            const SizedBox(height: 8),
            _buildGroupedCard([
              _SettingsRow(
                icon: Icons.translate_rounded,
                gradientColors: const [Color(0xFF33A3FF), Color(0xFF0B62D6)],
                title: context.tr('common.language'),
                subtitle: context.tr('common.choose_language'),
                textStyle: _textStyle,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF9CD0FF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        languageOption.nativeName,
                        style: _textStyle(
                          size: 11,
                          weight: FontWeight.w700,
                          color: const Color(0xFF0B62D6),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 15,
                        color: Color(0xFF0B62D6),
                      ),
                    ],
                  ),
                ),
                onTap: () => LanguageSelectorSheet.show(context),
              ),
              const Divider(
                height: 1,
                thickness: 0.8,
                indent: 62,
                color: Color(0xFFEBF2EE),
              ),
              _SettingsRow(
                icon: Icons.cloud_download_rounded,
                gradientColors: const [Color(0xFF28D17C), Color(0xFF0B8A54)],
                title: context.tr('settings.download_master_data'),
                subtitle: _getMasterDataSubtitle(context),
                textStyle: _textStyle,
                trailing: _isDownloadingMasterData
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: green,
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F8EE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7E9C4)),
                        ),
                        child: const Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: green,
                        ),
                      ),
                onTap: _handleDownloadMasterData,
              ),
            ]),
            const SizedBox(height: 16),
            _sectionLabel(context.tr('settings.section_account')),
            const SizedBox(height: 8),
            _buildLogoutCard(context),
            const SizedBox(height: 20),
            Center(
              child: Text(
                context.tr('profile.app_version'),
                style: _textStyle(
                  size: 10.5,
                  weight: FontWeight.w500,
                  color: const Color(0xFF83938B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: _textStyle(
          size: 10.5,
          weight: FontWeight.w700,
          color: const Color(0xFF5A6D63),
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    String displayName,
    String userCode,
    String initials,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFEDF9F2)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFE6CE), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B8A54).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF28D17C), Color(0xFF0B8A54)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16B85C).withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: _textStyle(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
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
                        style: _textStyle(
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userCode.isNotEmpty
                            ? '$userCode  •  ${context.tr('settings.view_profile')}'
                            : context.tr('settings.view_profile'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _textStyle(size: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F7EC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7E9C4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('profile.title'),
                        style: _textStyle(
                          size: 10.5,
                          weight: FontWeight.w700,
                          color: green,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: green,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEBE2), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFFF2F4)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD1D7), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD61F45).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _SettingsRow(
          icon: Icons.logout_rounded,
          gradientColors: const [Color(0xFFFF5E7E), Color(0xFFD61F45)],
          title: context.tr('profile.logout'),
          subtitle: context.tr('settings.logout_sub'),
          titleColor: const Color(0xFFC81E3D),
          textStyle: _textStyle,
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFFFE4E8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFFC81E3D),
            ),
          ),
          onTap: _logout,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  final Color titleColor;
  final TextStyle Function({
    double size,
    FontWeight weight,
    Color color,
    double? letterSpacing,
    double? height,
  })
  textStyle;

  const _SettingsRow({
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    required this.textStyle,
    this.titleColor = const Color(0xFF1E2D25),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.last.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textStyle(
                        size: 13,
                        weight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textStyle(
                        size: 11,
                        color: const Color(0xFF62726A),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
