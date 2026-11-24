import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> _contacts = [
    {
      'name': 'Rafiq Ahmed',
      'number': '+1-6860499',
      'district': 'Dhaka (+1)',
      'isOnline': true,
    },
    {
      'name': 'Farhan Ahmed',
      'number': '+2-1000001',
      'district': 'Narsingdi (+2)',
      'isOnline': false,
    },
    {
      'name': 'Kazi Sakib',
      'number': '+3-9182746',
      'district': 'Brahmanbaria (+3)',
      'isOnline': true,
    },
    {
      'name': 'Mahmudur Rahman',
      'number': '+15-5529103',
      'district': 'Chattogram (+15)',
      'isOnline': true,
    },
    {
      'name': 'Syed Nayeem',
      'number': '+49-2200718',
      'district': 'Sylhet (+49)',
      'isOnline': false,
    },
  ];

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final numberCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        title: const Text('Add IntraCom Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                hintText: 'e.g. Rafiq Islam',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberCtrl,
              decoration: const InputDecoration(
                labelText: 'IntraCom Number',
                hintText: '+1-6860499',
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
            style: ElevatedButton.styleFrom(backgroundColor: IosTheme.accentBlue),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && numberCtrl.text.isNotEmpty) {
                setState(() {
                  _contacts.add({
                    'name': nameCtrl.text.trim(),
                    'number': numberCtrl.text.trim(),
                    'district': 'Registered Contact',
                    'isOnline': false,
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Contact', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _contacts.where((c) {
      final q = _filter.toLowerCase();
      return c['name'].toString().toLowerCase().contains(q) ||
          c['number'].toString().toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
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
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(
                color: Colors.white10,
                indent: 72,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final isOnline = item['isOnline'] == true;

                return ListTile(
                  onTap: () {
                    // Tapping contact opens Chat!
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          contactName: item['name'],
                          contactNumber: item['number'],
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
                          (item['name'] as String).substring(0, 1).toUpperCase(),
                          style: const TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOnline ? IosTheme.primaryGreen : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    item['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Text(
                    '${item['number']} • ${item['district']}',
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: IosTheme.primaryGreen),
                        onPressed: () {
                          // Directly open In-Call Screen!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InCallScreen(
                                targetNumber: item['number'],
                                targetName: item['name'],
                                isVideo: false,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam, color: IosTheme.accentBlue),
                        onPressed: () {
                          // Directly open Video Call Screen!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InCallScreen(
                                targetNumber: item['number'],
                                targetName: item['name'],
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
            ),
          ),
        ],
      ),
    );
  }
}
