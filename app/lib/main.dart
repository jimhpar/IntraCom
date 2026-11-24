import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/api_service.dart';
import 'services/signaling_service.dart';
import 'theme/ios_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();

  if (ApiService.instance.isAuthenticated) {
    SignalingService.instance.connect();
  }

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
      home: ApiService.instance.isAuthenticated
          ? const MainNavigationScreen()
          : const AuthScreen(),
    );
  }
}
