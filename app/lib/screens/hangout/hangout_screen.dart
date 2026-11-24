import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';

class HangoutScreen extends StatefulWidget {
  const HangoutScreen({super.key});

  @override
  State<HangoutScreen> createState() => _HangoutScreenState();
}

class _HangoutScreenState extends State<HangoutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _activeHubId;
  bool _isMuted = false;
  bool _isDeafened = false;

  final List<Map<String, dynamic>> _publicHubs = [
    {
      'id': 'pub_1',
      'name': 'Bangladesh Central Voice Lounge',
      'district': 'All Districts',
      'description': 'Open community audio hub for everyone across 64 districts',
      'members': [
        {'name': 'Zim (Admin)', 'number': '+1-3847291', 'isSpeaking': true, 'isMuted': false},
        {'name': 'Rafiq', 'number': '+1-6860499', 'isSpeaking': false, 'isMuted': false},
      ],
    },
    {
      'id': 'pub_2',
      'name': 'Dhaka Developers Hub',
      'district': 'Dhaka (+1)',
      'description': 'Voice chat for software engineers, designers & tech enthusiasts',
      'members': [
        {'name': 'Tanvir', 'number': '+1-2098412', 'isSpeaking': false, 'isMuted': true},
      ],
    },
    {
      'id': 'pub_3',
      'name': 'Narsingdi Community Channel',
      'district': 'Narsingdi (+2)',
      'description': 'Local discussion & networking hub for Narsingdi district',
      'members': <Map<String, dynamic>>[],
    },
  ];

  final List<Map<String, dynamic>> _privateTables = [
    {
      'id': 'priv_1',
      'name': 'Core Team Private Table',
      'owner': 'Zim',
      'description': 'Private audio lounge for confidential team discussions',
      'members': [
        {'name': 'Zim (Host)', 'number': '+1-3847291', 'isSpeaking': false, 'isMuted': false},
      ],
      'allowedNumbers': ['+1-3847291', '+1-6860499'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen for real-time private hub invites
    SignalingService.instance.messageStream.listen((msg) {
      if (msg['type'] == 'private_hub_invite') {
        if (mounted) {
          final payload = msg['payload'];
          setState(() {
            _privateTables.add({
              'id': payload['table_id'],
              'name': payload['table_name'],
              'owner': payload['owner'],
              'description': 'Invited by ${payload['owner']}',
              'members': <Map<String, dynamic>>[],
              'allowedNumbers': <String>[],
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You were added to Private Table "${payload['table_name']}"!'),
              backgroundColor: IosTheme.accentBlue,
            ),
          );
        }
      }
    });
  }

  void _toggleJoin(String id) {
    setState(() {
      if (_activeHubId == id) {
        SignalingService.instance.leaveHangoutHub(_activeHubId!);
        _activeHubId = null;
      } else {
        _activeHubId = id;
        SignalingService.instance.joinHangoutHub(id);
      }
    });
  }

  // User submits a request to Admin to create a new Public Hub
  void _showRequestPublicHubDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Request Public Hub'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Public Hubs require admin approval before becoming visible to all users.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Hub Name',
                hintText: 'e.g. Chittagong Tech Lounge',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description / Purpose',
                hintText: 'What is this public hub for?',
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
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final res = await ApiService.instance.requestPublicHub(
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  districtCode: 1,
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Public Hub request submitted! Waiting for Admin approval.'),
                    backgroundColor: IosTheme.primaryGreen,
                  ),
                );
              }
            },
            child: const Text('Submit Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // User creates a Private Table and adds member IntraCom numbers
  void _showCreatePrivateTableDialog() {
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Create Private Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Private tables are only visible to you and the members you add.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Table Name',
                hintText: 'e.g. My Secret Voice Room',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: membersCtrl,
              decoration: const InputDecoration(
                labelText: 'Add Member Numbers (comma separated)',
                hintText: '+1-6860499, +2-1000001',
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
              if (nameCtrl.text.isNotEmpty) {
                final memberNums = membersCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final res = await ApiService.instance.createPrivateTable(
                  name: nameCtrl.text.trim(),
                  description: 'Private table',
                  memberNumbers: memberNums,
                );
                final tableData = res['data'];
                if (mounted && tableData != null) {
                  setState(() {
                    _privateTables.insert(0, {
                      'id': tableData['id'] ?? 'priv_${DateTime.now().millisecondsSinceEpoch}',
                      'name': tableData['name'] ?? nameCtrl.text.trim(),
                      'owner': tableData['owner_name'] ?? 'Me',
                      'description': 'Private lounge',
                      'members': <Map<String, dynamic>>[],
                      'allowedNumbers': memberNums,
                    });
                  });
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Private Table created! Added members can now see it in their Private Tables tab.'),
                    backgroundColor: IosTheme.primaryGreen,
                  ),
                );
              }
            },
            child: const Text('Create Table', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        title: const Text('Hangout Hubs'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: IosTheme.primaryGreen,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: '🌐 Public Hubs'),
            Tab(text: '🔒 Private Tables'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Active Voice Banner (if joined)
          if (_activeHubId != null)
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
                    decoration: const BoxDecoration(color: IosTheme.primaryGreen, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VOICE CONNECTED (RTC SFU)',
                            style: TextStyle(color: IosTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Text('Live Voice Channel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.redAccent : Colors.white),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),
                  IconButton(
                    icon: Icon(_isDeafened ? Icons.headset_off : Icons.headset, color: _isDeafened ? Colors.redAccent : Colors.white),
                    onPressed: () => setState(() => _isDeafened = !_isDeafened),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.redAccent),
                    onPressed: () => _toggleJoin(_activeHubId!),
                  ),
                ],
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. PUBLIC HUBS TAB
                _buildPublicHubsView(),

                // 2. PRIVATE TABLES TAB
                _buildPrivateTablesView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicHubsView() {
    return Column(
      children: [
        // Action Bar for Public Hubs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF141416),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Open Community Channels', style: TextStyle(fontSize: 13, color: Colors.white54)),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18, color: IosTheme.accentBlue),
                label: const Text('Request Hub', style: TextStyle(color: IosTheme.accentBlue, fontSize: 13)),
                onPressed: _showRequestPublicHubDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _publicHubs.length,
            itemBuilder: (context, i) {
              final hub = _publicHubs[i];
              return _buildHubCard(hub, isPrivate: false);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrivateTablesView() {
    return Column(
      children: [
        // Action Bar for Private Tables
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF141416),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Your Private Lounges', style: TextStyle(fontSize: 13, color: Colors.white54)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: IosTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.lock_open, size: 16, color: Colors.white),
                label: const Text('Create Table', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _showCreatePrivateTableDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _privateTables.isEmpty
              ? const Center(
                  child: Text('No private tables yet. Create one or get invited!', style: TextStyle(color: Colors.white38)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _privateTables.length,
                  itemBuilder: (context, i) {
                    final table = _privateTables[i];
                    return _buildHubCard(table, isPrivate: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHubCard(Map<String, dynamic> hub, {required bool isPrivate}) {
    final isConnected = _activeHubId == hub['id'];
    final members = (hub['members'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: IosTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? IosTheme.primaryGreen : Colors.white.withValues(alpha: 0.08),
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
                  : (isPrivate ? IosTheme.accentBlue.withValues(alpha: 0.15) : Colors.white12),
              child: Icon(
                isPrivate ? Icons.lock : Icons.volume_up_rounded,
                color: isConnected ? IosTheme.primaryGreen : (isPrivate ? IosTheme.accentBlue : Colors.white70),
                size: 20,
              ),
            ),
            title: Text(hub['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(
              isPrivate ? 'Private Table • ${members.length} listening' : '${hub['district']} • ${members.length} listening',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red.withValues(alpha: 0.2) : IosTheme.primaryGreen,
                foregroundColor: isConnected ? Colors.redAccent : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => _toggleJoin(hub['id']),
              child: Text(isConnected ? 'Leave' : 'Join Voice'),
            ),
          ),
          if (hub['description'] != null && hub['description'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(hub['description'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
          const SizedBox(height: 8),

          // Member chips
          if (members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: members.map((m) {
                  final speaking = m['isSpeaking'] == true;
                  return Chip(
                    avatar: Icon(speaking ? Icons.graphic_eq : Icons.person, size: 14, color: Colors.white),
                    label: Text(m['name'], style: TextStyle(fontSize: 11, color: speaking ? IosTheme.primaryGreen : Colors.white)),
                    backgroundColor: Colors.black38,
                    side: BorderSide(color: speaking ? IosTheme.primaryGreen : Colors.white10),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
