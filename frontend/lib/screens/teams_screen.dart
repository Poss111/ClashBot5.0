import 'package:carousel_slider/carousel_slider.dart';
import 'package:clash_companion/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
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
  String? _statusUpdatingKey;
  String? _leaveRevealKey;
  String? _leaveBusyKey;
  final Map<String, int> _carouselIndex = {};

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

  Color _statusBackground(String? status) {
    return status == 'maybe' ? AppBrandColors.warningSurface : AppBrandColors.successSurface;
  }

  Color _statusBorder(String? status) {
    return status == 'maybe'
        ? AppBrandColors.warning.withOpacity(0.6)
        : AppBrandColors.success.withOpacity(0.6);
  }

  Color _statusText(String? status) {
    return status == 'maybe' ? AppBrandColors.warning : AppBrandColors.success;
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
    const defaultStatus = 'all_in';
    try {
      await teamsService.assignRole(t.tournamentId, team.teamId, role, pid, status: defaultStatus);
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
          team.memberStatuses?.remove(k);
        }
        team.members![role] = pid;
        team.memberDisplayNames ??= {};
        team.memberDisplayNames![role] = _currentUserDisplayName ?? _maskIdentifier(pid);
        team.memberStatuses ??= {};
        team.memberStatuses![role] = defaultStatus;
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

  Future<void> _updateAvailability(Tournament t, Team team, String role, String status) async {
    final pid = _currentUserId;
    if (pid == null) {
      _showSnack('Sign in to update your status', isError: true);
      return;
    }
    if ((team.members ?? {})[role] != pid) {
      _showSnack('Only the player in this role can update the status', isError: true);
      return;
    }
    final key = '${team.teamId}:$role';
    setState(() {
      _statusUpdatingKey = key;
    });
    try {
      await teamsService.updateMemberStatus(t.tournamentId, team.teamId, role, pid, status);
      setState(() {
        team.memberStatuses ??= {};
        team.memberStatuses![role] = status;
        _statusUpdatingKey = null;
      });
      _showSnack(status == 'maybe' ? 'Marked as maybe' : 'Marked as all in');
    } catch (e) {
      setState(() {
        _statusUpdatingKey = null;
      });
      _showSnack('Failed to update status: $e', isError: true);
    }
  }

  void _toggleLeaveReveal(String key) {
    setState(() {
      _leaveRevealKey = _leaveRevealKey == key ? null : key;
    });
  }

  Future<void> _leaveTeamRole(Tournament t, Team team, String role) async {
    final pid = _currentUserId;
    if (pid == null) {
      _showSnack('Sign in to leave your team', isError: true);
      return;
    }
    if ((team.members ?? {})[role] != pid) {
      _showSnack('You can only leave your own slot', isError: true);
      return;
    }
    final key = '${team.teamId}:$role';
    setState(() {
      _leaveBusyKey = key;
    });
    try {
      await teamsService.removeMember(t.tournamentId, team.teamId, role);
      setState(() {
        team.members ??= {};
        team.members![role] = 'Open';
        team.memberDisplayNames?.remove(role);
        team.memberStatuses?.remove(role);
        _leaveBusyKey = null;
        _leaveRevealKey = null;
      });
      _showSnack('You left the team');
    } catch (e) {
      setState(() {
        _leaveBusyKey = null;
      });
      _showSnack('Failed to leave team: $e', isError: true);
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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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
        team.memberStatuses?.remove(role);
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
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
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
                          final List<Widget> teamCards = teams.isEmpty
                              ? [const ListTile(title: Text('No teams yet.'))]
                              : teams.map((team) {
                                  final members = team.members ?? {};
                                  final isCaptain = _isCaptain(team);
                                  final deleting = _deletingTeamId == team.teamId;
                                  final userInThisTeam = _currentUserId != null && members.values.contains(_currentUserId);
                                  final updatedAt = _teamUpdatedAt[team.teamId];
                                  return _TeamCard(
                                    tournament: t,
                                    team: team,
                                    members: members,
                                    isCaptain: isCaptain,
                                    deleting: deleting,
                                    userInThisTeam: userInThisTeam,
                                    updatedAt: updatedAt,
                                    currentUserId: _currentUserId,
                                    busyTeamId: _busyTeamId,
                                    busyRole: _busyRole,
                                    roleErrors: _roleErrors,
                                    kickingKey: _kickingKey,
                                    leaveRevealKey: _leaveRevealKey,
                                    leaveBusyKey: _leaveBusyKey,
                                    statusUpdatingKey: _statusUpdatingKey,
                                    teamRefreshing: _teamRefreshing[team.teamId] == true,
                                    roleOrder: _roleOrder,
                                    onRefresh: () => _refreshTeam(t.tournamentId, team.teamId),
                                    onDelete: isCaptain ? () => _deleteTeam(t, team) : null,
                                    onJoin: (role) => _joinTeam(t, team, role),
                                    onKick: (role, player) => _kickMember(t, team, role, player),
                                    onToggleLeave: _toggleLeaveReveal,
                                    onLeave: (role) => _leaveTeamRole(t, team, role),
                                    onUpdateStatus: (role, status) => _updateAvailability(t, team, role, status),
                                    memberLabel: (teamArg, role) => _memberLabel(teamArg, role),
                                    tournamentLabel: _tournamentLabel(t),
                                    formatUpdated: _formatUpdated(updatedAt),
                                    statusBackground: _statusBackground,
                                    statusBorder: _statusBorder,
                                    statusText: _statusText,
                                    roleIcon: _roleIcon,
                                    onDeepDive: () => context.go(
                                      '/teams/${t.tournamentId}/${team.teamId}/draft',
                                      extra: {
                                        'teamName': team.displayName ?? team.teamId,
                                        'tournamentLabel': _tournamentLabel(t),
                                      },
                                    ),
                                  );
                                }).toList();
                          final isMobileViewport = MediaQuery.of(context).size.width < 720;
                          final carouselIndex = _carouselIndex[t.tournamentId] ?? 0;
                          final totalTeams = teamCards.length;
                          final Widget teamsList = teams.isEmpty
                              ? const ListTile(title: Text('No teams yet.'))
                              : isMobileViewport
                                  ? SizedBox(
                                      height: 560,
                                      child: CarouselSlider(
                                        items: teamCards,
                                        options: CarouselOptions(
                                          height: 560,
                                          enableInfiniteScroll: false,
                                          viewportFraction: 0.9,
                                          enlargeCenterPage: true,
                                          enlargeStrategy: CenterPageEnlargeStrategy.height,
                                          padEnds: true,
                                          onPageChanged: (index, _) {
                                            setState(() {
                                              _carouselIndex[t.tournamentId] = index;
                                            });
                                          },
                                        ),
                                      ),
                                    )
                                  : Column(children: teamCards);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (createButton != null) createButton,
                                teamsList,
                                if (isMobileViewport && totalTeams > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(totalTeams, (i) {
                                        final active = i == carouselIndex;
                                        return Container(
                                          width: active ? 16 : 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
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

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.tournament,
    required this.team,
    required this.members,
    required this.isCaptain,
    required this.deleting,
    required this.userInThisTeam,
    required this.updatedAt,
    required this.currentUserId,
    required this.busyTeamId,
    required this.busyRole,
    required this.roleErrors,
    required this.kickingKey,
    required this.leaveRevealKey,
    required this.leaveBusyKey,
    required this.statusUpdatingKey,
    required this.teamRefreshing,
    required this.roleOrder,
    required this.onRefresh,
    required this.onDelete,
    required this.onJoin,
    required this.onKick,
    required this.onToggleLeave,
    required this.onLeave,
    required this.onUpdateStatus,
    required this.memberLabel,
    required this.tournamentLabel,
    required this.formatUpdated,
    required this.statusBackground,
    required this.statusBorder,
    required this.statusText,
    required this.roleIcon,
    required this.onDeepDive,
  });

  final Tournament tournament;
  final Team team;
  final Map<String, String> members;
  final bool isCaptain;
  final bool deleting;
  final bool userInThisTeam;
  final DateTime? updatedAt;
  final String? currentUserId;
  final String? busyTeamId;
  final String? busyRole;
  final Set<String> roleErrors;
  final String? kickingKey;
  final String? leaveRevealKey;
  final String? leaveBusyKey;
  final String? statusUpdatingKey;
  final bool teamRefreshing;
  final List<String> roleOrder;
  final VoidCallback onRefresh;
  final VoidCallback? onDelete;
  final void Function(String role) onJoin;
  final void Function(String role, String playerId) onKick;
  final void Function(String key) onToggleLeave;
  final void Function(String role) onLeave;
  final void Function(String role, String status) onUpdateStatus;
  final String Function(Team team, String role) memberLabel;
  final String tournamentLabel;
  final String formatUpdated;
  final Color Function(String? status) statusBackground;
  final Color Function(String? status) statusBorder;
  final Color Function(String? status) statusText;
  final IconData? Function(String role) roleIcon;
  final VoidCallback onDeepDive;

  @override
  Widget build(BuildContext context) {
    final memberStatuses = team.memberStatuses ?? {};
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
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tournamentLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatUpdated,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh team',
                        onPressed: teamRefreshing ? null : onRefresh,
                        icon: teamRefreshing
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
                          onPressed: deleting ? null : onDelete,
                          icon: deleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                          : Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
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
                          team.captainDisplayName ?? team.captainSummoner ?? 'Captain',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onDeepDive,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Draft deep dive'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...roleOrder.map((role) {
                final existing = members[role] ?? 'Open';
                final icon = roleIcon(role);
                final isBusy = busyTeamId == team.teamId && busyRole == role;
                final teamBusy = busyTeamId == team.teamId && busyRole != role;
                final hasError = roleErrors.contains('${team.teamId}:$role');
                final isKicking = kickingKey == '${team.teamId}:$role';
                final isSelf = existing == currentUserId;
                final userOnAnotherRoleSameTeam = userInThisTeam && existing != currentUserId;
                final memberLabelText = memberLabel(team, role);
                final status = existing == 'Open' ? null : memberStatuses[role] ?? 'all_in';
                final isOpenSlot = existing == 'Open';
                final statusUpdating = statusUpdatingKey == '${team.teamId}:$role';
                final tileColor = isOpenSlot ? null : statusBackground(status);
                final borderColor = isOpenSlot ? Theme.of(context).dividerColor : statusBorder(status);
                final leaveKey = '${team.teamId}:$role';
                final leaveRevealed = isSelf && leaveRevealKey == leaveKey;
                final isLeaving = leaveBusyKey == leaveKey;
                final showCompact = leaveRevealed;

                return Row(
                  children: [
                    if (isSelf)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: leaveRevealed ? 120 : 0,
                        child: leaveRevealed
                            ? Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ElevatedButton.icon(
                                  onPressed: isLeaving ? null : () => onLeave(role),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                                    minimumSize: const Size(120, 40),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                  icon: isLeaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.logout, size: 18),
                                  label: const Text('Leave'),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    Expanded(
                      child: ListTile(
                        onTap: isSelf ? () => onToggleLeave(leaveKey) : null,
                        dense: true,
                        tileColor: tileColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minLeadingWidth: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: borderColor),
                        ),
                        leading: icon != null ? Icon(icon, size: 20) : null,
                        title: showCompact ? null : Text(
                          role,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.inversePrimary),
                        ),
                        trailing: showCompact
                            ? null
                            : existing == 'Open'
                                ? hasError
                                          ? Text(
                                              'Error',
                                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                                            )
                                    : isBusy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : ElevatedButton(
                                            onPressed:
                                                (teamBusy || currentUserId == null) ? null : () => onJoin(role),
                                            child: Text(userOnAnotherRoleSameTeam ? 'Swap' : 'Join'),
                                          )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            memberLabelText, 
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.inversePrimary),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusBackground(status),
                                              border: Border.all(color: statusBorder(status)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              status == 'maybe' ? 'Maybe' : 'All in',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: statusText(status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isSelf)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: statusUpdating
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : PopupMenuButton<String>(
                                                  tooltip: 'Update your status',
                                                  onSelected: (value) => onUpdateStatus(role, value),
                                                  itemBuilder: (context) => const [
                                                    PopupMenuItem<String>(
                                                      value: 'all_in',
                                                      child: Text('All in'),
                                                    ),
                                                    PopupMenuItem<String>(
                                                      value: 'maybe',
                                                      child: Text('Maybe'),
                                                    ),
                                                  ],
                                                  child: Icon(
                                                    Icons.checklist,
                                                    color: statusText(status),
                                                    size: 20,
                                                  ),
                                                ),
                                        ),
                                      if (isCaptain && !isSelf && existing != 'Open')
                                        IconButton(
                                          tooltip: 'Remove player',
                                          onPressed: isKicking ? null : () => onKick(role, existing),
                                          icon: isKicking
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                                        ),
                                    ],
                                  ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

