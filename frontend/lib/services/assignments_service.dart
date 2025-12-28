import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AssignmentsService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> start(String tournamentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tournaments/$tournamentId/assign'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'tournamentId': tournamentId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to start assignment: ${response.statusCode}');
    }
  }
}

