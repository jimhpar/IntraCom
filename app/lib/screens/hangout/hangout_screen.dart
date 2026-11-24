import 'package:flutter/material.dart';
import '../../theme/ios_theme.dart';

class HangoutScreen extends StatefulWidget {
  const HangoutScreen({super.key});

  @override
  State<HangoutScreen> createState() => _HangoutScreenState();
}

class _HangoutScreenState extends State<HangoutScreen> {
  String? _activeHangoutId;
  bool _isMuted = false;
  bool _isDeafened = false;

  final List<Map<String, dynamic>> _hangoutRooms = [
    {
      'id': 'h1',
      'name': 'Dhaka Central Hub',
      'district': 'Dhaka (+1)',
      'description': 'General voice lounge for Dhaka district members',
      'members': [
        {'name': 'Zim (Host)', 'number': '+1-3847291', 'isSpeaking': true, 'isMuted': false},
        {'name': 'Tanvir', 'number': '+1-2098412', 'isSpeaking': false, 'isMuted': false},
        {'name': 'Sakib', 'number': '+1-8172635', 'isSpeaking': false, 'isMuted': true},
      ],
    },
    {
      'id': 'h2',
      'name': 'Narsingdi Voice Channel',
      'district': 'Narsingdi (+2)',
      'description': 'Community channel for Narsingdi developers & tech',
      'members': [
        {'name': 'Rafiq', 'number': '+2-1000001', 'isSpeaking': false, 'isMuted': false},
        {'name': 'Farhan', 'number': '+2-4412981', 'isSpeaking': false, 'isMuted': false},
      ],
    },
    {
      'id': 'h3',
      'name': 'Developers Audio Room',
      'district': 'All Districts',
      'description': 'Open tech discussion & collaboration',
      'members': <Map<String, dynamic>>[],
    },
  ];

  void _toggleJoin(String id) {
    setState(() {
      if (_activeHangoutId == id) {
        _activeHangoutId = null;
      } else {
        _activeHangoutId = id;
      }
    });
  }

  void _showCreateHubDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        title: const Text('Create Hangout Hub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Hub Name',
                hintText: 'e.g. Gaming Lounge',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Topic / Description',
                hintText: 'What is this hub about?',
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
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _hangoutRooms.add({
                    'id': 'h_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameController.text.trim(),
                    'district': 'Custom Hub',
                    'description': descController.text.trim(),
                    'members': <Map<String, dynamic>>[],
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create Hub', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hangouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: IosTheme.accentBlue),
            tooltip: 'Create Hub',
            onPressed: _showCreateHubDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active connection bar (Discord style bottom or top banner)
          if (_activeHangoutId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B382B),
                border: Border(bottom: BorderSide(color: IosTheme.primaryGreen.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: IosTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VOICE CONNECTED (RTC SFU)',
                          style: TextStyle(
                            color: IosTheme.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          _hangoutRooms.firstWhere((r) => r['id'] == _activeHangoutId)['name'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? Colors.redAccent : Colors.white),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),
                  IconButton(
                    icon: Icon(_isDeafened ? Icons.headset_off : Icons.headset,
                        color: _isDeafened ? Colors.redAccent : Colors.white),
                    onPressed: () => setState(() => _isDeafened = !_isDeafened),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.redAccent),
                    onPressed: () => setState(() => _activeHangoutId = null),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _hangoutRooms.length,
              itemBuilder: (context, index) {
                final room = _hangoutRooms[index];
                final isConnected = _activeHangoutId == room['id'];
                final members = room['members'] as List<dynamic>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: IosTheme.cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isConnected ? IosTheme.primaryGreen : Colors.white10,
                      width: isConnected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isConnected
                              ? IosTheme.primaryGreen.withValues(alpha: 0.2)
                              : Colors.white12,
                          child: Icon(
                            Icons.volume_up_rounded,
                            color: isConnected ? IosTheme.primaryGreen : Colors.white70,
                          ),
                        ),
                        title: Text(
                          room['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          '${room['district']} • ${members.length} listening',
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnected ? Colors.red.withValues(alpha: 0.2) : IosTheme.primaryGreen,
                            foregroundColor: isConnected ? Colors.redAccent : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () => _toggleJoin(room['id']),
                          child: Text(isConnected ? 'Disconnect' : 'Join Voice'),
                        ),
                      ),
                      if (room['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            room['description'],
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Connected members inside this Hub (Discord voice channel view)
                      if (members.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: members.map((m) {
                              final speaking = m['isSpeaking'] == true;
                              final muted = m['isMuted'] == true;
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: speaking ? IosTheme.primaryGreen : Colors.white24,
                                  child: Icon(
                                    muted ? Icons.mic_off : (speaking ? Icons.graphic_eq : Icons.person),
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                label: Text(
                                  m['name'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: speaking ? FontWeight.bold : FontWeight.normal,
                                    color: speaking ? IosTheme.primaryGreen : Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.black26,
                                side: BorderSide(
                                  color: speaking ? IosTheme.primaryGreen : Colors.white12,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 8),
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
