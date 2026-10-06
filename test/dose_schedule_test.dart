import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/domain/dose_schedule.dart';
import 'package:pillnote/domain/missed_dose_policy.dart';

void main() {
  final date = DateTime(2026, 10, 4);
  final pill = <String, dynamic>{
    'id': 'pill-1',
    'ITEM_NAME': '테스트약',
    'times': ['08:00', '18:00'],
  };

  test('daily plan retains completed doses after editing the schedule', () {
    final plan = DoseSchedule.dailyPlan(
      date: date,
      pills: [
        {
          ...pill,
          'times': ['18:00'],
        },
      ],
      groups: [],
      history: [
        {'pillId': 'pill-1', 'scheduledTime': '08:00'},
        {'pillId': 'pill-1', 'scheduledTime': '12:00', 'cancelled': true},
      ],
    );

    expect(plan.doses.map((dose) => dose.time), ['08:00', '18:00']);
    expect(plan.completed.single.time, '08:00');
    expect(plan.pending.single.time, '18:00');
    expect(plan.next?.time, '18:00');
    expect(plan.progress, .5);
  });

  test('a group period applies even when the individual period ended', () {
    final doses = DoseSchedule.forDate(
      date: date,
      pills: [
        {...pill, 'endDate': '2026-10-01'},
      ],
      groups: [
        {
          'pillIds': ['pill-1', 'missing'],
          'times': ['12:00'],
        },
        {
          'pillIds': ['pill-1'],
          'times': ['13:00'],
          'deleted': true,
        },
      ],
    );

    expect(doses.map((dose) => dose.time), ['12:00']);
  });

  test('overlapping schedules produce one alert at the grace boundary', () {
    final doses = DoseSchedule.forDate(
      date: date,
      pills: [pill],
      groups: [
        {
          'pillIds': ['pill-1'],
          'times': ['08:00'],
        },
        {
          'pillIds': ['pill-1'],
          'times': ['08:00'],
        },
      ],
    );
    final before = MissedDosePolicy.evaluate(
      now: DateTime(2026, 10, 4, 8, 29),
      doses: doses,
      history: [],
      reminderMinutes: 30,
    );
    final atBoundary = MissedDosePolicy.evaluate(
      now: DateTime(2026, 10, 4, 8, 30),
      doses: doses,
      history: [],
      reminderMinutes: 30,
    );

    expect(before, isEmpty);
    expect(atBoundary, hasLength(1));
    expect(atBoundary.single.eventKey, 'pill-1:20261004:0800');
    expect(atBoundary.single.scheduledAt, DateTime(2026, 10, 4, 8));
  });

  test('taken doses suppress alerts and cancelled doses are overdue again', () {
    final doses = DoseSchedule.forDate(date: date, pills: [pill], groups: []);
    final taken = {'pillId': 'pill-1', 'scheduledTime': '08:00'};

    expect(
      MissedDosePolicy.evaluate(
        now: DateTime(2026, 10, 4, 9),
        doses: doses,
        history: [taken],
        reminderMinutes: 30,
      ),
      isEmpty,
    );
    expect(
      MissedDosePolicy.evaluate(
        now: DateTime(2026, 10, 4, 9),
        doses: doses,
        history: [
          {...taken, 'cancelled': true},
        ],
        reminderMinutes: 30,
      ).single.eventKey,
      'pill-1:20261004:0800',
    );
  });
}
