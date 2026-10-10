import 'package:pillnote/domain/dose_schedule.dart';
import 'package:pillnote/models/medication.dart';
import 'package:timezone/timezone.dart' as tz;

/// Upcoming untaken doses, grouped by actual notification instant.
class DoseReminderPlan {
  DoseReminderPlan._();

  static List<DoseReminder> build({
    required DateTime now,
    required tz.Location location,
    required List<Map<String, dynamic>> pills,
    required List<Map<String, dynamic>> groups,
    required Map<String, dynamic> history,
    required int limit,
    int horizonDays = 366,
  }) {
    final today = tz.TZDateTime.from(now, location);
    final reminders = <DoseReminder>[];
    for (var offset = 0; offset < horizonDays; offset++) {
      final day = tz.TZDateTime(
        location,
        today.year,
        today.month,
        today.day + offset,
      );
      final date = Medication.dateKey(day);
      final taken = <String>{
        for (final entry
            in (history[date] as List? ?? const []).whereType<Map>())
          if (entry['cancelled'] != true && entry['pillId'] != null)
            '${entry['pillId']}|${entry['scheduledTime']}',
      };
      final byInstant = <int, DoseReminder>{};
      for (final dose in DoseSchedule.forDate(
        date: day,
        pills: pills,
        groups: groups,
      )) {
        if (taken.contains(dose.key)) continue;
        final parts = dose.time.split(':').map(int.parse).toList();
        // Construct each calendar day in its zone; adding 24h breaks DST.
        final at = tz.TZDateTime(
          location,
          day.year,
          day.month,
          day.day,
          parts[0],
          parts[1],
        );
        if (!at.isAfter(now)) continue;
        final existing = byInstant[at.millisecondsSinceEpoch];
        byInstant[at.millisecondsSinceEpoch] = DoseReminder(
          at: at,
          doseCount: (existing?.doseCount ?? 0) + 1,
        );
      }
      final daily = byInstant.values.toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      reminders.addAll(daily);
      if (reminders.length >= limit) break;
    }
    return reminders.take(limit).toList();
  }
}

class DoseReminder {
  const DoseReminder({required this.at, required this.doseCount});
  static const payloadPrefix = 'pillnote-dose:';
  final tz.TZDateTime at;
  final int doseCount;

  // Stable, positive Android int IDs in a namespace reserved for local doses.
  // Calendar minutes are unique throughout the bounded reservation period.
  int get id =>
      0x40000000 +
      (DateTime.utc(
                at.year,
                at.month,
                at.day,
                at.hour,
                at.minute,
              ).millisecondsSinceEpoch ~/
              60000) %
          0x40000000;
  String get time =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  String get title => 'PillNote 복용 시간 알림';
  String get body => '$time 복용할 약이 $doseCount개 있어요. 오늘 일정을 확인해주세요.';
  // No medication names or account identifiers appear on the lock screen.
  String payload({required bool exact}) =>
      '$payloadPrefix'
      '${at.millisecondsSinceEpoch}:${at.location.name}:$doseCount:$exact';
}
