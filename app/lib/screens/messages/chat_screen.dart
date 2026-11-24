import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/signaling_service.dart';
import '../../theme/ios_theme.dart';
import '../calling/in_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final String contactNumber;

  const ChatScreen({
    super.key,
    required this.contactName,
    required this.contactNumber,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'isMe': false,
      'text': 'Salam! Welcome to IntraCom.',
      'time': '12:30 PM',
    },
    {
      'isMe': true,
      'text': 'Walaykum Assalam! Audio calling and hangouts are working super fast.',
      'time': '12:32 PM',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Listen for live messages from WebSocket
    SignalingService.instance.messageStream.listen((msg) {
      if (msg['type'] == 'chat_message' && msg['from'] == widget.contactNumber) {
        if (mounted) {
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

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final myNum = ApiService.instance.currentUser?['full_number'] ?? '';
    setState(() {
      _messages.add({
        'isMe': true,
        'text': text,
        'time': 'Just now',
      });
      _msgCtrl.clear();
    });

    _scrollToBottom();

    // Send through WebSocket
    SignalingService.instance.sendSignal({
      'type': 'chat_message',
      'from': myNum,
      'to': widget.contactNumber,
      'payload': {'text': text},
    });
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
              child: Text(
                widget.contactName.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.contactName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(widget.contactNumber, style: const TextStyle(fontSize: 11, color: IosTheme.primaryGreen)),
              ],
            ),
          ],
        ),
        actions: [
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
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final m = _messages[i];
                final isMe = m['isMe'] == true;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF007AFF) : const Color(0xFF2C2C2E),
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
                        Text(m['text'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text(m['time'], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF161618),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: IosTheme.accentBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 22),
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
