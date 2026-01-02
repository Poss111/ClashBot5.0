import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tournament.dart';
import '../services/tournaments_service.dart';

class TournamentsListScreen extends StatefulWidget {
  final String? userEmail;
  const TournamentsListScreen({super.key, this.userEmail});

  @override
  State<TournamentsListScreen> createState() => _TournamentsListScreenState();
}

class _WeekdayLabel extends StatelessWidget {
  final String text;
  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TournamentsListScreenState extends State<TournamentsListScreen> {
  final TournamentsService _tournamentsService = TournamentsService();
  Map<String, List<Tournament>> _dayBuckets = {};
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTime.now();
  bool _loading = false;
  String? _error;
  bool _backendUnreachable = false;

  @override
  void initState() {
    super.initState();
    _load();
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
        _dayBuckets = _bucketByDay(tournaments);
        if (_dayBuckets.isNotEmpty) {
          // If selected day has no tournaments, snap to first available
          final selectedKey = _dayKey(_selectedDay);
          if (!_dayBuckets.containsKey(selectedKey)) {
            _selectedDay = DateTime.parse(_dayBuckets.keys.first);
            _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
          }
        }
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
          const SizedBox(height: 16),
          _buildCalendarCard(),
          const SizedBox(height: 16),
          _buildSelectedDayList(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
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

  Widget _buildCalendarCard() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekday = firstDay.weekday % 7; // Sunday = 0
    final cells = <DateTime?>[];
    for (int i = 0; i < firstWeekday; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final rows = <TableRow>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(
        TableRow(
          children: List.generate(7, (j) => _buildDayCell(cells[i + j])),
        ),
      );
    }

    final monthLabel = DateFormat.yMMMM().format(_visibleMonth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      monthLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next month',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Table(
              children: [
                const TableRow(
                  children: [
                    _WeekdayLabel('Sun'),
                    _WeekdayLabel('Mon'),
                    _WeekdayLabel('Tue'),
                    _WeekdayLabel('Wed'),
                    _WeekdayLabel('Thu'),
                    _WeekdayLabel('Fri'),
                    _WeekdayLabel('Sat'),
                  ],
                ),
                ...rows,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime? day) {
    final isMobile = _isMobile(context);
    final isToday = day != null &&
        day.year == DateTime.now().year &&
        day.month == DateTime.now().month &&
        day.day == DateTime.now().day;
    final selected = day != null &&
        day.year == _selectedDay.year &&
        day.month == _selectedDay.month &&
        day.day == _selectedDay.day;
    final key = day != null ? _dayKey(day) : null;
    final count = key != null ? (_dayBuckets[key]?.length ?? 0) : 0;
    final hasTournaments = count > 0;

    if (day == null) {
      return const SizedBox(height: 48);
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDay = day;
        });
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : (isMobile && hasTournaments
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                  : null),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : (isToday ? Theme.of(context).colorScheme.secondary : null),
                  ),
                ),
                const Spacer(),
                if (!isMobile && hasTournaments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayList() {
    final key = _dayKey(_selectedDay);
    final items = _dayBuckets[key] ?? [];
    final label = DateFormat.yMMMMd().format(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tournaments on $label', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('No tournaments scheduled for this day.')
        else
          ...items.map((t) => _buildTournamentCard(t)),
      ],
    );
  }

  Map<String, List<Tournament>> _bucketByDay(List<Tournament> tournaments) {
    final buckets = <String, List<Tournament>>{};
    for (final t in tournaments) {
      DateTime? dt;
      try {
        dt = DateTime.parse(t.startTime);
      } catch (_) {
        continue;
      }
      final key = _dayKey(dt);
      buckets.putIfAbsent(key, () => []);
      buckets[key]!.add(t);
    }
    return buckets;
  }

  String _dayKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

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

  Widget _buildTournamentCard(Tournament tournament) {
    final theme = Theme.of(context);
    DateTime? startTime;
    DateTime? registrationTime;
    final status = (tournament.status ?? 'N/A').toUpperCase();
    try {
      startTime = DateTime.parse(tournament.startTime);
    } catch (e) {
      // Invalid date format
    }
    if (tournament.registrationTime != null) {
      try {
        registrationTime = DateTime.parse(tournament.registrationTime!);
      } catch (_) {}
    }
    // Ensure registration precedes start for display; if inverted, swap.
    if (startTime != null && registrationTime != null && registrationTime.isAfter(startTime)) {
      final tmp = startTime;
      startTime = registrationTime;
      registrationTime = tmp;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  _statusIconData(status),
                  color: _statusIconColor(status, theme),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tournament.nameKeySecondary?.isNotEmpty == true
                        ? tournament.nameKeySecondary!
                        : (tournament.name?.isNotEmpty == true ? tournament.name! : tournament.tournamentId),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: Icons.public,
                  label: 'Region',
                  value: tournament.region ?? 'N/A',
                ),
                if (registrationTime != null)
                  _buildInfoChip(
                    icon: Icons.login,
                    label: 'Registration',
                    value: DateFormat('EEE, MMM d · h:mm a').format(registrationTime),
                  ),
                _buildInfoChip(
                  icon: Icons.event,
                  label: 'Start',
                  value: startTime != null
                      ? DateFormat('EEE, MMM d · h:mm a').format(startTime)
                      : tournament.startTime,
                ),
                _buildInfoChip(
                  icon: Icons.numbers,
                  label: 'ID',
                  value: tournament.tournamentId,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    Color? background,
  }) {
    final theme = Theme.of(context);
    return Chip(
      backgroundColor: background ?? theme.colorScheme.surfaceVariant.withOpacity(0.6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade800)),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  IconData _statusIconData(String status) {
    switch (status.toLowerCase()) {
      case 'upcoming':
      case 'open':
        return Icons.schedule;
      case 'in_progress':
      case 'live':
        return Icons.bolt;
      case 'closed':
      case 'locked':
        return Icons.lock;
      case 'cancelled':
      case 'canceled':
        return Icons.cancel;
      case 'completed':
      case 'finished':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Color _statusIconColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'upcoming':
      case 'open':
        return Colors.green.shade600;
      case 'in_progress':
      case 'live':
        return Colors.orange.shade700;
      case 'closed':
      case 'locked':
        return Colors.blueGrey.shade600;
      case 'cancelled':
      case 'canceled':
        return Colors.red.shade600;
      case 'completed':
      case 'finished':
        return Colors.blue.shade700;
      default:
        return theme.colorScheme.primary;
    }
  }

  bool _isMobile(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final platform = Theme.of(context).platform;
    final isSmallScreen = width < 640;
    final isHandset = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    return isSmallScreen || isHandset;
  }
}

