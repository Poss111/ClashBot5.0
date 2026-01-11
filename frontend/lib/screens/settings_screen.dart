import 'package:flutter/material.dart';
import '../models/champion.dart';
import '../services/champion_data_service.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialDisplayName;
  final Future<void> Function(String newName)? onDisplayNameChanged;

  const SettingsScreen({super.key, this.initialDisplayName, this.onDisplayNameChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _championService = ChampionDataService();
  final List<String> _roleOrder = const ['Top', 'Jungle', 'Mid', 'Bot', 'Support'];
  final Map<String, TextEditingController> _favoriteControllers = {};
  late final TextEditingController _nameController;
  bool _saving = false;
  bool _favoritesSaving = false;
  bool _rolesSaving = false;
  bool _loadingProfile = false;
  String? _error;
  String? _success;
  Map<String, List<String>> _favoriteChampions = {};
  String? _mainRole;
  String? _offRole;
  late Future<List<Champion>> _championsFuture;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDisplayName ?? '');
    _championsFuture = _championService.loadChampions();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _favoriteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Display name is required';
    if (text.length < 3 || text.length > 32) return 'Use 3-32 characters';
    if (text.contains('@')) return 'Do not use an email address';
    final regex = RegExp(r"^[a-zA-Z0-9 _.'-]+$");
    if (!regex.hasMatch(text)) return 'Only letters, numbers, spaces, and _ . \' - allowed';
    return null;
  }

  Future<void> _save() async {
    final currentFocus = FocusScope.of(context);
    if (currentFocus.hasFocus) currentFocus.unfocus();
    setState(() {
      _error = null;
      _success = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final value = _nameController.text.trim();
    setState(() => _saving = true);
    try {
      await _userService.setDisplayName(value);
      await widget.onDisplayNameChanged?.call(value);
      if (!mounted) return;
      setState(() {
        _success = 'Display name updated';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final profile = await _userService.getCurrentUser();
      if (!mounted) return;
      setState(() {
        final favs = <String, List<String>>{};
        (profile.favoriteChampions ?? {}).forEach((k, v) {
          favs[k] = v.where((e) => e.isNotEmpty).take(3).toList();
        });
        _favoriteChampions = favs;
        _mainRole = profile.mainRole;
        _offRole = profile.offRole;
        if ((_nameController.text.trim().isEmpty) && (profile.displayName?.trim().isNotEmpty ?? false)) {
          _nameController.text = profile.displayName!.trim();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _error ?? 'Failed to load profile: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  Future<void> _saveFavorites() async {
    setState(() {
      _error = null;
      _success = null;
      _favoritesSaving = true;
    });
    try {
      final cleaned = <String, List<String>>{};
      _favoriteChampions.forEach((role, list) {
        final filtered = list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().take(3).toList();
        if (filtered.isNotEmpty) cleaned[role] = filtered;
      });
      if (cleaned.isEmpty) {
        setState(() {
          _error = 'Select at least one favorite champion';
          _favoritesSaving = false;
        });
        return;
      }
      await _userService.setFavoriteChampions(cleaned);
      if (!mounted) return;
      setState(() {
        _success = 'Favorite champions updated';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save favorites: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _favoritesSaving = false);
      }
    }
  }

  Future<void> _saveRoles() async {
    final currentFocus = FocusScope.of(context);
    if (currentFocus.hasFocus) currentFocus.unfocus();
    setState(() {
      _error = null;
      _success = null;
    });
    final main = _mainRole;
    final off = _offRole;
    if (main == null || main.isEmpty) {
      setState(() {
        _error = 'Select a main role';
      });
      return;
    }
    if (off != null && off.isNotEmpty && off == main) {
      setState(() {
        _error = 'Main and off roles must be different';
      });
      return;
    }
    setState(() => _rolesSaving = true);
    try {
      final result = await _userService.setPreferredRoles(mainRole: main, offRole: off);
      if (!mounted) return;
      setState(() {
        _mainRole = result.mainRole ?? main;
        _offRole = result.offRole;
        _success = 'Preferred roles updated';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save roles: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _rolesSaving = false);
      }
    }
  }

  TextEditingController _controllerForRole(String role, List<Champion> champions) {
    final existing = _favoriteControllers[role];
    if (existing != null) return existing;
    final controller = TextEditingController();
    _favoriteControllers[role] = controller;
    return controller;
  }

  Champion? _championForId(List<Champion> champions, String? id) {
    if (id == null) return null;
    final lower = id.toLowerCase();
    for (final c in champions) {
      if (c.id.toLowerCase() == lower || c.name.toLowerCase() == lower || c.key == id) {
        return c;
      }
    }
    return null;
  }

  void _addFavorite(String role, Champion champ) {
    final list = _favoriteChampions[role] ?? [];
    if (list.contains(champ.id)) return;
    if (list.length >= 3) return;
    setState(() {
      final updated = List<String>.from(list)..add(champ.id);
      _favoriteChampions[role] = updated;
    });
  }

  void _removeFavorite(String role, String champId) {
    final list = _favoriteChampions[role] ?? [];
    setState(() {
      _favoriteChampions[role] = list.where((id) => id != champId).toList();
    });
  }

  Widget _favoriteAutocomplete(String role, List<Champion> champions) {
    final controller = _controllerForRole(role, champions);
    final selections = _favoriteChampions[role] ?? [];
    return Autocomplete<Champion>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (selections.length >= 3) return const Iterable<Champion>.empty();
        if (query.isEmpty) return const Iterable<Champion>.empty();
        return champions
            .where((c) => !selections.contains(c.id) && c.name.toLowerCase().contains(query))
            .take(5);
      },
      displayStringForOption: (c) => c.name,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        // Keep controller in sync with our stored instance.
        if (textController != controller) {
          textController
            ..text = controller.text
            ..selection = controller.selection;
          _favoriteControllers[role] = textController;
        }
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: '$role favorite'),
          onChanged: (val) {
            if (val.trim().isEmpty) {
              setState(() {
                // Do not clear selections; just reset input.
              });
            }
          },
        );
      },
      onSelected: (Champion champ) {
        setState(() {
          _addFavorite(role, champ);
          controller.clear();
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
              itemBuilder: (context, index) {
                final champ = opts[index];
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile', style: Theme.of(context).textTheme.titleLarge),
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
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  helperText: '3-32 characters, no emails',
                ),
                validator: _validate,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save'),
            ),
            const SizedBox(height: 32),
            Text('Preferred roles', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _mainRole,
              decoration: const InputDecoration(labelText: 'Main role'),
              items: _roleOrder
                  .map(
                    (role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _mainRole = value;
                  if (_offRole != null && _offRole == value) {
                    _offRole = null;
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _offRole,
              decoration: const InputDecoration(labelText: 'Off role (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None'),
                ),
                ..._roleOrder
                    .where((role) => role != _mainRole)
                    .map(
                      (role) => DropdownMenuItem<String?>(
                        value: role,
                        child: Text(role),
                      ),
                    )
                    .toList(),
              ],
              onChanged: (value) {
                setState(() {
                  _offRole = value == _mainRole ? null : value;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Choose exactly one main role and an optional off role. They must be different.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _rolesSaving ? null : _saveRoles,
              icon: _rolesSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield),
              label: Text(_rolesSaving ? 'Saving...' : 'Save roles'),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Favorite champions', style: Theme.of(context).textTheme.titleLarge),
                if (_loadingProfile)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Champion>>(
              future: _championsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Failed to load champions: ${snapshot.error}'),
                  );
                }
                final champions = snapshot.data ?? [];
                if (champions.isEmpty) {
                  return const Text('No champions found.');
                }
                return Column(
                  children: [
                    ..._roleOrder.map(
                      (role) {
                        final selections = _favoriteChampions[role] ?? [];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selections
                                    .map(
                                      (id) => _championForId(champions, id),
                                    )
                                    .whereType<Champion>()
                                    .map(
                                      (champ) => Chip(
                                        label: Text(champ.name),
                                        deleteIcon: const Icon(Icons.close),
                                        onDeleted: () => _removeFavorite(role, champ.id),
                                      ),
                                    )
                                    .toList(),
                              ),
                              if (selections.length >= 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Maximum 3 favorites',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              _favoriteAutocomplete(role, champions),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _favoritesSaving ? null : _saveFavorites,
                      icon: _favoritesSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.favorite),
                      label: Text(_favoritesSaving ? 'Saving...' : 'Save favorites'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


