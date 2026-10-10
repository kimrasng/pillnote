import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/domain/dose_reminder_plan.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz_data.initializeTimeZones();
  final seoul = tz.getLocation('Asia/Seoul');
  final now = DateTime.utc(2026, 10, 8, 8); // 17:00 in Seoul
  final pill = {
    'id': 'p1',
    'times': ['08:00', '18:00'],
    'name': 'private name',
  };

  List<DoseReminder> plan({
    List<Map<String, dynamic>>? pills,
    List<Map<String, dynamic>> groups = const [],
    Map<String, dynamic> history = const {},
    int limit = 60,
  }) => DoseReminderPlan.build(
    now: now,
    location: seoul,
    pills: pills ?? [pill],
    groups: groups,
    history: history,
    limit: limit,
  );

  test(
    '18:00 is the first future alarm, with a stable id and no drug name',
    () {
      final first = plan().first;
      expect(first.at.toUtc(), DateTime.utc(2026, 10, 8, 9));
      expect(first.id, plan().first.id);
      expect(first.body, contains('18:00'));
      expect(first.body, isNot(contains('private name')));
      expect(first.id, inInclusiveRange(0, 0x7fffffff));
    },
  );

  test(
    'overlapping pill/group doses and multiple drugs share one notification',
    () {
      final first = plan(
        pills: [
          pill,
          {
            'id': 'p2',
            'times': ['18:00'],
          },
        ],
        groups: [
          {
            'id': 'g',
            'pillIds': ['p1', 'p2'],
            'times': ['18:00'],
          },
        ],
      ).first;
      expect(first.doseCount, 2);
    },
  );

  test(
    'completed doses are skipped; cancellation restores the future dose',
    () {
      final history = {
        '2026-10-08': [
          {'pillId': 'p1', 'scheduledTime': '18:00'},
        ],
      };
      expect(plan(history: history).first.at.day, 9);
      expect(
        plan(
          history: {
            '2026-10-08': [
              {'pillId': 'p1', 'scheduledTime': '18:00', 'cancelled': true},
            ],
          },
        ).first.at.day,
        8,
      );
    },
  );

  test(
    'start/end dates, archive and deleted groups do not generate stale alarms',
    () {
      final reminders = plan(
        pills: [
          {...pill, 'startDate': '2026-10-10', 'endDate': '2026-10-11'},
          {
            'id': 'archived',
            'archived': true,
            'times': ['18:00'],
          },
          {
            'id': 'ended',
            'endDate': '2026-10-07',
            'times': ['18:00'],
          },
        ],
        groups: [
          {
            'id': 'deleted',
            'deleted': true,
            'pillIds': ['p1'],
            'times': ['19:00'],
          },
        ],
      );
      expect(reminders, hasLength(4));
      expect(reminders.map((r) => r.at.day).toSet(), {10, 11});
      expect(reminders.every((r) => r.doseCount == 1), isTrue);
    },
  );

  test('group dates independently extend an individually ended medication', () {
    final reminders = plan(
      pills: [
        {...pill, 'endDate': '2026-10-07'},
      ],
      groups: [
        {
          'pillIds': ['p1'],
          'times': ['18:00'],
          'endDate': '2026-10-08',
        },
      ],
    );
    expect(reminders, hasLength(1));
  });

  test(
    'reservation limit retains the nearest alarms in chronological order',
    () {
      final reminders = plan(limit: 3);
      expect(reminders.map((r) => '${r.at.day}/${r.time}'), [
        '8/18:00',
        '9/08:00',
        '9/18:00',
      ]);
      expect(plan().map((r) => r.id).toSet(), hasLength(60));
    },
  );

  test(
    'calendar scheduling preserves 18:00 across DST, rather than adding 24h',
    () {
      final ny = tz.getLocation('America/New_York');
      final reminders = DoseReminderPlan.build(
        now: DateTime.utc(2026, 10, 31, 20),
        location: ny,
        pills: [
          {
            'id': 'p',
            'times': ['18:00'],
          },
        ],
        groups: [],
        history: {},
        limit: 3,
      );
      expect(reminders.map((r) => r.at.hour), [18, 18, 18]);
      expect(
        reminders[1].at.difference(reminders[0].at),
        const Duration(hours: 25),
      );
    },
  );

  test(
    'a nonexistent spring time rolls forward and notifications stay ordered',
    () {
      final reminders = DoseReminderPlan.build(
        now: DateTime.utc(2026, 3, 8, 5),
        location: tz.getLocation('America/New_York'),
        pills: [
          {
            'id': 'p',
            'times': ['02:30', '03:00'],
          },
        ],
        groups: [],
        history: {},
        limit: 2,
      );
      expect(reminders[0].time, '03:00');
      expect(reminders[1].time, '03:30');
    },
  );
}
