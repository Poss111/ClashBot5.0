import 'dart:convert';
import 'package:clash_companion/services/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/home_screen.dart';
import 'screens/tournaments_list_screen.dart';
import 'screens/teams_screen.dart';
import 'screens/admin_screen.dart';
import 'services/auth_service.dart';
import 'services/websocket_config.dart';
import 'services/event_recorder.dart';
import 'services/tournaments_service.dart';
import 'theme.dart';
import 'models/notification_item.dart';
import 'models/notification_presentation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

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
  final _notifications = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _eventsChannel = AndroidNotificationChannel(
    'clash_events',
    'Clash Companion Events',
    description: 'Notifications for tournament events',
    importance: Importance.high,
  );
  static const _prefsDisclaimerSeen = 'disclaimer_seen';
  String? _userEmail;
  String? _userName;
  String? _userAvatar;
  String? _userRole;
  String? _effectiveRole;
  String? _appVersion;
  bool _authLoading = false;
  bool _authFailed = false;
  WebSocketChannel? _wsChannel;
  final List<AppNotification> _events = [];
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
            appVersion: _appVersion,
            onShowEvents: () => _showEvents(context),
            child: HomeScreen(
              effectiveRole: _effectiveRole ?? _userRole,
            navEnabled: true,
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
            appVersion: _appVersion,
            onShowEvents: () => _showEvents(context),
          allowUnauthed: true,
          child: TournamentsListScreen(userEmail: _userEmail),
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
            appVersion: _appVersion,
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
            appVersion: _appVersion,
            onShowEvents: () => _showEvents(context),
            child: !_authFailed && (_effectiveRole ?? _userRole) == 'ADMIN'
                ? AdminScreen(userEmail: _userEmail)
                : const _UnauthorizedScreen(message: 'Admins only'),
          ),
        ),
      ],
    );
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUser();
      _maybeShowDisclaimer();
      // Warm tournaments cache on app start.
      TournamentsService().refreshCache();
    });
    _initNotifications();
    EventRecorder.register(_pushEvent);
    _loadVersion();
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
      final token = AuthService.instance.backendToken;
      if (mounted) {
        setState(() {
          _userEmail = token != null ? user?.email : null;
          _userName = token != null ? user?.displayName : null;
          _userAvatar = token != null ? user?.photoUrl : null;
          _userRole = token != null ? AuthService.instance.backendRole : null;
          _effectiveRole = _userRole;
          _authFailed = token == null;
        });
        if (token != null) {
          _ensureWebSocket();
        } else {
          _disposeWebSocket();
        }
      }
    } catch (e) {
      logDebug("Error signing in: $e");
      await _showAuthError(context, 'Failed to sign in with Google. Please try again.');
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

  Future<void> _maybeShowDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsDisclaimerSeen) ?? false;
    if (seen || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Unofficial App'),
        content: const Text(
          'This app is an independent companion and is not affiliated with, endorsed by, '
          'or in any way associated with Riot Games or League of Legends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
    await prefs.setBool(_prefsDisclaimerSeen, true);
  }

  Future<void> _signIn() async {
    setState(() {
      _authLoading = true;
      _authFailed = false;
    });
    try {
      final user = await AuthService.instance.signIn(interactive: true); // allow prompt on manual sign-in
      final token = AuthService.instance.backendToken;
      if (mounted) {
        setState(() {
          _userEmail = token != null ? user?.email : null;
          _userName = token != null ? user?.displayName : null;
          _userAvatar = token != null ? user?.photoUrl : null;
          _userRole = token != null ? AuthService.instance.backendRole : null;
          _effectiveRole = _userRole;
          _authFailed = token == null;
        });
        if (token != null) {
          _ensureWebSocket();
        } else {
          _disposeWebSocket();
        }
        if (token == null) {
          // Sign-in attempt completed but we didn't get a token.
          await _showAuthError(context, 'Failed to sign in with Google. Please try again.');
        }
      }
    } catch (e) {
      logDebug("Error signing in: $e");
      await _showAuthError(context, 'Failed to sign in with Google. Please try again.');
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

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.buildNumber.isNotEmpty ? '${info.version}+${info.buildNumber}' : info.version;
      if (mounted) {
        setState(() {
          _appVersion = version;
        });
      }
    } catch (_) {
      // best-effort only
    }
  }

  void _ensureWebSocket() {
    if (_wsChannel != null) return;
    Uri uri = Uri.parse(WebSocketConfig.baseUrl);
    try {
      final token = AuthService.instance.backendToken;
      Map<String, dynamic>? headers;
      if (token != null) {
        if (kIsWeb) {
          final params = Map<String, String>.from(uri.queryParameters);
          params['auth'] = token;
          uri = uri.replace(queryParameters: params);
        } else {
          headers = {'authorization': 'Bearer $token'};
        }
      }
      if (!kIsWeb && headers != null) {
        _wsChannel = IOWebSocketChannel.connect(uri, headers: headers);
      } else {
        _wsChannel = WebSocketChannel.connect(uri);
      }
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
        } catch (e) {
          EventRecorder.record(type: 'ws.error', message: e.toString(), endpoint: 'GET /events', url: uri.toString(), statusCode: -1);
        }
        final item = AppNotification.fromMap(parsed);
        _pushEvent(parsed);
        final type = item.type.toLowerCase();
        if (type.contains('tournament')) {
          // Refresh tournament cache when a new tournament event arrives.
          TournamentsService().refreshCache();
        }
        _maybeNotifyTournament(item);
      }, onError: (_) {
        _disposeWebSocket();
      }, onDone: () {
        _disposeWebSocket();
      });
    } catch (e) {
      logDebug("Error connecting to web socket: $e, uri: $uri");
      EventRecorder.record(type: 'ws.error', message: e.toString(), endpoint: 'GET /events', url: uri.toString(), statusCode: -1);
      _disposeWebSocket();
    }
  }

  void _disposeWebSocket() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);
    final androidImpl =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      try {
        logDebug("Requesting notifications permission");
        final granted = await androidImpl.requestNotificationsPermission();
        logDebug("Notifications permission granted: $granted");
        if (granted ?? false) {
          await androidImpl.createNotificationChannel(_eventsChannel);
        }
      } catch (_) {
        // Older plugin versions may not support permission API; still attempt channel creation.
        await androidImpl.createNotificationChannel(_eventsChannel);
      }
    }
  }

  Future<void> _maybeNotifyTournament(AppNotification ev) async {
    if (kIsWeb) return;
    final type = ev.type?.toString().toLowerCase() ?? '';
    if (type != 'tournament.registered') return;
    final parsedName = ev.data?['nameKeySecondary'];
    final startTime = ev.data?['startTime'];
    final registrationTime = ev.data?['registrationTime'];
    var formattedStartTime = '';
    if (startTime != null || startTime.isNotEmpty) {
      try {
        formattedStartTime = AppDateFormats.formatLong(DateTime.parse(startTime).toLocal());
      } catch (e) {
        logDebug("Error parsing startTime: $e");
      }
    }
    var formattedRegistrationTime = '';
    if (registrationTime != null || registrationTime.isNotEmpty) {
      try {
        formattedRegistrationTime = AppDateFormats.formatLong(DateTime.parse(registrationTime).toLocal());
      } catch (e) {
        logDebug("Error parsing registrationTime: $e");
      }
    }
    final body = """
    $parsedName has been registered and will start on $formattedStartTime.
    Registration is open starting on $formattedRegistrationTime.

    Let's go Clashers!
    """;
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New Tournament Available!',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _eventsChannel.id,
          _eventsChannel.name,
          channelDescription: _eventsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _showAuthError(BuildContext context, String message) async {
    if (!mounted) return;
    final dialogContext = _routerKey.currentContext ?? context;
    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Sign-in Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _pushEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    // Only keep api.* events in debug builds; always keep other events (e.g., websocket).
    final type = event['type']?.toString() ?? '';
    if (!kDebugMode && type.startsWith('api.')) {
      return;
    }
    final item = AppNotification.fromMap(event);
    setState(() {
      _events.insert(0, item);
      if (_events.length > 100) {
        _events.removeRange(100, _events.length);
      }
      _unreadEvents += 1;
    });
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
        return Card(
          margin: const EdgeInsets.all(12),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _events.length,
            itemBuilder: (_, i) {
              final ev = _events[i];
              final presentation = NotificationPresenter.build(ev);
              final ts = ev.timestampLabel;
              final data = ev.data;
              return _NotificationCard(
                presentation: presentation,
                timestampLabel: ts,
                data: data,
                raw: ev.raw,
                onDismiss: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _events.removeAt(i);
                  });
                  // Reopen to reflect removal
                  WidgetsBinding.instance.addPostFrameCallback((_) => _showEvents(context));
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Clash Companion',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
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
  final bool allowUnauthed;
  final List<AppNotification> events;
  final int unreadEvents;
  final VoidCallback? onShowEvents;
  final String? appVersion;
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
    this.allowUnauthed = false,
    required this.events,
    required this.unreadEvents,
    this.onShowEvents,
    this.appVersion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = _isMobile(context);
    final showInlineRoleSwitcher = !authFailed && userRole == 'ADMIN' && !isMobile;
    final tournamentsEnabled = true;
    final teamsEnabled = !authFailed;
    return Scaffold(
      drawer: isMobile
          ? Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'Clash Companion',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  _buildNavTile(context, label: 'Home', route: '/', enabled: true),
                  _buildNavTile(
                    context,
                    label: 'Tournaments',
                    route: '/tournaments',
                    enabled: tournamentsEnabled,
                  ),
                  _buildNavTile(
                    context,
                    label: 'Teams',
                    route: '/teams',
                    enabled: teamsEnabled,
                  ),
                  if ((effectiveRole ?? userRole) == 'ADMIN')
                    _buildNavTile(context, label: 'Admin', route: '/admin', enabled: teamsEnabled),
                ],
              ),
            )
          : null,
      appBar: AppBar(
        title: const Text('Clash Companion'),
        leading: isMobile
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  tooltip: 'Menu',
                ),
              )
            : null,
        actions: [
          if (!isMobile)
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Home'),
            ),
          if (!isMobile)
            TextButton(
              onPressed: () => context.go('/tournaments'),
              child: const Text('Tournaments'),
            ),
          if (!isMobile)
            TextButton(
              onPressed: teamsEnabled ? () => context.go('/teams') : null,
              child: const Text('Teams'),
            ),
          _buildEventsIcon(context),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: onToggleTheme,
            tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
          ),
          if (showInlineRoleSwitcher) _buildRoleSwitcher(context),
          const SizedBox(width: 8),
          _buildAuthChip(context),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: authFailed && !isHome && !allowUnauthed
                    ? const _UnauthorizedScreen(message: 'Sign-in required')
                    : child,
              ),
            ],
          ),
          if (authLoading) ...[
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withOpacity(0.35),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.key, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Retrieving login token...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            'Clash Companion is an independent app and is not affiliated with, endorsed by, '
            'or associated with Riot Games or League of Legends.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthChip(BuildContext context) {
    final loggedIn = (userEmail ?? '').isNotEmpty || AuthService.instance.backendToken != null;
    final isMobile = _isMobile(context);
    final canSwitchRoles = userRole == 'ADMIN';
    final versionText = 'Version: ${appVersion ?? 'unknown'}';
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
              ),
              PopupMenuItem<String>(
                value: 'version',
                enabled: false,
                child: Text(versionText),
              ),
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
            if (canSwitchRoles && isMobile)
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Role', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    _buildRoleSwitcher(context),
                  ],
                ),
              ),
            if ((effectiveRole ?? userRole) == 'ADMIN')
              const PopupMenuItem(
                value: 'admin',
                child: Text('Admin'),
              ),
            const PopupMenuItem(
              value: 'home',
              child: Text('Home'),
            ),
            PopupMenuItem<String>(
              value: 'version',
              enabled: false,
              child: Text(versionText),
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
            if (!isMobile) ...[
              const SizedBox(width: 6),
              Text(
                loggedIn ? (userName ?? userEmail ?? 'Account') : 'Sign in',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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

  Widget _buildNavTile(BuildContext context,
      {required String label, required String route, required bool enabled}) {
    return ListTile(
      title: Text(label),
      enabled: enabled,
      onTap: enabled
          ? () {
              Navigator.of(context).pop(); // close drawer
              context.go(route);
            }
          : null,
      trailing: const Icon(Icons.chevron_right),
    );
  }

  bool _isMobile(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
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

class _NotificationCard extends StatelessWidget {
  final NotificationDisplay presentation;
  final String timestampLabel;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? raw;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.presentation,
    required this.timestampLabel,
    required this.onDismiss,
    this.data,
    this.raw,
  });

  @override
  Widget build(BuildContext context) {
    final title = presentation.title;
    final subtitle = presentation.subtitle;
    final causedBy = presentation.causedBy;
    final timestamp = presentation.timestamp;
    final isError = presentation.severity == NotificationSeverity.error;
    final isWarning = presentation.severity == NotificationSeverity.warning;
    final isSuccess = presentation.severity == NotificationSeverity.success;
    final isInfo = presentation.severity == NotificationSeverity.info;
    final bgColor = isError
        ? Colors.red
        : isWarning
            ? Colors.orange
            : isSuccess
                ? Colors.green
                : isInfo
                    ? Colors.blue
                    : null;
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
                if (bgColor != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                )
              ],
            ),
            if (causedBy != null || timestamp != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (causedBy != null)
                      Text(
                        'From $causedBy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                            ),
                      ),
                    if (timestamp != null)
                      Text(
                        timestamp,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                            ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            if (subtitle != null && subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ),
            ...presentation.details.map(
              (line) => Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(line, style: Theme.of(context).textTheme.bodySmall),
              ),
            )
          ],
        ),
      ),
    );
  }
}

