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

class _FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _FadeSlide(routeAnimation: animation, child: child);
  }
}

class _FadeSlide extends StatefulWidget {
  final Animation<double> routeAnimation;
  final Widget child;
  const _FadeSlide({required this.routeAnimation, required this.child});

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 1),
      reverseDuration: const Duration(seconds: 1),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.04, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Segue a animacao nativa da rota (0 -> 1 na entrada, 1 -> 0 na saida)
    widget.routeAnimation.addListener(_sync);
    _sync();
  }

  void _sync() {
    final status = widget.routeAnimation.status;
    if (status == AnimationStatus.forward) {
      if (!_ctrl.isAnimating && _ctrl.value < 1.0) {
        _ctrl.forward();
      }
    } else if (status == AnimationStatus.reverse) {
      if (!_ctrl.isAnimating && _ctrl.value > 0.0) {
        _ctrl.reverse();
      }
    } else if (status == AnimationStatus.completed) {
      _ctrl.value = 1.0;
    } else if (status == AnimationStatus.dismissed) {
      _ctrl.value = 0.0;
    }
  }

  @override
  void dispose() {
    widget.routeAnimation.removeListener(_sync);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
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
            TargetPlatform.android: _FadeSlideTransitionsBuilder(),
            TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
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
