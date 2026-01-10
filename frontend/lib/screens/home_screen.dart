import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/tournament.dart';
import '../services/auth_service.dart';
import '../services/champion_data_service.dart';
import '../services/teams_service.dart';
import '../services/tournaments_service.dart';
import '../services/user_service.dart';

class HomeScreen extends StatefulWidget {
  final String? effectiveRole;
  final bool navEnabled;
  final String? userId;
  final String? userDisplayName;

  const HomeScreen({
    super.key,
    this.effectiveRole,
    this.navEnabled = true,
    this.userId,
    this.userDisplayName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _SnapshotData {
  final Tournament tournament;
  final Team team;
  final String role;
  final List<_FavoriteDisplay> favorites;
  final bool hasFavorites;

  _SnapshotData({
    required this.tournament,
    required this.team,
    required this.role,
    required this.favorites,
    required this.hasFavorites,
  });
}

class _Membership {
  final Team team;
  final String role;
  _Membership({required this.team, required this.role});
}

class _FavoriteDisplay {
  final String id;
  final String label;
  final String? imageFull;

  const _FavoriteDisplay({required this.id, required this.label, this.imageFull});
}

class _HomeScreenState extends State<HomeScreen> {
  final _tournamentsService = TournamentsService();
  final _teamsService = TeamsService();
  final _userService = UserService();
  final _championService = ChampionDataService();
  final List<String> _roleOrder = const ['Top', 'Jungle', 'Mid', 'Bot', 'Support'];

  bool _loadingSnapshot = false;
  String? _snapshotError;
  _SnapshotData? _snapshot;
  String? _resolvedUserId;
  String? _ddVersion;

  bool get _isSignedIn {
    final hasBackendSession = AuthService.instance.backendToken != null;
    return hasBackendSession || widget.userId != null || _resolvedUserId != null;
  }

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadSnapshot();
    }
  }

  Future<void> _loadSnapshot() async {
    final hasBackendSession = AuthService.instance.backendToken != null;
    if (widget.userId == null && !hasBackendSession) {
      setState(() {
        _snapshot = null;
        _snapshotError = null;
        _loadingSnapshot = false;
        _resolvedUserId = null;
      });
      return;
    }
    setState(() {
      _loadingSnapshot = true;
      _snapshotError = null;
    });
    try {
      final profileFuture = _userService.getCurrentUser();
      final tournaments = await _tournamentsService.list();
      final upcoming = tournaments
          .where((t) => (t.status ?? 'upcoming').toLowerCase() == 'upcoming')
          .toList()
        ..sort((a, b) {
          final aStart = _safeParse(a.startTime);
          final bStart = _safeParse(b.startTime);
          if (aStart == null && bStart == null) return 0;
          if (aStart == null) return 1;
          if (bStart == null) return -1;
          return aStart.compareTo(bStart);
        });

      final profile = await profileFuture;
      final resolvedUserId = (widget.userId ?? profile.userId).trim();
      if (resolvedUserId.isEmpty) {
        setState(() {
          _snapshot = null;
          _snapshotError = 'Could not resolve user id';
          _loadingSnapshot = false;
          _resolvedUserId = null;
        });
        return;
      }
      _resolvedUserId = resolvedUserId;

      Tournament? joinedTournament;
      _Membership? membership;
      for (final t in upcoming) {
        final teams = await _teamsService.list(t.tournamentId);
        final match = _findMembership(teams, resolvedUserId);
        if (match != null) {
          joinedTournament = t;
          membership = match;
          break;
        }
      }

      List<_FavoriteDisplay> favorites = [];
      var hasFavorites = false;
      if (membership != null && profile.favoriteChampions != null) {
        final favIds = _favoritesForRole(profile.favoriteChampions!, membership.role);
        hasFavorites = favIds.isNotEmpty;
        if (favIds.isNotEmpty) {
          final champions = await _championService.loadChampions();
          _ddVersion = await _championService.getCachedVersion();
          favorites = favIds
              .map((id) {
                final champ = _championService.findById(champions, id);
                if (champ != null) {
                  return _FavoriteDisplay(id: champ.id, label: champ.name, imageFull: champ.imageFull);
                }
                return _FavoriteDisplay(id: id, label: id, imageFull: null);
              })
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        if (joinedTournament != null && membership != null) {
          _snapshot = _SnapshotData(
            tournament: joinedTournament,
            team: membership.team,
            role: membership.role,
            favorites: favorites,
            hasFavorites: hasFavorites,
          );
        } else {
          _snapshot = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _snapshotError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSnapshot = false;
        });
      }
    }
  }

  DateTime? _safeParse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return null;
    }
  }

  _Membership? _findMembership(List<Team> teams, String userId) {
    final current = userId.toLowerCase();
    for (final team in teams) {
      final members = team.members ?? {};
      for (final entry in members.entries) {
        if ((entry.value).toString().toLowerCase() == current) {
          return _Membership(team: team, role: entry.key);
        }
      }
    }
    return null;
  }

  List<String> _favoritesForRole(Map<String, List<String>> favorites, String role) {
    final match = favorites.entries.firstWhere(
      (e) => e.key.toLowerCase() == role.toLowerCase(),
      orElse: () => MapEntry(role, const []),
    );
    return match.value;
  }

  String? _championImageUrl(String? imageFull) {
    if (imageFull == null || imageFull.isEmpty) return null;
    final version = _ddVersion;
    if (version == null || version.isEmpty) return null;
    return 'https://ddragon.leagueoflegends.com/cdn/$version/img/champion/$imageFull';
  }

  String _maskIdentifier(String? value) {
    if (value == null || value.isEmpty || value == 'Open') return 'Open';
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
    final members = team.members ?? {};
    final memberId = members[role];
    if (memberId == null || memberId == 'Open') return 'Open';
    final display = team.memberDisplayNames?[role];
    return _labelForUser(memberId, display);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _isSignedIn;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSnapshotCard(context),
          if (!signedIn) ...[
            const SizedBox(height: 20),
            _buildHero(context),
            const SizedBox(height: 24),
            _buildFeatureGrid(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSnapshotCard(BuildContext context) {
    final theme = Theme.of(context);
    final hasBackendSession = AuthService.instance.backendToken != null;
    final hasUser = widget.userId != null || _resolvedUserId != null;
    final signedIn = hasBackendSession || hasUser;

    if (_loadingSnapshot) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(width: 12),
              Expanded(child: Text('Loading your snapshot...')),
            ],
          ),
        ),
      );
    }

    if (!signedIn) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.login, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sign in to see your upcoming tournaments and favorites.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_snapshotError != null) {
      return Card(
        color: theme.colorScheme.errorContainer.withOpacity(0.9),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to load snapshot: $_snapshotError',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadSnapshot,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_snapshot == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.event_available, color: theme.colorScheme.outline),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No upcoming tournaments joined yet. Find a tournament and grab a role.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (widget.navEnabled)
                TextButton(
                  onPressed: () => context.go('/tournaments'),
                  child: const Text('Browse tournaments'),
                ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final start = _safeParse(snapshot.tournament.startTime);
    final startLabel = start != null
        ? DateFormat('EEE, MMM d • h:mm a').format(start)
        : snapshot.tournament.startTime;
    final tournamentLabel = snapshot.tournament.nameKeySecondary?.isNotEmpty == true
        ? snapshot.tournament.nameKeySecondary!
        : (snapshot.tournament.name?.isNotEmpty == true
            ? snapshot.tournament.name!
            : snapshot.tournament.tournamentId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Your next tournament', style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh snapshot',
                  onPressed: _loadSnapshot,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tournamentLabel,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(startLabel, style: theme.textTheme.bodyMedium),
            if (widget.userDisplayName != null) ...[
              const SizedBox(height: 4),
              Text('Player: ${widget.userDisplayName}', style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.group, size: 18),
                  label: Text(snapshot.team.displayName ?? snapshot.team.teamId),
                ),
                Chip(
                  avatar: const Icon(Icons.badge, size: 18),
                  label: Text('Role: ${snapshot.role}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Preferred champions for ${snapshot.role}',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.navEnabled)
                TextButton.icon(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.favorite_border),
                  label: const Text('Edit favorites'),
                ),
            ],
          ),
            const SizedBox(height: 6),
            if (snapshot.favorites.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: snapshot.favorites
                    .map(
                      (fav) => Chip(
                        avatar: CircleAvatar(
                          backgroundImage: _championImageUrl(fav.imageFull) != null
                              ? NetworkImage(_championImageUrl(fav.imageFull)!)
                              : null,
                          child: _championImageUrl(fav.imageFull) == null
                              ? Text(fav.label.isNotEmpty ? fav.label[0] : '?')
                              : null,
                        ),
                        label: Text(fav.label),
                      ),
                    )
                    .toList(),
              )
            else
              Text(
                snapshot.hasFavorites
                    ? 'Favorites saved, but champion data is unavailable.'
                    : 'Add up to three favorites for this role to see them here.',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Text(
              'Team lineup',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _roleOrder.map((role) {
                final label = _memberLabel(snapshot.team, role);
                final isSelf = _resolvedUserId != null &&
                    (snapshot.team.members?[role]?.toLowerCase() == _resolvedUserId?.toLowerCase());
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: isSelf ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                    child: Text(
                      role[0],
                      style: TextStyle(
                        color: isSelf ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  label: Text('$role: $label'),
                  backgroundColor:
                      label == 'Open' ? theme.colorScheme.surfaceVariant.withOpacity(0.6) : null,
                );
              }).toList(),
            ),
            if (widget.navEnabled) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go(
                      '/teams/${snapshot.tournament.tournamentId}/${snapshot.team.teamId}/draft',
                      extra: {
                        'teamName': snapshot.team.displayName ?? snapshot.team.teamId,
                        'tournamentLabel': tournamentLabel,
                      },
                    ),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Draft deep dive'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/teams'),
                    icon: const Icon(Icons.groups),
                    label: const Text('View teams'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/tournaments'),
                    icon: const Icon(Icons.event),
                    label: const Text('Tournaments'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.secondary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.28),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LEAGUE OF LEGENDS CLASH',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onPrimary.withOpacity(0.82),
              letterSpacing: 0.08,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find your squad before Riot opens the gates.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Clash Companion keeps player signups in one place, matches roles fast, and gets teams ready for tournament day without last-minute chaos.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onPrimary.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: widget.navEnabled ? () => context.go('/tournaments') : null,
                child: const Text('View tournaments'),
              )
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final features = [
      {
        'title': 'Know when the next Tournament is!',
        'description': 'We pull upcoming tournaments from Riot and notify you.',
      },
      {
        'title': 'Build your team ahead of time!',
        'description': 'Draft comps, swap roles, and sanity-check your roster before Riot opens registrations.',
      }
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        double childAspectRatio = 2.6;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
          childAspectRatio = 0.9; // give cards more height on narrow screens
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
          childAspectRatio = 1.6;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      feature['title']!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      feature['description']!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

