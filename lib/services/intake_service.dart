import 'dart:math';

import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/models/medication.dart';

/// Owns intake history and the corresponding stock deduction/restoration.
class IntakeService {
  IntakeService({
    required this._store,
    required this._onChanged,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationStore _store;
  final void Function() _onChanged;
  final DateTime Function() _now;

  Map<String, dynamic> getFullHistory() => _store.readHistory();

  List<Map<String, dynamic>> getHistoryByDate(String date) {
    final value = getFullHistory()[date];
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .where((entry) => entry['cancelled'] != true)
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  Future<void> recordIntake(
    String pillId,
    String scheduledTime, {
    String? date,
  }) async {
    final targetDate = date ?? Medication.dateKey(_now());
    final history = getFullHistory();
    final dayHistory = List<dynamic>.from(
      history[targetDate] as List? ?? const [],
    );
    final alreadyRecorded = dayHistory.any(
      (entry) =>
          entry is Map &&
          entry['cancelled'] != true &&
          entry['pillId']?.toString() == pillId &&
          entry['scheduledTime']?.toString() == scheduledTime,
    );
    if (alreadyRecorded) return;

    final pills = _store.readPills();
    final index = pills.indexWhere((pill) => pill['id'] == pillId);
    if (index == -1) return;
    final pill = pills[index];
    final dosage = (pill['dosage'] as num?)?.toDouble() ?? 1;
    final stock = (pill['stock'] as num?)?.toDouble() ?? 0;
    final delta = Medication.tracksStock(pill) ? min(max(0, stock), dosage) : 0;
    dayHistory.removeWhere(
      (entry) =>
          entry is Map &&
          entry['pillId'] == pillId &&
          entry['scheduledTime'] == scheduledTime,
    );
    final timestamp = _now().toIso8601String();
    dayHistory.add({
      'pillId': pillId,
      'scheduledTime': scheduledTime,
      'takenAt': timestamp,
      'updatedAt': timestamp,
      'stockDelta': delta,
      'cancelled': false,
    });
    history[targetDate] = dayHistory;
    await _store.saveHistory(history);
    if (Medication.tracksStock(pill)) {
      pills[index]['stock'] = stock - delta;
      pills[index]['updatedAt'] = timestamp;
      await _store.savePills(pills);
    }
    _onChanged();
  }

  Future<void> undoIntake(String pillId, String time, {String? date}) async {
    final targetDate = date ?? Medication.dateKey(_now());
    final history = getFullHistory();
    final entries = List<dynamic>.from(
      history[targetDate] as List? ?? const [],
    );
    final index = entries.indexWhere(
      (entry) =>
          entry is Map &&
          entry['pillId'] == pillId &&
          entry['scheduledTime'] == time &&
          entry['cancelled'] != true,
    );
    if (index == -1) return;
    final entry = Map<String, dynamic>.from(entries[index] as Map);
    final timestamp = _now().toIso8601String();
    entries[index] = {...entry, 'cancelled': true, 'updatedAt': timestamp};
    history[targetDate] = entries;
    await _store.saveHistory(history);
    final pills = _store.readPills();
    final pillIndex = pills.indexWhere((p) => p['id'] == pillId);
    if (pillIndex != -1 && Medication.tracksStock(pills[pillIndex])) {
      pills[pillIndex]['updatedAt'] = timestamp;
      final delta =
          (entry['stockDelta'] as num?) ??
          (pills[pillIndex]['dosage'] as num?) ??
          1;
      pills[pillIndex]['stock'] =
          ((pills[pillIndex]['stock'] as num?) ?? 0) + delta;
      await _store.savePills(pills);
    }
    _onChanged();
  }

  Future<void> recordGroupIntake(
    String groupId,
    String scheduledTime, {
    String? date,
  }) async {
    final group = _store
        .readGroups()
        .where((item) => item['id'] == groupId && item['deleted'] != true)
        .firstOrNull;
    if (group == null) return;
    final targetDate = date ?? Medication.dateKey(_now());
    for (final pillId in group['pillIds'] as List? ?? const []) {
      await recordIntake(pillId.toString(), scheduledTime, date: targetDate);
    }

    final history = getFullHistory();
    final dayHistory = List<dynamic>.from(
      history[targetDate] as List? ?? const [],
    );
    if (dayHistory.any(
      (entry) =>
          entry is Map &&
          entry['groupId']?.toString() == groupId &&
          entry['scheduledTime']?.toString() == scheduledTime,
    )) {
      return;
    }
    dayHistory.add({
      'groupId': groupId,
      'scheduledTime': scheduledTime,
      'takenAt': _now().toIso8601String(),
    });
    history[targetDate] = dayHistory;
    await _store.saveHistory(history);
    _onChanged();
  }
}
