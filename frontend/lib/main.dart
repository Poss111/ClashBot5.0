import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/tournaments_list_screen.dart';
import 'screens/teams_screen.dart';
import 'screens/admin_screen.dart';
import 'services/auth_service.dart';
import 'services/websocket_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClashCompanionApp());
}

class ClashCompanionApp extends StatefulWidget {
  const ClashCompanionApp({super.key});

  @override
  State<ClashCompanionApp> createState() => _ClashCompanionAppState();
}

class _ClashCompanionAppState extends State<ClashCompanionApp> {
  bool _isDarkMode = false;
  final _routerKey = GlobalKey<NavigatorState>();
  late final GoRouter _router;
  String? _userEmail;
  String? _userName;
  String? _userAvatar;
  String? _userRole;
  String? _effectiveRole;
  bool _authLoading = false;
  bool _authFailed = false;
  WebSocketChannel? _wsChannel;
  final List<Map<String, dynamic>> _events = [];
  int _unreadEvents = 0;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
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
            events: _events,
            unreadEvents: _unreadEvents,
            onShowEvents: () => _showEvents(context),
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
            events: _events,
            unreadEvents: _unreadEvents,
            onShowEvents: () => _showEvents(context),
            child: _authFailed
                ? const _UnauthorizedScreen(message: 'Sign-in required')
                : TournamentsListScreen(userEmail: _userEmail),
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
            events: _events,
            unreadEvents: _unreadEvents,
            onShowEvents: () => _showEvents(context),
            child: _authFailed
                ? const _UnauthorizedScreen(message: 'Sign-in required')
                : TeamsScreen(userEmail: _userEmail),
          ),
        ),
        GoRoute(
          path: '/admin',
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
            events: _events,
            unreadEvents: _unreadEvents,
            onShowEvents: () => _showEvents(context),
            child: !_authFailed && (_effectiveRole ?? _userRole) == 'ADMIN'
                ? AdminScreen(userEmail: _userEmail)
                : const _UnauthorizedScreen(message: 'Admins only'),
          ),
        ),
      ],
    );
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
      final user = await AuthService.instance.signIn(); // attempt silent sign-in only
      if (mounted) {
        setState(() {
          _userEmail = user?.email;
          _userName = user?.displayName;
          _userAvatar = user?.photoUrl;
          _userRole = AuthService.instance.backendRole;
          _effectiveRole = _userRole;
          _authFailed = false;
        });
        _ensureWebSocket();
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
      final user = await AuthService.instance.signIn(interactive: true); // allow prompt on manual sign-in
      if (mounted) {
        setState(() {
          _userEmail = user?.email;
          _userName = user?.displayName;
          _userAvatar = user?.photoUrl;
          _userRole = AuthService.instance.backendRole;
          _effectiveRole = _userRole;
          _authFailed = false;
        });
        _ensureWebSocket();
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
        _events.clear();
        _unreadEvents = 0;
      });
      _disposeWebSocket();
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

  void _ensureWebSocket() {
    if (_wsChannel != null) return;
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(WebSocketConfig.baseUrl));
      _wsChannel!.stream.listen((event) {
        if (!mounted) return;
        Map<String, dynamic> parsed = {
          'raw': event.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        };
        try {
          final obj = json.decode(event.toString());
          if (obj is Map<String, dynamic>) {
            parsed.addAll(obj);
          }
        } catch (_) {
          // keep raw
        }
        setState(() {
          _events.insert(0, parsed);
          if (_events.length > 100) {
            _events.removeRange(100, _events.length);
          }
          _unreadEvents += 1;
        });
      }, onError: (_) {
        _disposeWebSocket();
      }, onDone: () {
        _disposeWebSocket();
      });
    } catch (_) {
      _disposeWebSocket();
    }
  }

  void _disposeWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void _showEvents(BuildContext context) {
    setState(() {
      _unreadEvents = 0;
    });
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (_events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No events yet.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _events.length,
          itemBuilder: (_, i) {
            final ev = _events[i];
            final title = (ev['type'] ?? 'event').toString();
            final causedBy = ev['causedBy']?.toString();
            final tournamentId = ev['tournamentId']?.toString();
            final ts = ev['timestamp']?.toString();
            final data = ev['data'];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Dismiss',
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _events.removeAt(i);
                            });
                            // Reopen to reflect removal
                            WidgetsBinding.instance.addPostFrameCallback((_) => _showEvents(context));
                          },
                        )
                      ],
                    ),
                    if (tournamentId != null) Text('Tournament: $tournamentId'),
                    if (causedBy != null) Text('Caused by: $causedBy'),
                    if (ts != null) Text('Time: $ts'),
                    if (data != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          const JsonEncoder.withIndent('  ').convert(data),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    if (data == null && ev['raw'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          ev['raw'].toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                        ),
                      )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clash Companion',
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
      routerConfig: _router,
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
  final List<Map<String, dynamic>> events;
  final int unreadEvents;
  final VoidCallback? onShowEvents;
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
    required this.events,
    required this.unreadEvents,
    this.onShowEvents,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clash Companion'),
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
          _buildEventsIcon(context),
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
    final loggedIn = (userEmail ?? '').isNotEmpty || AuthService.instance.backendToken != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        tooltip: loggedIn ? 'Account' : 'Sign in',
        onSelected: (value) async {
          if (value == 'signin') {
            await onSignIn?.call();
          } else if (value == 'admin') {
            context.go('/admin');
          } else if (value == 'home') {
            context.go('/');
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
                    backgroundImage: userAvatar != null ? CachedNetworkImageProvider(userAvatar!) : null,
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
            if ((effectiveRole ?? userRole) == 'ADMIN')
              const PopupMenuItem(
                value: 'admin',
                child: Text('Admin'),
              ),
            const PopupMenuItem(
              value: 'home',
              child: Text('Home'),
            ),
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
              backgroundImage: userAvatar != null ? CachedNetworkImageProvider(userAvatar!) : null,
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

  Widget _buildEventsIcon(BuildContext context) {
    final count = unreadEvents;
    return IconButton(
      tooltip: 'Events',
      onPressed: onShowEvents,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            )
        ],
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

