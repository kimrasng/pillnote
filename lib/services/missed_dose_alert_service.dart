import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/domain/dose_schedule.dart';
import 'package:pillnote/domain/missed_dose_policy.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

class MissedDoseAlertService {
  MissedDoseAlertService({
    required this._store,
    required this._api,
    required this._sessions,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationStore _store;
  final ApiClient _api;
  final SessionStore _sessions;
  final DateTime Function() _now;

  Future<void>? _inFlight;
  final Set<String> _sent = {};
  String? _sentDate;

  Future<void> checkAndSend({DateTime? at}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    final operation = _checkAndSend(at: at);
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<void> _checkAndSend({DateTime? at}) async {
    if (!_sessions.isLoggedIn) return;
    final settings = _store.readSettings();
    if (settings['guardianAlertsEnabled'] == false) return;
    final now = at ?? _now();
    final generation = _sessions.generation;
    final userId = _sessions.session!.userId;
    final date = Medication.dateKey(now);
    if (_sentDate != date) {
      _sent.clear();
      _sentDate = date;
    }
    final rawHistory = _store.readHistory()[date];
    final history = rawHistory is List
        ? rawHistory.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
    final missed = MissedDosePolicy.evaluate(
      now: now,
      doses: DoseSchedule.forDate(
        date: now,
        pills: _store.readPills(),
        groups: _store.readGroups(),
      ),
      history: history,
      reminderMinutes: (settings['reminderMinutes'] as num?)?.toInt() ?? 30,
    );
    for (final dose in missed) {
      if (generation != _sessions.generation ||
          _store.readSettings()['guardianAlertsEnabled'] == false) {
        return;
      }
      final key = '$userId:${dose.eventKey}';
      if (_sent.contains(key)) continue;
      // A dose may have been recorded while an earlier request was in flight.
      final currentHistory = _store.readHistory()[date] as List? ?? const [];
      final stillMissed = MissedDosePolicy.evaluate(
        now: now,
        doses: DoseSchedule.forDate(
          date: now,
          pills: _store.readPills(),
          groups: _store.readGroups(),
        ),
        history: currentHistory
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(),
        reminderMinutes:
            (_store.readSettings()['reminderMinutes'] as num?)?.toInt() ?? 30,
      ).any((candidate) => candidate.eventKey == dose.eventKey);
      if (!stillMissed) continue;
      try {
        await _api.sendMissedDoseAlert(
          eventKey: dose.eventKey,
          medicationName: String.fromCharCodes(
            dose.medicationName.runes.take(100),
          ),
          scheduledAt: dose.scheduledAt,
        );
        _sent.add(key);
      } on ApiException catch (error) {
        if (error.code == 'ACCEPTED_GUARDIAN_REQUIRED' ||
            error.code == 'GUARDIAN_DEVICE_REQUIRED' ||
            error.statusCode == 429 ||
            generation != _sessions.generation) {
          return;
        }
        debugPrint('미복용 보호자 알림 실패: ${error.code}');
      }
    }
  }
}
