import 'package:flutter/material.dart';
import '../models/tournament.dart';
import '../services/tournaments_service.dart';
import '../services/teams_service.dart';

class TeamsScreen extends StatefulWidget {
  final String? userEmail;
  const TeamsScreen({super.key, this.userEmail});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final tournamentsService = TournamentsService();
  final teamsService = TeamsService();
  final TextEditingController _playerIdController = TextEditingController(text: 'player-joiner');
  late Future<List<Tournament>> _tournamentsFuture;
  final List<String> _roleOrder = const ['Top', 'Jungle', 'Mid', 'Bot', 'Support'];

  @override
  void initState() {
    super.initState();
    if ((widget.userEmail ?? '').isNotEmpty) {
      _playerIdController.text = widget.userEmail!;
    }
    _tournamentsFuture = _loadTournaments();
  }

  Future<List<Tournament>> _loadTournaments() async {
    final items = await tournamentsService.list();
    return items.where((t) => (t.status ?? 'upcoming') == 'upcoming').toList();
  }

  Future<void> _joinTeam(Tournament t, Team team, String role) async {
    final pid = _playerIdController.text.trim();
    if (pid.isEmpty) {
      _showSnack('Player ID is required');
      return;
    }
    try {
      await tournamentsService.register(
        t.tournamentId,
        RegistrationPayload(
          playerId: pid,
          preferredRoles: [role],
          teamId: team.teamId,
        ),
      );
      _showSnack('Requested join for ${team.teamId} as $role');
    } catch (e) {
      _showSnack('Failed to join: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teams',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _playerIdController,
                    decoration: const InputDecoration(labelText: 'Player ID'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Tournament>>(
                future: _tournamentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final tournaments = snapshot.data ?? [];
                  if (tournaments.isEmpty) {
                    return const Center(child: Text('No upcoming tournaments found.'));
                  }
                  return ListView.builder(
                    itemCount: tournaments.length,
                    itemBuilder: (context, index) {
                      final t = tournaments[index];
                      return FutureBuilder<List<Team>>(
                        future: teamsService.list(t.tournamentId),
                        builder: (context, teamsSnapshot) {
                          if (teamsSnapshot.connectionState == ConnectionState.waiting) {
                            return Card(
                              child: ListTile(
                                title: Text(t.name ?? t.tournamentId),
                                subtitle: const Text('Loading teams...'),
                              ),
                            );
                          }
                          if (teamsSnapshot.hasError) {
                            return Card(
                              child: ListTile(
                                title: Text(t.name ?? t.tournamentId),
                                subtitle: Text('Error loading teams: ${teamsSnapshot.error}'),
                              ),
                            );
                          }
                          final teams = teamsSnapshot.data ?? [];
                          return Card(
                            child: ExpansionTile(
                              title: Text(t.name ?? t.tournamentId),
                              subtitle: Text('${t.region ?? 'Region N/A'} • ${t.startTime}'),
                              children: teams.isEmpty
                                  ? [const ListTile(title: Text('No teams yet.'))]
                                  : teams.map((team) {
                                      final members = team.members ?? [];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Card(
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(color: Theme.of(context).dividerColor),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(team.teamId, style: Theme.of(context).textTheme.titleMedium),
                                                    Text('Captain: ${team.captainSummoner ?? 'n/a'}'),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                ..._roleOrder.map((role) {
                                                  final existing = members.cast<String?>().firstWhere(
                                                    (m) => (m ?? '').toLowerCase().contains(role.toLowerCase()),
                                                    orElse: () => null,
                                                  );
                                                  return ListTile(
                                                    dense: true,
                                                    title: Text(role),
                                                    trailing: existing == null
                                                        ? TextButton(
                                                            onPressed: () => _joinTeam(t, team, role),
                                                            child: const Text('Join'),
                                                          )
                                                        : Text(existing),
                                                  );
                                                })
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

