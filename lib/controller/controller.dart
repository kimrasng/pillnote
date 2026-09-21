import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Controller {
  static late SharedPreferences _prefs;
  static bool _initialized = false;
  static Timer? _syncDebounce;
  static bool _syncing = false;
  static bool _syncAgain = false;

  static const _onboardingKey = 'onboarding_completed';
  static const _pillsKey = 'user_pills';
  static const _historyKey = 'intake_history';
  static const _groupsKey = 'pill_groups';
  static const _settingsKey = 'app_settings';
  static const _deviceIdKey = 'device_id';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_onboardingKey, completed);
  }

  static bool shouldShowOnboarding() =>
      !(_prefs.getBool(_onboardingKey) ?? false);

  static bool isLoggedIn() => SessionStore.instance.isLoggedIn;

  static String get deviceId {
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

  static List<Map<String, dynamic>> getPills() =>
      _decodeList(_prefs.getString(_pillsKey));

  static List<Map<String, dynamic>> getGroups() =>
      _decodeList(_prefs.getString(_groupsKey));

  static Map<String, dynamic> getFullHistory() =>
      _decodeMap(_prefs.getString(_historyKey));

  static Map<String, dynamic> getSettings() {
    final settings = _decodeMap(_prefs.getString(_settingsKey));
    return {'reminderMinutes': 30, 'guardianAlertsEnabled': true, ...settings};
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings));
    _scheduleSync();
  }

  static List<Map<String, dynamic>> getHistoryByDate(String date) {
    final value = getFullHistory()[date];
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  static Future<void> addPill(Map<String, dynamic> pill, int stock) async {
    final pills = getPills();
    pills.add({
      ...pill,
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'createdAt': DateTime.now().toIso8601String(),
      'startDate': null,
      'endDate': null,
      'times': <String>[],
      'stock': stock,
      'dosage': 1.0,
    });
    await _saveList(_pillsKey, pills);
  }

  static Future<void> updatePillSchedule(
    String pillId,
    String? startDate,
    String? endDate,
    List<String> times,
    double dosage,
  ) async {
    final pills = getPills();
    final index = pills.indexWhere((pill) => pill['id'] == pillId);
    if (index == -1) return;
    pills[index]['startDate'] = startDate;
    pills[index]['endDate'] = endDate;
    pills[index]['times'] = times;
    pills[index]['dosage'] = dosage;
    await _saveList(_pillsKey, pills);
  }

  static Future<void> removePill(String pillId) async {
    final pills = getPills()..removeWhere((pill) => pill['id'] == pillId);
    await _saveList(_pillsKey, pills);
  }

  static Future<void> removePillFromGroups(String pillId) async {
    final groups = getGroups();
    for (final group in groups) {
      final ids = List<dynamic>.from(group['pillIds'] as List? ?? const []);
      ids.removeWhere((id) => id.toString() == pillId);
      group['pillIds'] = ids;
    }
    groups.removeWhere((group) => (group['pillIds'] as List).isEmpty);
    await _saveList(_groupsKey, groups);
  }

  static Future<void> recordIntake(
    String pillId,
    String scheduledTime, {
    String? date,
  }) async {
    final targetDate = date ?? _dateKey(DateTime.now());
    final history = getFullHistory();
    final dayHistory = List<dynamic>.from(
      history[targetDate] as List? ?? const [],
    );
    final alreadyRecorded = dayHistory.any(
      (entry) =>
          entry is Map &&
          entry['pillId']?.toString() == pillId &&
          entry['scheduledTime']?.toString() == scheduledTime,
    );
    if (alreadyRecorded) return;

    dayHistory.add({
      'pillId': pillId,
      'scheduledTime': scheduledTime,
      'takenAt': DateTime.now().toIso8601String(),
    });
    history[targetDate] = dayHistory;
    await _prefs.setString(_historyKey, jsonEncode(history));

    final pills = getPills();
    final index = pills.indexWhere((pill) => pill['id'] == pillId);
    if (index != -1) {
      final dosage = (pills[index]['dosage'] as num?)?.toDouble() ?? 1.0;
      final stock = (pills[index]['stock'] as num?)?.toDouble() ?? 0;
      pills[index]['stock'] = max(0, stock - dosage);
      await _prefs.setString(_pillsKey, jsonEncode(pills));
    }
    _scheduleSync();
  }

  static Future<void> saveGroup(Map<String, dynamic> group) async {
    final groups = getGroups();
    final saved = Map<String, dynamic>.from(group);
    saved['id'] ??= DateTime.now().microsecondsSinceEpoch.toString();
    final index = groups.indexWhere((item) => item['id'] == saved['id']);
    if (index == -1) {
      groups.add(saved);
    } else {
      groups[index] = saved;
    }
    await _saveList(_groupsKey, groups);
  }

  static Future<void> removeGroup(String groupId) async {
    final groups = getGroups()..removeWhere((group) => group['id'] == groupId);
    await _saveList(_groupsKey, groups);
  }

  static Future<void> recordGroupIntake(
    String groupId,
    String scheduledTime, {
    String? date,
  }) async {
    final group = getGroups().firstWhere(
      (item) => item['id'] == groupId,
      orElse: () => <String, dynamic>{},
    );
    if (group.isEmpty) return;
    for (final pillId in List<dynamic>.from(
      group['pillIds'] as List? ?? const [],
    )) {
      await recordIntake(pillId.toString(), scheduledTime, date: date);
    }

    final targetDate = date ?? _dateKey(DateTime.now());
    final history = getFullHistory();
    final dayHistory = List<dynamic>.from(
      history[targetDate] as List? ?? const [],
    );
    if (!dayHistory.any(
      (entry) =>
          entry is Map &&
          entry['groupId']?.toString() == groupId &&
          entry['scheduledTime']?.toString() == scheduledTime,
    )) {
      dayHistory.add({
        'groupId': groupId,
        'scheduledTime': scheduledTime,
        'takenAt': DateTime.now().toIso8601String(),
      });
      history[targetDate] = dayHistory;
      await _prefs.setString(_historyKey, jsonEncode(history));
      _scheduleSync();
    }
  }

  static Map<String, dynamic> buildSnapshot() => {
    'schemaVersion': 1,
    'deviceId': deviceId,
    'pills': getPills(),
    'groups': getGroups(),
    'intakeHistory': getFullHistory(),
    'settings': getSettings(),
  };

  static Future<int?> reconcileWithServer() async {
    if (!SessionStore.instance.isLoggedIn) return null;
    final remote = await ApiClient.instance.fetchSnapshot();
    final revision = (remote['revision'] as num?)?.toInt() ?? 0;
    final remoteSnapshot = remote['snapshot'];
    if (remoteSnapshot is Map) {
      await _applySnapshot(
        _mergeSnapshots(
          Map<String, dynamic>.from(remoteSnapshot),
          buildSnapshot(),
        ),
      );
    }
    await _setSyncRevision(revision);
    return syncToServer();
  }

  static Future<int?> syncToServer() async {
    if (!SessionStore.instance.isLoggedIn) return null;
    if (_syncing) {
      _syncAgain = true;
      return _syncRevision;
    }

    _syncing = true;
    try {
      int? revision;
      do {
        _syncAgain = false;
        revision = await _uploadSnapshot();
      } while (_syncAgain);
      return revision;
    } finally {
      _syncing = false;
    }
  }

  static Future<void> deleteCloudBackup() async {
    if (!SessionStore.instance.isLoggedIn) return;
    final remote = await ApiClient.instance.fetchSnapshot();
    final revision = (remote['revision'] as num?)?.toInt() ?? 0;
    await ApiClient.instance.deleteSnapshot(revision);
    await _setSyncRevision(0);
  }

  static Future<int> _uploadSnapshot() async {
    var revision = _syncRevision;
    if (revision == null) {
      final remote = await ApiClient.instance.fetchSnapshot();
      revision = (remote['revision'] as num?)?.toInt() ?? 0;
      await _setSyncRevision(revision);
    }

    try {
      final saved = await ApiClient.instance.saveSnapshot(
        baseRevision: revision,
        snapshot: buildSnapshot(),
      );
      final next = (saved['revision'] as num?)?.toInt() ?? revision + 1;
      await _setSyncRevision(next);
      return next;
    } on ApiException catch (error) {
      if (error.code != 'SYNC_CONFLICT') rethrow;
      final remote = await ApiClient.instance.fetchSnapshot();
      final currentRevision = (remote['revision'] as num?)?.toInt() ?? 0;
      final remoteSnapshot = remote['snapshot'];
      if (remoteSnapshot is Map) {
        await _applySnapshot(
          _mergeSnapshots(
            Map<String, dynamic>.from(remoteSnapshot),
            buildSnapshot(),
          ),
        );
      }
      final saved = await ApiClient.instance.saveSnapshot(
        baseRevision: currentRevision,
        snapshot: buildSnapshot(),
      );
      final next = (saved['revision'] as num?)?.toInt() ?? currentRevision + 1;
      await _setSyncRevision(next);
      return next;
    }
  }

  static Future<void> checkAndSendMissedDoseAlerts({DateTime? at}) async {
    if (!SessionStore.instance.isLoggedIn) return;
    final settings = getSettings();
    if (settings['guardianAlertsEnabled'] == false) return;
    final now = at ?? DateTime.now();
    final date = _dateKey(now);
    final history = getHistoryByDate(date);
    final grace = (settings['reminderMinutes'] as num?)?.toInt() ?? 30;

    for (final pill in getPills()) {
      final id = pill['id']?.toString() ?? '';
      final name =
          pill['ITEM_NAME']?.toString() ?? pill['name']?.toString() ?? '등록한 약';
      if (id.isEmpty || !_isActiveOn(pill, now)) continue;
      for (final rawTime in List<dynamic>.from(
        pill['times'] as List? ?? const [],
      )) {
        final parts = rawTime.toString().split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;
        final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        if (scheduled.add(Duration(minutes: grace)).isAfter(now)) continue;
        final taken = history.any(
          (entry) =>
              entry['pillId']?.toString() == id &&
              entry['scheduledTime']?.toString() == rawTime.toString(),
        );
        if (taken) continue;

        final safeId = id.replaceAll(RegExp(r'[^0-9A-Za-z._:-]'), '_');
        final eventKey =
            '$safeId:${date.replaceAll('-', '')}:${rawTime.toString().replaceAll(':', '')}';
        try {
          await ApiClient.instance.sendMissedDoseAlert(
            eventKey: eventKey,
            medicationName: name,
            scheduledAt: scheduled,
          );
        } on ApiException catch (error) {
          if (error.code != 'ACCEPTED_GUARDIAN_REQUIRED' &&
              error.code != 'GUARDIAN_DEVICE_REQUIRED') {
            debugPrint('미복용 보호자 알림 실패: ${error.code}');
          }
        }
      }
    }
  }

  static Future<void> clearLocalData() async {
    _syncDebounce?.cancel();
    final session = SessionStore.instance.session;
    await Future.wait([
      _prefs.remove(_pillsKey),
      _prefs.remove(_groupsKey),
      _prefs.remove(_historyKey),
      _prefs.remove(_settingsKey),
      if (session != null) _prefs.remove(_revisionKey(session.userId)),
    ]);
  }

  static int? get _syncRevision {
    final session = SessionStore.instance.session;
    return session == null ? null : _prefs.getInt(_revisionKey(session.userId));
  }

  static Future<void> _setSyncRevision(int revision) async {
    final session = SessionStore.instance.session;
    if (session != null) {
      await _prefs.setInt(_revisionKey(session.userId), revision);
    }
  }

  static String _revisionKey(String userId) => 'sync_revision_$userId';

  static void _scheduleSync() {
    if (!_initialized || !SessionStore.instance.isLoggedIn) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        await syncToServer();
      } catch (error) {
        debugPrint('백그라운드 동기화 실패: $error');
      }
    });
  }

  static Future<void> _saveList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    await _prefs.setString(key, jsonEncode(value));
    _scheduleSync();
  }

  static Future<void> _applySnapshot(Map<String, dynamic> snapshot) async {
    await Future.wait([
      _prefs.setString(_pillsKey, jsonEncode(snapshot['pills'] ?? const [])),
      _prefs.setString(_groupsKey, jsonEncode(snapshot['groups'] ?? const [])),
      _prefs.setString(
        _historyKey,
        jsonEncode(snapshot['intakeHistory'] ?? const <String, dynamic>{}),
      ),
      _prefs.setString(
        _settingsKey,
        jsonEncode(snapshot['settings'] ?? const <String, dynamic>{}),
      ),
    ]);
  }

  static Map<String, dynamic> _mergeSnapshots(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) {
    List<Map<String, dynamic>> mergeById(Object? first, Object? second) {
      final merged = <String, Map<String, dynamic>>{};
      for (final source in [first, second]) {
        if (source is! List) continue;
        for (final item in source.whereType<Map>()) {
          final map = Map<String, dynamic>.from(item);
          final id = map['id']?.toString();
          if (id != null && id.isNotEmpty) merged[id] = map;
        }
      }
      return merged.values.toList();
    }

    final history = <String, dynamic>{};
    for (final source in [remote['intakeHistory'], local['intakeHistory']]) {
      if (source is! Map) continue;
      for (final entry in source.entries) {
        final key = entry.key.toString();
        final existing = List<dynamic>.from(history[key] as List? ?? const []);
        for (final item in List<dynamic>.from(
          entry.value as List? ?? const [],
        )) {
          final encoded = jsonEncode(item);
          if (!existing.any((value) => jsonEncode(value) == encoded)) {
            existing.add(item);
          }
        }
        history[key] = existing;
      }
    }

    return {
      'schemaVersion': 1,
      'deviceId': local['deviceId'] ?? remote['deviceId'],
      'pills': mergeById(remote['pills'], local['pills']),
      'groups': mergeById(remote['groups'], local['groups']),
      'intakeHistory': history,
      'settings': {
        ...Map<String, dynamic>.from(remote['settings'] as Map? ?? const {}),
        ...Map<String, dynamic>.from(local['settings'] as Map? ?? const {}),
      },
    };
  }

  static bool _isActiveOn(Map<String, dynamic> pill, DateTime date) {
    final start = DateTime.tryParse(pill['startDate']?.toString() ?? '');
    final end = DateTime.tryParse(pill['endDate']?.toString() ?? '');
    final day = DateTime(date.year, date.month, date.day);
    if (start != null &&
        day.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null && day.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  static List<Map<String, dynamic>> _decodeList(String? value) {
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

  static Map<String, dynamic> _decodeMap(String? value) {
    if (value == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      return {};
    }
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
