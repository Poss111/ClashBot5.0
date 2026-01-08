import 'package:clash_companion/services/api_config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_broker_service.dart';
import 'logger.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const _prefsTokenKey = 'auth_backend_token';
  static const _prefsRoleKey = 'auth_backend_role';
  static const _prefsMockKey = 'auth_backend_mock';

  static const String _env = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
  // Google OAuth client ID (web); used as serverClientId on mobile per google_sign_in_android guidance.
  static const Map<String, Map<String, String>> _environmentsToClients = {
    'dev': {
      'web': '443293502674-6sh7ss1lfkea74rhmctmjghpbraprddn.apps.googleusercontent.com',
      'android': '443293502674-tqvldv6fmtt70o5029nhcqs7hfadvf30.apps.googleusercontent.com'
    },
    'prod': {
      'web': '443293502674-6sh7ss1lfkea74rhmctmjghpbraprddn.apps.googleusercontent.com',
      'android': '870493288034-vfuevtj7u6mpgo5ce0ds8jug11rdqsmj.apps.googleusercontent.com'
    },
  };

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? currentUser;
  String? backendToken;
  String? backendRole;

  GoogleSignIn _client() {
    // For Android/iOS, pass the web client ID as serverClientId; web uses the web client ID.
    String clientId = '';
    String serverId = '';
    if (kIsWeb) {
      try {
        clientId = _environmentsToClients[_env]!['web']!;
      } catch (e) {
        logDebug("Error getting web client ID: $e");
        throw Exception('Error getting web client ID for environment $_env: $e');
      }
    } else {
      try {
        serverId = _environmentsToClients[_env]!['android']!;
      } catch (e) {
        logDebug("Error getting android server ID: $e");
        throw Exception('Error getting android server ID for environment $_env: $e');
      }
    }
    logDebug("Client ID: $clientId serverId: $serverId");
    _googleSignIn ??= GoogleSignIn(
      clientId: clientId,
      serverClientId: serverId,
      scopes: ['email', 'profile'],
    );
    return _googleSignIn!;
  }

  Future<GoogleSignInAccount?> signIn({bool interactive = false}) async {
    // If MOCK_AUTH is enabled, skip Google and use injected token/role.
    if (const bool.fromEnvironment('MOCK_AUTH', defaultValue: false)) {
      logDebug("Signing in with mock auth");
      backendToken = const String.fromEnvironment('MOCK_TOKEN', defaultValue: 'mock-jwt-token');
      backendRole = const String.fromEnvironment('MOCK_ROLE', defaultValue: 'GENERAL_USER');
      // We don't fabricate a GoogleSignInAccount; UI will treat backendToken as logged-in.
      currentUser = null;
      await _persistBackendSession();
      return currentUser;
    }
    // Try restoring an existing backend session first to avoid a Google prompt.
    logDebug("Restoring existing backend session");
    await _restoreBackendSession();
    logDebug("Restored existing backend session: $backendToken");
    final hasBackendSession = backendToken != null;
    logDebug("Has backend session: $hasBackendSession");

    final client = _client();

    // Always attempt silent sign-in to refresh profile if possible, but ignore errors.
    try {
      currentUser = await client.signInSilently();
      logDebug("Signed in silently: ${currentUser?.displayName}");
    } catch (e) {
      logDebug("Error signing in silently: $e");
    }

    // If we already have a backend session and we're not in interactive mode, skip prompting.
    if (currentUser == null && !interactive && hasBackendSession) {
      return currentUser;
    }

    // If no user yet, only prompt when interactive is allowed.
    if (currentUser == null && interactive) {
      logDebug("Signing in interactively");
      try {
        currentUser = await client.signIn();
      } catch (e) {
        logDebug("Error signing in interactively: $e");
        rethrow;
      }
      logDebug("Signed in interactively: ${currentUser?.displayName}");
    }

    logDebug("Current user: ${currentUser?.displayName}");
    if (currentUser != null) {
      logDebug("Current user is not null");
      final auth = await currentUser!.authentication;
      logDebug("Authentication: ${auth.idToken}");
      final idToken = auth.idToken;
      logDebug("ID Token: $idToken");
      final accessToken = auth.accessToken;
      logDebug("Access Token: $accessToken");
      // Fallback: if neither present, try to get an auth code and treat as access token
      final tokenToUse = idToken ?? accessToken ?? currentUser!.serverAuthCode;
      logDebug("Trying to exchange token...");
      if (tokenToUse != null) {
        logDebug("We have a token to use");
        final broker = AuthBrokerService();
        logDebug("Exchanging token: $tokenToUse");
        final result = await broker.exchange(idToken: idToken, accessToken: tokenToUse);
        logDebug("Exchange result: $result");
        backendToken = result.token;
        backendRole = result.role;
        logDebug("Backend token: $backendToken");
        logDebug("Backend role: $backendRole");
        await _persistBackendSession();
        logDebug("Persisted backend session");
      }
    } else if (!interactive && backendToken != null) {
      logDebug("Silent sign-in failed and we're relying only on a cached token, clearing it");
      // If silent sign-in failed and we're relying only on a cached token, clear it to avoid showing logged-in state.
      await signOut();
      throw Exception('Silent sign-in failed; cleared cached session');
    }
    return currentUser;
  }

  Future<void> signOut() async {
    final client = _client();
    await client.signOut();
    currentUser = null;
    backendToken = null;
    backendRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsTokenKey);
    await prefs.remove(_prefsRoleKey);
    await prefs.remove(_prefsMockKey);
  }

  Future<void> _restoreBackendSession() async {
    final prefs = await SharedPreferences.getInstance();
    final wasMock = prefs.getBool(_prefsMockKey) ?? false;
    if (wasMock) {
      // Do not restore mock sessions when MOCK_AUTH is off.
      await prefs.remove(_prefsMockKey);
      await prefs.remove(_prefsTokenKey);
      await prefs.remove(_prefsRoleKey);
      backendToken = null;
      backendRole = null;
      return;
    }
    backendToken ??= prefs.getString(_prefsTokenKey);
    backendRole ??= prefs.getString(_prefsRoleKey);
  }

  Future<void> _persistBackendSession() async {
    if (backendToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsTokenKey, backendToken!);
    if (backendRole != null) {
      await prefs.setString(_prefsRoleKey, backendRole!);
    }
    // Mark whether this session was created under mock auth.
    final isMock = const bool.fromEnvironment('MOCK_AUTH', defaultValue: false);
    await prefs.setBool(_prefsMockKey, isMock);
  }

}

