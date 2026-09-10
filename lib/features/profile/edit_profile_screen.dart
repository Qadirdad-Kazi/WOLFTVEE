import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/theme/wolf_colors.dart';
import '../shell/app_shell.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  bool _saving = false;
  bool _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final s = AppScope.settingsOf(context);
    _name.text = s.displayName;
    _handle.text = s.handle;
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final s = AppScope.settingsOf(context);
    await s.setDisplayName(_name.text);
    await s.setHandle(_handle.text);
    if (!mounted) return;
    setState(() => _saving = false);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WolfTopBar(title: 'EDIT PROFILE'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('DISPLAY NAME', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            style: Theme.of(context).textTheme.bodyLarge,
            cursorColor: WolfColors.lime,
            decoration: const InputDecoration(hintText: 'Hunter'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 20),
          Text('HANDLE', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _handle,
            style: Theme.of(context).textTheme.bodyLarge,
            cursorColor: WolfColors.lime,
            decoration: const InputDecoration(hintText: 'pack_alpha'),
          ),
          const SizedBox(height: 28),
          Material(
            color: WolfColors.lime,
            child: InkWell(
              onTap: _saving ? null : _save,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _saving ? 'SAVING…' : 'SAVE',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: WolfColors.voidBlack,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
