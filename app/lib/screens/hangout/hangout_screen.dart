import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';
import '../messages/chat_screen.dart';

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
  bool _loading = false;

  List<Map<String, dynamic>> _publicHubs = [
    {
      'id': 'pub_1',
      'name': 'Bangladesh Central Voice Lounge',
      'district': 'All Districts',
      'description': 'Open community audio hub for everyone across 64 districts',
    },
    {
      'id': 'pub_2',
      'name': 'Dhaka Developers Hub',
      'district': 'Dhaka (+1)',
      'description': 'Voice chat for software engineers, designers & tech enthusiasts',
    },
    {
      'id': 'pub_3',
      'name': 'Narsingdi Community Channel',
      'district': 'Narsingdi (+2)',
      'description': 'Local discussion & networking hub for Narsingdi district',
    },
  ];

  List<Map<String, dynamic>> _privateTables = [
    {
      'id': 'priv_1',
      'name': 'Core Team Private Table',
      'owner': 'Zim Official',
      'description': 'Private audio lounge for confidential team discussions',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHubs();

    // Listen for real-time private hub invites
    SignalingService.instance.messageStream.listen((msg) {
      if (msg['type'] == 'private_hub_invite') {
        if (mounted) {
          final payload = msg['payload'];
          setState(() {
            _privateTables.insert(0, {
              'id': payload['table_id'],
              'name': payload['table_name'],
              'owner': payload['owner'],
              'description': 'Invited by ${payload['owner']}',
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

  Future<void> _loadHubs() async {
    setState(() => _loading = true);
    try {
      final pubRes = await ApiService.instance.getPublicHubs();
      if (pubRes['success'] == true && pubRes['data'] is List) {
        final list = List<Map<String, dynamic>>.from(pubRes['data']);
        if (list.isNotEmpty) {
          _publicHubs = list;
        }
      }

      final privRes = await ApiService.instance.getPrivateTables();
      if (privRes['success'] == true && privRes['data'] is List) {
        final list = List<Map<String, dynamic>>.from(privRes['data']);
        if (list.isNotEmpty) {
          _privateTables = list;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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

  // Show Users Modal with Add to Contact option
  void _showHubUsersModal(Map<String, dynamic> hub) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final avatarBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final btnBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final hubId = hub['id'].toString();
    final hubName = hub['name'] ?? 'Hub';

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: ApiService.instance.getHubMembers(hubId),
          builder: (context, snapshot) {
            final members = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$hubName • Members',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: secondaryTextColor, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white12 : const Color(0xFFE5E5EA)),
                  const SizedBox(height: 8),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator(color: IosTheme.primaryGreen)),
                    )
                  else if (members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('No other members currently in this hub.', style: TextStyle(color: secondaryTextColor)),
                      ),
                    )
                  else
                    Expanded(
                      child: ValueListenableBuilder<Set<String>>(
                        valueListenable: SignalingService.instance.onlineUsersNotifier,
                        builder: (context, onlineUsers, child) {
                          return ListView.separated(
                            itemCount: members.length,
                            separatorBuilder: (context, index) => Divider(color: isDark ? Colors.white10 : const Color(0xFFE5E5EA), height: 1),
                            itemBuilder: (context, i) {
                              final user = members[i];
                              final userNum = user['full_number'] ?? '';
                              final userName = user['display_name'] ?? 'IntraCom User';
                              final district = user['district_name'] ?? '';
                              final isOnline = onlineUsers.contains(userNum);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: avatarBg,
                                      child: Text(
                                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                        style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: isOnline ? IosTheme.primaryGreen : Colors.grey,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  userName,
                                  style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor, fontSize: 14),
                                ),
                                subtitle: Text(
                                  '$userNum ${district.isNotEmpty ? '• $district' : ''}',
                                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                ),
                                trailing: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: btnBg,
                                    foregroundColor: IosTheme.primaryGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                                  label: const Text('Add to Contact', style: TextStyle(fontSize: 11)),
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    await ApiService.instance.addContact(
                                      name: userName,
                                      number: userNum,
                                      district: district.isNotEmpty ? district : 'IntraCom User',
                                    );
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Added $userName ($userNum) to your contacts!'),
                                          backgroundColor: IosTheme.primaryGreen,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
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
          },
        );
      },
    );
  }

  // User submits a request to Admin to create a new Public Hub
  void _showRequestPublicHubDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Request Public Hub', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Public Hubs require admin approval before becoming visible to all users.',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Hub Name',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: 'e.g. Chittagong Tech Lounge',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Description / Purpose',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: 'What is this public hub for?',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
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
                _loadHubs();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final nameCtrl = TextEditingController();
    final membersCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Create Private Table', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Private tables are only visible to you and the members you add.',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Table Name',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: 'e.g. My Secret Voice Room',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: membersCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Add Member Numbers (comma separated)',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: '+1-6860499, +2-1000001',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: secondaryTextColor)),
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
                    });
                  });
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Private Table created! Added members can now see it in their Private Tables tab.'),
                    backgroundColor: IosTheme.primaryGreen,
                  ),
                );
                _loadHubs();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hangout Hubs'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : const Color(0xFF3A3A3C)),
            onPressed: _loadHubs,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: IosTheme.primaryGreen,
          labelColor: isDark ? Colors.white : IosTheme.primaryGreen,
          unselectedLabelColor: isDark ? Colors.white38 : const Color(0xFF8E8E93),
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
                        Text('Live Voice Channel Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: IosTheme.primaryGreen))
                : TabBarView(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionBarBg = isDark ? const Color(0xFF141416) : const Color(0xFFE5E5EA);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF6C6C70);

    return Column(
      children: [
        // Action Bar for Public Hubs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: actionBarBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Open Community Channels', style: TextStyle(fontSize: 13, color: secondaryTextColor)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionBarBg = isDark ? const Color(0xFF141416) : const Color(0xFFE5E5EA);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF6C6C70);

    return Column(
      children: [
        // Action Bar for Private Tables
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: actionBarBg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Private Lounges', style: TextStyle(fontSize: 13, color: secondaryTextColor)),
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
              ? Center(
                  child: Text('No private tables yet. Create one or get invited!', style: TextStyle(color: secondaryTextColor)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final descTextColor = isDark ? Colors.white70 : const Color(0xFF3A3A3C);
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final cardBorder = isDark ? Colors.white10 : const Color(0xFFE5E5EA);
    final chatBtnBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final usersBtnBorder = isDark ? Colors.white24 : const Color(0xFFD1D1D6);

    final hubId = hub['id'].toString();
    final isConnected = _activeHubId == hubId;
    final name = hub['name'] ?? 'Hub';
    final district = hub['district_name'] ?? hub['district'] ?? (isPrivate ? 'Private Table' : 'General');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? IosTheme.primaryGreen : cardBorder,
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
                  : (isPrivate ? IosTheme.accentBlue.withValues(alpha: 0.15) : (isDark ? Colors.white12 : const Color(0xFFE5E5EA))),
              child: Icon(
                isPrivate ? Icons.lock : Icons.volume_up_rounded,
                color: isConnected ? IosTheme.primaryGreen : (isPrivate ? IosTheme.accentBlue : (isDark ? Colors.white70 : const Color(0xFF1C1C1E))),
                size: 20,
              ),
            ),
            title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor)),
            subtitle: Text(
              district,
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected ? Colors.red.withValues(alpha: 0.2) : IosTheme.primaryGreen,
                foregroundColor: isConnected ? Colors.redAccent : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () => _toggleJoin(hubId),
              child: Text(isConnected ? 'Leave' : 'Join Voice'),
            ),
          ),
          if (hub['description'] != null && hub['description'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(hub['description'], style: TextStyle(fontSize: 12, color: descTextColor)),
            ),
          const SizedBox(height: 12),

          // Clean Actions Row: "Users" button & "Chat" button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // 1. "Users" button with member count & modal
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: usersBtnBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.people_outline, size: 18, color: IosTheme.accentBlue),
                    label: const Text('Users', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => _showHubUsersModal(hub),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. "Chat" button with chat icon
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: chatBtnBg,
                      foregroundColor: primaryTextColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18, color: IosTheme.primaryGreen),
                    label: const Text('Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            contactName: name,
                            contactNumber: hubId,
                            isHubChat: true,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
