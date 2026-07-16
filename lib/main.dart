import 'package:flutter/material.dart';
import 'package:severina/data/app_settings.dart';
import 'package:severina/screens/chat_screen.dart';
import 'package:severina/screens/settings_screen.dart';
import 'package:severina/screens/setup_screen.dart';

void main() {
  runApp(const SeverinaApp());
}

class SeverinaApp extends StatelessWidget {
  const SeverinaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Severina',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B73C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AppRouter(),
      routes: {
        '/chat': (ctx) => const ChatScreen(),
        '/settings': (ctx) => const SettingsScreen(),
        '/setup': (ctx) => const SetupScreen(),
      },
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool? _configured;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final ready = await AppSettings.isConfiguredStatic();
    setState(() => _configured = ready);
  }

  @override
  Widget build(BuildContext context) {
    if (_configured == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_configured == false) {
      return const SetupScreen();
    }
    return const ChatScreen();
  }
}
