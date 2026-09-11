import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app.dart';
import '../../core/playback/player_ad_block.dart';
import '../../core/theme/wolf_colors.dart';
import '../../data/models/media_item.dart';

/// Futuristic in-app player with keyboard shortcuts, conditional quality /
/// audio / subtitle menus, aspect ratio, and speed (HLS / media_kit).
class StreamPlayerScreen extends StatefulWidget {
  const StreamPlayerScreen({
    super.key,
    required this.title,
    required this.streamUrl,
    this.userAgent,
    this.referrer,
    this.mode = 'live',
    this.provider = 'live',
    this.kind,
    this.mediaId,
    this.channelId,
    this.season = 1,
    this.episode = 1,
    this.sources = const [],
    this.sourceIndex = 0,
    this.forceWebView = false,
  });

  final String title;
  final String streamUrl;
  final String? userAgent;
  final String? referrer;
  final String mode;
  final String provider;
  final String? kind;
  final String? mediaId;
  final String? channelId;
  final int season;
  final int episode;
  final List<LiveStreamSource> sources;
  final int sourceIndex;
  final bool forceWebView;

  @override
  State<StreamPlayerScreen> createState() => _StreamPlayerScreenState();
}

class _StreamPlayerScreenState extends State<StreamPlayerScreen> {
  InAppWebViewController? _webController;
  Timer? _progressPoll;
  Timer? _chromeHide;
  Timer? _progressSave;

  Player? _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Tracks>? _tracksSub;
  final _focus = FocusNode();

  late String _activeUrl;
  late String? _activeUa;
  late String? _activeReferrer;
  late int _sourceIndex;

  var _loading = true;
  String? _error;
  var _webKey = 0;
  final _triedSources = <int>{};
  var _handlingFailure = false;

  var _chromeVisible = true;
  var _fitIndex = 0;
  var _rate = 1.0;
  var _subsEnabled = false;

  List<VideoTrack> _videoTracks = const [];
  List<AudioTrack> _audioTracks = const [];
  List<SubtitleTrack> _subtitleTracks = const [];
  VideoTrack? _videoTrack;
  AudioTrack? _audioTrack;
  SubtitleTrack? _subtitleTrack;

  static const _fits = <(String, BoxFit)>[
    ('Fit', BoxFit.contain),
    ('Fill', BoxFit.cover),
    ('Stretch', BoxFit.fill),
    ('Width', BoxFit.fitWidth),
    ('Height', BoxFit.fitHeight),
  ];

  static const _rates = <double>[0.75, 1.0, 1.25, 1.5, 2.0];

  static const _defaultUa =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
      'Safari/605.1.15';

  static const _injectJs = r'''
(function () {
  if (window.__WOLF_PLAYER_HOOKED__) return;
  window.__WOLF_PLAYER_HOOKED__ = true;
  function tryPlay() {
    try {
      document.querySelectorAll('video').forEach(function (v) {
        v.setAttribute('playsinline', 'true');
        var p = v.play();
        if (p && p.catch) p.catch(function () {});
      });
    } catch (e) {}
  }
  tryPlay();
  setTimeout(tryPlay, 800);
  setTimeout(tryPlay, 2000);
})();
''';

  bool get _isVod => widget.mode == 'vod';

  bool get _isHls {
    if (widget.forceWebView && !_looksLikeHls(_activeUrl)) return false;
    return _looksLikeHls(_activeUrl);
  }

  static bool _looksLikeHls(String url) {
    final u = url.toLowerCase();
    return u.contains('.m3u8') ||
        u.contains('format=m3u8') ||
        u.contains('getm3u8') ||
        u.contains('/live/') ||
        u.contains('jam01su.site') ||
        u.endsWith('.ts');
  }

  String get _ua =>
      (_activeUa != null && _activeUa!.isNotEmpty) ? _activeUa! : _defaultUa;

  List<LiveStreamSource> get _sources {
    if (widget.sources.isNotEmpty) return widget.sources;
    if (_activeUrl.isEmpty) return const [];
    return [
      LiveStreamSource(
        url: _activeUrl,
        userAgent: _activeUa,
        referrer: _activeReferrer,
      ),
    ];
  }

  /// Server / mirror quality from catalog `players[]` (only if multiple).
  bool get _showServerQuality => _sources.length > 1;

  /// HLS ladder quality from media_kit video tracks (only if multiple).
  bool get _showHlsQuality {
    final usable = _videoTracks
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();
    return usable.length > 1;
  }

