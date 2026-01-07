import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';
import 'event_recorder.dart';
import '../models/draft.dart';

class DraftsService {
  final String baseUrl = ApiConfig.baseUrl;

  Map<String, String> _headers() {
    final token = AuthService.instance.backendToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<DraftProposal?> fetchDraft(String tournamentId, String teamId) async {
    final route = 'GET /tournaments/$tournamentId/teams/$teamId/draft';
    final url = '$baseUrl/tournaments/$tournamentId/teams/$teamId/draft';
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers());
      if (resp.statusCode == 404) {
        return null;
      }
      if (resp.statusCode != 200) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to load draft',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          responseBody: resp.body,
        );
        throw Exception('Failed to load draft: ${resp.statusCode}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      EventRecorder.record(
        type: 'api.call',
        message: 'Loaded draft',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        responseBody: resp.body,
      );
      return DraftProposal.fromJson(data);
    } catch (e) {
      EventRecorder.record(
        type: 'api.error',
        message: e.toString(),
        endpoint: route,
        url: url,
        statusCode: -1,
      );
      rethrow;
    }
  }

  Future<DraftProposal> saveDraft(DraftProposal draft) async {
    final tournamentId = draft.tournamentId;
    final teamId = draft.teamId;
    final route = 'PUT /tournaments/$tournamentId/teams/$teamId/draft';
    final url = '$baseUrl/tournaments/$tournamentId/teams/$teamId/draft';
    final payload = draft.toJson();
    try {
      final resp = await http.put(
        Uri.parse(url),
        headers: _headers(),
        body: json.encode(payload),
      );
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to save draft',
          statusCode: resp.statusCode,
          endpoint: route,
          url: url,
          requestBody: payload,
          responseBody: resp.body,
        );
        throw Exception('Failed to save draft: ${resp.statusCode} ${resp.body}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      EventRecorder.record(
        type: 'api.call',
        message: 'Saved draft',
        statusCode: resp.statusCode,
        endpoint: route,
        url: url,
        requestBody: payload,
        responseBody: resp.body,
      );
      return DraftProposal.fromJson(data);
    } catch (e) {
      EventRecorder.record(
        type: 'api.error',
        message: e.toString(),
        endpoint: route,
        url: url,
        statusCode: -1,
      );
      rethrow;
    }
  }
}

