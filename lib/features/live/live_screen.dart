import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app.dart';
import '../../core/playback/stream_nav.dart';
import '../../core/theme/wolf_colors.dart';
import '../../core/widgets/category_bar.dart';
import '../../core/widgets/scan_line.dart';
import '../../core/widgets/tv_focusable.dart';
import '../../data/models/media_item.dart';
import '../shell/app_shell.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<LiveChannel> _all = const [];
  List<String> _cats = const ['All'];
  List<String> _countries = const ['All'];
  int _selectedCat = 0;
  int _selectedCountry = 0;
  bool _loading = true;
  String? _error;

  bool _booted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booted) return;
    _booted = true;
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final channels = await AppScope.repoOf(context)
          .liveChannels(forceRefresh: forceRefresh);
      if (!mounted) return;
      final cats = {
        for (final c in channels) c.category,
      }.toList()
        ..sort();
      final countries = {
        for (final c in channels)
          if (c.countryName != null && c.countryName!.isNotEmpty) c.countryName!,
      }.toList()
        ..sort();
      setState(() {
        _all = channels;
        _cats = ['All', ...cats];
        _countries = ['All', ...countries];
        _selectedCat = 0;
        _selectedCountry = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _all = const [];
        _cats = const ['All'];
        _countries = const ['All'];
        _error = e.toString();
        _loading = false;
      });
    }
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
    return list.toList();
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
    // In-app only — no external browser.
    openLiveStreamPlayer(context, channel: channel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WolfTopBar(
        title: 'LIVE TV',
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh, color: WolfColors.lime),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: WolfColors.lime),
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
    return Column(
      children: [
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              const Expanded(child: ScanLine(height: 2)),
              const SizedBox(width: 12),
              Text(
                '${items.length} CH',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'No channels for this filter.',
                    style: TextStyle(color: WolfColors.mist),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final ch = items[i];
                    return _LiveTile(
                      channel: ch,
                      index: i,
                      onTap: () => _openChannel(ch),
                    )
                        .animate(delay: (40 * (i % 24)).ms)
                        .fadeIn()
                        .slideY(begin: 0.08);
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
    return WolfTvFocusable(
      onActivate: onTap,
      child: Material(
        color: WolfColors.slate,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: WolfColors.steel),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: channel.isLive ? WolfColors.ember : WolfColors.mist,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      channel.isLive ? 'ON AIR' : 'OFF',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: channel.isLive
                                ? WolfColors.ember
                                : WolfColors.mist,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      channel.category.toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  channel.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  channel.subtitle ??
                      'CH ${(index + 1).toString().padLeft(2, '0')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
