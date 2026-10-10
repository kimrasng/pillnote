import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/screen/pages/submenu/dose_reminders.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'helpers/fake_dose_reminder_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  final now = DateTime.utc(2026, 10, 8, 8);
  late LocalMedicationStore store;
  late FakeDoseReminderGateway gateway;
  late DoseReminderService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalMedicationStore(await SharedPreferences.getInstance());
    gateway = FakeDoseReminderGateway(tz.getLocation('Asia/Seoul'));
    service = DoseReminderService(
      store: store,
      gateway: gateway,
      now: () => now,
    );
    await store.savePills([
      {
        'id': 'p1',
        'times': ['18:00'],
      },
    ]);
  });
  tearDown(() => service.dispose());

  test(
    'guest reminders default to enabled; refresh is idempotent and explicit disable persists',
    () async {
      expect(service.isEnabled, isTrue);
      await service.refresh();
      expect(gateway.permissionRequests, 0);
      expect(service.pendingCount, 60);
      expect(service.nextScheduledAt!.hour, 18);
      await service.refresh();
      expect(gateway.schedules, 60);
      await service.setEnabled(false);
      final restored = LocalMedicationStore(
        await SharedPreferences.getInstance(),
      );
      final restarted = DoseReminderService(
        store: restored,
        gateway: gateway,
        now: () => now,
      );
      addTearDown(restarted.dispose);
      await restarted.refresh();
      expect(restarted.isEnabled, isFalse);
      expect(gateway.items, isEmpty);
      expect(gateway.permissionRequests, 0);
      expect(restored.readSettings(), isNot(contains('doseRemindersEnabled')));
    },
  );

  test(
    'permission refusal never marks reminders as enabled or reserved',
    () async {
      await store.setDoseRemindersEnabled(false);
      gateway.granted = false;
      await service.setEnabled(true);
      expect(service.isEnabled, isFalse);
      expect(service.pendingCount, 0);
      expect(service.lastError, contains('권한'));
      expect(gateway.items, isEmpty);
    },
  );

  test(
    'Android denied exact permission uses delayed mode, then updates existing alarms',
    () async {
      gateway.android = true;
      gateway.exact = false;
      await service.setEnabled(true);
      expect(gateway.exactRequests, 1);
      expect(gateway.items.values.first.payload, endsWith(':false'));
      gateway.exact = true;
      await service.requestExactPermission();
      expect(
        gateway.items.values.every((i) => i.payload!.endsWith(':true')),
        isTrue,
      );
      expect(service.pendingCount, 60);
    },
  );

  test(
    'taking a dose cancels today only; undo restores it; disabling preserves other notifications',
    () async {
      gateway.items[7] = const PendingDoseReminder(7, 'guardian-alert');
      await service.setEnabled(true);
      final todayId = gateway.reminders.values.first.id;
      await store.saveHistory({
        '2026-10-08': [
          {'pillId': 'p1', 'scheduledTime': '18:00'},
        ],
      });
      await service.refresh();
      expect(gateway.items, isNot(contains(todayId)));
      await store.saveHistory({
        '2026-10-08': [
          {'pillId': 'p1', 'scheduledTime': '18:00', 'cancelled': true},
        ],
      });
      await service.refresh();
      expect(gateway.items, contains(todayId));
      await service.setEnabled(false);
      expect(gateway.items.keys, [7]);
      expect(service.pendingCount, 0);
    },
  );

  test(
    'revoking system permission cancels alarms and regranting rebuilds them',
    () async {
      await service.refresh();
      gateway.granted = false;
      await service.refresh();
      expect(service.isEnabled, isTrue);
      expect(service.permissionGranted, isFalse);
      expect(gateway.items, isEmpty);
      gateway.granted = true;
      await service.refresh();
      expect(service.pendingCount, 60);
      expect(gateway.permissionRequests, 0);
    },
  );

  test('timezone changes replace alarms at the new local wall time', () async {
    await service.setEnabled(true);
    final first = service.nextScheduledAt!;
    gateway.zone = tz.getLocation('Asia/Kolkata');
    await service.refresh();
    expect(service.nextScheduledAt!.hour, 18);
    expect(service.nextScheduledAt!.isAtSameMomentAs(first), isFalse);
    expect(gateway.items.values.first.payload, contains('Asia/Kolkata'));
  });

  test(
    'readback failures and provider exceptions are visible and retryable',
    () async {
      gateway.dropSchedules = true;
      await service.setEnabled(true);
      expect(service.pendingCount, 0);
      expect(service.lastError, isNotNull);
      gateway.dropSchedules = false;
      gateway.failSchedules = true;
      await service.refresh();
      expect(service.lastError, isNotNull);
      gateway.failSchedules = false;
      await service.refresh();
      expect(service.pendingCount, 60);
      expect(service.lastError, isNull);
    },
  );

  test(
    'a queued disable removes all alarms even while an earlier schedule is in flight',
    () async {
      gateway.pendingLimit = 1;
      gateway.scheduleStarted = Completer<void>();
      gateway.finishSchedule = Completer<void>();
      final enabling = service.setEnabled(true);
      await gateway.scheduleStarted!.future;
      final disabling = service.setEnabled(false);
      gateway.finishSchedule!.complete();
      await Future.wait([enabling, disabling]);
      expect(service.isEnabled, isFalse);
      expect(gateway.items, isEmpty);
    },
  );

  test(
    'saving, editing, group changes, intake, archive and reset await alarm reconciliation',
    () async {
      final sessions = SessionStore.inMemory();
      final app = AppServices(
        store: store,
        sessions: sessions,
        now: () => now,
        reminderGateway: gateway,
        api: ApiClient(
          baseUrl: 'https://example.test',
          sessionStore: sessions,
          client: MockClient(
            (_) async => throw StateError('Guests must not need a server'),
          ),
        ),
      );
      addTearDown(app.dispose);
      await app.reminders.setEnabled(true);
      await app.medications.updatePillSchedule('p1', null, null, ['19:00'], 1);
      expect(app.reminders.nextScheduledAt!.hour, 19);
      await app.medications.saveGroup({
        'id': 'g1',
        'pillIds': ['p1'],
        'times': ['18:00'],
      });
      expect(app.reminders.nextScheduledAt!.hour, 18);
      await app.intakes.recordIntake('p1', '18:00', date: '2026-10-08');
      expect(app.reminders.nextScheduledAt!.hour, 19);
      await app.intakes.undoIntake('p1', '18:00', date: '2026-10-08');
      expect(app.reminders.nextScheduledAt!.hour, 18);
      await app.medications.removeGroup('g1');
      expect(app.reminders.nextScheduledAt!.hour, 19);
      await app.medications.archivePill('p1', true);
      expect(gateway.items, isEmpty);
      await app.medications.archivePill('p1', false);
      expect(gateway.items, isNotEmpty);
      await app.clearLocalData();
      expect(gateway.items, isEmpty);
      expect(app.reminders.isEnabled, isTrue);
    },
  );

  test(
    'downloaded cloud schedules rebuild alarms without overwriting device opt-in',
    () async {
      final sessions = SessionStore.inMemory();
      await sessions.save(
        const UserSession(
          userId: 'owner',
          email: 'owner@example.com',
          accessToken: 'access',
          refreshToken: 'refresh',
          accessTokenExpiresIn: 900,
          refreshTokenExpiresIn: 2592000,
        ),
      );
      final app = AppServices(
        store: store,
        sessions: sessions,
        now: () => now,
        reminderGateway: gateway,
        api: ApiClient(
          baseUrl: 'https://example.test',
          sessionStore: sessions,
          client: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'data': request.method == 'GET'
                    ? {
                        'revision': 1,
                        'snapshot': {
                          'pills': [
                            {
                              'id': 'p1',
                              'times': ['20:00'],
                              'updatedAt': '2026-10-08T10:00:00Z',
                            },
                          ],
                          'groups': [],
                          'intakeHistory': {},
                          'settings': {},
                        },
                      }
                    : {'revision': 2},
              }),
              200,
            ),
          ),
        ),
      );
      addTearDown(app.dispose);
      await app.reminders.setEnabled(true);
      await app.sync.reconcileWithServer();
      expect(app.reminders.nextScheduledAt!.hour, 20);
      expect(app.reminders.isEnabled, isTrue);
    },
  );

  testWidgets(
    'settings expose confirmed reservation dates and denied exact permission',
    (tester) async {
      gateway.android = true;
      gateway.exact = false;
      await tester.runAsync(service.refresh);
      await tester.pumpWidget(
        MaterialApp(home: DoseReminders(service: service)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(find.text('복용 시간 알림 60건이 예약되어 있어요.'), findsOneWidget);
      expect(find.textContaining('다음 알림 · 2026년 10월 8일 18:00'), findsOneWidget);
      expect(find.text('정확한 시간 알림 허용'), findsOneWidget);
      expect(find.textContaining('예약된 마지막 날짜'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
