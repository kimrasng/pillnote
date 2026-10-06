import 'package:pillnote/models/medication.dart';

/// Pure schedule calculation, shared by the home screen and missed-dose alerts.
class DoseSchedule {
  DoseSchedule._();

  /// Individual and group schedules describe one dose when pill and time match.
  static List<ScheduledDose> forDate({
    required DateTime date,
    required List<Map<String, dynamic>> pills,
    required List<Map<String, dynamic>> groups,
  }) {
    final byId = {for (final pill in pills) pill['id'].toString(): pill};
    final slots = <String, ScheduledDose>{};
    for (final pill in pills.where((p) => Medication.isActiveOn(p, date))) {
      for (final time in Medication.times(pill['times'])) {
        final dose = ScheduledDose(pill: pill, time: time);
        slots[dose.key] = dose;
      }
    }
    for (final group in groups.where(
      (g) => g['deleted'] != true && Medication.isActiveOn(g, date),
    )) {
      for (final id in group['pillIds'] as List? ?? const []) {
        final pill = byId[id.toString()];
        // Group periods are independent of the individual medication's period.
        if (pill == null || Medication.isArchivedOn(pill, date)) continue;
        for (final time in Medication.times(group['times'])) {
          final key = '$id|$time';
          slots[key] = ScheduledDose(
            pill: pill,
            time: time,
            groups: {
              ...?slots[key]?.groups,
              (group['name'] ?? '약 묶음').toString(),
            }.toList(),
          );
        }
      }
    }
    return slots.values.toList()..sort((a, b) {
      final timeOrder = a.time.compareTo(b.time);
      return timeOrder != 0
          ? timeOrder
          : Medication.name(a.pill).compareTo(Medication.name(b.pill));
    });
  }

  static DailyDosePlan dailyPlan({
    required DateTime date,
    required List<Map<String, dynamic>> pills,
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> history,
  }) {
    final takenKeys = <String>{};
    final slots = {
      for (final dose in forDate(date: date, pills: pills, groups: groups))
        dose.key: dose,
    };
    final byId = {for (final pill in pills) pill['id']: pill};
    // Completed doses stay on their original day after their schedule is edited.
    for (final record in history) {
      if (record['cancelled'] == true || record['pillId'] == null) continue;
      takenKeys.add('${record['pillId']}|${record['scheduledTime']}');
      final pill = byId[record['pillId']];
      if (pill == null) continue;
      final dose = ScheduledDose(
        pill: pill,
        time: '${record['scheduledTime']}',
      );
      slots.putIfAbsent(dose.key, () => dose);
    }
    final doses = slots.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return DailyDosePlan(
      doses: doses,
      pending: doses.where((dose) => !takenKeys.contains(dose.key)).toList(),
      completed: doses.where((dose) => takenKeys.contains(dose.key)).toList(),
    );
  }
}

class DailyDosePlan {
  DailyDosePlan({
    required List<ScheduledDose> doses,
    required List<ScheduledDose> pending,
    required List<ScheduledDose> completed,
  }) : doses = List.unmodifiable(doses),
       pending = List.unmodifiable(pending),
       completed = List.unmodifiable(completed);

  final List<ScheduledDose> doses;
  final List<ScheduledDose> pending;
  final List<ScheduledDose> completed;

  ScheduledDose? get next => pending.firstOrNull;
  double get progress => doses.isEmpty ? 0 : completed.length / doses.length;
}
