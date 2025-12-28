import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../services/api_config.dart';
import '../services/websocket_config.dart';
import '../services/auth_service.dart';

class WebSocketTestScreen extends StatefulWidget {
  final String? userEmail;
  const WebSocketTestScreen({super.key, this.userEmail});

  @override
  State<WebSocketTestScreen> createState() => _WebSocketTestScreenState();
}

class _WebSocketTestScreenState extends State<WebSocketTestScreen> {
  final TextEditingController _apiBaseController =
      TextEditingController(text: ApiConfig.baseUrl);
  final TextEditingController _wsUrlController =
      TextEditingController(text: WebSocketConfig.baseUrl);
  final TextEditingController _tournamentIdController =
      TextEditingController(text: 'clash-test-1');
  final TextEditingController _tournamentNameController =
      TextEditingController(text: 'Fun Cup');
  final TextEditingController _regionController =
      TextEditingController(text: 'NA1');
  final TextEditingController _themeIdController =
      TextEditingController(text: '1');
  final TextEditingController _nameKeyController =
      TextEditingController(text: 'wolfcup');
  final TextEditingController _nameKeySecondaryController =
      TextEditingController(text: 'Wolf Cup');
  final TextEditingController _registrationTimeController =
      TextEditingController(text: '');
  final TextEditingController _startTimeController =
      TextEditingController(text: '');
  final TextEditingController _teamIdController =
      TextEditingController(text: 'team-1');
  final TextEditingController _captainController =
      TextEditingController(text: 'captain-1');
  final TextEditingController _playerIdController =
      TextEditingController(text: 'player-1');
  final TextEditingController _rolesController =
      TextEditingController(text: 'top,jungle');

  final List<String> _logs = [];
  WebSocketChannel? _channel;
  bool _wsConnected = false;
  Map<String, String> get _headers {
    final token = AuthService.instance.backendToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    final initialDate = DateTime.tryParse(controller.text) ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (pickedTime == null) return;
    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    controller.text = combined.toIso8601String();
  }

  @override
  void initState() {
    super.initState();
    if ((widget.userEmail ?? '').isNotEmpty) {
      _playerIdController.text = widget.userEmail!;
    }
  }

  @override
  void dispose() {
    _apiBaseController.dispose();
    _wsUrlController.dispose();
    _tournamentIdController.dispose();
    _tournamentNameController.dispose();
    _regionController.dispose();
    _themeIdController.dispose();
    _nameKeyController.dispose();
    _nameKeySecondaryController.dispose();
    _registrationTimeController.dispose();
    _startTimeController.dispose();
    _teamIdController.dispose();
    _captainController.dispose();
    _playerIdController.dispose();
    _rolesController.dispose();
    _disconnectWs();
    super.dispose();
  }

  String get _baseUrl {
    final base = _apiBaseController.text.trim();
    if (base.isEmpty) throw Exception('API base URL is required');
    return base;
  }

  void _log(String message, [Object? data]) {
    if (!mounted) return;
    final line =
        '[${DateTime.now().toIso8601String()}] $message${data != null ? " ${jsonEncode(data)}" : ""}';
    setState(() {
      _logs.insert(0, line);
    });
  }

