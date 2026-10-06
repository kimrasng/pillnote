import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:pillnote/data/medication_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the existing preference keys and JSON format readable without migration.
class LocalMedicationStore implements MedicationStore {
  LocalMedicationStore(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingKey = 'onboarding_completed';
  static const _pillsKey = 'user_pills';
  static const _historyKey = 'intake_history';
  static const _groupsKey = 'pill_groups';
  static const _settingsKey = 'app_settings';
  static const _deviceIdKey = 'device_id';

  @override
  bool get onboardingCompleted => _prefs.getBool(_onboardingKey) ?? false;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_onboardingKey, completed);
  }

  @override
  String get deviceId {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final generated = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    unawaited(_prefs.setString(_deviceIdKey, generated));
    return generated;
  }

  @override
  List<Map<String, dynamic>> readPills() => _readList(_pillsKey);

  @override
  List<Map<String, dynamic>> readGroups() => _readList(_groupsKey);

  @override
  Map<String, dynamic> readHistory() => _readMap(_historyKey);

  @override
  Map<String, dynamic> readSettings() => {
    'reminderMinutes': 30,
    'guardianAlertsEnabled': true,
    ..._readMap(_settingsKey),
  };

  @override
  Future<void> savePills(List<Map<String, dynamic>> pills) =>
      _writeJson(_pillsKey, pills);

  @override
  Future<void> saveGroups(List<Map<String, dynamic>> groups) =>
      _writeJson(_groupsKey, groups);

  @override
  Future<void> saveHistory(Map<String, dynamic> history) =>
      _writeJson(_historyKey, history);

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) =>
      _writeJson(_settingsKey, settings);

  @override
  int? readSyncRevision(String userId) => _prefs.getInt(_revisionKey(userId));

  @override
  Future<void> saveSyncRevision(String userId, int revision) async {
    await _prefs.setInt(_revisionKey(userId), revision);
  }

  @override
  DateTime? readLastSyncedAt(String? userId) =>
      DateTime.tryParse(_prefs.getString(_lastSyncKey(userId)) ?? '');

  @override
  Future<void> saveLastSyncedAt(String? userId, DateTime at) async {
    await _prefs.setString(_lastSyncKey(userId), at.toIso8601String());
  }

  @override
  Future<void> clearLastSyncedAt(String? userId) async {
    await _prefs.remove(_lastSyncKey(userId));
  }

  @override
  Future<void> clear({String? userId}) async {
    await Future.wait([
      _prefs.remove(_pillsKey),
      _prefs.remove(_groupsKey),
      _prefs.remove(_historyKey),
      _prefs.remove(_settingsKey),
      if (userId != null) _prefs.remove(_revisionKey(userId)),
      _prefs.remove(_lastSyncKey(userId)),
    ]);
  }

  Future<void> _writeJson(String key, Object value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  List<Map<String, dynamic>> _readList(String key) {
    final value = _prefs.getString(key);
    if (value == null) return [];
    try {
      return (jsonDecode(value) as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _readMap(String key) {
    final value = _prefs.getString(key);
    if (value == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return {};
    }
  }

  static String _revisionKey(String userId) => 'sync_revision_$userId';
  static String _lastSyncKey(String? userId) =>
      'last_synced_at_${userId ?? 'guest'}';
}
