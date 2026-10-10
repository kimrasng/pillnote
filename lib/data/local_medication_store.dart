import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:pillnote/data/medication_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the existing preference keys and JSON format readable without migration.
class LocalMedicationStore implements MedicationStore {
  LocalMedicationStore(this._prefs);

  final SharedPreferences _prefs;
  int _dataGeneration = 0;

  static const _onboardingKey = 'onboarding_completed';
  static const _startupPermissionsKey = 'startup_permissions_requested';
  static const _pillsKey = 'user_pills';
  static const _historyKey = 'intake_history';
  static const _groupsKey = 'pill_groups';
  static const _settingsKey = 'app_settings';
  static const _deviceIdKey = 'device_id';
  static const _doseRemindersKey = 'dose_reminders_enabled';
  static const _dataOwnerKey = 'local_data_owner_id';

  @override
  int get dataGeneration => _dataGeneration;

  @override
  bool get hasExplicitDataOwner => _prefs.containsKey(_dataOwnerKey);

  @override
  String? get dataOwnerId =>
      _prefs.getString(_dataOwnerKey) ?? _legacyDataOwner();

  // Older versions kept account sync metadata even after signing out.
  // An ambiguous legacy cache must not be treated as fresh guest data.
  String? _legacyDataOwner() {
    final accounts = <String>{};
    final syncDates = <String, DateTime>{};
    for (final key in _prefs.getKeys()) {
      if (key.startsWith('sync_revision_')) {
        final id = key.substring('sync_revision_'.length);
        if (id.isNotEmpty) accounts.add(id);
      } else if (key.startsWith('last_synced_at_')) {
        final id = key.substring('last_synced_at_'.length);
        if (id.isEmpty || id == 'guest') continue;
        accounts.add(id);
        final at = DateTime.tryParse(_prefs.getString(key) ?? '');
        if (at != null) syncDates[id] = at;
      }
    }
    if (accounts.isEmpty) return null;
    if (accounts.length == 1) return accounts.single;
    final recent = syncDates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (recent.isNotEmpty &&
        (recent.length == 1 || recent.first.value.isAfter(recent[1].value))) {
      return recent.first.key;
    }
    return '<legacy-account-cache>';
  }

  @override
  Future<void> saveDataOwnerId(String userId) async {
    if (!await _prefs.setString(_dataOwnerKey, userId)) {
      throw StateError('로컬 데이터 소유 계정을 저장하지 못했습니다.');
    }
  }

  @override
  Future<void> clearSyncMetadata(String userId) async {
    await _removeKeys([_revisionKey(userId), _lastSyncKey(userId)]);
  }

  // Notification preferences belong to this installation, not cloud settings.
  @override
  bool get doseRemindersEnabled => _prefs.getBool(_doseRemindersKey) ?? true;

  @override
  Future<void> setDoseRemindersEnabled(bool enabled) async {
    await _prefs.setBool(_doseRemindersKey, enabled);
  }

  @override
  bool get onboardingCompleted => _prefs.getBool(_onboardingKey) ?? false;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_onboardingKey, completed);
  }

  @override
  bool get startupPermissionsRequested =>
      _prefs.getBool(_startupPermissionsKey) ?? false;

  @override
  Future<void> setStartupPermissionsRequested() async {
    if (!await _prefs.setBool(_startupPermissionsKey, true)) {
      throw StateError('첫 실행 권한 요청 상태를 저장하지 못했습니다.');
    }
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
  Map<String, dynamic> readSettings() {
    final saved = _readMap(_settingsKey);
    return {
      'reminderMinutes': 30,
      'guardianAlertsEnabled': true,
      ...saved,
      // Distinguish existing legacy settings from untouched device defaults.
      if (saved.isNotEmpty && saved['updatedAt'] == null)
        'updatedAt': '1970-01-01T00:00:00.000Z',
    };
  }

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
    _dataGeneration++;
    await _removeKeys([
      _pillsKey,
      _groupsKey,
      _historyKey,
      _settingsKey,
      _doseRemindersKey,
      if (userId != null) _revisionKey(userId),
      _lastSyncKey(userId),
    ]);
  }

  Future<void> _removeKeys(List<String> keys) async {
    final removed = await Future.wait(keys.map(_prefs.remove));
    if (removed.any((success) => !success)) {
      throw StateError('이전 로컬 데이터를 삭제하지 못했습니다.');
    }
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
