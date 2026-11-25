import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';
import '../calling/in_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final String contactNumber;
  final bool isHubChat;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactNumber,
    this.isHubChat = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription? _signalSub;

  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Listen for live messages from WebSocket
    _signalSub = SignalingService.instance.messageStream.listen((msg) {
      if (!mounted) return;
      final type = msg['type'];

      if (widget.isHubChat) {
        if (type == 'hub_chat_message' &&
            (msg['hangout_id'] == widget.contactNumber ||
                msg['payload']?['hangout_id'] == widget.contactNumber)) {
          final payload = msg['payload'] ?? msg;
          final senderNum = payload['sender_num'] ?? msg['from'] ?? '';
          final myNum = ApiService.instance.currentUser?['full_number'] ?? '';

          if (senderNum != myNum) {
            setState(() {
              _messages.add({
                'id': payload['id'],
                'isMe': false,
                'senderName': payload['sender_name'] ?? senderNum,
                'text': payload['content'] ?? payload['text'] ?? '',
                'time': 'Just now',
              });
            });
            _scrollToBottom();
          }
        }
      } else {
        if (type == 'chat_message') {
          final fromNum = (msg['from'] ?? '').toString();
          // Normalize comparison
          final cleanFrom = fromNum.replaceAll('-', '').replaceAll('+', '');
          final cleanContact = widget.contactNumber.replaceAll('-', '').replaceAll('+', '');

          if (cleanFrom == cleanContact || fromNum == widget.contactNumber) {
            final payload = msg['payload'] ?? {};
            final text = payload['text'] ?? payload['content'] ?? msg['content'] ?? '';
            setState(() {
              _messages.add({
                'isMe': false,
                'senderName': widget.contactName,
                'text': text,
                'time': 'Just now',
              });
            });
            _scrollToBottom();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _formatMsgTime(dynamic val) {
    if (val == null) return 'Now';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period';
    } catch (_) {
      return 'Now';
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    if (widget.isHubChat) {
      final list = await ApiService.instance.getHubMessages(widget.contactNumber);
      if (mounted) {
        final myNum = ApiService.instance.currentUser?['full_number'] ?? '';
        setState(() {
          _messages = list.map((m) {
            final isMe = m['sender_num'] == myNum;
            return {
              'id': m['id'],
              'isMe': isMe,
              'senderName': m['sender_name'] ?? m['sender_num'] ?? 'User',
              'text': m['content'] ?? '',
              'time': _formatMsgTime(m['created_at']),
            };
          }).toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } else {
      // 1-on-1 Persistent chat messages
      final list = await ApiService.instance.getDirectChat(widget.contactNumber);
      if (mounted) {
        final myNum = (ApiService.instance.currentUser?['full_number'] ?? '').replaceAll('-', '').replaceAll('+', '');
        setState(() {
          _messages = list.map((m) {
            final senderNum = (m['sender_num'] ?? '').toString().replaceAll('-', '').replaceAll('+', '');
            final isMe = m['is_me'] == true || (myNum.isNotEmpty && senderNum == myNum);
            return {
              'id': m['id'],
              'isMe': isMe,
              'senderName': isMe ? 'Me' : widget.contactName,
              'text': m['content'] ?? '',
              'time': _formatMsgTime(m['created_at']),
            };
          }).toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final myNum = ApiService.instance.currentUser?['full_number'] ?? '';
    final myName = ApiService.instance.currentUser?['display_name'] ?? 'Me';

    setState(() {
      _messages.add({
        'isMe': true,
        'senderName': myName,
        'text': text,
        'time': 'Just now',
      });
      _msgCtrl.clear();
    });

    _scrollToBottom();

    if (widget.isHubChat) {
      // 1. Persist to server via REST API
      await ApiService.instance.sendHubMessage(widget.contactNumber, text);

      // 2. Broadcast via WebSocket
      SignalingService.instance.sendSignal({
        'type': 'hub_chat_message',
        'hangout_id': widget.contactNumber,
        'from': myNum,
        'payload': {
          'hangout_id': widget.contactNumber,
          'content': text,
          'sender_name': myName,
          'sender_num': myNum,
        },
      });
    } else {
      // 1:1 Direct Message: Persist via API & real-time push via WebSocket
      await ApiService.instance.sendDirectMessage(widget.contactNumber, text);

      SignalingService.instance.sendSignal({
        'type': 'chat_message',
        'from': myNum,
        'to': widget.contactNumber,
        'payload': {
          'text': text,
          'sender_name': myName,
          'sender_num': myNum,
        },
      });
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History?'),
        content: const Text('Are you sure you want to clear all messages in this conversation?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!widget.isHubChat) {
        await ApiService.instance.deleteConversation(widget.contactNumber);
      }
      setState(() {
        _messages.clear();
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark ? Colors.white54 : const Color(0xFF8E8E93);
    final otherBubbleBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final otherBubbleText = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final otherBubbleTime = isDark ? Colors.white38 : const Color(0xFF8E8E93);
    final bottomBarBg = isDark ? const Color(0xFF161618) : Colors.white;
    final bottomBarBorder = isDark ? Colors.white10 : const Color(0xFFE5E5EA);
    final inputBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final avatarBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarBg,
              child: Icon(
                widget.isHubChat ? Icons.forum_rounded : Icons.person,
                color: widget.isHubChat ? IosTheme.accentBlue : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.isHubChat ? 'Lounge Group Chat' : widget.contactNumber,
                    style: const TextStyle(fontSize: 11, color: IosTheme.primaryGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!widget.isHubChat) ...[
            IconButton(
              icon: const Icon(Icons.phone, color: IosTheme.primaryGreen),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InCallScreen(
                      targetNumber: widget.contactNumber,
                      targetName: widget.contactName,
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
                      targetNumber: widget.contactNumber,
                      targetName: widget.contactName,
                      isVideo: true,
                    ),
                  ),
                );
              },
            ),
          ],
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : const Color(0xFF3A3A3C)),
            onSelected: (val) {
              if (val == 'refresh') {
                _loadMessages();
              } else if (val == 'clear') {
                _clearChat();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Refresh Messages'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Clear Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: IosTheme.primaryGreen))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_chat_read_outlined, size: 48, color: secondaryTextColor.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              widget.isHubChat ? 'No Lounge Messages Yet' : 'No messages yet with ${widget.contactName}',
                              style: TextStyle(color: secondaryTextColor, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type a message below to start chatting.',
                              style: TextStyle(color: secondaryTextColor.withOpacity(0.7), fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final isMe = m['isMe'] == true;
                          final senderName = m['senderName'];

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? IosTheme.primaryGreen : otherBubbleBg,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (widget.isHubChat && !isMe && senderName != null) ...[
                                    Text(
                                      senderName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: IosTheme.accentBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    m['text'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white : otherBubbleText,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m['time'] ?? '',
                                    style: TextStyle(
                                      color: isMe ? Colors.white70 : otherBubbleTime,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bottomBarBg,
              border: Border(top: BorderSide(color: bottomBarBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: widget.isHubChat ? 'Chat with hub members...' : 'Message...',
                          hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: IosTheme.primaryGreen,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
