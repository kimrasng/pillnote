import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/models/medication.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
  });
  Future<String> add({num? stock, List<String> times = const ['08:00']}) async {
    await Controller.addPill({
      'ITEM_NAME': '테스트약',
      'startDate': '2020-01-01',
      'times': times,
      'dosage': 1,
    }, stock);
    return '${Controller.getPills().last['id']}';
  }

  test(
    'registration retains a schedule and unknown stock allows logging',
    () async {
      final id = await add();
      expect(
        Controller.scheduledDoses(DateTime(2026, 10, 3)).single.time,
        '08:00',
      );
      await Controller.recordIntake(id, '08:00', date: '2026-10-03');
      expect(Controller.getHistoryByDate('2026-10-03'), hasLength(1));
      expect(Controller.getPills().single['stock'], isNull);
      expect(Medication.tracksStock(Controller.getPills().single), isFalse);
    },
  );
  test(
    'zero stock does not block recording or create negative stock',
    () async {
      final id = await add(stock: 0);
      await Controller.recordIntake(id, '08:00', date: '2026-10-03');
      await Controller.undoIntake(id, '08:00', date: '2026-10-03');
      expect(Controller.getPills().single['stock'], 0);
      expect(Controller.getHistoryByDate('2026-10-03'), isEmpty);
    },
  );
  test(
    'undo restores only the stock actually deducted and is idempotent',
    () async {
      final id = await add(stock: .5);
      await Controller.recordIntake(id, '08:00', date: '2026-10-03');
      expect(Controller.getPills().single['stock'], 0);
      await Controller.undoIntake(id, '08:00', date: '2026-10-03');
      await Controller.undoIntake(id, '08:00', date: '2026-10-03');
      expect(Controller.getPills().single['stock'], .5);
      await Controller.recordIntake(id, '08:00', date: '2026-10-03');
      expect(Controller.getHistoryByDate('2026-10-03'), hasLength(1));
      expect(Controller.getPills().single['stock'], 0);
    },
  );
  test(
    'a cancelled intake survives merging with an older cloud record',
    () async {
      final id = await add(stock: 10);
      await Controller.recordIntake(id, '08:00', date: '2026-10-03');
      final remote = Controller.buildSnapshot();
      await Controller.undoIntake(id, '08:00', date: '2026-10-03');
      final merged = Controller.mergeSnapshots(
        remote,
        Controller.buildSnapshot(),
      );
      final records = (merged['intakeHistory'] as Map)['2026-10-03'] as List;
      expect(records, hasLength(1));
      expect(records.single['cancelled'], isTrue);
      expect((merged['pills'] as List).single['stock'], 10);
      final reversed = Controller.mergeSnapshots(
        Controller.buildSnapshot(),
        remote,
      );
      expect((reversed['pills'] as List).single['stock'], 10);
      expect(
        ((reversed['intakeHistory'] as Map)['2026-10-03'] as List)
            .single['cancelled'],
        isTrue,
      );
    },
  );
  test('group and individual schedules deduplicate by pill and time', () async {
    final id = await add(stock: 10);
    await Controller.saveGroup({
      'name': '아침 묶음',
      'pillIds': [id],
      'startDate': '2020-01-01',
      'times': ['08:00', '13:00'],
    });
    await Controller.saveGroup({
      'name': '또 다른 묶음',
      'pillIds': [id],
      'times': ['08:00'],
    });
    final doses = Controller.scheduledDoses(DateTime(2026, 10, 3));
    expect(doses.map((d) => d.time), ['08:00', '13:00']);
    expect(doses.first.groups, ['아침 묶음', '또 다른 묶음']);
  });
  test(
    'a group-only schedule appears and an ended group is excluded',
    () async {
      final id = await add(times: []);
      await Controller.saveGroup({
        'name': '공통 일정',
        'pillIds': [id],
        'startDate': '2020-01-01',
        'endDate': '2026-10-03',
        'times': ['12:00'],
      });
      expect(Controller.scheduledDoses(DateTime(2026, 10, 3)), hasLength(1));
      expect(Controller.scheduledDoses(DateTime(2026, 10, 4)), isEmpty);
    },
  );
  test(
    'archiving excludes future doses while retaining data and history',
    () async {
      final id = await add(stock: 10);
      final today = Medication.dateKey(DateTime.now());
      await Controller.recordIntake(id, '08:00', date: today);
      await Controller.saveGroup({
        'name': '공통 일정',
        'pillIds': [id],
        'times': ['12:00'],
      });
      await Controller.archivePill(id, true);
      expect(Controller.scheduledDoses(DateTime.now()), isEmpty);
      expect(Controller.getHistoryByDate(today), hasLength(1));
      expect(Controller.getGroups(), hasLength(1));
      await Controller.archivePill(id, false);
      expect(Controller.scheduledDoses(DateTime.now()), hasLength(2));
    },
  );
  test(
    'deleted groups stay deleted when merged with an older backup',
    () async {
      final id = await add();
      await Controller.saveGroup({
        'name': '공통 일정',
        'pillIds': [id],
        'times': ['12:00'],
      });
      final remote = Controller.buildSnapshot();
      await Controller.removeGroup('${Controller.getGroups().single['id']}');
      final merged = Controller.mergeSnapshots(
        remote,
        Controller.buildSnapshot(),
      );
      expect(Controller.getGroups(), isEmpty);
      expect((merged['groups'] as List).single['deleted'], isTrue);
      final reversed = Controller.mergeSnapshots(
        Controller.buildSnapshot(),
        remote,
      );
      expect((reversed['groups'] as List).single['deleted'], isTrue);
    },
  );
  test('schedule times are normalized, sorted and invalid times removed', () {
    expect(
      Medication.times(['8:00', '08:00', '25:00', '12:60', 'bad', '18:30']),
      ['08:00', '18:30'],
    );
  });
  test('existing stock data remains tracked without a migration', () {
    expect(Medication.tracksStock({'stock': 30}), isTrue);
    expect(Medication.tracksStock({'stock': 30, 'trackStock': false}), isFalse);
  });
}
