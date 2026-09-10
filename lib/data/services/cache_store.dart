import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Memory + disk JSON cache with TTL.
class CacheStore {
  CacheStore({this.ttl = const Duration(hours: 6)});

  Duration ttl;
  final Map<String, _MemEntry> _memory = {};
  Directory? _dir;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}/wolftvee_cache');
      if (!await _dir!.exists()) {
        await _dir!.create(recursive: true);
      }
      _ready = true;
    } catch (e) {
      debugPrint('CacheStore init failed: $e');
      _ready = true;
    }
  }

  String _safeName(String key) =>
      key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  Future<Map<String, dynamic>?> get(String key) async {
    await init();
    final mem = _memory[key];
    if (mem != null && !mem.isExpired) return mem.data;

    final dir = _dir;
    if (dir == null) return null;

    final file = File('${dir.path}/${_safeName(key)}.json');
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(raw['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (DateTime.now().difference(savedAt) > ttl) {
        await file.delete();
        return null;
      }
      final data = Map<String, dynamic>.from(raw['data'] as Map);
      _memory[key] = _MemEntry(data, savedAt.add(ttl));
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String key, Map<String, dynamic> data) async {
    await init();
    final expires = DateTime.now().add(ttl);
    _memory[key] = _MemEntry(data, expires);

    final dir = _dir;
    if (dir == null) return;
    final file = File('${dir.path}/${_safeName(key)}.json');
    final payload = jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'data': data,
    });
    await file.writeAsString(payload);
  }

  Future<CacheStats> stats() async {
    await init();
    var files = 0;
    var bytes = 0;
    final dir = _dir;
    if (dir != null && await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          files++;
          bytes += await entity.length();
        }
      }
    }
    return CacheStats(
      memoryEntries: _memory.length,
      diskFiles: files,
      diskBytes: bytes,
    );
  }

  Future<void> clear() async {
    _memory.clear();
    final dir = _dir;
    if (dir == null || !await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
  }
}

class CacheStats {
  const CacheStats({
    required this.memoryEntries,
    required this.diskFiles,
    required this.diskBytes,
  });

  final int memoryEntries;
  final int diskFiles;
  final int diskBytes;

  String get diskLabel {
    if (diskBytes < 1024) return '$diskBytes B';
    if (diskBytes < 1024 * 1024) {
      return '${(diskBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(diskBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _MemEntry {
  _MemEntry(this.data, this.expiresAt);
  final Map<String, dynamic> data;
  final DateTime expiresAt;
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
