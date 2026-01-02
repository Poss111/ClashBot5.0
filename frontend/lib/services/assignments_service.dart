import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'event_recorder.dart';

class AssignmentsService {
  final String baseUrl = ApiConfig.baseUrl;
  Map<String, String> _headers() {
    final token = AuthService.instance.backendToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> start(String tournamentId) async {
    final route = 'POST /tournaments/$tournamentId/assign';
    final url = '$baseUrl/tournaments/$tournamentId/assign';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(),
        body: json.encode({'tournamentId': tournamentId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        EventRecorder.record(
          type: 'api.call',
          message: 'Started assignment workflow',
          statusCode: response.statusCode,
          endpoint: route,
        url: url,
          requestBody: {'tournamentId': tournamentId},
          responseBody: response.body,
        );
        return body;
      }
      EventRecorder.record(
        type: 'api.error',
        message: 'Failed to start assignment',
        statusCode: response.statusCode,
        endpoint: route,
        url: url,
        requestBody: {'tournamentId': tournamentId},
        responseBody: response.body,
      );
      throw Exception('Failed to start assignment: ${response.statusCode}');
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }
}

