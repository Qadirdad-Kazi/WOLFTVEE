import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User profile + app preference store.
class SettingsStore extends ChangeNotifier {
  SettingsStore();

  static const _kName = 'wolf_display_name';
  static const _kHandle = 'wolf_handle';
  static const _kMotion = 'wolf_motion';
  static const _kAutoRefresh = 'wolf_auto_refresh';
  static const _kCacheHours = 'wolf_cache_hours';
  static const _kNotifs = 'wolf_notifs';

  String displayName = 'Hunter';
  String handle = 'pack_alpha';
  bool intenseMotion = true;
  bool autoRefreshOnOpen = true;
  bool notifications = false;
  int cacheHours = 6;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    displayName = p.getString(_kName) ?? displayName;
    handle = p.getString(_kHandle) ?? handle;
    intenseMotion = p.getBool(_kMotion) ?? true;
    autoRefreshOnOpen = p.getBool(_kAutoRefresh) ?? true;
    notifications = p.getBool(_kNotifs) ?? false;
    cacheHours = p.getInt(_kCacheHours) ?? 6;
    notifyListeners();
  }

  Future<void> setDisplayName(String v) async {
    displayName = v.trim().isEmpty ? 'Hunter' : v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, displayName);
    notifyListeners();
  }

  Future<void> setHandle(String v) async {
    handle = v.trim().replaceAll(' ', '_').toLowerCase();
    if (handle.isEmpty) handle = 'pack_alpha';
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHandle, handle);
    notifyListeners();
  }

  Future<void> setMotion(bool v) async {
    intenseMotion = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMotion, v);
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool v) async {
    autoRefreshOnOpen = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAutoRefresh, v);
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    notifications = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNotifs, v);
    notifyListeners();
  }

  Future<void> setCacheHours(int hours) async {
    cacheHours = hours.clamp(1, 72);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kCacheHours, cacheHours);
    notifyListeners();
  }
}
