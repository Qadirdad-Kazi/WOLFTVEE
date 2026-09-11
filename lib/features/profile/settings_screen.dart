import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/scan_line.dart';
import '../../data/services/cache_store.dart';
import '../shell/app_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CacheStats? _stats;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadStats());
  }

  Future<void> _reloadStats() async {
    final stats = await AppScope.catalogOf(context).cacheStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _clearCache() async {
    setState(() => _clearing = true);
    await AppScope.catalogOf(context).clearCache();
    await _reloadStats();
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: WolfColors.steel,
        content: Text('Cache cleared', style: TextStyle(color: WolfColors.bone)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.settingsOf(context);

    return Scaffold(
      appBar: const WolfTopBar(title: 'SETTINGS'),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text('EXPERIENCE',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: WolfColors.voidBlack,
                activeTrackColor: WolfColors.lime,
                title: Text('Intense motion',
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text('Scan lines, shear, eye pulse',
                    style: Theme.of(context).textTheme.bodySmall),
                value: settings.intenseMotion,
                onChanged: settings.setMotion,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: WolfColors.voidBlack,
                activeTrackColor: WolfColors.lime,
                title: Text('Fresh hunt on open',
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text('Pull latest catalog when Home boots',
                    style: Theme.of(context).textTheme.bodySmall),
                value: settings.autoRefreshOnOpen,
                onChanged: settings.setAutoRefresh,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: WolfColors.voidBlack,
                activeTrackColor: WolfColors.lime,
                title: Text('Pack alerts',
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text('Local preference flag (no push yet)',
                    style: Theme.of(context).textTheme.bodySmall),
                value: settings.notifications,
                onChanged: settings.setNotifications,
              ),
              const SizedBox(height: 16),
              const ScanLine(height: 2),
              const SizedBox(height: 20),
              Text('CACHE', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'TTL · ${settings.cacheHours}h  ·  '
                '${_stats == null ? '…' : '${_stats!.diskFiles} files · ${_stats!.diskLabel}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Slider(
                value: settings.cacheHours.toDouble(),
                min: 1,
                max: 48,
                divisions: 47,
                activeColor: WolfColors.lime,
                inactiveColor: WolfColors.steel,
                label: '${settings.cacheHours}h',
                onChanged: (v) async {
                  final hours = v.round();
                  final catalog = AppScope.catalogOf(context);
                  await settings.setCacheHours(hours);
                  catalog.updateCacheTtl(Duration(hours: hours));
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _clearing ? null : _clearCache,
                style: OutlinedButton.styleFrom(
                  foregroundColor: WolfColors.ember,
                  side: const BorderSide(color: WolfColors.ember),
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_clearing ? 'CLEARING…' : 'CLEAR CACHE'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await AppScope.watchProgressOf(context).clear();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: WolfColors.steel,
                      content: Text(
                        'Continue Watching cleared',
                        style: TextStyle(color: WolfColors.bone),
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: WolfColors.mist,
                  side: const BorderSide(color: WolfColors.steel),
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('CLEAR CONTINUE WATCHING'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await AppScope.favoritesOf(context).clear();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: WolfColors.steel,
                      content: Text(
                        'Favorites cleared',
                        style: TextStyle(color: WolfColors.bone),
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: WolfColors.mist,
                  side: const BorderSide(color: WolfColors.steel),
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('CLEAR FAVORITES'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await AppScope.deadStreamsOf(context).clear();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: WolfColors.steel,
                      content: Text(
                        'Dead streams list cleared — they can show again',
                        style: TextStyle(color: WolfColors.bone),
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: WolfColors.mist,
                  side: const BorderSide(color: WolfColors.steel),
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('CLEAR DEAD STREAMS'),
              ),
              const SizedBox(height: 28),
              Text(
                'Data is cached on device for speed. Refresh runs a hunt sweep '
                'and replaces cache with the latest catalog payloads. Watch progress '
                'comes from WOLFTVEE playback while watching in-app.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
