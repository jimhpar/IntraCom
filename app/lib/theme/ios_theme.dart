import 'package:flutter/material.dart';

class IosTheme {
  // iOS Light & Dark Palettes
  static const Color primaryGreen = Color(0xFF34C759); // iOS Call green
  static const Color destructiveRed = Color(0xFFFF3B30); // iOS Hangup red
  static const Color dialerBgDark = Color(0xFF000000);
  static const Color dialerKeyDark = Color(0xFF2C2C2E);
  static const Color dialerKeyTextDark = Colors.white;
  static const Color dialerKeySubtextDark = Color(0xFF8E8E93);

  static const Color bgDark = Color(0xFF000000);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color navBarDark = Color(0xFF161618);
  static const Color accentBlue = Color(0xFF007AFF);

  // Default OLED Dark Theme
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF000000),
    cardColor: const Color(0xFF1C1C1E),
    primaryColor: primaryGreen,
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      secondary: accentBlue,
      surface: Color(0xFF1C1C1E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121214),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF121214),
      selectedItemColor: accentBlue,
      unselectedItemColor: Color(0xFF8E8E93),
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
  );

  // Midnight Navy Theme
  static ThemeData midnightNavyTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B132B),
    cardColor: const Color(0xFF1C2541),
    primaryColor: const Color(0xFF48CAE4),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF48CAE4),
      secondary: Color(0xFF5BC0BE),
      surface: Color(0xFF1C2541),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0F24),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF0A0F24),
      selectedItemColor: Color(0xFF48CAE4),
      unselectedItemColor: Color(0xFF8E8E93),
      type: BottomNavigationBarType.fixed,
    ),
  );

  // Charcoal Slate Theme
  static ThemeData charcoalSlateTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1E2022),
    cardColor: const Color(0xFF282B30),
    primaryColor: primaryGreen,
    colorScheme: const ColorScheme.dark(
      primary: primaryGreen,
      secondary: accentBlue,
      surface: Color(0xFF282B30),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF18191B),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF18191B),
      selectedItemColor: primaryGreen,
      unselectedItemColor: Color(0xFF8E8E93),
      type: BottomNavigationBarType.fixed,
    ),
  );

  // Light Mode
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    cardColor: Colors.white,
    primaryColor: primaryGreen,
    canvasColor: const Color(0xFFF2F2F7),
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: accentBlue,
      surface: Colors.white,
      onSurface: Color(0xFF1C1C1E),
    ),
    dividerColor: const Color(0xFFE5E5EA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1C1C1E),
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color(0xFF1C1C1E)),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1C1E),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      titleTextStyle: TextStyle(color: Color(0xFF1C1C1E), fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: Color(0xFF3A3A3C), fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: primaryGreen,
      unselectedLabelColor: Color(0xFF8E8E93),
      indicatorColor: primaryGreen,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryGreen,
      unselectedItemColor: Color(0xFF8E8E93),
      type: BottomNavigationBarType.fixed,
    ),
  );

  // Reactive Theme Notifiers
  static final ValueNotifier<String> themeNameNotifier = ValueNotifier<String>('iOS Dark Dial Mode');
  static final ValueNotifier<ThemeData> currentThemeNotifier = ValueNotifier<ThemeData>(darkTheme);

  static void setTheme(String name) {
    themeNameNotifier.value = name;
    if (name == 'Midnight Navy') {
      currentThemeNotifier.value = midnightNavyTheme;
    } else if (name == 'Charcoal Slate') {
      currentThemeNotifier.value = charcoalSlateTheme;
    } else if (name == 'iOS Clean Light') {
      currentThemeNotifier.value = lightTheme;
    } else {
      currentThemeNotifier.value = darkTheme;
    }
  }
}
