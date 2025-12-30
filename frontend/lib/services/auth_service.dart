import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_broker_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const _prefsTokenKey = 'auth_backend_token';
  static const _prefsRoleKey = 'auth_backend_role';

  // Web client ID provided by user
  static const String _webClientId =
      '443293502674-6sh7ss1lfkea74rhmctmjghpbraprddn.apps.googleusercontent.com';

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? currentUser;
  String? backendToken;
  String? backendRole;

  GoogleSignIn _client() {
    _googleSignIn ??= GoogleSignIn(
      clientId: kIsWeb ? _webClientId : null,
      scopes: ['email', 'profile'],
    );
    return _googleSignIn!;
  }

  Future<GoogleSignInAccount?> signIn({bool interactive = false}) async {
    // Try restoring an existing backend session first to avoid a Google prompt.
    await _restoreBackendSession();
    final hasBackendSession = backendToken != null;

    final client = _client();

    // Always attempt silent sign-in to refresh profile if possible, but ignore errors.
    try {
      currentUser = await client.signInSilently();
    } catch (_) {
      // ignore; we may still rely on cached backend session
    }

    // If we already have a backend session and we're not in interactive mode, skip prompting.
    if (currentUser == null && !interactive && hasBackendSession) {
      return currentUser;
    }

    // If no user yet, only prompt when interactive is allowed.
    if (currentUser == null && interactive) {
      currentUser = await client.signIn();
    }

    if (currentUser != null) {
      final auth = await currentUser!.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      // Fallback: if neither present, try to get an auth code and treat as access token
      final tokenToUse = idToken ?? accessToken ?? currentUser!.serverAuthCode;
      if (tokenToUse != null) {
        final broker = AuthBrokerService();
        final result = await broker.exchange(idToken: idToken, accessToken: tokenToUse);
        backendToken = result.token;
        backendRole = result.role;
        await _persistBackendSession();
      }
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
  }

  Future<void> _restoreBackendSession() async {
    final prefs = await SharedPreferences.getInstance();
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
  }
}

