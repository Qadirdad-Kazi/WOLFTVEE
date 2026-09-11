import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app.dart';
import '../../core/playback/stream_nav.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/category_bar.dart';
import '../../core/widgets/scan_line.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../data/models/media_item.dart';
import '../../data/services/dead_stream_store.dart';
import '../../data/services/stream_health_service.dart';
import '../shell/app_shell.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  /// Full catalog after known-dead filter (pre health-sweep removals applied via listener).
  List<LiveChannel> _catalog = const [];
  List<LiveChannel> _all = const [];
  List<String> _cats = const ['All'];
  List<String> _countries = const ['All'];
  int _selectedCat = 0;
  int _selectedCountry = 0;
  bool _loading = true;
  String? _error;
  String _query = '';
  final _searchCtrl = TextEditingController();
  DeadStreamStore? _deadStore;
  final _health = StreamHealthService();
  HealthSweepProgress? _healthProgress;

  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dead = AppScope.deadStreamsOf(context);
    if (!identical(_deadStore, dead)) {
      _deadStore?.removeListener(_onDeadStreamsChanged);
      _deadStore = dead;
      _deadStore!.addListener(_onDeadStreamsChanged);
    }
    if (_booted) return;
    _booted = true;
    _load();
  }

  @override
  void dispose() {
    _health.cancel();
    _deadStore?.removeListener(_onDeadStreamsChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyChannelMeta(List<LiveChannel> channels) {
    final cats = {
      for (final c in channels) c.category,
    }.toList()
      ..sort((a, b) {
        if (a.toLowerCase() == 'sports') return -1;
        if (b.toLowerCase() == 'sports') return 1;
        return a.compareTo(b);
      });
    final countries = {
      for (final c in channels)
        if (c.countryName != null && c.countryName!.isNotEmpty) c.countryName!,
    }.toList()
      ..sort();
    _all = channels;
    _cats = ['All', ...cats];
    _countries = ['All', ...countries];
    if (_selectedCat >= _cats.length) _selectedCat = 0;
    if (_selectedCountry >= _countries.length) _selectedCountry = 0;
  }

  void _refreshFromCatalog() {
    final dead = AppScope.deadStreamsOf(context);
    _applyChannelMeta(dead.filterChannels(_catalog));
  }

  void _onDeadStreamsChanged() {
    if (!mounted || _loading) return;
    setState(_refreshFromCatalog);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    _health.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _healthProgress = null;
    });
    try {
      final dead = AppScope.deadStreamsOf(context);
      final channels = await AppScope.repoOf(context)
          .liveChannels(forceRefresh: forceRefresh);
      if (!mounted) return;
      _catalog = channels;
      setState(() {
        _selectedCat = 0;
        _selectedCountry = 0;
        _applyChannelMeta(dead.filterChannels(channels));
        _loading = false;
      });
      // Probe in background — hide dead URLs without waiting to open each one.
      unawaited(_runHealthSweep());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalog = const [];
        _all = const [];
        _cats = const ['All'];
        _countries = const ['All'];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runHealthSweep() async {
    final dead = AppScope.deadStreamsOf(context);
    await _health.sweep(
      channels: _catalog,
      dead: dead,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _healthProgress = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _refreshFromCatalog();
      final p = _healthProgress;
      if (p != null) {
        _healthProgress = HealthSweepProgress(
          checked: p.checked,
          total: p.total,
          markedDead: p.markedDead,
          keptAlive: p.keptAlive,
          running: false,
        );
      }
    });
  }

  List<LiveChannel> get _filtered {
    Iterable<LiveChannel> list = _all;
    if (_selectedCat > 0) {
      final cat = _cats[_selectedCat];
      list = list.where((c) => c.category == cat);
    }
    if (_selectedCountry > 0) {
      final country = _countries[_selectedCountry];
      list = list.where((c) => c.countryName == country);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.category.toLowerCase().contains(q) ||
            (c.countryName?.toLowerCase().contains(q) ?? false) ||
            (c.countryCode?.toLowerCase().contains(q) ?? false);
      });
    }
    return list.toList();
  }

  List<LiveChannel> get _sportsPreview {
    final sports = _all
        .where((c) => c.category.toLowerCase() == 'sports')
        .take(24)
        .toList();
    return sports;
  }

  Future<void> _openChannel(LiveChannel channel) async {
    final url = channel.streamUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: WolfColors.steel,
          content: Text(
            'No stream URL for this channel.',
            style: TextStyle(color: WolfColors.bone),
          ),
        ),
      );
      return;
    }
    openLiveStreamPlayer(context, channel: channel);
  }

  @override
  Widget build(BuildContext context) {
    final sportsCount =
        _all.where((c) => c.category.toLowerCase() == 'sports').length;
    return Scaffold(
      appBar: WolfTopBar(
        title: 'LIVE TV',
        actions: [
          if (!_loading && _all.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '${_all.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: WolfColors.lime,
                      ),
                ),
              ),
            ),
          IconButton(
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh, color: WolfColors.lime),
          ),
        ],
      ),
      body: _buildBody(sportsCount),
    );
  }

  Widget _buildHealthBanner() {
    final p = _healthProgress;
    if (p == null || p.total <= 0) return const SizedBox.shrink();
    final label = p.running
        ? 'Checking streams ${p.checked}/${p.total} · removed ${p.markedDead}'
        : 'Verified · removed ${p.markedDead} dead';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRect(
            child: LinearProgressIndicator(
              value: p.running ? p.fraction : 1,
              minHeight: 2,
              color: WolfColors.lime,
              backgroundColor: WolfColors.steel,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: WolfColors.mist,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(int sportsCount) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: WolfColors.lime),
            SizedBox(height: 16),
            Text(
              'Loading live channels…',
              style: TextStyle(color: WolfColors.mist),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return _EmptyLive(
        title: 'COULD NOT LOAD CHANNELS',
        message: _error!,
        actionLabel: 'RETRY',
        onAction: _load,
      );
    }

    if (_all.isEmpty) {
      return _EmptyLive(
        title: 'NO CHANNELS',
        message:
            'Live feed returned no playable channels. Pull to refresh later.',
        actionLabel: 'RETRY',
        onAction: () => _load(forceRefresh: true),
      );
    }

    final items = _filtered;
    final showSportsRail =
        _selectedCat == 0 && _query.isEmpty && _sportsPreview.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: WolfColors.bone),
            cursorColor: WolfColors.lime,
            decoration: InputDecoration(
              hintText: 'Search channels, sports, countries…',
              hintStyle: const TextStyle(color: WolfColors.mist),
              prefixIcon: const Icon(Icons.search, color: WolfColors.mist),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close, color: WolfColors.mist),
                    ),
              filled: true,
              fillColor: WolfColors.slate,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        _buildHealthBanner(),
        CategoryBar(
          labels: _cats,
          selected: _selectedCat,
          onSelect: (i) => setState(() => _selectedCat = i),
        ),
        if (_countries.length > 1)
          CategoryBar(
            labels: _countries,
            selected: _selectedCountry,
            onSelect: (i) => setState(() => _selectedCountry = i),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              const Expanded(child: ScanLine(height: 2)),
              const SizedBox(width: 12),
              Text(
                '${items.length} CH',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (sportsCount > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '· $sportsCount SPORTS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: WolfColors.ember,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (showSportsRail) _SportsRail(
          channels: _sportsPreview,
          onOpen: _openChannel,
          onSeeAll: () {
            final i = _cats.indexWhere((c) => c.toLowerCase() == 'sports');
            if (i >= 0) setState(() => _selectedCat = i);
          },
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No channels for this filter.',
                    style: TextStyle(color: WolfColors.mist),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    // Compact tiles: ~168–200px wide on phone/desktop.
                    final cross = (w / 168).floor().clamp(2, 6);
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        // Wide, short cards (not tall squares).
                        childAspectRatio: 2.55,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final ch = items[i];
                        return _LiveTile(
                          channel: ch,
                          index: i,
                          onTap: () => _openChannel(ch),
                        )
                            .animate(delay: (20 * (i % 24)).ms)
                            .fadeIn(duration: 180.ms);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SportsRail extends StatelessWidget {
  const _SportsRail({
    required this.channels,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<LiveChannel> channels;
  final ValueChanged<LiveChannel> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                color: WolfColors.ember,
              ),
              const SizedBox(width: 8),
              Text(
                'SPORTS',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: WolfColors.ember,
                      letterSpacing: 1.2,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onSeeAll,
                child: const Text(
                  'SEE ALL',
                  style: TextStyle(color: WolfColors.lime, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final ch = channels[i];
              return WolfTvFocusable(
                onActivate: () => onOpen(ch),
                child: Material(
                  color: WolfColors.slate,
                  child: InkWell(
                    onTap: () => onOpen(ch),
                    child: Container(
                      width: 168,
                      decoration: BoxDecoration(
                        border: Border.all(color: WolfColors.steel),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _ChannelLogo(url: ch.logoUrl, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ch.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (ch.countryCode != null)
                                  Text(
                                    ch.countryCode!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: WolfColors.mist),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyLive extends StatelessWidget {
  const _EmptyLive({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_off, color: WolfColors.mist, size: 40),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(color: WolfColors.lime),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({
    required this.channel,
    required this.index,
    required this.onTap,
  });

  final LiveChannel channel;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSports = channel.category.toLowerCase() == 'sports';
    return WolfTvFocusable(
      onActivate: onTap,
      child: Material(
        color: WolfColors.slate,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSports
                    ? WolfColors.ember.withValues(alpha: 0.55)
                    : WolfColors.steel,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _ChannelLogo(url: channel.logoUrl, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            color: channel.isLive
                                ? WolfColors.ember
                                : WolfColors.mist,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              [
                                channel.category,
                                if (channel.countryCode != null)
                                  channel.countryCode!,
                                if (channel.quality != null &&
                                    channel.quality!.isNotEmpty)
                                  channel.quality!,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: isSports
                                        ? WolfColors.ember
                                        : WolfColors.mist,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url, this.size = 36});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: WolfColors.steel);
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: WolfColors.voidBlack, border: border),
        child: const Icon(Icons.live_tv, color: WolfColors.mist, size: 18),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: border),
      clipBehavior: Clip.hardEdge,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.contain,
        placeholder: (_, _) => Container(color: WolfColors.voidBlack),
        errorWidget: (_, _, _) => Container(
          color: WolfColors.voidBlack,
          child: const Icon(Icons.live_tv, color: WolfColors.mist, size: 18),
        ),
      ),
    );
  }
}
