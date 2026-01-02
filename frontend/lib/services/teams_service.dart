import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'event_recorder.dart';

class Team {
  final String teamId;
  final String tournamentId;
  final String? captainSummoner;
  final Map<String, dynamic>? members;
  final String? status;

  Team({
    required this.teamId,
    required this.tournamentId,
    this.captainSummoner,
    this.members,
    this.status,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        teamId: json['teamId'] as String,
        tournamentId: json['tournamentId'] as String,
        captainSummoner: json['captainSummoner'] as String?,
        members: json['members'] as Map<String, dynamic>?,
        status: json['status'] as String?,
      );
}

class TeamsService {
  final String baseUrl = ApiConfig.baseUrl;

  Map<String, String> _headers() {
    final token = AuthService.instance.backendToken;
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Team>> list(String tournamentId) async {
    final route = 'GET /tournaments/$tournamentId/teams';
    final url = '$baseUrl/tournaments/$tournamentId/teams';
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers());
      if (resp.statusCode != 200) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to load teams',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          responseBody: resp.body,
        );
        throw Exception('Failed to load teams: ${resp.statusCode}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Team.fromJson(e as Map<String, dynamic>))
          .toList();
      EventRecorder.record(
        type: 'api.call',
        message: 'Loaded teams',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        responseBody: resp.body,
      );
      return items;
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }

  Future<void> assignRole(String tournamentId, String teamId, String role, String playerId) async {
    final route = 'POST /tournaments/$tournamentId/teams/$teamId/roles/$role';
    final url = '$baseUrl/tournaments/$tournamentId/teams/$teamId/roles/$role';
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: _headers(),
        body: json.encode({'playerId': playerId}),
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to assign role',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          requestBody: {'playerId': playerId},
          responseBody: resp.body,
        );
        throw Exception('Failed to assign role: ${resp.statusCode} ${resp.body}');
      }
      EventRecorder.record(
        type: 'api.call',
        message: 'Assigned role',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        requestBody: {'playerId': playerId},
        responseBody: resp.body,
      );
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }
}

