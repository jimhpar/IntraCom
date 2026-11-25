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

  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // Listen for live messages from WebSocket
    SignalingService.instance.messageStream.listen((msg) {
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
        if (type == 'chat_message' && msg['from'] == widget.contactNumber) {
          setState(() {
            _messages.add({
              'isMe': false,
              'text': msg['payload']?['text'] ?? '',
              'time': 'Just now',
            });
          });
          _scrollToBottom();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    if (widget.isHubChat) {
      setState(() => _loading = true);
      final list = await ApiService.instance.getHubMessages(widget.contactNumber);
      if (mounted) {
        final myNum = ApiService.instance.currentUser?['full_number'] ?? '';
        setState(() {
          _messages = list.map((m) {
            final isMe = m['sender_num'] == myNum;
            return {
              'isMe': isMe,
              'senderName': m['sender_name'] ?? m['sender_num'] ?? 'User',
              'text': m['content'] ?? '',
              'time': 'Recent',
            };
          }).toList();
          if (_messages.isEmpty) {
            _messages = [
              {
                'isMe': false,
                'senderName': 'System',
                'text': 'Welcome to ${widget.contactName} live lounge chat! Send a message to everyone here.',
                'time': 'Now',
              }
            ];
          }
          _loading = false;
        });
        _scrollToBottom();
      }
    } else {
      _messages = [
        {
          'isMe': false,
          'text': 'Salam! Welcome to IntraCom direct secure messaging.',
          'time': '12:30 PM',
        },
      ];
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
      // 1:1 Direct Message via WebSocket
      SignalingService.instance.sendSignal({
        'type': 'chat_message',
        'from': myNum,
        'to': widget.contactNumber,
        'payload': {'text': text},
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2C2C2E),
              child: Icon(
                widget.isHubChat ? Icons.forum_rounded : Icons.person,
                color: widget.isHubChat ? IosTheme.accentBlue : Colors.white,
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        actions: widget.isHubChat
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: _loadMessages,
                ),
              ]
            : [
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
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: IosTheme.primaryGreen))
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
                            color: isMe ? IosTheme.primaryGreen : const Color(0xFF2C2C2E),
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
                                  color: isMe ? Colors.white : Colors.white.withValues(alpha: 0.95),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['time'] ?? '',
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.white38,
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
              color: const Color(0xFF161618),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: widget.isHubChat ? 'Chat with hub members...' : 'Message...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
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
