import 'package:flutter/material.dart';
import '../../theme/ios_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final List<Map<String, dynamic>> _chats = [
    {
      'name': 'Md. Tanvir Hasan',
      'number': '+1-3847291',
      'lastMessage': 'Audio call connected nicely with low latency!',
      'time': '1:45 PM',
      'unread': 2,
    },
    {
      'name': 'Farhan Ahmed',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: IosTheme.accentBlue),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Start new direct message chat')),
              );
            },
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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening chat with ${chat['number']}...')),
              );
            },
          );
        },
      ),
    );
  }
}
