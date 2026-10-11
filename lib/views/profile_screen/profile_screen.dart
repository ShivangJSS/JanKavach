
import 'package:flutter/material.dart';

import '../../data/services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color green = Color(0xFF075832);
  static const Color background = Color(0xFFF4F7F5);

  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await StorageService.getUserProfile();

    if (!mounted) return;

    setState(() {
      _user = user;
      _loading = false;
    });
  }

  String _value(String key) {
    final value = _user?[key];

    if (value == null || value.toString().trim().isEmpty) {
      return 'Not provided';
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final role = _user?['role'];

    final roleName = role is Map
        ? (role['name']?.toString() ?? 'Not provided')
        : 'Not provided';

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: green,
        ),
      )
          : _user == null
          ? _buildEmptyState()
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white,
                  child: Text(
                    _initials(_value('name')),
                    style: const TextStyle(
                      color: green,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _value('name'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _value('user_code'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'PERSONAL INFORMATION',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _ProfileField(
            icon: Icons.badge_outlined,
            label: 'User ID',
            value: _value('id'),
          ),

          _ProfileField(
            icon: Icons.account_circle_outlined,
            label: 'Username',
            value: _value('username'),
          ),

          _ProfileField(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _value('email'),
          ),

          _ProfileField(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: _value('mobile'),
          ),

          _ProfileField(
            icon: Icons.work_outline,
            label: 'Designation',
            value: _value('designation'),
          ),

          _ProfileField(
            icon: Icons.business_outlined,
            label: 'Organization',
            value: _value('organization'),
          ),

          _ProfileField(
            icon: Icons.verified_user_outlined,
            label: 'Role',
            value: roleName,
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name == 'Not provided' || name.trim().isEmpty) {
      return 'U';
    }

    final parts = name.trim().split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 54,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text(
              'Profile information unavailable',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please sign in again to load your profile.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE8EEEA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF075832),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF26352E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