  void _connectWs() {
    if (_wsConnected) {
      _log('WebSocket already connected');
      return;
    }
    final url = _wsUrlController.text.trim();
    if (url.isEmpty) {
      _log('WebSocket URL required');
      return;
    }
    try {
      _log('WebSocket connecting to $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        (event) {
          _log('WebSocket message', _safeJson(event.toString()));
        },
        onDone: () {
          _log('WebSocket closed');
          if (mounted) setState(() => _wsConnected = false);
        },
        onError: (err) {
          _log('WebSocket error', err.toString());
          if (mounted) setState(() => _wsConnected = false);
        },
      );
      setState(() => _wsConnected = true);
      _log('WebSocket connected');
    } catch (e) {
      _log('WebSocket connect failed', e.toString());
      setState(() => _wsConnected = false);
    }
  }

  void _disconnectWs() {
    try {
      _channel?.sink.close(ws_status.goingAway);
    } catch (_) {}
    _channel = null;
    if (mounted) {
      setState(() => _wsConnected = false);
      _log('WebSocket disconnected');
    }
  }

  Future<void> _createTournament() async {
    try {
      final reg = _parseMillis(_registrationTimeController.text);
      final start = _parseMillis(_startTimeController.text);
      if (reg == null || start == null) {
        _log('createTournament error', {'message': 'registrationTime and startTime required'});
        return;
      }
      final body = {
        'tournamentId': _tournamentIdController.text.trim(),
        'themeId': int.tryParse(_themeIdController.text.trim()),
        'nameKey': _nameKeyController.text.trim(),
        'nameKeySecondary': _nameKeySecondaryController.text.trim(),
        'region': _regionController.text.trim(),
        'tournament': {
          'tournamentId': _tournamentIdController.text.trim(),
          'themeId': int.tryParse(_themeIdController.text.trim()),
          'nameKey': _nameKeyController.text.trim(),
          'nameKeySecondary': _nameKeySecondaryController.text.trim(),
          'schedule': [
            {
              'id': 1,
              'registrationTime': reg,
              'startTime': start
            }
          ]
        }
      };
      final resp = await http.post(
        Uri.parse('$_baseUrl/tournaments'),
        headers: _headers,
        body: jsonEncode(body),
      );
      _log('createTournament status=${resp.statusCode}', _safeJson(resp.body));
    } catch (e) {
      _log('createTournament error', e.toString());
    }
  }

  int? _parseMillis(String input) {
    if (input.isEmpty) return null;
    final v = int.tryParse(input);
    if (v != null) return v;
    final dt = DateTime.tryParse(input);
    return dt?.millisecondsSinceEpoch;
  }

  Future<void> _createTeam() async {
    try {
      final tid = _tournamentIdController.text.trim();
      final body = {
        'teamId': _teamIdController.text.trim(),
        'tournamentId': tid,
        'captainSummoner': _captainController.text.trim(),
        'members': [_captainController.text.trim()]
      };
      final resp = await http.post(
        Uri.parse('$_baseUrl/tournaments/$tid/teams'),
        headers: _headers,
        body: jsonEncode(body),
      );
      _log('createTeam status=${resp.statusCode}', _safeJson(resp.body));
    } catch (e) {
      _log('createTeam error', e.toString());
    }
  }

  Future<void> _registerPlayer() async {
    try {
      final tid = _tournamentIdController.text.trim();
      final pid = _playerIdController.text.trim();
      final teamId = _teamIdController.text.trim();
      final roles = _rolesController.text
          .split(',')
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .toList();

      final resp = await http.post(
        Uri.parse('$_baseUrl/tournaments/$tid/registrations'),
        headers: _headers,
        body: jsonEncode({'playerId': pid, 'preferredRoles': roles, 'teamId': teamId.isEmpty ? null : teamId}),
      );
      _log('registerPlayer status=${resp.statusCode}', _safeJson(resp.body));
    } catch (e) {
      _log('registerPlayer error', e.toString());
    }
  }

  Future<void> _startAssignment() async {
    try {
      final tid = _tournamentIdController.text.trim();
      final teamId = _teamIdController.text.trim();
      final resp = await http.post(
        Uri.parse('$_baseUrl/tournaments/$tid/assign'),
        headers: _headers,
        body: jsonEncode({'tournamentId': tid, if (teamId.isNotEmpty) 'teamId': teamId}),
      );
      _log('startAssignment status=${resp.statusCode}', _safeJson(resp.body));
    } catch (e) {
      _log('startAssignment error', e.toString());
    }
  }

  Object? _safeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Left column: execution
        Expanded(
          flex: 1,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _apiBaseController,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create tournament', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tournamentIdController,
                        decoration: const InputDecoration(labelText: 'Tournament ID'),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _themeIdController,
                              decoration: const InputDecoration(labelText: 'Theme ID'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _regionController,
                              decoration: const InputDecoration(labelText: 'Region'),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameKeyController,
                              decoration: const InputDecoration(labelText: 'Name Key'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _nameKeySecondaryController,
                              decoration: const InputDecoration(labelText: 'Name Key Secondary'),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _registrationTimeController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Registration Time',
                                hintText: 'Select date & time',
                              ),
                              onTap: () => _pickDateTime(_registrationTimeController),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _startTimeController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                hintText: 'Select date & time',
                              ),
                              onTap: () => _pickDateTime(_startTimeController),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _createTournament,
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create team', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _teamIdController,
                        decoration: const InputDecoration(labelText: 'Team ID'),
                      ),
                      TextField(
                        controller: _captainController,
                        decoration: const InputDecoration(labelText: 'Captain / member'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _createTeam,
                        child: const Text('Create team'),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Register + assign', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _playerIdController,
                        decoration: const InputDecoration(labelText: 'Player ID'),
                      ),
                      TextField(
                        controller: _rolesController,
                        decoration: const InputDecoration(labelText: 'Preferred roles (comma)'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _registerPlayer,
                            child: const Text('Register player'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _startAssignment,
                            child: const Text('Start assignment'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // Right column: log
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WebSocket',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _wsUrlController,
                          decoration: const InputDecoration(
                            labelText: 'WebSocket URL',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _wsConnected ? null : _connectWs,
                              icon: const Icon(Icons.link),
                              label: const Text('Connect'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _wsConnected ? _disconnectWs : null,
                              icon: const Icon(Icons.link_off),
                              label: const Text('Disconnect'),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _wsConnected ? Icons.check_circle : Icons.cancel,
                              color: _wsConnected ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(_wsConnected ? 'Connected' : 'Disconnected'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Log (${_logs.length})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _logs.isEmpty
                        ? Center(
                            child: Text(
                              'No events yet',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            reverse: false,
                            padding: const EdgeInsets.all(12),
                            itemCount: _logs.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _logs[index],
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

