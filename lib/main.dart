import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:severina/data/app_settings.dart';
import 'package:severina/screens/chat_screen.dart';
import 'package:severina/screens/settings_screen.dart';
import 'package:severina/screens/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SeverinaApp());
}

class _FullscreenKeeper extends StatefulWidget {
  final Widget child;
  const _FullscreenKeeper({required this.child});

  @override
  State<_FullscreenKeeper> createState() => _FullscreenKeeperState();
}

class _FullscreenKeeperState extends State<_FullscreenKeeper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterFullscreen();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Re-ativa fullscreen se o sistema reexibir as barras
    Future.microtask(_enterFullscreen);
  }

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
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
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            // Material 3: fade + slide sutil (efeito 'fadeForwards')
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const _FullscreenKeeper(child: AppRouter()),
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
