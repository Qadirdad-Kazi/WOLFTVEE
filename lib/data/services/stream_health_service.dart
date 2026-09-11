import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import 'dead_stream_store.dart';

/// Probes live stream URLs so dead feeds can be hidden before playback.
class StreamHealthService {
  StreamHealthService({
    this.concurrency = 24,
    this.timeout = const Duration(seconds: 3),
  });

  final int concurrency;
  final Duration timeout;

  static const _ua =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
      'Safari/605.1.15';

  var _generation = 0;

  void cancel() => _generation++;

  /// Background sweep. Sports first. Safe to call again (cancels prior run).
  Future<HealthSweepStats> sweep({
    required List<LiveChannel> channels,
    required DeadStreamStore dead,
    void Function(HealthSweepProgress progress)? onProgress,
  }) async {
    final gen = ++_generation;
    final ordered = [
      ...channels.where((c) => c.category.toLowerCase() == 'sports'),
      ...channels.where((c) => c.category.toLowerCase() != 'sports'),
    ];

    final toCheck = <LiveChannel>[];
    for (final ch in ordered) {
      if (dead.isChannelDead(ch.id)) continue;
      final sources = [
        for (final s in ch.selectableSources)
          if (!dead.isUrlDead(s.url) && dead.needsProbe(s.url)) s,
      ];
      if (sources.isEmpty) {
        // All sources already known; if none living, channel will be filtered.
        continue;
      }
      toCheck.add(ch);
    }

    var checked = 0;
    var markedDead = 0;
    var keptAlive = 0;
    final total = toCheck.length;
    onProgress?.call(HealthSweepProgress(
      checked: 0,
      total: total,
      markedDead: 0,
      keptAlive: 0,
      running: true,
    ));

    final pendingDeadUrls = <String>[];
    final pendingDeadChannels = <String>[];
    final pendingAliveUrls = <String>[];

    Future<void> flush() async {
      if (pendingDeadUrls.isEmpty &&
          pendingDeadChannels.isEmpty &&
          pendingAliveUrls.isEmpty) {
        return;
      }
      await dead.applyProbeResults(
        deadUrls: List.of(pendingDeadUrls),
        deadChannels: List.of(pendingDeadChannels),
        aliveUrls: List.of(pendingAliveUrls),
      );
      pendingDeadUrls.clear();
      pendingDeadChannels.clear();
      pendingAliveUrls.clear();
    }

    Future<void> checkOne(LiveChannel ch) async {
      if (gen != _generation) return;
      final sources = [
        for (final s in ch.selectableSources)
          if (!dead.isUrlDead(s.url)) s,
      ];
      if (sources.isEmpty) {
        pendingDeadChannels.add(ch.id);
        markedDead++;
        return;
      }

      var anyAlive = false;
      for (final s in sources) {
        if (gen != _generation) return;
        if (!dead.needsProbe(s.url)) {
          if (dead.isUrlAlive(s.url)) {
            anyAlive = true;
            break;
          }
          continue;
        }
        final ok = await probeUrl(s.url);
        if (gen != _generation) return;
        if (ok) {
          pendingAliveUrls.add(s.url);
          anyAlive = true;
          break;
        }
        pendingDeadUrls.add(s.url);
      }

      if (anyAlive) {
        keptAlive++;
      } else {
        pendingDeadChannels.add(ch.id);
        markedDead++;
      }
    }

    var index = 0;
    Future<void> worker() async {
      while (true) {
        if (gen != _generation) return;
        final i = index++;
        if (i >= toCheck.length) return;
        await checkOne(toCheck[i]);
        checked++;
        if (checked % 8 == 0 || checked == total) {
          await flush();
          onProgress?.call(HealthSweepProgress(
            checked: checked,
            total: total,
            markedDead: markedDead,
            keptAlive: keptAlive,
            running: true,
          ));
        }
      }
    }

    final workers = [
      for (var i = 0; i < concurrency; i++) worker(),
    ];
    await Future.wait(workers);
    if (gen != _generation) {
      return HealthSweepStats(
        checked: checked,
        markedDead: markedDead,
        keptAlive: keptAlive,
        cancelled: true,
      );
    }
    await flush();
    onProgress?.call(HealthSweepProgress(
      checked: checked,
      total: total,
      markedDead: markedDead,
      keptAlive: keptAlive,
      running: false,
    ));
    debugPrint(
      'StreamHealthService: checked=$checked dead=$markedDead '
      'alive=$keptAlive',
    );
    return HealthSweepStats(
      checked: checked,
      markedDead: markedDead,
      keptAlive: keptAlive,
    );
  }

  /// Returns true if the URL looks like a live playlist/media endpoint.
  Future<bool> probeUrl(String url) async {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return false;
    }

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = timeout
        ..idleTimeout = timeout
        ..userAgent = _ua
        ..badCertificateCallback = (cert, host, port) => true;

      final req = await client.getUrl(uri).timeout(timeout);
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.followRedirects = true;
      req.maxRedirects = 5;

      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 400) {
        await res.drain<void>();
        return false;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length >= 96) break;
      }
      await res.drain<void>().catchError((_) {});

      final bytes = builder.takeBytes();
      if (bytes.isEmpty) return false;

      final head = utf8.decode(bytes, allowMalformed: true).trimLeft();
      final lower = head.toLowerCase();
      if (lower.startsWith('#extm3u') ||
          lower.startsWith('#ext-x') ||
          lower.contains('#extinf') ||
          lower.contains('<mpd') ||
          lower.contains('<?xml')) {
        return true;
      }
      // Some feeds serve raw TS / binary — treat non-HTML payload as ok.
      if (lower.startsWith('<!doctype') ||
          lower.startsWith('<html') ||
          lower.contains('not found') ||
          lower.contains('forbidden')) {
        return false;
      }
      return bytes.length >= 16;
    } catch (e) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }
}

class HealthSweepProgress {
  const HealthSweepProgress({
    required this.checked,
    required this.total,
    required this.markedDead,
    required this.keptAlive,
    required this.running,
  });

  final int checked;
  final int total;
  final int markedDead;
  final int keptAlive;
  final bool running;

  double get fraction => total <= 0 ? 1 : checked / total;
}

class HealthSweepStats {
  const HealthSweepStats({
    required this.checked,
    required this.markedDead,
    required this.keptAlive,
    this.cancelled = false,
  });

  final int checked;
  final int markedDead;
  final int keptAlive;
  final bool cancelled;
}
