import 'package:flutter/material.dart';
import '../../theme/ios_theme.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'Rafiq Ahmed',
      'number': '+1-6860499',
      'lastMessage': 'Audio call connected nicely with low latency!',
      'time': '1:45 PM',
      'unread': 2,
    },
    {
      'name': 'Farhan (Narsingdi)',
      'number': '+2-1000001',
      'lastMessage': 'See you in the Narsingdi Hangout tonight.',
      'time': 'Yesterday',
      'unread': 0,
    },
    {
      'name': 'Kazi Sakib',
      'number': '+3-9182746',
      'lastMessage': 'Sent an attachment: voice_note_01.aac',
      'time': 'Monday',
      'unread': 0,
    },
  ];

  void _openChat(Map<String, dynamic> chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          contactName: chat['name'],
          contactNumber: chat['number'],
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    final numberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: IosTheme.cardDark,
        title: const Text('Start New Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberCtrl,
              decoration: const InputDecoration(
                labelText: 'IntraCom Number',
                hintText: '+1-6860499',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name (Optional)',
                hintText: 'e.g. Tanvir',
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
              if (numberCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                final name = nameCtrl.text.isEmpty ? numberCtrl.text : nameCtrl.text;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      contactName: name,
                      contactNumber: numberCtrl.text.trim(),
                    ),
                  ),
                );
              }
            },
            child: const Text('Chat', style: TextStyle(color: Colors.white)),
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
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: IosTheme.accentBlue),
            onPressed: _showNewChatDialog,
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const Divider(
          color: Colors.white10,
          indent: 72,
          height: 1,
        ),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          final unread = (chat['unread'] as int) > 0;

          return ListTile(
            onTap: () => _openChat(chat),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF2C2C2E),
              child: Text(
                (chat['name'] as String).substring(0, 1),
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    chat['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  chat['time'],
                  style: TextStyle(
                    fontSize: 12,
                    color: unread ? IosTheme.accentBlue : Colors.white38,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    chat['lastMessage'],
                    style: TextStyle(
                      fontSize: 13,
                      color: unread ? Colors.white : Colors.white54,
                      fontWeight: unread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: IosTheme.accentBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${chat['unread']}',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
