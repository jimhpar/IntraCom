import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../theme/ios_theme.dart';
import '../admin/admin_screen.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _displayName;
  late String _number;
  late String _district;
  late String _bio;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _refreshUserData();
  }

  void _refreshUserData() {
    final user = ApiService.instance.currentUser;
    _displayName = user?['display_name'] ?? 'IntraCom User';
    _number = user?['full_number'] ?? '+1-0000000';
    _district = user?['district_name'] ?? 'Bangladesh';
    _bio = user?['bio'] ?? 'Available on IntraCom';
    _isAdmin = ApiService.instance.isAdmin;
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.person, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Bio / Status',
                labelStyle: TextStyle(color: Colors.white54),
                prefixIcon: Icon(Icons.edit_note, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: IosTheme.primaryGreen),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newBio = bioCtrl.text.trim();
              if (newName.isEmpty) return;

              Navigator.pop(ctx);
              final res = await ApiService.instance.updateProfile(displayName: newName, bio: newBio);
              if (mounted) {
                if (res['success'] == true) {
                  setState(() {
                    _displayName = newName;
                    _bio = newBio;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: IosTheme.primaryGreen),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['error'] ?? 'Update failed'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out from IntraCom?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.instance.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: IosTheme.accentBlue),
            onPressed: _showEditProfileDialog,
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFF2C2C2E),
                  child: Text(
                    _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _showEditProfileDialog,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: IosTheme.accentBlue,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'ADMIN',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _number));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('IntraCom Number copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: IosTheme.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _number,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: IosTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy, size: 14, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _district,
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
                if (_bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _bio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.white70, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Admin Section (Visible to Admins)
          if (_isAdmin) ...[
            _buildSectionHeader('ADMINISTRATION'),
            _buildSettingsTile(
              Icons.admin_panel_settings,
              'Admin Control Panel',
              'Manage Users, Hub Requests & Moderation',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                );
              },
              iconColor: Colors.amber,
            ),
            const SizedBox(height: 16),
          ],

          // Settings Section
          _buildSectionHeader('SYSTEM & CALLING'),
          _buildSettingsTile(Icons.wifi_tethering, 'Oracle Server Relay', 'Connected (129.225.125.127:8080)', () {}),
          _buildSettingsTile(Icons.security, 'WebRTC Encryption', 'DTLS-SRTP Enabled', () {}),
          _buildSettingsTile(Icons.volume_up_outlined, 'Audio & Codec', 'Opus HD Voice (48kHz)', () {}),

          const SizedBox(height: 20),
          _buildSectionHeader('APPLICATION SETTINGS'),
          _buildSettingsTile(Icons.notifications_outlined, 'Push Notifications', 'FCM / APNs Ready', () {}),
          _buildSettingsTile(Icons.dark_mode_outlined, 'Theme', 'iOS Dark Dial Mode', () {}),
          _buildSettingsTile(Icons.info_outline, 'About IntraCom', 'v1.1.0 (Independent, Zero 3rd-Party Relay)', () {}),

          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: _handleLogout,
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  static Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8E8E93),
          letterSpacing: 1,
        ),
      ),
    );
  }

  static Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: IosTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? IosTheme.accentBlue),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}
