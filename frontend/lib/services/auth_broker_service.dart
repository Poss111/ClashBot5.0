import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AuthBrokerResult {
  final String token;
  final String role;
  AuthBrokerResult({required this.token, required this.role});
}

class AuthBrokerService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<AuthBrokerResult> exchange({String? idToken, String? accessToken}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/auth/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Auth broker failed: ${resp.statusCode}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return AuthBrokerResult(
      token: data['token'] as String,
      role: data['role'] as String? ?? 'GENERAL_USER',
    );
  }
}

