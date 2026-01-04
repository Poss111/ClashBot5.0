import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'event_recorder.dart';
import '../models/user_profile.dart';

class UserService {
  final String baseUrl = ApiConfig.baseUrl;

  Map<String, String> _headers() {
    final token = AuthService.instance.backendToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<UserProfile> getCurrentUser() async {
    const route = 'GET /users/me';
    final url = '$baseUrl/users/me';
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers());
      if (resp.statusCode != 200) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to load profile',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          responseBody: resp.body,
        );
        throw Exception('Failed to load profile: ${resp.statusCode}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      EventRecorder.record(
        type: 'api.call',
        message: 'Loaded profile',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        responseBody: resp.body,
      );
      return UserProfile.fromJson(data);
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }

  Future<UserProfile> setDisplayName(String displayName) async {
    const route = 'PUT /users/me/display-name';
    final url = '$baseUrl/users/me/display-name';
    final payload = {'displayName': displayName};
    try {
      final resp = await http.put(Uri.parse(url), headers: _headers(), body: json.encode(payload));
      if (resp.statusCode != 200) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to set display name',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          requestBody: payload,
          responseBody: resp.body,
        );
        throw Exception('Failed to set display name: ${resp.statusCode}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      EventRecorder.record(
        type: 'api.call',
        message: 'Updated display name',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        requestBody: payload,
        responseBody: resp.body,
      );
      return UserProfile.fromJson(data);
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }
}


