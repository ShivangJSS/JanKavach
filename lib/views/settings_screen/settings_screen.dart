
import 'package:flutter/material.dart';

import '../../data/services/storage_service.dart';
import '../welcome_screen/welcome_screen.dart';
import '../profile_screen/profile_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final language = await StorageService.getLanguage();

    if (!mounted) return;

    setState(() {
      _language = language;
      _loading = false;
    });
  }

  Future<void> _changeLanguage(String language) async {
    await StorageService.saveLanguage(language);

    if (!mounted) return;

    setState(() => _language = language);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          language == 'hi'
              ? 'भाषा हिन्दी में चुनी गई'
              : 'Language set to English',
        ),
      ),
    );
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
                ? 'हिन्दी'
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
                    child: Text('हिन्दी'),
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
