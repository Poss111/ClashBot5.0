import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_broker_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

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

  Future<GoogleSignInAccount?> signIn() async {
    final client = _client();
    currentUser = await client.signInSilently();
    currentUser ??= await client.signIn();
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
  }
}

