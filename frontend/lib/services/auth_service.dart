import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_broker_service.dart';
import 'event_recorder.dart';
import 'logger.dart';

class SignInFailure implements Exception {
  final String stage; // e.g., google_sign_in, google_tokens, backend_exchange
  final String message;
  final Object? cause;

  SignInFailure({required this.stage, required this.message, this.cause});

  @override
  String toString() {
    final suffix = cause != null ? ' ($cause)' : '';
    return 'SignInFailure($stage): $message$suffix';
  }
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const _prefsTokenKey = 'auth_backend_token';
  static const _prefsRoleKey = 'auth_backend_role';
  static const _prefsMockKey = 'auth_backend_mock';

  static const String _env = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
  // Google OAuth client ID (web); used as serverClientId on mobile per google_sign_in_android guidance.
  static const String webClientId = "870493288034-645v0rnvn0djspbue6fi3oovbosa1hht.apps.googleusercontent.com";

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? currentUser;
  String? backendToken;
  String? backendRole;
  String? _lastExchangedIdToken;
  bool _googleInitialized = false;
  bool _signInInProgress = false;
  bool _exchangeInProgress = false;
  Future<GoogleSignInAccount?>? _ongoingSignIn;

  Future<GoogleSignIn> _client() async {
    // For Android/iOS, pass the web client ID as serverClientId; web uses the web client ID.
    if (!_googleInitialized) {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb ? webClientId : null,
        serverClientId: kIsWeb ? null : webClientId,
      );
      _googleInitialized = true;
    }
    _googleSignIn ??= GoogleSignIn.instance;
    return _googleSignIn!;
  }

  Future<GoogleSignInAccount?> signIn({bool interactive = false}) {
    // Prevent overlapping sign-in flows; reuse the in-flight one.
    if (_signInInProgress && _ongoingSignIn != null) {
      logDebug("Sign-in already in progress; reusing ongoing future");
      return _ongoingSignIn!;
    }
    _signInInProgress = true;
    _ongoingSignIn = _signInInternal(interactive: interactive).whenComplete(() {
      _signInInProgress = false;
      _ongoingSignIn = null;
    });
    return _ongoingSignIn!;
  }

  Future<GoogleSignInAccount?> _signInInternal({required bool interactive}) async {
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

    final client = await _client();
    final scopes = ['email', 'profile', 'openid'];

    // Always attempt silent sign-in to refresh profile if possible, but ignore errors.
    try {
      final maybeFuture = client.attemptLightweightAuthentication(reportAllExceptions: true);
      if (maybeFuture != null) {
        currentUser = await maybeFuture;
        logDebug("Signed in silently: ${currentUser?.displayName}");
      } else {
        logDebug("Silent sign-in returned no future (platform-managed flow)");
      }
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
        currentUser = await client.authenticate(scopeHint: scopes);
      } catch (e) {
        logDebug("Error signing in interactively: $e");
        EventRecorder.record(
          type: 'auth.error',
          message: 'Google interactive sign-in failed',
          data: {
            'stage': 'google_sign_in',
            'interactive': interactive,
            'error': e.toString()
          },
        );
        throw SignInFailure(stage: 'google_sign_in', message: 'Google sign-in failed', cause: e);
      }
      logDebug("Signed in interactively: ${currentUser?.displayName}");
    }

    logDebug("Current user: ${currentUser?.displayName}");
    if (currentUser != null) {
      logDebug("Current user is not null");
      final auth = currentUser!.authentication;
      logDebug("Authentication: ${auth.idToken}");
      final idToken = auth.idToken;
      logDebug("ID Token: $idToken");
      final tokenToUse = idToken;
      logDebug("Trying to exchange token...");
      final alreadyExchanged = tokenToUse != null && _lastExchangedIdToken == tokenToUse && backendToken != null;
      if (alreadyExchanged) {
        logDebug("Skipping backend exchange; token already exchanged");
        return currentUser;
      }
      if (tokenToUse != null) {
        logDebug("We have a token to use");
        final broker = AuthBrokerService();
        logDebug("Exchanging token: $tokenToUse");
        if (_exchangeInProgress) {
          logDebug("Exchange already in progress; skipping duplicate");
          return currentUser;
        }
        _exchangeInProgress = true;
        try {
          final result = await broker.exchange(idToken: idToken, accessToken: tokenToUse);
          logDebug("Exchange result: $result");
          backendToken = result.token;
          backendRole = result.role;
          _lastExchangedIdToken = tokenToUse;
          logDebug("Backend token: $backendToken");
          logDebug("Backend role: $backendRole");
          await _persistBackendSession();
          logDebug("Persisted backend session");
        } catch (e) {
          EventRecorder.record(
            type: 'auth.error',
            message: 'Backend token exchange failed',
            data: {
              'stage': 'backend_exchange',
              'interactive': interactive,
              'hasIdToken': idToken != null,
              'googleUserEmail': currentUser?.email,
              'error': e.toString()
            },
          );
          throw SignInFailure(
            stage: 'backend_exchange',
            message: 'Signed in with Google but backend token exchange failed',
            cause: e,
          );
        } finally {
          _exchangeInProgress = false;
        }
      } else {
        EventRecorder.record(
          type: 'auth.error',
          message: 'Google sign-in returned no token',
          data: {
            'stage': 'google_tokens',
            'interactive': interactive,
            'hasIdToken': idToken != null,
            'googleUserEmail': currentUser?.email,
          },
        );
        throw SignInFailure(
          stage: 'google_tokens',
          message: 'Google sign-in succeeded but returned no token',
        );
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
    final client = await _client();
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

