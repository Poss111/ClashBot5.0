import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/tournaments_service.dart';
import '../models/tournament.dart';
import '../theme.dart';

class AdminScreen extends StatefulWidget {
  final String? userEmail;
  const AdminScreen({super.key, this.userEmail});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _svc = TournamentsService();
  final _tournamentIdController = TextEditingController();
  final _themeIdController = TextEditingController(text: '1');
  final _nameKeyController = TextEditingController(text: 'rift');
  final _nameKeySecondaryController = TextEditingController(text: 'Clash Night');
  final _regionController = TextEditingController(text: 'NA');
  final _registrationTimeController = TextEditingController();
  final _startTimeController = TextEditingController();

  // Edit dialog controllers are created per dialog

  bool _loading = false;
  bool _listLoading = false;
  String? _error;
  String? _success;
  List<Tournament> _tournaments = [];

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _tournamentIdController.dispose();
    _themeIdController.dispose();
    _nameKeyController.dispose();
    _nameKeySecondaryController.dispose();
    _regionController.dispose();
    _registrationTimeController.dispose();
    _startTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _listLoading = true;
      _error = null;
    });
    try {
      final items = await _svc.list();
      setState(() {
        _tournaments = items;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load tournaments: $e');
    } finally {
      if (mounted) {
        setState(() => _listLoading = false);
      }
    }
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    final initialDate = DateTime.tryParse(controller.text) ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
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

  String? _validateInputs() {
    if (_tournamentIdController.text.trim().isEmpty) return 'Tournament ID is required';
    if (_nameKeySecondaryController.text.trim().isEmpty) return 'Tournament name is required';
    final reg = DateTime.tryParse(_registrationTimeController.text);
    final start = DateTime.tryParse(_startTimeController.text);
    if (reg == null) return 'Registration time is required';
    if (start == null) return 'Start time is required';
    final now = DateTime.now();
    if (reg.isBefore(now)) return 'Registration time cannot be in the past';
    if (start.isBefore(now)) return 'Start time cannot be in the past';
    if (start.isBefore(reg)) return 'Start time must be after registration time';
    return null;
  }

  Future<void> _createTournament() async {
    final validation = _validateInputs();
    if (validation != null) {
      setState(() {
        _error = validation;
        _success = null;
      });
      return;
    }

    final reg = DateTime.parse(_registrationTimeController.text);
    final start = DateTime.parse(_startTimeController.text);

    final payload = {
      'tournamentId': _tournamentIdController.text.trim(),
      'themeId': int.tryParse(_themeIdController.text.trim()),
      'nameKey': _nameKeyController.text.trim(),
      'nameKeySecondary': _nameKeySecondaryController.text.trim(),
      'region': _regionController.text.trim(),
      'schedule': [
        {
          'id': 1,
          'registrationTime': reg.millisecondsSinceEpoch,
          'startTime': start.millisecondsSinceEpoch,
        }
      ]
    };

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      await _svc.createTournament(payload);
      setState(() => _success = 'Tournament created');
      await _loadTournaments();
    } catch (e) {
      setState(() => _error = 'Create failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_success!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Tournament', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tournamentIdController,
                    decoration: const InputDecoration(labelText: 'Tournament ID'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameKeySecondaryController,
                    decoration: const InputDecoration(labelText: 'Tournament Name (nameKeySecondary)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameKeyController,
                    decoration: const InputDecoration(labelText: 'Name Key'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _themeIdController,
                          decoration: const InputDecoration(labelText: 'Theme ID'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _regionController,
                          decoration: const InputDecoration(labelText: 'Region'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _registrationTimeController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Registration Time',
                            hintText: 'Pick date & time',
                          ),
                          onTap: () => _pickDateTime(_registrationTimeController),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _startTimeController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            hintText: 'Pick date & time',
                          ),
                          onTap: () => _pickDateTime(_startTimeController),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _createTournament,
                    child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text('Create'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tournaments', style: Theme.of(context).textTheme.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _listLoading ? null : _loadTournaments,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_listLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else if (_tournaments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No tournaments found'),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Edit')),
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Registration')),
                          DataColumn(label: Text('Start')),
                          DataColumn(label: Text('Region')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: _tournaments
                            .map(
                              (t) => DataRow(
                                cells: [
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Edit tournament',
                                      onPressed: () => _openEditDialog(t),
                                    ),
                                  ),
                                  DataCell(Text(t.tournamentId)),
                                  DataCell(Text(t.name ?? t.nameKeySecondary ?? '')),
                                  DataCell(Text(_formatLocal(_getRegistrationIso(t)))),
                                  DataCell(Text(_formatLocal(t.startTime))),
                                  DataCell(Text(t.region ?? '-')),
                                  DataCell(Text(t.status ?? '-')),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(Tournament t) async {
    final nameKeyController = TextEditingController(text: t.nameKey ?? '');
    final nameKeySecondaryController = TextEditingController(text: t.nameKeySecondary ?? t.name ?? '');
    final themeIdController = TextEditingController(text: (t.themeId ?? '').toString());
    final regionController = TextEditingController(text: t.region ?? '');
    final registrationTimeController = TextEditingController(
      text: t.registrationTime ??
          (t.schedule != null && t.schedule!.isNotEmpty ? _toIso(t.schedule!.first['registrationTime']) : ''),
    );
    final startTimeController = TextEditingController(
      text: t.startTime.isNotEmpty
          ? t.startTime
          : (t.schedule != null && t.schedule!.isNotEmpty ? _toIso(t.schedule!.first['startTime']) : ''),
    );

    String saveLabel = 'Save';
    bool dirty = false;
    bool saving = false;
    bool coolDown = false;
    Color? saveColor;

    Map<String, String> initial = {
      'nameKey': nameKeyController.text,
      'nameKeySecondary': nameKeySecondaryController.text,
      'themeId': themeIdController.text,
      'region': regionController.text,
      'registrationTime': registrationTimeController.text,
      'startTime': startTimeController.text,
    };

    bool isDirty(Map<String, String> current) {
      for (final entry in initial.entries) {
        if ((current[entry.key] ?? '').trim() != entry.value.trim()) return true;
      }
      return false;
    }

    Future<void> handleSave(void Function(void Function()) setState) async {
      setState(() {
        saving = true;
        saveLabel = 'Saving...';
      });
      final reg = _parseDate(registrationTimeController.text);
      final start = _parseDate(startTimeController.text);
      if (reg == null || start == null) {
        setState(() {
          saving = false;
          saveLabel = 'Save';
        });
        return;
      }
      final payload = {
        'themeId': int.tryParse(themeIdController.text.trim()),
        'nameKey': nameKeyController.text.trim(),
        'nameKeySecondary': nameKeySecondaryController.text.trim(),
        'region': regionController.text.trim(),
        'schedule': [
          {
            'id': 1,
            'registrationTime': reg.millisecondsSinceEpoch,
            'startTime': start.millisecondsSinceEpoch,
          }
        ]
      };
      try {
        await _svc.updateTournament(t.tournamentId, payload);
        setState(() {
          saving = false;
          saveLabel = 'Success';
          saveColor = AppBrandColors.success;
          coolDown = true;
          dirty = false;
        });
        await _loadTournaments();
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) {
          setState(() {
            coolDown = false;
            saveLabel = 'Save';
            saveColor = null;
          });
        }
      } catch (e) {
        setState(() {
          saving = false;
          coolDown = true;
          saveLabel = 'Error';
          saveColor = Theme.of(context).colorScheme.error;
        });
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) {
          setState(() {
            coolDown = false;
            saveLabel = 'Save';
            saveColor = null;
          });
        }
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          final current = {
            'nameKey': nameKeyController.text,
            'nameKeySecondary': nameKeySecondaryController.text,
            'themeId': themeIdController.text,
            'region': regionController.text,
            'registrationTime': registrationTimeController.text,
            'startTime': startTimeController.text,
          };
          dirty = isDirty(current);
          final saveDisabled = saving || coolDown || !dirty;

          return AlertDialog(
            title: const Text('Edit Tournament'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameKeySecondaryController,
                    decoration: const InputDecoration(labelText: 'Tournament Name (nameKeySecondary)'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameKeyController,
                    decoration: const InputDecoration(labelText: 'Name Key'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: themeIdController,
                          decoration: const InputDecoration(labelText: 'Theme ID'),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: regionController,
                          decoration: const InputDecoration(labelText: 'Region'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: registrationTimeController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Registration Time',
                            hintText: 'Pick date & time',
                          ),
                          onTap: () async {
                            await _pickDateTime(registrationTimeController);
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: startTimeController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            hintText: 'Pick date & time',
                          ),
                          onTap: () async {
                            await _pickDateTime(startTimeController);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: saveColor,
                  foregroundColor:
                      saveColor != null ? Theme.of(context).colorScheme.onPrimary : null,
                ),
                onPressed: saveDisabled ? null : () => handleSave(setState),
                child: saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(saveLabel),
              ),
            ],
          );
        });
      },
    );
  }

  String _toIso(dynamic value) {
    if (value == null) return '';
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    if (value is String) return value;
    return '';
  }

  DateTime? _parseDate(String input) {
    if (input.isEmpty) return null;
    return DateTime.tryParse(input);
  }

  String _formatLocal(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, y h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String? _getRegistrationIso(Tournament t) {
    if (t.registrationTime != null && t.registrationTime!.isNotEmpty) return t.registrationTime;
    if (t.schedule != null && t.schedule!.isNotEmpty) {
      final val = t.schedule!.first['registrationTime'];
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val).toIso8601String();
      if (val is String) return val;
    }
    return null;
  }
}


