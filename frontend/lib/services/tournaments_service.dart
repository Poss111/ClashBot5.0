import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tournament.dart';
import 'api_config.dart';

class TournamentsService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<List<Tournament>> list() async {
    final response = await http.get(
      Uri.parse('$baseUrl/tournaments'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      return items.map((item) => Tournament.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load tournaments: ${response.statusCode}');
    }
  }

  Future<Tournament> get(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/tournaments/$id'),
    );

    if (response.statusCode == 200) {
      return Tournament.fromJson(json.decode(response.body) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to load tournament: ${response.statusCode}');
    }
  }

  Future<void> register(String id, RegistrationPayload payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tournaments/$id/registrations'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to register: ${response.statusCode}');
    }
  }
}

