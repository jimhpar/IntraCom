import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'contacts/contacts_screen.dart';
import 'dialer/dialer_screen.dart';
import 'messages/messages_screen.dart';
import 'profile/profile_screen.dart';
import 'hangout/hangout_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 1; // Default to Dialer (index 1) like iPhone phone app

  final List<Widget> _screens = const [
    ContactsScreen(),
    DialerScreen(),
    MessagesScreen(),
    ProfileScreen(),
    HangoutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            activeIcon: Icon(CupertinoIcons.person_2_fill),
            label: 'Contacts',
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
            icon: Icon(CupertinoIcons.person_crop_circle),
            activeIcon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.speaker_2),
            activeIcon: Icon(CupertinoIcons.speaker_2_fill),
            label: 'Hangout',
          ),
        ],
      ),
    );
  }
}
