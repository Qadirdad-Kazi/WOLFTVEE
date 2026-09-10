import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../core/config/env.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/hunt_refresh.dart';
import '../../core/widgets/scan_line.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../core/widgets/wolf_brand.dart';
import '../../data/controllers/catalog_controller.dart';
import '../../data/services/cache_store.dart';
import '../../data/services/settings_store.dart';
import '../shell/app_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  CacheStats? _stats;
  bool _booted = false;
  CatalogController? _catalog;
  SettingsStore? _settings;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _settings = AppScope.settingsOf(context);
    _catalog = AppScope.catalogOf(context);
    _settings!.addListener(_onChange);
    _catalog!.addListener(_onChange);
    _loadStats();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStats() async {
    final stats = await _catalog!.cacheStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  @override
  void dispose() {
    _settings?.removeListener(_onChange);
    _catalog?.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.settingsOf(context);
    final catalog = AppScope.catalogOf(context);
    final sweeping = catalog.phase == CatalogPhase.sweeping;

    return Scaffold(
      appBar: WolfTopBar(
        title: 'YOU',
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune, color: WolfColors.lime),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    color: WolfColors.slate,
                    alignment: Alignment.center,
                    child: const WolfLogoMark(size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.displayName.toUpperCase(),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          '@${settings.handle}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/edit-profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WolfColors.lime,
                      side: const BorderSide(color: WolfColors.lime),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: const Text('EDIT'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const ScanLine(height: 2),
              const SizedBox(height: 20),
              Text(
                'PACK STATUS',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              _StatusRow(
                label: 'Catalog',
                value: Env.hasTmdbKey
                    ? (Env.hasTrakt ? 'ELO + TRAKT/TMDB' : 'ELO + TMDB')
                    : 'ELO ONLY',
                ok: true,
              ),
              _StatusRow(
                label: 'Last hunt',
                value: catalog.lastUpdated == null
                    ? '—'
                    : DateFormat('MMM d · HH:mm').format(catalog.lastUpdated!),
                ok: catalog.lastUpdated != null,
              ),
              _StatusRow(
                label: 'Cache',
                value: _stats == null
                    ? '…'
                    : '${_stats!.diskFiles} files · ${_stats!.diskLabel}',
                ok: true,
              ),
              const SizedBox(height: 16),
              HuntRefreshButton(
                busy: sweeping,
                onPressed: () async {
                  await catalog.huntRefresh();
                  await _loadStats();
                },
              ),
              const SizedBox(height: 28),
              Text(
                'QUICK LINKS',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              _LinkTile(
                label: 'Settings',
                subtitle: 'Motion, cache, notifications',
                onTap: () => context.push('/settings'),
              ),
              _LinkTile(
                label: 'Edit profile',
                subtitle: 'Name and pack handle',
                onTap: () => context.push('/edit-profile'),
              ),
              _LinkTile(
                label: 'About WOLFTVEE',
                subtitle: 'Version and credits',
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          HuntSweepOverlay(active: sweeping),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: WolfColors.steel),
        color: WolfColors.charcoal,
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ok ? WolfColors.lime : WolfColors.ember,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WolfTvFocusable(
      onActivate: onTap,
      child: Material(
        color: WolfColors.charcoal,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: WolfColors.steel),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: WolfColors.mist),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
