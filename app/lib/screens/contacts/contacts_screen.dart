import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';
import '../calling/in_call_screen.dart';
import '../messages/chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    final list = await ApiService.instance.getSavedContacts();
    if (mounted) {
      setState(() {
        _contacts = list;
        _loading = false;
      });
    }
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add IntraCom Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: 'e.g. Rafiq Islam',
                hintStyle: TextStyle(color: Colors.white24),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'IntraCom Number',
                labelStyle: TextStyle(color: Colors.white54),
                hintText: '+1-6860499',
                hintStyle: TextStyle(color: Colors.white24),
                border: OutlineInputBorder(),
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
              final name = nameCtrl.text.trim();
              final num = numberCtrl.text.trim();
              if (name.isNotEmpty && num.isNotEmpty) {
                Navigator.pop(ctx);
                await ApiService.instance.addContact(name: name, number: num);
                await _loadContacts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Contact "$name" saved!'),
                      backgroundColor: IosTheme.primaryGreen,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _contacts.where((c) {
      final q = _filter.toLowerCase();
      return (c['name'] ?? '').toString().toLowerCase().contains(q) ||
          (c['number'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadContacts,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: IosTheme.accentBlue, size: 28),
            onPressed: _showAddContactDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // iOS Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _filter = v),
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search by name or +Code-Number',
                  hintStyle: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF8E8E93), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: IosTheme.primaryGreen))
                : ValueListenableBuilder<Set<String>>(
                    valueListenable: SignalingService.instance.onlineUsersNotifier,
                    builder: (context, onlineUsers, child) {
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('No contacts found', style: TextStyle(color: Colors.white38)),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: Colors.white10,
                          indent: 72,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final num = item['number']?.toString() ?? '';
                          final name = item['name']?.toString() ?? 'User';
                          final district = item['district']?.toString() ?? '';
                          final isOnline = onlineUsers.contains(num);

                          return ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    contactName: name,
                                    contactNumber: num,
                                  ),
                                ),
                              );
                            },
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFF2C2C2E),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isOnline ? IosTheme.primaryGreen : Colors.grey.shade700,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white),
                                ),
                                if (isOnline) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: IosTheme.primaryGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('ONLINE', style: TextStyle(color: IosTheme.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '$num ${district.isNotEmpty ? '• $district' : ''}',
                              style: const TextStyle(fontSize: 13, color: Colors.white54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.phone, color: IosTheme.primaryGreen),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InCallScreen(
                                          targetNumber: num,
                                          targetName: name,
                                          isVideo: false,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.videocam, color: IosTheme.accentBlue),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InCallScreen(
                                          targetNumber: num,
                                          targetName: name,
                                          isVideo: true,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
