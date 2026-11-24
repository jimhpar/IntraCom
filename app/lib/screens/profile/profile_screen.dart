import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/ios_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String myNumber = '+1-3847291';
    const String myName = 'Zim (Admin)';
    const String myDistrict = 'Dhaka (+1)';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Stack(
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFF2C2C2E),
                  child: Icon(Icons.person, size: 54, color: Colors.white70),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: IosTheme.accentBlue,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                const Text(
                  myName,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: myNumber));
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          myNumber,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: IosTheme.primaryGreen,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.copy, size: 14, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  myDistrict,
                  style: TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Settings Section
          _buildSectionHeader('SYSTEM & CALLING'),
          _buildSettingsTile(Icons.wifi_tethering, 'Oracle Server Relay', 'Connected (129.225.114.149)', () {}),
          _buildSettingsTile(Icons.security, 'WebRTC Encryption', 'DTLS-SRTP Enabled', () {}),
          _buildSettingsTile(Icons.volume_up_outlined, 'Audio & Codec', 'Opus HD Voice (48kHz)', () {}),

          const SizedBox(height: 24),
          _buildSectionHeader('APPLICATION SETTINGS'),
          _buildSettingsTile(Icons.notifications_outlined, 'Push Notifications', 'FCM / APNs Ready', () {}),
          _buildSettingsTile(Icons.dark_mode_outlined, 'Theme', 'iOS Dark Dial Mode', () {}),
          _buildSettingsTile(Icons.info_outline, 'About IntraCom', 'v1.0.0 (Independent)', () {}),

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

  static Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: IosTheme.cardDark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: IosTheme.accentBlue),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
        onTap: onTap,
      ),
    );
  }
}
