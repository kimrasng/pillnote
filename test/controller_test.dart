import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
  });

  test(
    'local medication data produces a backend-compatible snapshot',
    () async {
      await Controller.addPill({'ITEM_SEQ': '123', 'ITEM_NAME': '테스트약'}, 30);
      final pill = Controller.getPills().single;
      await Controller.updatePillSchedule(
        pill['id'].toString(),
        '2026-09-18',
        '2026-10-18',
        ['08:00'],
        1,
      );
      await Controller.recordIntake(
        pill['id'].toString(),
        '08:00',
        date: '2026-09-18',
      );

      final snapshot = Controller.buildSnapshot();
      expect(snapshot['schemaVersion'], 1);
      expect((snapshot['pills'] as List).single['stock'], 29);
      expect(snapshot['groups'], isEmpty);
      expect((snapshot['intakeHistory'] as Map)['2026-09-18'], hasLength(1));
      expect(snapshot['settings'], containsPair('reminderMinutes', 30));
      expect((snapshot['deviceId'] as String).length, 48);
    },
  );

  test(
    'an intake is idempotent for the same pill and scheduled time',
    () async {
      await Controller.addPill({'ITEM_NAME': '테스트약'}, 10);
      final id = Controller.getPills().single['id'].toString();
      await Controller.recordIntake(id, '09:00', date: '2026-09-18');
      await Controller.recordIntake(id, '09:00', date: '2026-09-18');

      expect(Controller.getHistoryByDate('2026-09-18'), hasLength(1));
      expect(Controller.getPills().single['stock'], 9);
    },
  );
}
