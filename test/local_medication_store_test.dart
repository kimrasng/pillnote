import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy preference data and sync markers remain readable', () async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'existing-device',
      'user_pills': jsonEncode([
        {'id': 'pill-1', 'stock': 30},
      ]),
      'pill_groups': jsonEncode([
        {'id': 'group-1', 'deleted': true},
      ]),
      'intake_history': jsonEncode({
        '2026-10-04': [
          {'pillId': 'pill-1', 'cancelled': true, 'stockDelta': .5},
        ],
      }),
      'app_settings': jsonEncode({'reminderMinutes': 15}),
    });
    final store = LocalMedicationStore(await SharedPreferences.getInstance());

    expect(store.deviceId, 'existing-device');
    expect(store.readPills().single['stock'], 30);
    expect(store.readGroups().single['deleted'], isTrue);
    expect(store.readHistory()['2026-10-04'].single['cancelled'], isTrue);
    expect(store.readSettings(), {
      'reminderMinutes': 15,
      'guardianAlertsEnabled': true,
      'updatedAt': '1970-01-01T00:00:00.000Z',
    });
    final pills = store.readPills();
    pills.single['stock'] = 0;
    expect(store.readPills().single['stock'], 30);
  });

  test(
    'invalid saved JSON falls back to empty data and setting defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        'user_pills': '{broken',
        'pill_groups': '{}',
        'intake_history': '[]',
        'app_settings': 'null',
      });
      final store = LocalMedicationStore(await SharedPreferences.getInstance());

      expect(store.readPills(), isEmpty);
      expect(store.readGroups(), isEmpty);
      expect(store.readHistory(), isEmpty);
      expect(store.readSettings()['reminderMinutes'], 30);
    },
  );

  test(
    'clearing data preserves onboarding, device ID and other accounts',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'device_id': 'existing-device',
      });
      final store = LocalMedicationStore(await SharedPreferences.getInstance());
      await store.savePills([
        {'id': 'pill-1'},
      ]);
      await store.saveSyncRevision('owner', 3);
      await store.saveSyncRevision('other', 7);
      await store.saveLastSyncedAt('owner', DateTime(2026, 10, 4));
      await store.clear(userId: 'owner');

      expect(store.readPills(), isEmpty);
      expect(store.onboardingCompleted, isTrue);
      expect(store.deviceId, 'existing-device');
      expect(store.readSyncRevision('owner'), isNull);
      expect(store.readLastSyncedAt('owner'), isNull);
      expect(store.readSyncRevision('other'), 7);
    },
  );
}
