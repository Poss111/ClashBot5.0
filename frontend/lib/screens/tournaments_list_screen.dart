import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tournament.dart';
import '../services/tournaments_service.dart';
import '../services/assignments_service.dart';

class TournamentsListScreen extends StatefulWidget {
  final String? userEmail;
  const TournamentsListScreen({super.key, this.userEmail});

  @override
  State<TournamentsListScreen> createState() => _TournamentsListScreenState();
}

class _TournamentsListScreenState extends State<TournamentsListScreen> {
  final TournamentsService _tournamentsService = TournamentsService();
  final AssignmentsService _assignmentsService = AssignmentsService();
  
  List<Tournament> _tournaments = [];
  bool _loading = false;
  bool _submitting = false;
  bool _assigning = false;
  String? _error;
  String? _message;
  bool _backendUnreachable = false;

  final _playerIdController = TextEditingController();
  final _rolesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if ((widget.userEmail ?? '').isNotEmpty) {
      _playerIdController.text = widget.userEmail!;
    }
    _load();
  }

  @override
  void dispose() {
    _playerIdController.dispose();
    _rolesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _backendUnreachable = false;
    });

    try {
      final tournaments = await _tournamentsService.list();
      setState(() {
        _tournaments = tournaments;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _backendUnreachable = true;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _register(Tournament tournament) async {
    if (_playerIdController.text.isEmpty) {
      setState(() {
        _error = 'Player ID required';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _message = null;
      _backendUnreachable = false;
    });

    try {
      final roles = _rolesController.text
          .split(',')
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .toList();

      await _tournamentsService.register(
        tournament.tournamentId,
        RegistrationPayload(
          playerId: _playerIdController.text,
          preferredRoles: roles.isEmpty ? null : roles,
        ),
      );

      setState(() {
        _message = 'Registration submitted';
        _playerIdController.clear();
        _rolesController.clear();
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _backendUnreachable = true;
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  Future<void> _startAssignment(String tournamentId) async {
    setState(() {
      _assigning = true;
      _error = null;
      _message = null;
      _backendUnreachable = false;
    });

    try {
      await _assignmentsService.start(tournamentId);
      setState(() {
        _message = 'Assignment workflow started';
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _backendUnreachable = true;
      });
    } finally {
      setState(() {
        _assigning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const SizedBox(height: 16),
          if (_error != null) _buildErrorCard(),
          if (_backendUnreachable) _buildOfflineCard(),
          if (_message != null) _buildSuccessCard(),
          const SizedBox(height: 16),
          ..._tournaments.map((tournament) => _buildTournamentCard(tournament)),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: _loading ? null : _load,
          child: const Text('Refresh'),
        ),
        const Spacer(),
        if (_loading)
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backend is unreachable',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check connectivity, VPN/proxy settings, or try again shortly.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(_message!)),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final theme = Theme.of(context);
    DateTime? startTime;
    try {
      startTime = DateTime.parse(tournament.startTime);
    } catch (e) {
      // Invalid date format
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                      tournament.name?.isNotEmpty == true ? tournament.name! : tournament.tournamentId,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${tournament.region ?? 'region N/A'} · ${startTime != null ? DateFormat('MMM d, y h:mm a').format(startTime) : tournament.startTime} · status: ${tournament.status ?? 'N/A'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _playerIdController,
                    decoration: const InputDecoration(
                      labelText: 'Search for Player',
                      hintText: 'discord or summoner',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _rolesController,
                    decoration: const InputDecoration(
                      labelText: 'Preferred Roles (comma)',
                      hintText: 'top, jungle',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _assigning ? null : () => _startAssignment(tournament.tournamentId),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_assigning ? 'Starting...' : 'Start assignment'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _submitting ? null : () => _register(tournament),
                  icon: const Icon(Icons.person_add),
                  label: Text(_submitting ? 'Submitting...' : 'Register'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

