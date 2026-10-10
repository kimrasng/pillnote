import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/domain/dose_reminder_plan.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Run with native notification permission granted on a QA device.
/// On PILLNOTE_REMINDER_QA_BACKGROUND_READY, put the app in the background.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('pillnote.reminder.qa.');

  testWidgets('native reservations follow edits, intake, undo and disable', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final store = LocalMedicationStore(prefs);
    final gateway = NativeDoseReminderGateway();
    final service = DoseReminderService(store: store, gateway: gateway);
    addTearDown(() async {
      await service.setEnabled(false);
      service.dispose();
      await prefs.clear();
    });
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('알림 예약 QA'))),
    );
    await gateway.initialize();
    final zone = await gateway.location();
    final next = tz.TZDateTime.now(zone).add(const Duration(minutes: 2));
    String time(tz.TZDateTime at) =>
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final pill = {
      'id': 'qa-local-dose',
      'times': [time(next)],
      'startDate': Medication.dateKey(next),
      'endDate': Medication.dateKey(next),
    };
    await store.savePills([pill]);
    await service.setEnabled(true);
    expect(service.lastError, isNull);
    expect(service.permissionGranted, isTrue);
    expect(service.pendingCount, 1);
    final first = (await gateway.pending())
        .where((p) => p.isDoseReminder)
        .single;

    final edited = next.add(const Duration(minutes: 1));
    await store.savePills([
      {
        ...pill,
        'times': [time(edited)],
        'startDate': Medication.dateKey(edited),
        'endDate': Medication.dateKey(edited),
      },
    ]);
    await service.refresh();
    final updated = (await gateway.pending())
        .where((p) => p.isDoseReminder)
        .single;
    expect(updated.id, isNot(first.id));
    await store.saveHistory({
      Medication.dateKey(edited): [
        {'pillId': pill['id'], 'scheduledTime': time(edited)},
      ],
    });
    await service.refresh();
    expect(service.pendingCount, 0);
    await store.saveHistory({});
    await service.refresh();
    expect(service.pendingCount, 1);
    await service.setEnabled(false);
    expect((await gateway.pending()).where((p) => p.isDoseReminder), isEmpty);
  });

  testWidgets('OS presents an alarm while the QA app is in the background', (
    tester,
  ) async {
    final gateway = NativeDoseReminderGateway();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('백그라운드 알림 QA'))),
    );
    await gateway.initialize();
    expect(await gateway.permission(), isTrue);
    final zone = await gateway.location();
    final at = tz.TZDateTime.now(zone).add(const Duration(seconds: 20));
    final reminder = DoseReminder(at: at, doseCount: 1);
    addTearDown(() => gateway.cancel(reminder.id));
    await gateway.schedule(reminder, exact: await gateway.exactPermission());
    expect((await gateway.pending()).any((p) => p.id == reminder.id), isTrue);
    debugPrint('PILLNOTE_REMINDER_QA_BACKGROUND_READY id=${reminder.id}');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 30)),
    );
    final active = await FlutterLocalNotificationsPlugin()
        .getActiveNotifications();
    expect(active.any((item) => item.id == reminder.id), isTrue);
    expect((await gateway.pending()).any((p) => p.id == reminder.id), isFalse);
    debugPrint('PILLNOTE_REMINDER_QA_DELIVERED id=${reminder.id}');
  });
}
