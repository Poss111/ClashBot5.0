import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/tournaments_list_screen.dart';
import 'screens/websocket_test_screen.dart';
import 'screens/teams_screen.dart';
import 'services/api_config.dart';
import 'services/auth_service.dart';

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
  String? _userEmail;
  String? _userName;
  String? _userAvatar;
  String? _userRole;
  String? _effectiveRole;
  bool _authLoading = false;
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadUser();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('theme_dark') ?? false;
      });
    }
  }

  Future<void> _loadUser() async {
    setState(() {
      _authLoading = true;
      _authFailed = false;
    });
    try {
      final user = await AuthService.instance.signIn(); // attempt silent sign-in
      if (mounted) {
        setState(() {
          _userEmail = user?.email;
          _userName = user?.displayName;
          _userAvatar = user?.photoUrl;
          _userRole = AuthService.instance.backendRole;
          _effectiveRole = _userRole;
          _authFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _authFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _authLoading = false;
        });
      }
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _authLoading = true;
      _authFailed = false;
    });
    try {
      final user = await AuthService.instance.signIn();
      if (mounted) {
        setState(() {
          _userEmail = user?.email;
          _userName = user?.displayName;
          _userAvatar = user?.photoUrl;
          _userRole = AuthService.instance.backendRole;
          _effectiveRole = _userRole;
          _authFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _authFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _authLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      setState(() {
        _userEmail = null;
        _userName = null;
        _userAvatar = null;
        _userRole = null;
        _effectiveRole = null;
        _authFailed = false;
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

  void _setEffectiveRole(String role) {
    setState(() {
      _effectiveRole = role;
    });
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
            onSignIn: _signIn,
            onSignOut: _signOut,
            userEmail: _userEmail,
            userName: _userName,
            userAvatar: _userAvatar,
            userRole: _userRole,
            effectiveRole: _effectiveRole ?? _userRole,
            onRoleChange: _setEffectiveRole,
            authLoading: _authLoading,
            authFailed: _authFailed,
            isHome: true,
            child: HomeScreen(
              effectiveRole: _effectiveRole ?? _userRole,
              navEnabled: !_authFailed && !_authLoading,
            ),
          ),
        ),
        GoRoute(
          path: '/tournaments',
          builder: (context, state) => _AppScaffold(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
            onSignIn: _signIn,
            onSignOut: _signOut,
            userEmail: _userEmail,
            userName: _userName,
            userAvatar: _userAvatar,
            userRole: _userRole,
            effectiveRole: _effectiveRole ?? _userRole,
            onRoleChange: _setEffectiveRole,
            authLoading: _authLoading,
            authFailed: _authFailed,
            isHome: false,
            child: _authFailed
                ? const _UnauthorizedScreen(message: 'Sign-in required')
                : TournamentsListScreen(userEmail: _userEmail),
          ),
        ),
        GoRoute(
          path: '/websocket-test',
          builder: (context, state) => _AppScaffold(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
            onSignIn: _signIn,
            onSignOut: _signOut,
            userEmail: _userEmail,
            userName: _userName,
            userAvatar: _userAvatar,
            userRole: _userRole,
            effectiveRole: _effectiveRole ?? _userRole,
            onRoleChange: _setEffectiveRole,
            authLoading: _authLoading,
            authFailed: _authFailed,
            isHome: false,
            child: !_authFailed && (_effectiveRole ?? _userRole) == 'ADMIN'
                ? WebSocketTestScreen(userEmail: _userEmail)
                : const _UnauthorizedScreen(message: 'Admins only'),
          ),
        ),
        GoRoute(
          path: '/teams',
          builder: (context, state) => _AppScaffold(
            isDarkMode: _isDarkMode,
            onToggleTheme: _toggleTheme,
            onSignIn: _signIn,
            onSignOut: _signOut,
            userEmail: _userEmail,
            userName: _userName,
            userAvatar: _userAvatar,
            userRole: _userRole,
            effectiveRole: _effectiveRole ?? _userRole,
            onRoleChange: _setEffectiveRole,
            authLoading: _authLoading,
            authFailed: _authFailed,
            isHome: false,
            child: _authFailed
                ? const _UnauthorizedScreen(message: 'Sign-in required')
                : TeamsScreen(userEmail: _userEmail),
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
  final Future<void> Function()? onSignIn;
  final Future<void> Function()? onSignOut;
  final String? userEmail;
  final String? userName;
  final String? userAvatar;
  final String? userRole;
  final String? effectiveRole;
  final ValueChanged<String>? onRoleChange;
  final bool authLoading;
  final bool authFailed;
  final bool isHome;
  final Widget child;

  const _AppScaffold({
    required this.isDarkMode,
    required this.onToggleTheme,
    this.onSignIn,
    this.onSignOut,
    this.userEmail,
    this.userName,
    this.userAvatar,
    this.userRole,
    this.effectiveRole,
    this.onRoleChange,
    required this.authLoading,
    required this.authFailed,
    required this.isHome,
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
            onPressed: authFailed ? null : () => context.go('/tournaments'),
            child: const Text('Tournaments'),
          ),
          TextButton(
            onPressed: authFailed ? null : () => context.go('/teams'),
            child: const Text('Teams'),
          ),
          if (!authFailed && userRole == 'ADMIN')
            TextButton(
              onPressed: () => context.go('/websocket-test'),
              child: const Text('WebSocket Test'),
            ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: onToggleTheme,
            tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
          ),
          if (!authFailed && userRole == 'ADMIN') _buildRoleSwitcher(context),
          const SizedBox(width: 8),
          _buildAuthChip(context),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: authFailed && !isHome
                    ? const _UnauthorizedScreen(message: 'Sign-in required')
                    : child,
              ),
            ],
          ),
          if (authLoading)
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withOpacity(0.3),
            ),
          if (authLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildAuthChip(BuildContext context) {
    final loggedIn = userEmail != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        tooltip: loggedIn ? 'Account' : 'Sign in',
        onSelected: (value) async {
          if (value == 'signin') {
            await onSignIn?.call();
          } else if (value == 'signout') {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Sign out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes, sign out')),
                ],
              ),
            );
            if (confirmed == true) {
              await onSignOut?.call();
            }
          }
        },
        itemBuilder: (ctx) {
          if (!loggedIn) {
            return [
              const PopupMenuItem(
                value: 'signin',
                child: Text('Sign in with Google'),
              )
            ];
          }
          return [
            PopupMenuItem(
              value: 'account',
              enabled: false,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: userAvatar != null ? NetworkImage(userAvatar!) : null,
                    child: userAvatar == null
                        ? Text(
                            (userName?.isNotEmpty ?? false)
                                ? userName!.characters.first
                                : (userEmail?.characters.first ?? '?'),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(userName ?? userEmail ?? 'Signed in', style: Theme.of(context).textTheme.bodySmall),
                        if (userEmail != null)
                          Text(userEmail!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'signout',
              child: Text('Sign out'),
            ),
          ];
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage: userAvatar != null ? NetworkImage(userAvatar!) : null,
              child: userAvatar == null
                  ? Text(
                      (userName?.isNotEmpty ?? false)
                          ? userName!.characters.first
                          : (userEmail?.characters.first ?? '?'),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              loggedIn ? (userName ?? userEmail ?? 'Account') : 'Sign in',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSwitcher(BuildContext context) {
    const roles = ['ADMIN', 'GENERAL_USER'];
    final current = effectiveRole ?? userRole ?? 'GENERAL_USER';
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: current,
        onChanged: (val) {
          if (val != null) {
            onRoleChange?.call(val);
          }
        },
        items: roles
            .map(
              (r) => DropdownMenuItem<String>(
                value: r,
                child: Text(
                  r,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _UnauthorizedScreen extends StatelessWidget {
  final String? message;
  const _UnauthorizedScreen({this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message ?? 'Unauthorized'),
      ),
    );
  }
}

