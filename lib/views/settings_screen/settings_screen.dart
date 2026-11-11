import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/master_data_download_result.dart';
import '../../data/providers/language_provider.dart';
import '../../data/services/connectivity_sync_service.dart';
import '../../data/services/geography_service.dart';
import '../../data/services/storage_service.dart';
import '../profile_screen/profile_screen.dart';
import '../welcome_screen/welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color green = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  String _language = 'en';
  bool _loading = true;
  bool _isDownloadingMasterData = false;
  MasterDataDownloadResult? _masterDataSummary;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadMasterDataSummary();
  }

  Future<void> _loadLanguage() async {
    final language = await StorageService.getLanguage();

    if (!mounted) return;

    setState(() {
      _language = language;
      _loading = false;
    });
  }

  Future<void> _loadMasterDataSummary() async {
    final summary = await StorageService.getMasterDataDownloadSummary();

    if (!mounted) return;

    setState(() {
      _masterDataSummary = summary;
    });
  }

  Future<void> _changeLanguage(String language) async {
    await Provider.of<LanguageProvider>(context, listen: false).setLanguage(language);

    if (!mounted) return;

    setState(() => _language = language);

    final msg = language == 'hi'
        ? 'भाषा हिन्दी में चुनी गई'
        : (language == 'as' ? 'ভাষা অসমীয়াত নিৰ্বাচন কৰা হ\'ল' : 'Language set to English');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $ampm';
  }

  String _getMasterDataSubtitle() {
    if (_isDownloadingMasterData) {
      return _language == 'hi'
          ? 'मास्टर डेटा डाउनलोड हो रहा है...'
          : 'Downloading states, districts, blocks & villages...';
    }

    if (_masterDataSummary != null) {
      final summary = _masterDataSummary!;
      final dateStr = _formatDate(summary.downloadedAt);
      return '$dateStr (${summary.stateCount} states, ${summary.districtCount} dists, ${summary.blockCount} blocks, ${summary.villageCount} villages)';
    }

    return _language == 'hi'
        ? 'ऑफ़लाइन पंजीकरण हेतु राज्य, ज़िले, ब्लॉक व गांव डेटा डाउनलोड करें'
        : 'Download states, districts, blocks & villages for offline use';
  }

  Future<void> _handleDownloadMasterData() async {
    if (_isDownloadingMasterData) return;

    // Check connectivity first
    final isOnline = await ConnectivitySyncService.instance.isConnected();
    if (!isOnline && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _language == 'hi'
                      ? 'मास्टर डेटा डाउनलोड करने के लिए इंटरनेट कनेक्शन आवश्यक है।'
                      : 'Internet connection is required to download master data.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _language == 'hi'
                      ? 'मास्टर डेटा सफलतापूर्वक डाउनलोड किया गया (${result.stateCount} राज्य, ${result.districtCount} ज़िले, ${result.blockCount} ब्लॉक, ${result.villageCount} गांव)'
                      : 'Master data downloaded successfully (${result.stateCount} states, ${result.districtCount} districts, ${result.blockCount} blocks, ${result.villageCount} villages)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
          errorMsg = _language == 'hi'
              ? 'सर्वर से कनेक्ट नहीं हो सका। कृपया अपना इंटरनेट जांचें।'
              : 'Cannot connect to server. Please check your internet connection.';
        } else if (e.response?.statusCode == 401) {
          errorMsg = _language == 'hi'
              ? 'सत्र समाप्त हो गया है। कृपया पुनः ऑनलाइन लॉगिन करें।'
              : 'Session expired. Please log in again online.';
        } else if (e.response?.data is Map && e.response?.data['message'] != null) {
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
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _language == 'hi'
                      ? 'मास्टर डेटा डाउनलोड विफल: $errorMsg'
                      : 'Failed to download master data: $errorMsg',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: green,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await StorageService.clearSession();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Padding(
            padding: EdgeInsets.only(
              left: 4,
              bottom: 14,
            ),
            child: Text(
              'ACCOUNT',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),

          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'View your account information',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.translate,
            title: 'Language',
            subtitle: _loading
                ? 'Loading language...'
                : _language == 'hi'
                ? 'हिन्दी (Hindi)'
                : _language == 'as'
                ? 'অসমীয়া (Assamese)'
                : 'English',
            trailing: _loading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                items: const [
                  DropdownMenuItem(
                    value: 'en',
                    child: Text('English'),
                  ),
                  DropdownMenuItem(
                    value: 'hi',
                    child: Text('हिन्दी (Hindi)'),
                  ),
                  DropdownMenuItem(
                    value: 'as',
                    child: Text('অসমীয়া (Assamese)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _changeLanguage(value);
                  }
                },
              ),
            ),
            onTap: () {},
          ),

          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.cloud_download_outlined,
            title: _language == 'hi'
                ? 'मास्टर डेटा डाउनलोड करें'
                : 'Download Master Data',
            subtitle: _getMasterDataSubtitle(),
            trailing: _isDownloadingMasterData
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: green,
              ),
            )
                : const Icon(
              Icons.cloud_download_rounded,
              color: green,
            ),
            onTap: _handleDownloadMasterData,
          ),

          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            iconColor: Colors.red,
            titleColor: Colors.red,
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color iconColor;
  final Color titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.iconColor = const Color(0xFF075832),
    this.titleColor = const Color(0xFF26352E),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