  bool get _showAudio => _audioTracks.length > 1;

  bool get _showSubtitles {
    final real = _subtitleTracks.where((t) => t.id != 'no').toList();
    return real.isNotEmpty;
  }

  String get _fitLabel => _fits[_fitIndex].$1;
  BoxFit get _fit => _fits[_fitIndex].$2;

  @override
  void initState() {
    super.initState();
    _sourceIndex = widget.sources.isEmpty
        ? 0
        : widget.sourceIndex.clamp(0, widget.sources.length - 1);
    _activeUrl = widget.streamUrl;
    _activeUa = widget.userAgent;
    _activeReferrer = widget.referrer;

    if (widget.sources.isNotEmpty) {
      final src = widget.sources[_sourceIndex];
      _activeUrl = src.url;
      _activeUa = src.userAgent ?? widget.userAgent;
      _activeReferrer = src.referrer ?? widget.referrer;
    }
    _triedSources.add(_sourceIndex);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (_activeUrl.isEmpty) {
      _loading = false;
      _error = 'Missing stream URL';
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      if (_isHls) _startNativeLive();
      _armChromeHide();
    });
  }

  void _armChromeHide() {
    _chromeHide?.cancel();
    if (!_chromeVisible) return;
    _chromeHide = Timer(const Duration(seconds: 3), () {
      if (mounted && _isHls) setState(() => _chromeVisible = false);
    });
  }

  void _bumpChrome() {
    setState(() => _chromeVisible = true);
    _armChromeHide();
  }

  Future<void> _switchPlayback({
    required String url,
    String? userAgent,
    String? referrer,
  }) async {
    await _errorSub?.cancel();
    await _playingSub?.cancel();
    await _tracksSub?.cancel();
    _progressSave?.cancel();
    await _player?.dispose();
    _player = null;
    _videoController = null;
    _webController = null;
    _progressPoll?.cancel();
    _videoTracks = const [];
    _audioTracks = const [];
    _subtitleTracks = const [];
    _subsEnabled = false;

    setState(() {
      _activeUrl = url;
      _activeUa = userAgent;
      _activeReferrer = referrer;
      _error = null;
      _loading = true;
      _webKey++;
    });

    if (_isHls) await _startNativeLive();
  }

  Future<void> _selectSource(int index) async {
    final sources = _sources;
    if (index < 0 || index >= sources.length || index == _sourceIndex) return;
    final src = sources[index];
    setState(() => _sourceIndex = index);
    _triedSources.add(index);
    await _switchPlayback(
      url: src.url,
      userAgent: src.userAgent ?? widget.userAgent,
      referrer: src.referrer ?? widget.referrer,
    );
  }

  Future<void> _onPrimaryFailure(String message) async {
    if (_handlingFailure) return;
    _handlingFailure = true;
    final dead =
        widget.mode == 'live' ? AppScope.deadStreamsOf(context) : null;
    try {
      if (dead != null && _activeUrl.isNotEmpty) {
        await dead.markUrlDead(_activeUrl);
      }

      for (var i = 0; i < _sources.length; i++) {
        if (_triedSources.contains(i)) continue;
        _triedSources.add(i);
        if (!mounted) return;
        setState(() => _sourceIndex = i);
        await _switchPlayback(
          url: _sources[i].url,
          userAgent: _sources[i].userAgent ?? widget.userAgent,
          referrer: _sources[i].referrer ?? widget.referrer,
        );
        return;
      }

      if (dead != null) {
        for (final i in _triedSources) {
          if (i >= 0 && i < _sources.length) {
            await dead.markUrlDead(_sources[i].url);
          }
        }
        final channelId = widget.channelId;
        if (channelId != null && channelId.isNotEmpty) {
          await dead.markChannelDead(channelId);
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _chromeVisible = true;
        _error = _friendlyError(message);
      });
    } finally {
      _handlingFailure = false;
    }
  }

  /// Turn raw media_kit / DNS errors into something users can act on.
  String _friendlyError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('failed to resolve hostname') ||
        m.contains('nodename nor servname') ||
        m.contains('name or service not known') ||
        m.contains('temporary failure in name resolution')) {
      return 'This stream host is offline or unreachable.\n'
          'Try another source, or go back and pick a different channel.';
    }
    if (m.contains('connection refused') ||
        m.contains('timed out') ||
        m.contains('network is unreachable') ||
        m.contains('connection reset')) {
      return 'Could not connect to this stream.\n'
          'Check your network, then retry or try another source.';
    }
    if (m.contains('404') || m.contains('403') || m.contains('410')) {
      return 'This stream link is dead or blocked.\n'
          'Try another source or a different channel.';
    }
    // Strip noisy "tcp: " prefix from media_kit.
    final cleaned = raw.replaceFirst(RegExp(r'^tcp:\s*', caseSensitive: false), '');
    if (cleaned.length > 160) {
      return '${cleaned.substring(0, 157)}…';
    }
    return cleaned.isEmpty ? 'Playback failed' : cleaned;
  }

  Future<void> _goBack() async {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _tryNextSource() async {
    for (var i = 0; i < _sources.length; i++) {
      if (i == _sourceIndex) continue;
      await _selectSource(i);
      return;
    }
    await _reload();
  }

  Future<void> _startNativeLive() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final player = Player();
      final video = VideoController(player);
      final headers = <String, String>{
        'User-Agent': _ua,
        if (_activeReferrer != null && _activeReferrer!.isNotEmpty) ...{
          'Referer': _activeReferrer!,
          'Origin': _activeReferrer!,
        },
      };

      await player.open(Media(_activeUrl, httpHeaders: headers), play: true);
      // Subtitles off by default.
      await player.setSubtitleTrack(SubtitleTrack.no());

      await _errorSub?.cancel();
      await _playingSub?.cancel();
      await _tracksSub?.cancel();

      _errorSub = player.stream.error.listen((message) {
        if (!mounted || message.isEmpty) return;
        _onPrimaryFailure(message);
      });

      _playingSub = player.stream.playing.listen((playing) {
        if (!mounted) return;
        if (playing) setState(() => _loading = false);
      });

      _tracksSub = player.stream.tracks.listen((tracks) {
        if (!mounted) return;
        setState(() {
          _videoTracks = tracks.video;
          _audioTracks = tracks.audio;
          _subtitleTracks = tracks.subtitle;
          _videoTrack = player.state.track.video;
          _audioTrack = player.state.track.audio;
          _subtitleTrack = player.state.track.subtitle;
        });
      });

      _progressSave?.cancel();
      _progressSave = Timer.periodic(const Duration(seconds: 8), (_) {
        _persistProgress();
      });

      Future<void>.delayed(const Duration(seconds: 6), () {
        if (mounted && _loading) setState(() => _loading = false);
      });

      setState(() {
        _player = player;
        _videoController = video;
      });
    } catch (e) {
      if (!mounted) return;
      await _onPrimaryFailure(e.toString());
    }
  }

  Future<void> _persistProgress() async {
    final player = _player;
    final id = widget.mediaId;
    if (player == null || id == null || id.isEmpty || !_isVod) return;
    try {
      final pos = player.state.position.inMilliseconds / 1000.0;
      final dur = player.state.duration.inMilliseconds / 1000.0;
      await AppScope.watchProgressOf(context).upsertPlayback(
        id: id,
        type: widget.kind == MediaKind.tv.name ? 'tv' : 'movie',
        title: widget.title,
        watchedSec: pos,
        durationSec: dur,
        season: widget.season,
        episode: widget.episode,
      );
    } catch (_) {}
  }

  Future<void> _togglePlay() async {
    final p = _player;
    if (p == null) return;
    p.state.playing ? await p.pause() : await p.play();
    _bumpChrome();
  }

  Future<void> _seekBy(Duration d) async {
    final p = _player;
    if (p == null) return;
    final next = p.state.position + d;
    await p.seek(next < Duration.zero ? Duration.zero : next);
    _bumpChrome();
  }

  Future<void> _cycleFit() async {
    setState(() => _fitIndex = (_fitIndex + 1) % _fits.length);
    _bumpChrome();
  }

  Future<void> _cycleRate() async {
    final p = _player;
    if (p == null) return;
    final i = _rates.indexOf(_rate);
    final next = _rates[(i + 1) % _rates.length];
    await p.setRate(next);
    setState(() => _rate = next);
    _bumpChrome();
  }

  Future<void> _toggleMute() async {
    final p = _player;
    if (p == null) return;
    await p.setVolume(p.state.volume > 0 ? 0 : 100);
    _bumpChrome();
  }

  Future<void> _setVideoTrack(VideoTrack t) async {
    await _player?.setVideoTrack(t);
    setState(() => _videoTrack = t);
  }

  Future<void> _setAudioTrack(AudioTrack t) async {
    await _player?.setAudioTrack(t);
    setState(() => _audioTrack = t);
  }

  Future<void> _setSubtitle(SubtitleTrack? t, {required bool on}) async {
    if (!on || t == null) {
      await _player?.setSubtitleTrack(SubtitleTrack.no());
      setState(() {
        _subsEnabled = false;
        _subtitleTrack = SubtitleTrack.no();
      });
    } else {
      await _player?.setSubtitleTrack(t);
      setState(() {
        _subsEnabled = true;
        _subtitleTrack = t;
      });
    }
    _bumpChrome();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_isHls) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      _seekBy(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
      _seekBy(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _player?.setVolume(((_player?.state.volume ?? 0) + 5).clamp(0, 100));
      _bumpChrome();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _player?.setVolume(((_player?.state.volume ?? 0) - 5).clamp(0, 100));
      _bumpChrome();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _toggleMute();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      _cycleFit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyS && _showSubtitles) {
      if (_subsEnabled) {
        _setSubtitle(null, on: false);
      } else {
        final first = _subtitleTracks.cast<SubtitleTrack?>().firstWhere(
              (t) => t != null && t.id != 'no',
              orElse: () => null,
            );
        if (first != null) _setSubtitle(first, on: true);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA && _showAudio) {
      // Cycle audio
      final list = _audioTracks;
      if (list.isEmpty) return KeyEventResult.handled;
      final cur = _audioTrack;
      final i = cur == null ? -1 : list.indexWhere((t) => t.id == cur.id);
      final next = list[(i + 1) % list.length];
      _setAudioTrack(next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.bracketLeft ||
        key == LogicalKeyboardKey.bracketRight) {
      _cycleRate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      _bumpChrome();
      _showShortcutsHelp();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showShortcutsHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: WolfColors.charcoal,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHORTCUTS', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text('Space — play / pause', style: TextStyle(color: WolfColors.bone)),
            const Text('← / → or J / L — seek ±10s', style: TextStyle(color: WolfColors.bone)),
            const Text('↑ / ↓ — volume', style: TextStyle(color: WolfColors.bone)),
            const Text('M — mute · F — aspect · [ ] — speed', style: TextStyle(color: WolfColors.bone)),
            const Text('S — subtitles · A — audio language', style: TextStyle(color: WolfColors.bone)),
            const Text('Esc — close · H — this help', style: TextStyle(color: WolfColors.bone)),
          ],
        ),
      ),
    );
  }

  Future<void> _inject() async {
    final c = _webController;
    if (c == null || _isHls) return;
    try {
      await c.evaluateJavascript(source: PlayerAdBlock.hideAdsJs);
      await c.evaluateJavascript(source: PlayerAdBlock.trapClicksJs);
      await c.evaluateJavascript(source: _injectJs);
    } catch (e) {
      debugPrint('inject failed: $e');
    }
  }

  bool _isSafeWebNav(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.startsWith('about:')) return true;
    if (PlayerAdBlock.isAdUrl(url)) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'blob' || scheme == 'data') return true;
    if (scheme != 'http' && scheme != 'https') return false;
    return PlayerAdBlock.isAllowedHost(url, popcorn: false);
  }

  Future<void> _reload() async {
    setState(() {
      _error = null;
      _loading = true;
      _chromeVisible = true;
    });
    // Allow previously failed mirrors to be tried again.
    _triedSources
      ..clear()
      ..add(_sourceIndex);
    if (_isHls) {
      await _player?.dispose();
      _player = null;
      _videoController = null;
      await _startNativeLive();
      return;
    }
    await _webController?.reload();
  }

  @override
  void dispose() {
    _persistProgress();
    _chromeHide?.cancel();
    _progressSave?.cancel();
    _progressPoll?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _tracksSub?.cancel();
    _focus.dispose();
    _player?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: WolfColors.voidBlack,
          body: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_isHls) {
                    setState(() => _chromeVisible = !_chromeVisible);
                    if (_chromeVisible) _armChromeHide();
                  }
                },
                onDoubleTapDown: _isHls
                    ? (d) {
                        final w = MediaQuery.sizeOf(context).width;
                        if (d.localPosition.dx < w * 0.4) {
                          _seekBy(const Duration(seconds: -10));
                        } else if (d.localPosition.dx > w * 0.6) {
                          _seekBy(const Duration(seconds: 10));
                        } else {
                          _togglePlay();
                        }
                      }
                    : null,
                child: _isHls ? _buildNativeLive() : _buildWebEmbed(),
              ),
              if (_error != null) _buildError(),
              if (_loading)
                const ColoredBox(
                  color: Color(0xCC070708),
                  child: Center(
                    child: CircularProgressIndicator(color: WolfColors.lime),
                  ),
                ),
              if (_chromeVisible && _error == null) _buildChrome(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChrome() {
    return IgnorePointer(
      ignoring: false,
      child: AnimatedOpacity(
        opacity: _chromeVisible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC070708), Color(0x00070708)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: WolfColors.bone),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: WolfColors.bone,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_isHls)
                      IconButton(
                        tooltip: 'Shortcuts (H)',
                        onPressed: _showShortcutsHelp,
                        icon: const Icon(Icons.keyboard, color: WolfColors.lime),
                      ),
                    IconButton(
                      tooltip: 'Reload',
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh, color: WolfColors.lime),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xEE070708), Color(0x00070708)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_showServerQuality) _serverMenu(),
                      if (_isHls && _showHlsQuality) _hlsQualityMenu(),
                      if (_isHls && _showAudio) _audioMenu(),
                      if (_isHls && _showSubtitles) _subsMenu(),
                      if (_isHls) ...[
                        _chip(Icons.aspect_ratio, _fitLabel, _cycleFit),
                        _chip(Icons.speed, '${_rate}x', _cycleRate),
                        _chip(Icons.volume_up, 'Mute', _toggleMute),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: WolfColors.lime),
      label: Text(
        label,
        style: const TextStyle(
          color: WolfColors.bone,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _serverMenu() {
    return PopupMenuButton<int>(
      tooltip: 'Server / quality',
      onSelected: _selectSource,
      color: WolfColors.slate,
      itemBuilder: (context) => [
        for (var i = 0; i < _sources.length; i++)
          CheckedPopupMenuItem(
            value: i,
            checked: i == _sourceIndex,
            child: Text(_sources[i].label),
          ),
      ],
      child: _menuLabel(Icons.dns_outlined, _sources[_sourceIndex].label),
    );
  }

  Widget _hlsQualityMenu() {
    final tracks = _videoTracks.where((t) => t.id != 'auto').toList();
    return PopupMenuButton<VideoTrack>(
      tooltip: 'Stream quality',
      onSelected: _setVideoTrack,
      color: WolfColors.slate,
      itemBuilder: (context) => [
        for (final t in tracks)
          CheckedPopupMenuItem(
            value: t,
            checked: _videoTrack?.id == t.id,
            child: Text(_videoLabel(t)),
          ),
      ],
      child: _menuLabel(
        Icons.high_quality_outlined,
        _videoTrack != null ? _videoLabel(_videoTrack!) : 'Quality',
      ),
    );
  }

  String _videoLabel(VideoTrack t) {
    if (t.h != null && t.h! > 0) return '${t.h}p';
    if (t.title != null && t.title!.isNotEmpty) return t.title!;
    if (t.language != null && t.language!.isNotEmpty) return t.language!;
    return t.id;
  }

  Widget _audioMenu() {
    return PopupMenuButton<AudioTrack>(
      tooltip: 'Audio language',
      onSelected: _setAudioTrack,
      color: WolfColors.slate,
      itemBuilder: (context) => [
        for (final t in _audioTracks)
          CheckedPopupMenuItem(
            value: t,
            checked: _audioTrack?.id == t.id,
            child: Text(_audioLabel(t)),
          ),
      ],
      child: _menuLabel(
        Icons.record_voice_over_outlined,
        _audioTrack != null ? _audioLabel(_audioTrack!) : 'Audio',
      ),
    );
  }

  String _audioLabel(AudioTrack t) {
    if (t.title != null && t.title!.isNotEmpty) return t.title!;
    if (t.language != null && t.language!.isNotEmpty) {
      return t.language!.toUpperCase();
    }
    return 'Track ${t.id}';
  }

  Widget _subsMenu() {
    final real = _subtitleTracks.where((t) => t.id != 'no').toList();
    return PopupMenuButton<String>(
      tooltip: 'Subtitles',
      onSelected: (v) {
        if (v == 'off') {
          _setSubtitle(null, on: false);
        } else {
          final t = real.firstWhere((e) => e.id == v);
          _setSubtitle(t, on: true);
        }
      },
      color: WolfColors.slate,
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: 'off',
          checked: !_subsEnabled,
          child: const Text('Off'),
        ),
        for (final t in real)
          CheckedPopupMenuItem(
            value: t.id,
            checked: _subsEnabled && _subtitleTrack?.id == t.id,
            child: Text(_subLabel(t)),
          ),
      ],
      child: _menuLabel(
        Icons.closed_caption,
        _subsEnabled && _subtitleTrack != null
            ? _subLabel(_subtitleTrack!)
            : 'Subs Off',
      ),
    );
  }

  String _subLabel(SubtitleTrack t) {
    if (t.title != null && t.title!.isNotEmpty) return t.title!;
    if (t.language != null && t.language!.isNotEmpty) {
      return t.language!.toUpperCase();
    }
    return 'Track ${t.id}';
  }

  Widget _menuLabel(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WolfColors.lime, size: 16),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WolfColors.bone,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNativeLive() {
    final controller = _videoController;
    if (controller == null) {
      return const ColoredBox(color: WolfColors.voidBlack);
    }
    return MaterialVideoControlsTheme(
      normal: MaterialVideoControlsThemeData(
        backdropColor: WolfColors.voidBlack.withValues(alpha: 0.35),
        seekBarPositionColor: WolfColors.lime,
        seekBarThumbColor: WolfColors.lime,
        seekBarHeight: 3,
        bottomButtonBar: const [
          MaterialPlayOrPauseButton(),
          MaterialPositionIndicator(),
          Spacer(),
          MaterialFullscreenButton(),
        ],
      ),
      fullscreen: MaterialVideoControlsThemeData(
        backdropColor: WolfColors.voidBlack.withValues(alpha: 0.35),
        seekBarPositionColor: WolfColors.lime,
        seekBarThumbColor: WolfColors.lime,
      ),
      child: Video(
        controller: controller,
        controls: _chromeVisible ? MaterialVideoControls : NoVideoControls,
        fill: WolfColors.voidBlack,
        fit: _fit,
      ),
    );
  }

  Widget _buildWebEmbed() {
    return ColoredBox(
      color: WolfColors.voidBlack,
      child: InAppWebView(
        key: ValueKey('web-$_webKey-$_activeUrl'),
        initialUrlRequest: URLRequest(
          url: WebUri(_activeUrl),
          headers: {
            'User-Agent': _ua,
            if (_activeReferrer != null && _activeReferrer!.isNotEmpty)
              'Referer': _activeReferrer!,
          },
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          transparentBackground: false,
          userAgent: _ua,
          useShouldOverrideUrlLoading: true,
          javaScriptCanOpenWindowsAutomatically: false,
        ),
        onWebViewCreated: (controller) {
          _webController = controller;
          _progressPoll?.cancel();
          _progressPoll = Timer.periodic(
            const Duration(seconds: 1),
            (_) => _inject(),
          );
        },
        onLoadStart: (_, _) {
          if (mounted) {
            setState(() {
              _loading = true;
              _error = null;
            });
          }
        },
        onLoadStop: (controller, url) async {
          if (!mounted) return;
          setState(() => _loading = false);
          await _inject();
        },
        shouldOverrideUrlLoading: (controller, action) async {
          final url = action.request.url?.toString();
          if (_isSafeWebNav(url)) return NavigationActionPolicy.ALLOW;
          return NavigationActionPolicy.CANCEL;
        },
        onCreateWindow: (controller, createWindowAction) async => false,
      ),
    );
  }

  Widget _buildError() {
    final hasOtherSources = _sources.length > 1;
    return ColoredBox(
      color: const Color(0xEE070708),
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back, color: WolfColors.bone),
                tooltip: 'Back',
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: WolfColors.ember,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'Playback failed',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: WolfColors.bone),
                    ),
                    if (hasOtherSources) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Source ${_sourceIndex + 1} of ${_sources.length}',
                        style: const TextStyle(
                          color: WolfColors.mist,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _goBack,
                          child: const Text(
                            'BACK',
                            style: TextStyle(color: WolfColors.bone),
                          ),
                        ),
                        if (hasOtherSources)
                          TextButton(
                            onPressed: _tryNextSource,
                            child: const Text(
                              'NEXT SOURCE',
                              style: TextStyle(color: WolfColors.lime),
                            ),
                          ),
                        TextButton(
                          onPressed: _reload,
                          child: const Text(
                            'RETRY',
                            style: TextStyle(color: WolfColors.lime),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
