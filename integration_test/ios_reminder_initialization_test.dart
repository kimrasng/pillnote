import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

// Run on an isolated iOS QA simulator and allow its notification prompt.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('pillnote.reminder.initialization.qa.');

  testWidgets(
    'iOS initializes without requesting permission, then enables and cancels native alarms',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('iOS 알림 초기화 QA'))),
      );
      final result = await FlutterLocalNotificationsPlugin().initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      expect(result, isFalse);
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final store = LocalMedicationStore(prefs);
      final gateway = NativeDoseReminderGateway();
      final service = DoseReminderService(store: store, gateway: gateway);
      addTearDown(() async {
        service.dispose();
        await prefs.clear();
      });
      await gateway.initialize();
      for (var attempt = 0; attempt < 3; attempt++) {
        await service.refresh();
        expect(service.lastError, isNull);
        expect(service.pendingCount, 0);
      }
      final zone = await gateway.location();
      final at = tz.TZDateTime.now(zone).add(const Duration(minutes: 2));
      final time =
          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
      await store.savePills([
        {
          'id': 'qa-ios-initialization',
          'times': [time],
          'startDate': Medication.dateKey(at),
          'endDate': Medication.dateKey(at),
        },
      ]);
      debugPrint('PILLNOTE_IOS_REMINDER_QA_PERMISSION_READY');
      await service.setEnabled(true);
      expect(service.permissionGranted, isTrue);
      expect(service.lastError, isNull);
      expect(service.pendingCount, 1);
      final reminder = (await gateway.pending())
          .where((item) => item.isDoseReminder)
          .single;
      addTearDown(() => gateway.cancel(reminder.id));
      await service.setEnabled(false);
      expect(
        (await gateway.pending()).any((item) => item.id == reminder.id),
        isFalse,
      );
      debugPrint('PILLNOTE_IOS_REMINDER_INITIALIZATION_VERIFIED');
    },
  );
}
