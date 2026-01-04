import 'package:clash_companion/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/tournament.dart';
import '../services/tournaments_service.dart';
import '../services/teams_service.dart';

class TeamsScreen extends StatefulWidget {
  final String? userEmail;
  final String? userDisplayName;
  const TeamsScreen({super.key, this.userEmail, this.userDisplayName});

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
  String? _creatingTournamentId;
  String? _deletingTeamId;
  String? _kickingKey;
  final Map<String, bool> _teamRefreshing = {};
  final Map<String, DateTime> _teamUpdatedAt = {};
  final Map<String, bool> _tournamentExpanded = {};

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _loadTournaments();
  }

  Future<List<Team>> _teamsFuture(String tournamentId) {
    return _teamFutures.putIfAbsent(tournamentId, () => teamsService.list(tournamentId));
  }

  Future<void> _refreshTeam(String tournamentId, String teamId) async {
    setState(() {
      _teamRefreshing[teamId] = true;
    });
    try {
      final list = await teamsService.list(tournamentId);
      _teamFutures[tournamentId] = Future.value(list);
      setState(() {
        _teamUpdatedAt[teamId] = DateTime.now();
      });
    } catch (e) {
      _showSnack('Failed to refresh team: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _teamRefreshing.remove(teamId);
        });
      }
    }
  }

  String _formatUpdated(DateTime? dt) {
    if (dt == null) return 'Updated: --';
    final now = DateTime.now();
    final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final formattedTime = AppDateFormats.formatJustTime(dt);
    final formattedDate = AppDateFormats.formatStandard(dt);
    return sameDay ? 'Updated: $formattedTime' : 'Updated: $formattedDate';
  }

  String? get _currentUserId {
    final email = widget.userEmail?.trim() ?? '';
    return email.isEmpty ? null : email;
  }

  String? get _currentUserDisplayName {
    final name = widget.userDisplayName?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  String _maskIdentifier(String? value) {
    if (value == null || value.isEmpty || value == 'Open') return 'Player';
    var hash = 0;
    for (var i = 0; i < value.length; i++) {
      hash = (hash * 31 + value.codeUnitAt(i)) & 0x7fffffff;
    }
    final code = hash.toRadixString(16).padLeft(6, '0').substring(0, 6);
    return 'Player-$code';
  }

  String _labelForUser(String? userId, String? displayName) {
    if (displayName != null && displayName.trim().isNotEmpty) return displayName.trim();
    return _maskIdentifier(userId);
  }

  String _memberLabel(Team team, String role) {
    final existing = (team.members ?? {})[role];
    if (existing == null || existing == 'Open') return 'Open';
    final display = team.memberDisplayNames?[role];
    return _labelForUser(existing, display);
  }

  Future<void> _refreshTeams(String tournamentId) async {
    final future = teamsService.list(tournamentId);
    setState(() {
      _teamFutures[tournamentId] = future;
    });
    await future;
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
    if (_selectedTournamentId == null && upcomingOrFuture.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedTournamentId = upcomingOrFuture.first.tournamentId;
        });
      });
    }
    return upcomingOrFuture;
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

  bool _isCaptain(Team team) {
    final current = _currentUserId;
    if (current == null) return false;
    return team.captainSummoner == current || team.createdBy == current;
  }

  String _tournamentLabel(Tournament t) {
    final name = t.nameKeySecondary ?? t.tournamentId;
    return name;
  }

  Future<void> _joinTeam(Tournament t, Team team, String role) async {
    final pid = _currentUserId;
    if (pid == null) {
      _showSnack('Sign in to join a team', isError: true);
      return;
    }
    setState(() {
      _busyTeamId = team.teamId;
      _busyRole = role;
      _roleErrors.remove('${team.teamId}:$role');
    });
    try {
      await teamsService.assignRole(t.tournamentId, team.teamId, role, pid);
      setState(() {
        team.members ??= {};
        // Clear any prior role this user held on this team (swap support).
        final toClear = <String>[];
        team.members!.forEach((k, v) {
          if (v == pid && k != role) {
            toClear.add(k);
          }
        });
        for (final k in toClear) {
          team.members![k] = 'Open';
          team.memberDisplayNames?.remove(k);
        }
        team.members![role] = pid;
        team.memberDisplayNames ??= {};
        team.memberDisplayNames![role] = _currentUserDisplayName ?? _maskIdentifier(pid);
        _busyTeamId = null;
        _busyRole = null;
      });
      _showSnack('Joined ${team.displayName ?? team.teamId} as $role');
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

  Future<void> _createTeam(Tournament t, String teamName, String role) async {
    if (_currentUserId == null) {
      _showSnack('Sign in to create a team', isError: true);
      return;
    }
    if (teamName.trim().isEmpty) {
      _showSnack('Team name is required', isError: true);
      return;
    }
    setState(() {
      _creatingTournamentId = t.tournamentId;
    });
    try {
      await teamsService.createTeam(t.tournamentId, displayName: teamName.trim(), role: role);
      await _refreshTeams(t.tournamentId);
      _showSnack('Created team $teamName as $role');
    } catch (e) {
      _showSnack('Failed to create team: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _creatingTournamentId = null;
        });
      }
    }
  }

  Future<void> _openCreateTeamDialog(Tournament t) async {
    if (_currentUserId == null) {
      _showSnack('Sign in to create a team', isError: true);
      return;
    }
    final nameController = TextEditingController();
    String selectedRole = _roleOrder.first;
    Map<String, String>? result;
    try {
      result = await showDialog<Map<String, String>?>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create team'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Team name'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Your role'),
                        items: _roleOrder
                            .map((r) => DropdownMenuItem<String>(
                                  value: r,
                                  child: Text(r),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedRole = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop({
                    'name': nameController.text.trim(),
                    'role': selectedRole,
                  });
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    } finally {
      // Delay dispose until after dialog teardown to avoid focus/ancestor lookups on a disposed controller.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
      });
    }
    if (!mounted) return;
    if (result == null) return;
    final name = result['name'] ?? '';
    final role = result['role'] ?? _roleOrder.first;
    await _createTeam(t, name, role);
  }

  Future<void> _deleteTeam(Tournament t, Team team) async {
    if (!_isCaptain(team)) {
      _showSnack('Only the captain can delete the team', isError: true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete team'),
        content: Text('Delete ${team.displayName ?? team.teamId}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _deletingTeamId = team.teamId;
    });
    try {
      await teamsService.deleteTeam(t.tournamentId, team.teamId);
      await _refreshTeams(t.tournamentId);
      _showSnack('Deleted ${team.displayName ?? team.teamId}');
    } catch (e) {
      _showSnack('Failed to delete team: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingTeamId = null;
        });
      }
    }
  }

  Future<void> _kickMember(Tournament t, Team team, String role, String playerId) async {
    if (!_isCaptain(team)) {
      _showSnack('Only the captain can remove members', isError: true);
      return;
    }
    if (_currentUserId == playerId) {
      _showSnack('You cannot remove yourself as captain', isError: true);
      return;
    }
    final key = '${team.teamId}:$role';
    setState(() {
      _kickingKey = key;
    });
    try {
      final removedLabel = _labelForUser(playerId, team.memberDisplayNames?[role]);
      await teamsService.removeMember(t.tournamentId, team.teamId, role);
      setState(() {
        team.members ??= {};
        team.members![role] = 'Open';
        team.memberDisplayNames?.remove(role);
      });
      _showSnack('Removed $removedLabel from $role');
    } catch (e) {
      _showSnack('Failed to remove member: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _kickingKey = null;
        });
      }
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
                                title: Text(t.nameKeySecondary ?? t.tournamentId),
                                subtitle: const Text('Loading teams...'),
                              ),
                            );
                          }
                          if (teamsSnapshot.hasError) {
                            return Card(
                              child: ListTile(
                                title: Text(t.nameKeySecondary ?? t.tournamentId),
                                subtitle: Text('Error loading teams: ${teamsSnapshot.error}'),
                              ),
                            );
                          }
                          final teams = teamsSnapshot.data ?? [];
                          final isCreatingHere = _creatingTournamentId == t.tournamentId;
                          final alreadyInTeam = _currentUserId != null &&
                              teams.any((tm) => (tm.members ?? {}).values.contains(_currentUserId));
                          final isCaptainInTournament =
                              _currentUserId != null && teams.any((tm) => _isCaptain(tm));
                          final Widget? createButton = isCaptainInTournament
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: ElevatedButton.icon(
                                      onPressed: isCreatingHere
                                          ? null
                                          : alreadyInTeam
                                              ? () => _showSnack('Leave or disband your current team first', isError: true)
                                              : () => _openCreateTeamDialog(t),
                                      icon: isCreatingHere
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.group_add),
                                      label: Text(isCreatingHere ? 'Creating...' : 'Create team'),
                                    ),
                                  ),
                                );
                          final teamCards = teams.isEmpty
                              ? [const ListTile(title: Text('No teams yet.'))]
                              : teams.map((team) {
                                  final members = team.members ?? {};
                                  final isCaptain = _isCaptain(team);
                                  final deleting = _deletingTeamId == team.teamId;
                                  final userInThisTeam = _currentUserId != null && members.values.contains(_currentUserId);
                                  final updatedAt = _teamUpdatedAt[team.teamId];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 280),
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
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              team.displayName ?? team.teamId,
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium
                                                                  ?.copyWith(fontWeight: FontWeight.bold),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              _formatUpdated(updatedAt),
                                                              style: Theme.of(context).textTheme.bodySmall,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Refresh team',
                                                        onPressed: (_teamRefreshing[team.teamId] == true)
                                                            ? null
                                                            : () => _refreshTeam(t.tournamentId, team.teamId),
                                                        icon: (_teamRefreshing[team.teamId] == true)
                                                            ? const SizedBox(
                                                                width: 18,
                                                                height: 18,
                                                                child: CircularProgressIndicator(strokeWidth: 2),
                                                              )
                                                            : const Icon(Icons.refresh),
                                                      ),
                                                      if (isCaptain)
                                                        IconButton(
                                                          tooltip: 'Delete team',
                                                          onPressed: deleting ? null : () => _deleteTeam(t, team),
                                                          icon: deleting
                                                              ? const SizedBox(
                                                                  width: 18,
                                                                  height: 18,
                                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                                )
                                                              : const Icon(Icons.delete_outline, color: Colors.red),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.military_tech, size: 18),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          team.captainDisplayName ??
                                                              _maskIdentifier(team.captainSummoner),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              ..._roleOrder.map((role) {
                                                final existing = members[role];
                                                final icon = _roleIcon(role);
                                                final isBusy = _busyTeamId == team.teamId && _busyRole == role;
                                                final teamBusy = _busyTeamId == team.teamId && _busyRole != role;
                                                final hasError = _roleErrors.contains('${team.teamId}:$role');
                                                final isKicking = _kickingKey == '${team.teamId}:$role';
                                                final isSelf = existing != null && existing == _currentUserId;
                                                final userOnAnotherRoleSameTeam =
                                                    userInThisTeam && (existing == null || existing != _currentUserId);
                                                final memberLabel = _memberLabel(team, role);
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
                                                                  onPressed: (teamBusy || _currentUserId == null)
                                                                      ? null
                                                                      : () => _joinTeam(t, team, role),
                                                                  child: Text(userOnAnotherRoleSameTeam ? 'Swap' : 'Join'),
                                                                )
                                                      : Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(memberLabel),
                                                            if (isCaptain && !isSelf)
                                                              IconButton(
                                                                tooltip: 'Remove player',
                                                                onPressed:
                                                                    isKicking ? null : () => _kickMember(t, team, role, existing),
                                                                icon: isKicking
                                                                    ? const SizedBox(
                                                                        width: 18,
                                                                        height: 18,
                                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                                      )
                                                                    : const Icon(Icons.close, color: Colors.red),
                                                              ),
                                                          ],
                                                        ),
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList();
                          return Card(
                            child: ExpansionTile(
                              initiallyExpanded: _tournamentExpanded[t.tournamentId] ?? false,
                              onExpansionChanged: (expanded) {
                                setState(() {
                                  _tournamentExpanded[t.tournamentId] = expanded;
                                });
                              },
                              title: Text(
                                t.nameKeySecondary ?? t.tournamentId,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.region ?? 'Region N/A'),
                                  const SizedBox(height: 4),
                                  t.registrationTime != null ? Row(
                                    children: [
                                      const Icon(Icons.app_registration, size: 16),
                                      const SizedBox(width: 6),
                                      Text(AppDateFormats.formatLong(DateTime.parse(t.registrationTime!))),
                                    ],
                                  ) : const SizedBox.shrink(),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 6),
                                      Text(AppDateFormats.formatLong(DateTime.parse(t.startTime))),
                                    ],
                                  ),
                                ],
                              ),
                              children: [
                                if (createButton != null) createButton,
                                ...teamCards,
                              ],
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

