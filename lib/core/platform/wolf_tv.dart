import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Runtime TV / Fire Stick detector.
///
/// Focus chrome and D-pad traversal are enabled **only** when this reports
/// true. Android phones, macOS, Windows, and iOS always stay false — never
/// inferred from screen size alone.
abstract final class WolfTv {
  static const _channel = MethodChannel('wolftvee/device');

  static bool _isTv = false;
  static bool _ready = false;

  /// True only on Android TV / Fire TV / Fire Stick (leanback / Fire TV).
  static bool get isTv => _isTv;

  static bool get isReady => _ready;

  /// Call once from [main] before [runApp].
  static Future<void> init() async {
    if (_ready) return;
    _ready = true;

    if (kIsWeb || !Platform.isAndroid) {
      _isTv = false;
      return;
    }

    try {
      final result = await _channel.invokeMethod<bool>('isTelevision');
      _isTv = result ?? false;
    } catch (_) {
      _isTv = false;
    }
  }

  /// Test / preview override — never call from production UI paths.
  @visibleForTesting
  static void debugSetIsTv(bool value) {
    _isTv = value;
    _ready = true;
  }
}
