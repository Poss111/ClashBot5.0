import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/tournaments_list_screen.dart';
import 'screens/websocket_test_screen.dart';
import 'services/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClashBotApp());
}

class ClashBotApp extends StatefulWidget {
  const ClashBotApp({super.key});

  @override
  State<ClashBotApp> createState() => _ClashBotAppState();
}

class _ClashBotAppState extends State<ClashBotApp> {
  bool _isDarkMode = false;
  final _routerKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('theme_dark') ?? false;
      });
    }
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('theme_dark', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      navigatorKey: _routerKey,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => _AppScaffold(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/tournaments',
          builder: (context, state) => _AppScaffold(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
            child: const TournamentsListScreen(),
          ),
        ),
        GoRoute(
          path: '/websocket-test',
          builder: (context, state) => _AppScaffold(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
            child: const WebSocketTestScreen(),
          ),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'ClashBot',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        cardColor: const Color(0xFF111827),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}

class _AppScaffold extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Widget child;

  const _AppScaffold({
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ClashBot'),
        actions: [
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Home'),
          ),
          TextButton(
            onPressed: () => context.go('/tournaments'),
            child: const Text('Tournaments'),
          ),
          TextButton(
            onPressed: () => context.go('/websocket-test'),
            child: const Text('WebSocket Test'),
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: onToggleTheme,
            tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: child,
          ),
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              'API: ${ApiConfig.baseUrl}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

