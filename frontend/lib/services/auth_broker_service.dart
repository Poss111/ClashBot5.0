import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'event_recorder.dart';

class AuthBrokerResult {
  final String token;
  final String role;
  AuthBrokerResult({required this.token, required this.role});
}

class AuthBrokerService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<AuthBrokerResult> exchange({String? idToken, String? accessToken}) async {
    const route = 'POST /auth/token';
    final url = '$baseUrl/auth/token';
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (idToken != null) 'idToken': idToken,
          if (accessToken != null) 'accessToken': accessToken,
        }),
      );

      if (resp.statusCode != 200) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Auth broker failed',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          requestBody: {
            if (idToken != null) 'idToken': '[redacted]',
            if (accessToken != null) 'accessToken': '[redacted]',
          },
          responseBody: resp.body,
        );
        throw Exception('Auth broker failed: ${resp.statusCode} ${resp.body}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      EventRecorder.record(
        type: 'api.call',
        message: 'Auth broker exchange',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        requestBody: {
          if (idToken != null) 'idToken': '[redacted]',
          if (accessToken != null) 'accessToken': '[redacted]',
        },
        responseBody: resp.body,
      );
      return AuthBrokerResult(
        token: data['token'] as String,
        role: data['role'] as String? ?? 'GENERAL_USER',
      );
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }
}

