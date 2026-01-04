import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  late Future<List<Tournament>> _tournamentsFuture;
  final Map<String, Future<List<Team>>> _teamFutures = {};
  final List<String> _roleOrder = const ['Top', 'Jungle', 'Mid', 'Bot', 'Support'];
  String? _busyTeamId;
  String? _busyRole;
  final Set<String> _roleErrors = {};
  String? _selectedTournamentId;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _loadTournaments();
  }

  Future<List<Team>> _teamsFuture(String tournamentId) {
    return _teamFutures.putIfAbsent(tournamentId, () => teamsService.list(tournamentId));
  }

  Future<List<Tournament>> _loadTournaments() async {
    final items = await tournamentsService.list();
    final upcomingOrFuture = items.where((t) => (t.status ?? 'upcoming') == 'upcoming').toList();
    upcomingOrFuture.sort((a, b) {
      final aStart = _safeParse(a.startTime);
      final bStart = _safeParse(b.startTime);
      if (aStart == null && bStart == null) return 0;
      if (aStart == null) return 1;
      if (bStart == null) return -1;
      return aStart.compareTo(bStart);
    });
    return upcomingOrFuture;
  }

  String _formatLocalTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown time';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final tzRaw = dt.timeZoneName;
      final tz = _abbrOrOffset(dt, tzRaw);
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(hour12)}:${_two(dt.minute)} $ampm $tz';
    } catch (_) {
      return iso;
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _abbrOrOffset(DateTime dt, String tzRaw) {
    // Prefer a short abbreviation; if the platform returns a long name, fall back to GMT offset.
    if (tzRaw.length <= 5 && !tzRaw.contains(' ')) return tzRaw;
    final offset = dt.timeZoneOffset;
    final sign = offset.inMinutes >= 0 ? '+' : '-';
    final total = offset.inMinutes.abs();
    final hours = total ~/ 60;
    final mins = total % 60;
    return 'GMT$sign${_two(hours)}:${_two(mins)}';
  }

  DateTime? _safeParse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  IconData? _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'top':
        return Icons.landscape;
      case 'jungle':
        return Icons.park;
      case 'mid':
      case 'middle':
        return Icons.remove_red_eye;
      case 'bot':
      case 'bottom':
      case 'adc':
        return Icons.whatshot;
      case 'support':
        return Icons.volunteer_activism;
      default:
        return null;
    }
  }

  String _tournamentLabel(Tournament t) {
    final start = _safeParse(t.startTime);
    final startText = start != null ? _formatLocalTime(t.startTime) : 'Unknown start';
    final name = t.name ?? t.tournamentId;
    return '$name · $startText';
  }

  Future<void> _joinTeam(Tournament t, Team team, String role) async {
    final pid = (widget.userEmail ?? '').isNotEmpty ? widget.userEmail!.trim() : 'mock-player';
    setState(() {
      _busyTeamId = team.teamId;
      _busyRole = role;
      _roleErrors.remove('${team.teamId}:$role');
    });
    try {
      await teamsService.assignRole(t.tournamentId, team.teamId, role, pid);
      setState(() {
        team.members?[role] = pid;
        _busyTeamId = null;
        _busyRole = null;
      });
      _showSnack('Joined ${team.teamId} as $role');
    } catch (e) {
      setState(() {
        _busyTeamId = null;
        _busyRole = null;
        _roleErrors.add('${team.teamId}:$role');
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          _roleErrors.remove('${team.teamId}:$role');
        });
      });
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
            const SizedBox(height: 8),
            FutureBuilder<List<Tournament>>(
              future: _tournamentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Error loading tournaments: ${snapshot.error}'),
                  );
                }
                final tournaments = snapshot.data ?? [];
                if (tournaments.isEmpty) return const SizedBox.shrink();
                final dropdown = DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: _selectedTournamentId,
                    hint: const Text('All tournaments'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All tournaments'),
                      ),
                      ...tournaments.map(
                        (t) => DropdownMenuItem<String?>(
                          value: t.tournamentId,
                          child: Text(
                            _tournamentLabel(t),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedTournamentId = val;
                      });
                    },
                  ),
                );
                return Row(
                  children: [
                    const Text('Filter by tournament:'),
                    const SizedBox(width: 12),
                    if (kIsWeb)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: dropdown,
                      )
                    else
                      Expanded(child: dropdown),
                  ],
                );
              },
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
                  var tournaments = snapshot.data ?? [];
                  if (_selectedTournamentId != null) {
                    tournaments =
                        tournaments.where((t) => t.tournamentId == _selectedTournamentId).toList();
                  }
                  if (tournaments.isEmpty) {
                    return const Center(child: Text('No upcoming tournaments found.'));
                  }
                  return ListView.builder(
                    itemCount: tournaments.length,
                    itemBuilder: (context, index) {
                      final t = tournaments[index];
                      return FutureBuilder<List<Team>>(
                        future: _teamsFuture(t.tournamentId),
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
                              title: Text(
                                t.name ?? t.tournamentId,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.region ?? 'Region N/A'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 6),
                                      Text(_formatLocalTime(t.startTime)),
                                    ],
                                  ),
                                ],
                              ),
                              children: teams.isEmpty
                                  ? [const ListTile(title: Text('No teams yet.'))]
                                  : teams.map((team) {
                                      final members = team.members ?? {};
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 250),
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
                                                    Text(
                                                      team.teamId,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(fontWeight: FontWeight.bold),
                                                    ),
                                                      Text('Captain: ${team.captainSummoner ?? 'n/a'}'),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                              ..._roleOrder.map((role) {
                                                final existing = members[role] as String?;
                                                final icon = _roleIcon(role);
                                                final isBusy = _busyTeamId == team.teamId && _busyRole == role;
                                                final teamBusy = _busyTeamId == team.teamId && _busyRole != role;
                                                final hasError = _roleErrors.contains('${team.teamId}:$role');
                                                return ListTile(
                                                  dense: true,
                                                  leading: icon != null ? Icon(icon, size: 20) : null,
                                                  title: Text(role),
                                                  trailing: existing == null || existing == 'Open'
                                                      ? hasError
                                                          ? const Text(
                                                              'Error',
                                                              style: TextStyle(color: Colors.red),
                                                            )
                                                          : isBusy
                                                              ? const SizedBox(
                                                                  width: 18,
                                                                  height: 18,
                                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                                )
                                                              : ElevatedButton(
                                                                  onPressed: teamBusy
                                                                      ? null
                                                                      : () => _joinTeam(t, team, role),
                                                                  child: const Text('Join'),
                                                                )
                                                      : Text(existing),
                                                );
                                              })
                                                ],
                                              ),
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

