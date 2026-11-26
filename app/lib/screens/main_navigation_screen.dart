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
import '../services/api_service.dart';
import '../services/browser_alert_service.dart';
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
    // Initial fetch to populate Navbar unread red dot immediately
    ApiService.instance.getConversations();
  }

  void _listenForIncomingEvents() {
    _signalingSub = SignalingService.instance.messageStream.listen((msg) {
      if (!mounted) return;

      final type = msg['type'];

      if (type == 'call_offer' && !_isIncomingCallVisible) {
        final callerNumber = (msg['from'] ?? 'Unknown Caller').toString();
        final callerName = (msg['caller_name'] ?? 'IntraCom User').toString();
        final isVideo = msg['call_type'] == 'video';
        final offerPayload = msg['payload'];

        BrowserAlertService.playRingtone();
        BrowserAlertService.startTabFlash('📞 Incoming Call: $callerName');
        _showIncomingCallDialog(callerNumber, callerName, isVideo, offerPayload);
      } else if (type == 'call_hangup' && _isIncomingCallVisible) {
        BrowserAlertService.stopRingtone();
        BrowserAlertService.stopTabFlash();
        if (_incomingCallDialogCtx != null && mounted) {
          Navigator.of(_incomingCallDialogCtx!).pop();
          _incomingCallDialogCtx = null;
          _isIncomingCallVisible = false;
        }
      } else if (type == 'chat_message') {
        final payload = msg['payload'] ?? {};
        final text = (payload['content'] ?? payload['text'] ?? msg['content'] ?? '').toString();
        final senderName = (msg['caller_name'] ?? payload['sender_name'] ?? msg['from'] ?? 'User').toString();
        final senderNum = (msg['from'] ?? payload['sender_num'] ?? '').toString();

        // Refresh unread counts for Navbar Red Dot & Chat Threads
        ApiService.instance.getConversations();

        final activePeer = SignalingService.instance.activeChatPeer ?? '';
        final cleanActive = activePeer.replaceAll('+', '').replaceAll('-', '');
        final cleanSender = senderNum.replaceAll('+', '').replaceAll('-', '');
        final isSameChatOpen = cleanActive.isNotEmpty &&
            (cleanActive == cleanSender ||
                (cleanActive.length == 7 && cleanSender.endsWith(cleanActive)) ||
                (cleanSender.length == 7 && cleanActive.endsWith(cleanSender)));

        if (text.isNotEmpty && !isSameChatOpen) {
          BrowserAlertService.playMessageSound();
          BrowserAlertService.startTabFlash('💬 $senderName: $text');

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

  void _showIncomingCallDialog(String callerNumber, String callerName, bool isVideo, dynamic offerPayload) {
    _isIncomingCallVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        _incomingCallDialogCtx = ctx;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white12, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: IosTheme.primaryGreen.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.phone_fill,
                              color: IosTheme.primaryGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVideo ? 'Incoming Video Call' : 'Incoming IntraCom Call',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: IosTheme.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  callerName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  callerNumber,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF3B30),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.call_end, size: 18),
                              label: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                _isIncomingCallVisible = false;
                                BrowserAlertService.stopRingtone();
                                BrowserAlertService.stopTabFlash();
                                SignalingService.instance.sendHangup(callerNumber);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: IosTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                _isIncomingCallVisible = false;
                                BrowserAlertService.stopRingtone();
                                BrowserAlertService.stopTabFlash();
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
                                      remoteOffer: offerPayload,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isIncomingCallVisible = false;
      _incomingCallDialogCtx = null;
      BrowserAlertService.stopRingtone();
      BrowserAlertService.stopTabFlash();
    });
  }

  @override
  void dispose() {
    _signalingSub?.cancel();
    super.dispose();
  }

  Widget _buildMessagesNavIcon(bool active) {
    return ValueListenableBuilder<int>(
      valueListenable: ApiService.instance.unreadMessagesNotifier,
      builder: (context, unreadCount, _) {
        final icon = Icon(active ? CupertinoIcons.chat_bubble_2_fill : CupertinoIcons.chat_bubble_2);
        if (unreadCount <= 0) return icon;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
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
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            ApiService.instance.callHistoryRefreshNotifier.value++;
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            activeIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Contacts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock),
            activeIcon: Icon(CupertinoIcons.clock_fill),
            label: 'Recents',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.circle_grid_3x3),
            activeIcon: Icon(CupertinoIcons.circle_grid_3x3_fill),
            label: 'Keypad',
          ),
          BottomNavigationBarItem(
            icon: _buildMessagesNavIcon(false),
            activeIcon: _buildMessagesNavIcon(true),
            label: 'Messages',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.speaker_2),
            activeIcon: Icon(CupertinoIcons.speaker_2_fill),
            label: 'Hangout',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle),
            activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
