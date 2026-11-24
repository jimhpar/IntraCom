import 'package:flutter/material.dart';
import '../../models/district.dart';
import '../../services/api_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';
import '../main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  District _selectedDistrict = bangladeshDistricts.first; // Default Dhaka (+1)
  bool _isLoading = false;

  void _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final res = await ApiService.instance.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      districtCode: _selectedDistrict.code,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (res['success'] == true) {
      final user = res['data'];
      final fullNumber = user['full_number'] ?? '';

      // Connect WebSocket
      SignalingService.instance.connect();

      // Show welcome dialog with newly assigned unique IntraCom Number
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: IosTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: IosTheme.primaryGreen, size: 28),
              SizedBox(width: 10),
              Text('Registration Complete!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your unique IntraCom Calling Number has been assigned based on your district:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: IosTheme.primaryGreen, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      fullNumber,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: IosTheme.primaryGreen,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedDistrict.nameEn} (${_selectedDistrict.nameBn}) • Area Code +${_selectedDistrict.code}',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can now make and receive audio/video calls using this number.',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: IosTheme.primaryGreen,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                );
              },
              child: const Text('Enter IntraCom', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Registration failed'),
          backgroundColor: IosTheme.destructiveRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'IntraCom',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Independent Calling & Voice Network',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 32),

                // District Dropdown (Area code assignment)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: IosTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 2),
                        child: Text(
                          'SELECT YOUR DISTRICT (ZILLA)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: IosTheme.accentBlue),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<District>(
                          value: _selectedDistrict,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1C1C1E),
                          items: bangladeshDistricts.map((d) {
                            return DropdownMenuItem<District>(
                              value: d,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${d.nameEn} (${d.nameBn})', style: const TextStyle(color: Colors.white)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: IosTheme.accentBlue.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '+${d.code}',
                                      style: const TextStyle(color: IosTheme.accentBlue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedDistrict = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    filled: true,
                    fillColor: IosTheme.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Please enter name' : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    filled: true,
                    fillColor: IosTheme.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number',
                    hintText: '017XXXXXXXX',
                    filled: true,
                    fillColor: IosTheme.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v == null || v.length < 10 ? 'Valid phone required' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    filled: true,
                    fillColor: IosTheme.cardDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IosTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _onRegister,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Register & Get IntraCom Number',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
