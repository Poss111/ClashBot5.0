import 'package:flutter/material.dart';
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
  late final TextEditingController _nameController;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialDisplayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          ],
        ),
      ),
    );
  }
}


