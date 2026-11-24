import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/ios_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: IntraComApp(),
    ),
  );
}

class IntraComApp extends StatelessWidget {
  const IntraComApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IntraCom',
      debugShowCheckedModeBanner: false,
      theme: IosTheme.darkTheme,
      darkTheme: IosTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const MainNavigationScreen(),
    );
  }
}
