import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  StreamSubscription? _msgSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();

    // 1. Silent live background poller every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _loadConversations(silent: true);
      }
    });

    // 2. Listen for live messages from WebSocket to refresh conversations
    _msgSub = SignalingService.instance.messageStream.listen((msg) {
      if (!mounted) return;
      final type = msg['type'];
      if (type == 'chat_message' || type == 'message') {
        _loadConversations(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgSub?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final list = await ApiService.instance.getConversations();
      if (mounted) {
        setState(() {
          _conversations = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteConversation(String peerNum, String peerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Conversation?',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1C1C1E),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete all messages with $peerName ($peerNum)? This cannot be undone.',
            style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF3A3A3C)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ApiService.instance.deleteConversation(peerNum);
      _loadConversations();
    }
  }

  void _openChat(Map<String, dynamic> chat) async {
    final name = chat['peer_name'] ?? chat['peer_number'] ?? 'User';
    final number = chat['peer_number'] ?? '';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contactName: name,
          contactNumber: number,
        ),
      ),
    );
    _loadConversations(silent: true);
  }

  void _showNewChatDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final numberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Start New Message',
          style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'IntraCom Number or Mobile',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: 'e.g. 1111111 or +1-6860499',
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                labelText: 'Name (Optional)',
                labelStyle: TextStyle(color: secondaryTextColor),
                hintText: 'e.g. Rafiq',
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
            onPressed: () {
              final raw = numberCtrl.text.trim();
              if (raw.isNotEmpty) {
                Navigator.pop(ctx);
                final name = nameCtrl.text.trim().isEmpty ? raw : nameCtrl.text.trim();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      contactName: name,
                      contactNumber: raw,
                    ),
                  ),
                ).then((_) => _loadConversations(silent: true));
              }
            },
            child: const Text('Chat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic val) {
    if (val == null) return '';
    try {
      final str = val.toString();
      final dt = DateTime.parse(str).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$hour:$minute $period';
      }
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final avatarBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final dividerColor = isDark ? Colors.white10 : const Color(0xFFE5E5EA);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: IosTheme.accentBlue),
            tooltip: 'New Message',
            onPressed: _showNewChatDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: IosTheme.primaryGreen))
          : _conversations.isEmpty
              ? RefreshIndicator(
                  onRefresh: () => _loadConversations(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 64,
                              color: secondaryTextColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Messages Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap the top-right button to start a conversation.',
                              style: TextStyle(fontSize: 14, color: secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadConversations(),
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (context, index) => Divider(
                      color: dividerColor,
                      indent: 72,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final chat = _conversations[index];
                      final name = chat['peer_name'] ?? chat['peer_number'] ?? 'User';
                      final number = chat['peer_number'] ?? '';
                      final lastMsg = chat['last_message'] ?? '';
                      final timeStr = _formatTime(chat['last_message_time'] ?? chat['last_message_at']);
                      final unreadCount = chat['unread_count'] is int ? chat['unread_count'] as int : 0;

                      return Dismissible(
                        key: Key('conv_$number'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteConversation(number, name);
                          return false; // Handled manually
                        },
                        child: ListTile(
                          onTap: () => _openChat(chat),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: avatarBg,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 16,
                                    color: primaryTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: unreadCount > 0 ? IosTheme.accentBlue : secondaryTextColor,
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMsg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0 ? primaryTextColor : secondaryTextColor,
                                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: IosTheme.accentBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: secondaryTextColor, size: 20),
                            onSelected: (val) {
                              if (val == 'delete') {
                                _deleteConversation(number, name);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Delete Chat', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
