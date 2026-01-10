import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/draft.dart';
import '../models/champion.dart';
import '../services/champion_data_service.dart';
import '../services/drafts_service.dart';

class TeamDraftScreen extends StatefulWidget {
  final String tournamentId;
  final String teamId;
  final String? teamName;
  final String? tournamentLabel;

  const TeamDraftScreen({
    super.key,
    required this.tournamentId,
    required this.teamId,
    this.teamName,
    this.tournamentLabel,
  });

  @override
  State<TeamDraftScreen> createState() => _TeamDraftScreenState();
}

class _TeamDraftScreenState extends State<TeamDraftScreen> {
  final _draftsService = DraftsService();
  final _championService = ChampionDataService();
  late DraftProposal _draft;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late Future<List<Champion>> _championsFuture;
  final Map<String, TextEditingController> _slotControllers = {};

  @override
  void initState() {
    super.initState();
    _draft = DraftProposal.empty(tournamentId: widget.tournamentId, teamId: widget.teamId);
    _championsFuture = _loadChampions();
    _loadDraft();
  }

  @override
  void dispose() {
    _resetControllers(disposeControllers: false);
    super.dispose();
  }

  Future<List<Champion>> _loadChampions() async {
    return _championService.loadChampions();
  }

  Future<void> _loadDraft() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final existing = await _draftsService.fetchDraft(widget.tournamentId, widget.teamId);
      if (!mounted) return;
      setState(() {
        _resetControllers();
        _draft = existing ?? DraftProposal.empty(tournamentId: widget.tournamentId, teamId: widget.teamId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveDraft() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _draftsService.saveDraft(_draft);
      if (!mounted) return;
      setState(() {
        _resetControllers();
        _draft = saved;
      });
      _showSnack('Draft saved');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _showSnack('Failed to save draft: $_error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _copyShareLink() async {
    final link = '/teams/${widget.tournamentId}/${widget.teamId}/draft';
    await Clipboard.setData(ClipboardData(text: link));
    _showSnack('Link copied');
  }

  void _updateNotes(String value) {
    setState(() {
      _draft = _draft.copyWith(notes: value);
    });
  }

  void _updateSideValue({
    required bool isOurSide,
    required String field,
    required int index,
    required String value,
  }) {
    setState(() {
      final side = isOurSide ? _draft.ourSide : _draft.enemySide;
      DraftSide updated;
      switch (field) {
        case 'firstRoundBans':
          final items = List<String>.from(side.firstRoundBans)..[index] = value;
          updated = side.copyWith(firstRoundBans: items);
          break;
        case 'secondRoundBans':
          final items = List<String>.from(side.secondRoundBans)..[index] = value;
          updated = side.copyWith(secondRoundBans: items);
          break;
        case 'firstRoundPicks':
          final items = List<String>.from(side.firstRoundPicks)..[index] = value;
          updated = side.copyWith(firstRoundPicks: items);
          break;
        case 'secondRoundPicks':
          final items = List<String>.from(side.secondRoundPicks)..[index] = value;
          updated = side.copyWith(secondRoundPicks: items);
          break;
        default:
          updated = side;
      }
      _draft = isOurSide ? _draft.copyWith(ourSide: updated) : _draft.copyWith(enemySide: updated);
    });
  }

  TextEditingController _controllerForSlot({
    required bool isOurSide,
    required String fieldKey,
    required int index,
    required List<Champion> champions,
  }) {
    final slotKey = '${isOurSide ? 'our' : 'enemy'}:$fieldKey:$index';
    final existing = _slotControllers[slotKey];
    if (existing != null) return existing;
    final controller = TextEditingController();
    // Prefill with champion name if we can resolve it.
    final values = _valuesForField(isOurSide: isOurSide, fieldKey: fieldKey);
    if (index < values.length) {
      final id = values[index];
      final name = _championName(id, champions) ?? id;
      controller.text = name;
    }
    _slotControllers[slotKey] = controller;
    return controller;
  }

  List<String> _valuesForField({required bool isOurSide, required String fieldKey}) {
    final side = isOurSide ? _draft.ourSide : _draft.enemySide;
    switch (fieldKey) {
      case 'firstRoundBans':
        return side.firstRoundBans;
      case 'secondRoundBans':
        return side.secondRoundBans;
      case 'firstRoundPicks':
        return side.firstRoundPicks;
      case 'secondRoundPicks':
        return side.secondRoundPicks;
      default:
        return const [];
    }
  }

  String? _championName(String? id, List<Champion> champions) {
    if (id == null || id.isEmpty) return null;
    final lower = id.toLowerCase();
    for (final c in champions) {
      if (c.id.toLowerCase() == lower || c.name.toLowerCase() == lower || c.key == id) {
        return c.name;
      }
    }
    return null;
  }

  Iterable<Champion> _champOptions({
    required List<Champion> champions,
    required bool isOurSide,
    required String fieldKey,
    required int index,
    required String query,
    required String currentValue,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final allValues = _allSelectedValues();
    return champions
        .where((c) {
          if (c.id == currentValue) return true;
          if (allValues.contains(c.id)) return false;
          if (normalizedQuery.isEmpty) return true;
          return c.name.toLowerCase().contains(normalizedQuery);
        })
        .take(5);
  }

  Set<String> _allValuesForSide(bool isOurSide) {
    final side = isOurSide ? _draft.ourSide : _draft.enemySide;
    return {
      ...side.firstRoundBans.where((e) => e.isNotEmpty),
      ...side.secondRoundBans.where((e) => e.isNotEmpty),
      ...side.firstRoundPicks.where((e) => e.isNotEmpty),
      ...side.secondRoundPicks.where((e) => e.isNotEmpty),
    };
  }

  Set<String> _allSelectedValues() {
    return {
      ..._allValuesForSide(true),
      ..._allValuesForSide(false),
    };
  }

  void _resetControllers({bool disposeControllers = false}) {
    if (disposeControllers) {
      for (final controller in _slotControllers.values) {
        controller.dispose();
      }
    }
    _slotControllers.clear();
  }

  Widget _buildSection({
    required String title,
    required List<String> values,
    required String fieldKey,
    required bool isOurSide,
    required List<Champion> champions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(values.length, (index) {
            final controller = _controllerForSlot(
              isOurSide: isOurSide,
              fieldKey: fieldKey,
              index: index,
              champions: champions,
            );
            return SizedBox(
              width: 200,
              child: Autocomplete<Champion>(
                optionsBuilder: (textEditingValue) {
                  final selections = _valuesForField(isOurSide: isOurSide, fieldKey: fieldKey);
                  if (selections.length > index && selections[index].isNotEmpty) {
                    // Allow replacing existing value; still show options.
                  }
                  final currentValue = index < selections.length ? selections[index] : '';
                  return _champOptions(
                    champions: champions,
                    isOurSide: isOurSide,
                    fieldKey: fieldKey,
                    index: index,
                    query: textEditingValue.text,
                    currentValue: currentValue,
                  );
                },
                displayStringForOption: (c) => c.name,
                fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                  if (textController != controller) {
                    textController
                      ..text = controller.text
                      ..selection = controller.selection;
                    _slotControllers['${isOurSide ? 'our' : 'enemy'}:$fieldKey:$index'] = textController;
                  }
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: '${title.split(' ').first} ${index + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  );
                },
                onSelected: (Champion champ) {
                  _updateSideValue(
                    isOurSide: isOurSide,
                    field: fieldKey,
                    index: index,
                    value: champ.id,
                  );
                  setState(() {
                    controller.text = champ.name;
                  });
                },
                optionsViewBuilder: (context, onSelected, options) {
                  final opts = options.toList();
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: opts.length,
                        itemBuilder: (context, i) {
                          final champ = opts[i];
                          return ListTile(
                            dense: true,
                            title: Text(champ.name),
                            subtitle: champ.tags.isNotEmpty ? Text(champ.tags.join('/')) : null,
                            onTap: () => onSelected(champ),
                          );
                        },
                      ),
                    ),
                  );
                },
                optionsMaxHeight: 220,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSideForm({
    required String label,
    required DraftSide side,
    required bool isOurSide,
    required List<Champion> champions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildSection(
          title: '1st round bans',
          values: side.firstRoundBans,
          fieldKey: 'firstRoundBans',
          isOurSide: isOurSide,
          champions: champions,
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: '2nd round bans',
          values: side.secondRoundBans,
          fieldKey: 'secondRoundBans',
          isOurSide: isOurSide,
          champions: champions,
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: '1st round picks',
          values: side.firstRoundPicks,
          fieldKey: 'firstRoundPicks',
          isOurSide: isOurSide,
          champions: champions,
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: '2nd round picks',
          values: side.secondRoundPicks,
          fieldKey: 'secondRoundPicks',
          isOurSide: isOurSide,
          champions: champions,
        ),
      ],
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
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
    final teamName = widget.teamName ?? widget.teamId;
    final tournamentLabel = widget.tournamentLabel ?? widget.tournamentId;
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draft deep dive',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$teamName • $tournamentLabel',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh draft',
                  onPressed: _loading ? null : _loadDraft,
                  icon: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.error.withOpacity(0.35)),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Champion>>(
                future: _championsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Failed to load champions: ${snapshot.error}'));
                  }
                  final champs = snapshot.data ?? const <Champion>[];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildSideForm(
                                  label: 'Your side',
                                  side: _draft.ourSide,
                                  isOurSide: true,
                                  champions: champs,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildSideForm(
                                  label: 'Enemy side',
                                  side: _draft.enemySide,
                                  isOurSide: false,
                                  champions: champs,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          TabBar(
                            labelColor: theme.colorScheme.primary,
                            indicatorColor: theme.colorScheme.primary,
                            tabs: const [
                              Tab(text: 'Your team'),
                              Tab(text: 'Enemy team'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: TabBarView(
                              children: [
                                SingleChildScrollView(
                                  child: _buildSideForm(
                                    label: 'Your side',
                                    side: _draft.ourSide,
                                    isOurSide: true,
                                    champions: champs,
                                  ),
                                ),
                                SingleChildScrollView(
                                  child: _buildSideForm(
                                    label: 'Enemy side',
                                    side: _draft.enemySide,
                                    isOurSide: false,
                                    champions: champs,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _draft.notes ?? '',
              minLines: 2,
              maxLines: 4,
              onChanged: _updateNotes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _copyShareLink,
                  icon: const Icon(Icons.link),
                  label: const Text('Copy share link'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _saveDraft,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save draft'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

