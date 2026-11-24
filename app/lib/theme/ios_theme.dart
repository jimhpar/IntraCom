import 'package:flutter/material.dart';

class IosTheme {
  // iOS Light & Dark Palettes
  static const Color primaryGreen = Color(0xFF34C759); // iOS Call green
  static const Color destructiveRed = Color(0xFFFF3B30); // iOS Hangup red
  static const Color dialerBgDark = Color(0xFF000000);
  static const Color dialerKeyDark = Color(0xFF2C2C2E);
  static const Color dialerKeyTextDark = Colors.white;
  static const Color dialerKeySubtextDark = Color(0xFF8E8E93);

  static const Color bgDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color navBarDark = Color(0xFF161618);
  static const Color accentBlue = Color(0xFF007AFF);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgDark,
    primaryColor: primaryGreen,
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      secondary: accentBlue,
      surface: cardDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: navBarDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: navBarDark,
      selectedItemColor: accentBlue,
      unselectedItemColor: Color(0xFF8E8E93),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
  );
}
