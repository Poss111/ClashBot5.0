import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/champion.dart';

class ChampionDataService {
  static const _versionKey = 'ddragon_version';
  static const _dataKey = 'ddragon_champions_json';
  static const _fetchedAtKey = 'ddragon_champions_fetched_at';

  Future<List<Champion>> loadChampions({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedVersion = prefs.getString(_versionKey);
    final cachedJson = prefs.getString(_dataKey);

    String? latestVersion;
    try {
      latestVersion = await _fetchLatestVersion();
    } catch (_) {
      // If version lookup fails, fall back to cached version.
      latestVersion = cachedVersion;
    }

    final cacheIsFresh = !forceRefresh && cachedVersion != null && cachedJson != null && cachedVersion == latestVersion;
    if (cacheIsFresh) {
      final parsed = json.decode(cachedJson) as Map<String, dynamic>;
      return _parseChampions(parsed);
    }

    if (latestVersion == null) {
      // No network and no version; return cache if possible.
      if (cachedJson != null) {
        final parsed = json.decode(cachedJson) as Map<String, dynamic>;
        return _parseChampions(parsed);
      }
      throw Exception('Unable to load champion data');
    }

    final data = await _fetchChampionData(latestVersion);
    await prefs.setString(_versionKey, latestVersion);
    await prefs.setString(_dataKey, json.encode(data));
    await prefs.setString(_fetchedAtKey, DateTime.now().toIso8601String());
    return _parseChampions(data);
  }

  Future<String?> getCachedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_versionKey);
  }

  Champion? findById(List<Champion> champions, String? id) {
    if (id == null) return null;
    final lower = id.toLowerCase();
    for (final c in champions) {
      if (c.id.toLowerCase() == lower || c.name.toLowerCase() == lower || c.key == id) {
        return c;
      }
    }
    return null;
  }

  Future<String> _fetchLatestVersion() async {
    final resp = await http.get(Uri.parse('https://ddragon.leagueoflegends.com/api/versions.json'));
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch Data Dragon versions');
    }
    final data = json.decode(resp.body) as List<dynamic>;
    if (data.isEmpty) throw Exception('No Data Dragon versions returned');
    return data.first.toString();
  }

  Future<Map<String, dynamic>> _fetchChampionData(String version) async {
    final url = 'https://ddragon.leagueoflegends.com/cdn/$version/data/en_US/champion.json';
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw Exception('Failed to fetch champion data ($version)');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  List<Champion> _parseChampions(Map<String, dynamic> data) {
    final map = data['data'] as Map<String, dynamic>? ?? {};
    final champions = map.values
        .map((value) => Champion.fromJson(value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return champions;
  }
}

