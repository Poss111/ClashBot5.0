import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'event_recorder.dart';

class Team {
  final String teamId;
  final String tournamentId;
  final String? displayName;
  final String? captainSummoner;
  final String? captainDisplayName;
  final String? createdBy;
  final String? createdByDisplayName;
  Map<String, String>? members;
  Map<String, String>? memberDisplayNames;
  Map<String, String>? memberStatuses;
  final String? status;
  final String? createdAt;

  Team({
    required this.teamId,
    required this.tournamentId,
    this.displayName,
    this.captainSummoner,
    this.captainDisplayName,
    this.createdBy,
    this.createdByDisplayName,
    this.members,
    this.status,
    this.memberDisplayNames,
    this.memberStatuses,
    this.createdAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        teamId: json['teamId'] as String,
        tournamentId: json['tournamentId'] as String,
        displayName: json['displayName'] as String?,
        captainSummoner: json['captainSummoner'] as String?,
        captainDisplayName: json['captainDisplayName'] as String?,
        createdBy: json['createdBy'] as String?,
        createdByDisplayName: json['createdByDisplayName'] as String?,
        members: (json['members'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
        memberDisplayNames: (json['memberDisplayNames'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
        memberStatuses: (json['memberStatuses'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
        status: json['status'] as String?,
        createdAt: json['createdAt'] as String?,
      );
}

class TeamsService {
  final String baseUrl = ApiConfig.baseUrl;

  Map<String, String> _headers() {
    final token = AuthService.instance.backendToken;
    return {
      'Content-Type': 'application/json',
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

  Future<Team> createTeam(String tournamentId, {required String displayName, required String role}) async {
    final route = 'POST /tournaments/$tournamentId/teams';
    final url = '$baseUrl/tournaments/$tournamentId/teams';
    final payload = {'displayName': displayName, 'role': role};
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: _headers(),
        body: json.encode(payload),
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to create team',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          requestBody: payload,
          responseBody: resp.body,
        );
        throw Exception('Failed to create team: ${resp.statusCode} ${resp.body}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      EventRecorder.record(
        type: 'api.call',
        message: 'Created team',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        requestBody: payload,
        responseBody: resp.body,
      );
      return Team.fromJson(data);
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }

  Future<void> deleteTeam(String tournamentId, String teamId) async {
    final route = 'DELETE /tournaments/$tournamentId/teams/$teamId';
    final url = '$baseUrl/tournaments/$tournamentId/teams/$teamId';
    try {
      final resp = await http.delete(Uri.parse(url), headers: _headers());
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to delete team',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          responseBody: resp.body,
        );
        throw Exception('Failed to delete team: ${resp.statusCode} ${resp.body}');
      }
      EventRecorder.record(
        type: 'api.call',
        message: 'Deleted team',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        responseBody: resp.body,
      );
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }

  Future<void> assignRole(String tournamentId, String teamId, String role, String playerId,
      {String? status}) async {
    final route = 'POST /tournaments/$tournamentId/teams/$teamId/roles/$role';
    final url = '$baseUrl/tournaments/$tournamentId/teams/$teamId/roles/$role';
    final payload = {
      'playerId': playerId,
      if (status != null) 'status': status,
    };
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: _headers(),
        body: json.encode(payload),
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to assign role',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          requestBody: payload,
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
        requestBody: payload,
        responseBody: resp.body,
      );
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }

  Future<void> removeMember(String tournamentId, String teamId, String role) async {
    final route = 'DELETE /tournaments/$tournamentId/teams/$teamId/roles/$role';
    final url = '$baseUrl/tournaments/$tournamentId/teams/$teamId/roles/$role';
    try {
      final resp = await http.delete(Uri.parse(url), headers: _headers());
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to remove role',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          responseBody: resp.body,
        );
        throw Exception('Failed to remove member: ${resp.statusCode} ${resp.body}');
      }
      EventRecorder.record(
        type: 'api.call',
        message: 'Removed member from role',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        responseBody: resp.body,
      );
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: url, statusCode: -1);
      rethrow;
    }
  }

  Future<void> updateMemberStatus(
      String tournamentId, String teamId, String role, String playerId, String status) {
    return assignRole(tournamentId, teamId, role, playerId, status: status);
  }
}

