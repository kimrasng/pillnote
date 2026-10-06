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

  Future<void> checkAndSend({DateTime? at}) async {
    if (!_sessions.isLoggedIn) return;
    final settings = _store.readSettings();
    if (settings['guardianAlertsEnabled'] == false) return;
    final now = at ?? _now();
    final rawHistory = _store.readHistory()[Medication.dateKey(now)];
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
      try {
        await _api.sendMissedDoseAlert(
          eventKey: dose.eventKey,
          medicationName: dose.medicationName,
          scheduledAt: dose.scheduledAt,
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
