import 'package:pillnote/models/medication.dart';

class MissedDose {
  const MissedDose({
    required this.eventKey,
    required this.medicationName,
    required this.scheduledAt,
  });

  final String eventKey;
  final String medicationName;
  final DateTime scheduledAt;
}

/// Determines overdue doses without reading storage or contacting the server.
class MissedDosePolicy {
  MissedDosePolicy._();

  static List<MissedDose> evaluate({
    required DateTime now,
    required List<ScheduledDose> doses,
    required List<Map<String, dynamic>> history,
    required int reminderMinutes,
  }) {
    final takenKeys = history
        .where((entry) => entry['cancelled'] != true)
        .map((entry) => '${entry['pillId']}|${entry['scheduledTime']}')
        .toSet();
    final date = Medication.dateKey(now).replaceAll('-', '');
    final missed = <MissedDose>[];
    for (final dose in doses) {
      final id = dose.pill['id']?.toString() ?? '';
      if (id.isEmpty || takenKeys.contains(dose.key)) continue;
      final parts = dose.time.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduled.add(Duration(minutes: reminderMinutes)).isAfter(now)) {
        continue;
      }
      final safeId = id.replaceAll(RegExp(r'[^0-9A-Za-z._:-]'), '_');
      missed.add(
        MissedDose(
          eventKey: '$safeId:$date:${dose.time.replaceAll(':', '')}',
          medicationName:
              (dose.pill['ITEM_NAME'] ?? dose.pill['name'] ?? '등록한 약')
                  .toString(),
          scheduledAt: scheduled,
        ),
      );
    }
    return missed;
  }
}
