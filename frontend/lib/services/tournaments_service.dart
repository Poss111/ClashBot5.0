import 'dart:convert';
import 'dart:io';
import 'package:clash_companion/services/auth_service.dart';
import 'package:clash_companion/services/logger.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tournament.dart';
import 'api_config.dart';
import 'event_recorder.dart';

class TournamentsService {
  final String baseUrl = ApiConfig.baseUrl;
  static const _cacheKey = 'tournaments_cache';
  static const _cacheExpKey = 'tournaments_cache_exp';
  static const _cacheTtlSeconds = 300; // 5 minutes

  Map<String, String> _headers() {
    final token = AuthService.instance.backendToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Tournament>> list({bool forceRefresh = false}) async {
    final endpoint = '$baseUrl/tournaments';
    logDebug("Endpoint to hit: $endpoint");
    final prefs = await SharedPreferences.getInstance();
    // serve from cache if valid and not forcing refresh
    if (!forceRefresh) {
      final cached = _readCache(prefs);
      if (cached != null) {
        // fire-and-forget refresh to keep cache warm
        _fetchAndCache(endpoint, prefs).catchError((_) => <Tournament>[]);
        return cached;
      }
    }
    final fetched = await _fetchAndCache(endpoint, prefs);
    return fetched;
  }

  Future<Tournament> get(String id) async {
    final endpoint = '$baseUrl/tournaments/$id';
    try {
      final response = await http.get(Uri.parse(endpoint), headers: _headers());
      if (response.statusCode == 200) {
        EventRecorder.record(
          type: 'api.call',
          message: 'Loaded tournament $id',
          statusCode: response.statusCode,
          endpoint: 'GET /tournaments/$id',
          url: endpoint,
          responseBody: response.body,
        );
        return Tournament.fromJson(json.decode(response.body) as Map<String, dynamic>);
      }
      EventRecorder.record(
        type: 'api.error',
        message: 'Failed to load tournament',
        statusCode: response.statusCode,
        endpoint: 'GET /tournaments/$id',
        url: endpoint,
        responseBody: response.body,
      );
      throw Exception('Failed to load tournament: ${response.statusCode}');
    } catch (e) {
      EventRecorder.record(
        type: 'api.error',
        message: e.toString(),
        endpoint: 'GET /tournaments/$id',
        url: endpoint,
        statusCode: -1,
      );
      rethrow;
    }
  }

  Future<void> register(String id, RegistrationPayload payload) async {
    final endpoint = '$baseUrl/tournaments/$id/registrations';
    try {
      final response = await http.post(Uri.parse(endpoint), headers: _headers(), body: json.encode(payload.toJson()));
      if (response.statusCode != 200 && response.statusCode != 201) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to register',
          statusCode: response.statusCode,
          endpoint: 'POST /tournaments/$id/registrations',
          url: endpoint,
          requestBody: payload.toJson(),
          responseBody: response.body,
        );
        throw Exception('Failed to register: ${response.statusCode}');
      }
      EventRecorder.record(
        type: 'api.call',
        message: 'Registered for tournament',
        statusCode: response.statusCode,
        endpoint: 'POST /tournaments/$id/registrations',
        url: endpoint,
        requestBody: payload.toJson(),
        responseBody: response.body,
      );
    } catch (e) {
      EventRecorder.record(
        type: 'api.error',
        message: e.toString(),
        endpoint: 'POST /tournaments/$id/registrations',
        url: endpoint,
        statusCode: -1,
      );
      rethrow;
    }
  }

  Future<void> createTournament(Map<String, dynamic> payload) async {
    const route = 'POST /tournaments';
    final endpoint = '$baseUrl/tournaments';
    try {
      final response = await http.post(Uri.parse(endpoint), headers: _headers(), body: json.encode(payload));
      if (response.statusCode != 200 && response.statusCode != 201) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to create tournament',
          statusCode: response.statusCode,
          endpoint: route,
          url: endpoint,
          requestBody: payload,
          responseBody: response.body,
        );
        throw Exception('Failed to create tournament: ${response.statusCode} ${response.body}');
      }
      EventRecorder.record(
        type: 'api.call',
        message: 'Created tournament',
        statusCode: response.statusCode,
        endpoint: route,
        url: endpoint,
        requestBody: payload,
        responseBody: response.body,
      );
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: endpoint, statusCode: -1);
      rethrow;
    }
  }

  Future<void> updateTournament(String id, Map<String, dynamic> payload) async {
    final route = 'PUT /tournaments/$id';
    final endpoint = '$baseUrl/tournaments/$id';
    try {
      final response = await http.put(Uri.parse(endpoint), headers: _headers(), body: json.encode(payload));
      if (response.statusCode != 200 && response.statusCode != 201) {
        EventRecorder.record(
          type: 'api.error',
          message: 'Failed to update tournament',
          statusCode: response.statusCode,
          endpoint: route,
          url: endpoint,
          requestBody: payload,
          responseBody: response.body,
        );
        throw Exception('Failed to update tournament: ${response.statusCode} ${response.body}');
      }
      EventRecorder.record(
        type: 'api.call',
        message: 'Updated tournament',
        statusCode: response.statusCode,
        endpoint: route,
        url: endpoint,
        requestBody: payload,
        responseBody: response.body,
      );
    } catch (e) {
      EventRecorder.record(type: 'api.error', message: e.toString(), endpoint: route, url: endpoint, statusCode: -1);
      rethrow;
    }
  }

  Future<List<Tournament>> refreshCache() async {
    final prefs = await SharedPreferences.getInstance();
    return _fetchAndCache('$baseUrl/tournaments', prefs);
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheExpKey);
  }

  List<Tournament>? _readCache(SharedPreferences prefs) {
    final cachedJson = prefs.getString(_cacheKey);
    final exp = prefs.getInt(_cacheExpKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (cachedJson != null && now < exp) {
      try {
        final data = json.decode(cachedJson) as List<dynamic>;
        return data.map((item) => Tournament.fromJson(item as Map<String, dynamic>)).toList();
      } catch (e) {
        logDebug('Failed to decode cached tournaments: $e');
      }
    }
    return null;
  }

  Future<List<Tournament>> _fetchAndCache(String endpoint, SharedPreferences prefs) async {
    try {
      final response = await http.get(Uri.parse(endpoint), headers: _headers());
      logDebug("Response body: ${response.body}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await prefs.setString(_cacheKey, json.encode(items));
        await prefs.setInt(_cacheExpKey, now + _cacheTtlSeconds);
        EventRecorder.record(
          type: 'api.call',
          message: 'Loaded tournaments',
          statusCode: response.statusCode,
          endpoint: 'GET /tournaments',
          url: endpoint,
          responseBody: response.body,
        );
        return items.map((item) => Tournament.fromJson(item as Map<String, dynamic>)).toList();
      }
      EventRecorder.record(
        type: 'api.error',
        message: 'Failed to load tournaments',
        statusCode: response.statusCode,
        endpoint: 'GET /tournaments',
        url: endpoint,
        responseBody: response.body,
      );
      throw Exception('Failed to load tournaments: ${response.statusCode}');
    } on HttpException catch (e) {
      logDebug("Got HttpException: ${e.message}");
      EventRecorder.record(
        type: 'api.error',
        message: e.message,
        endpoint: 'GET /tournaments',
        url: endpoint,
        statusCode: -1,
      );
      rethrow;
    } catch (e) {
      logDebug("Got exception: ${e.toString()}");
      EventRecorder.record(
        type: 'api.error',
        message: e.toString(),
        endpoint: 'GET /tournaments',
        url: endpoint,
        statusCode: -1,
      );
      // fallback to cache on error
      final cached = _readCache(prefs);
      if (cached != null) return cached;
      rethrow;
    }
  }
}

