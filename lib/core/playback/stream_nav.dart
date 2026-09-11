import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../data/models/media_item.dart';
import '../../core/theme/wolf_colors.dart';

/// Opens the licensed stream player for a movie or series title.
///
/// Prefers direct HLS (m3u8) via media_kit; otherwise iframe WebView.
Future<void> openStreamPlayer(
  BuildContext context, {
  required String title,
  required MediaKind kind,
  required int mediaId,
  List<PlaySource> players = const [],
  int season = 1,
  int episode = 1,
  int? year,
}) async {
  var list = players;
  if (list.isEmpty && context.mounted) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: WolfColors.voidBlack.withValues(alpha: 0.72),
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: WolfColors.lime),
      ),
    );
    try {
      final detail = await AppScope.repoOf(context).detail(kind, mediaId);
      list = detail.players;
    } catch (e) {
      debugPrint('openStreamPlayer resolve failed: $e');
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
  if (!context.mounted) return;

  final playable = list.isEmpty
      ? const <PlaySource>[]
      : [
          ...list.where((p) => p.isHls),
          ...list.where((p) => !p.isHls),
        ];

  if (playable.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: WolfColors.steel,
        content: Text(
          'No licensed stream for this title yet (discovery-only).',
          style: TextStyle(color: WolfColors.bone),
        ),
      ),
    );
    return;
  }

  final first = playable.first;
  final useWebView = !first.isHls;

  context.push('/stream', extra: {
    'title': title,
    'url': first.url,
    'mode': 'vod',
    'provider': 'elo',
    'kind': kind.name,
    'mediaId': '$mediaId',
    'mediaIdInt': mediaId,
    'season': season,
    'episode': episode,
    'year': year,
    'webview': useWebView,
    'referrer': Uri.tryParse(first.url)?.origin,
    'sources': [
      for (final s in playable) s.toLiveSource().toJson(),
    ],
    'sourceIndex': 0,
  });
}

/// Opens live TV with optional alternate quality / server sources.
void openLiveStreamPlayer(
  BuildContext context, {
  required LiveChannel channel,
}) {
  final dead = AppScope.deadStreamsOf(context);
  final living = dead.livingChannel(channel);
  if (living == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: WolfColors.steel,
        content: Text(
          'This channel’s streams are marked dead. Try again later.',
          style: TextStyle(color: WolfColors.bone),
        ),
      ),
    );
    return;
  }

  final sources = living.selectableSources;
  final primary = sources.isNotEmpty
      ? sources.first
      : LiveStreamSource(
          url: living.streamUrl ?? '',
          quality: living.quality,
          userAgent: living.userAgent,
          referrer: living.referrer,
        );

  context.push('/stream', extra: {
    'title': living.name,
    'url': primary.url,
    'mode': 'live',
    'provider': 'live',
    'channelId': living.id,
    'userAgent': primary.userAgent ?? living.userAgent,
    'referrer': primary.referrer ?? living.referrer,
    'sources': [for (final s in sources) s.toJson()],
    'sourceIndex': 0,
  });
}
