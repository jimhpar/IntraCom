import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'contacts/contacts_screen.dart';
import 'calls/call_history_screen.dart';
import 'dialer/dialer_screen.dart';
import 'messages/messages_screen.dart';
import 'hangout/hangout_screen.dart';
import 'profile/profile_screen.dart';
import 'calling/in_call_screen.dart';
import 'messages/chat_screen.dart';
import '../services/signaling_service.dart';
import '../theme/ios_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 2; // Default to Keypad/Dialer (index 2) like iPhone
  StreamSubscription? _signalingSub;
  bool _isIncomingCallVisible = false;
  BuildContext? _incomingCallDialogCtx;

  // Ordered: Contacts -> Recents (Call History) -> Keypad -> Messages -> Hangout -> Profile
  final List<Widget> _screens = const [
    ContactsScreen(),
    CallHistoryScreen(),
    DialerScreen(),
    MessagesScreen(),
    HangoutScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForIncomingEvents();
  }

  void _listenForIncomingEvents() {
    _signalingSub = SignalingService.instance.messageStream.listen((msg) {
      if (!mounted) return;

      final type = msg['type'];

      if (type == 'call_offer' && !_isIncomingCallVisible) {
        final callerNumber = msg['from'] ?? 'Unknown Caller';
        final callerName = msg['caller_name'] ?? 'IntraCom User';
        final isVideo = msg['call_type'] == 'video';

        _showIncomingCallDialog(callerNumber, callerName, isVideo);
      } else if (type == 'call_hangup' && _isIncomingCallVisible) {
        if (_incomingCallDialogCtx != null && mounted) {
          Navigator.of(_incomingCallDialogCtx!).pop();
          _incomingCallDialogCtx = null;
          _isIncomingCallVisible = false;
        }
      } else if (type == 'chat_message') {
        final payload = msg['payload'] ?? {};
        final text = payload['content'] ?? payload['text'] ?? msg['content'] ?? '';
        final senderName = msg['caller_name'] ?? payload['sender_name'] ?? msg['from'] ?? 'User';
        final senderNum = (msg['from'] ?? payload['sender_num'] ?? '').toString();

        if (text.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1C1C1E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(CupertinoIcons.chat_bubble_fill, color: IosTheme.primaryGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Reply',
                textColor: IosTheme.primaryGreen,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        contactName: senderName,
                        contactNumber: senderNum,
                      ),
                    ),
                  );
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  void _showIncomingCallDialog(String callerNumber, String callerName, bool isVideo) {
    _isIncomingCallVisible = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      pageBuilder: (ctx, anim1, anim2) {
        _incomingCallDialogCtx = ctx;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 40),
                Column(
                  children: [
                    Text(
                      isVideo ? 'Incoming Video Call' : 'Incoming IntraCom Call',
                      style: const TextStyle(fontSize: 16, color: IosTheme.primaryGreen, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      callerName,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        callerNumber,
                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircleAvatar(
                      radius: 60,
                      backgroundColor: Color(0xFF2C2C2E),
                      child: Icon(Icons.person, size: 64, color: Colors.white70),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 50, left: 40, right: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decline button
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _isIncomingCallVisible = false;
                              SignalingService.instance.sendHangup(callerNumber);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call_end, size: 36, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                      // Accept button
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _isIncomingCallVisible = false;
                              SignalingService.instance.sendCallAnswer(callerNumber, {'type': 'answer'});
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InCallScreen(
                                    targetNumber: callerNumber,
                                    targetName: callerName,
                                    isVideo: isVideo,
                                    isIncoming: true,
                                    initialConnected: true,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                color: IosTheme.primaryGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call, size: 36, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Accept', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isIncomingCallVisible = false;
      _incomingCallDialogCtx = null;
    });
  }

  @override
  void dispose() {
    _signalingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            activeIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock),
            activeIcon: Icon(CupertinoIcons.clock_fill),
            label: 'Recents',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.circle_grid_3x3),
            activeIcon: Icon(CupertinoIcons.circle_grid_3x3_fill),
            label: 'Keypad',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble_2),
            activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.speaker_2),
            activeIcon: Icon(CupertinoIcons.speaker_2_fill),
            label: 'Hangout',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle),
            activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
