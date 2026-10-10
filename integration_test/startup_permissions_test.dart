import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:pillnote/services/startup_permission_service.dart';
import 'package:pillnote/widgets/startup_permission_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Use a disposable iOS QA simulator and refuse both permission prompts.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('pillnote.startup.permissions.qa.');

  testWidgets(
    'first screen explains refusals and continues only after choosing to use the app',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final store = RecordingStartupStore(prefs);
      final notifications = NativeDoseReminderGateway();
      expect(notifications.isAndroid, isFalse);
      final gateway = RecordingStartupGateway(notifications);
      final service = StartupPermissionService(store: store, gateway: gateway);
      addTearDown(() async {
        service.dispose();
        await prefs.clear();
      });
      var completed = false;
      debugPrint('PILLNOTE_STARTUP_PERMISSIONS_QA_READY');
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            onCompleted: () => completed = true,
            child: const Scaffold(body: Text('권한 요청 완료')),
          ),
        ),
      );
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      while (find.text('그냥 이용하기').evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pump();
      }
      expect(completed, isFalse);
      expect(find.text('알림 · 미허용'), findsOneWidget);
      expect(find.text('위치 · 미허용'), findsOneWidget);
      expect(find.text('다시 권한 허용하기'), findsOneWidget);
      expect(store.startupPermissionsRequested, isFalse);
      expect(service.lastError, isNull);
      expect(gateway.calls, [
        StartupPermission.notifications,
        StartupPermission.location,
        if (notifications.isAndroid) StartupPermission.exactAlarms,
      ]);
      expect(await notifications.permission(), isFalse);
      expect(
        await Geolocator.checkPermission(),
        anyOf(LocationPermission.denied, LocationPermission.deniedForever),
      );
      if (notifications.isAndroid) {
        expect(await notifications.exactPermission(), isTrue);
      }
      final choice = find.widgetWithText(TextButton, '그냥 이용하기');
      final choiceDeadline = DateTime.now().add(const Duration(seconds: 20));
      while ((service.isBusy ||
              tester.widget<TextButton>(choice).onPressed == null) &&
          DateTime.now().isBefore(choiceDeadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(choice).onPressed, isNotNull);
      expect(choice.hitTestable(), findsOneWidget);
      debugPrint('PILLNOTE_STARTUP_SKIP_READY busy=${service.isBusy}');
      await tester.tap(choice);
      final completionDeadline = DateTime.now().add(
        const Duration(seconds: 20),
      );
      while (!completed && DateTime.now().isBefore(completionDeadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(store.startupPermissionsRequested, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('권한 요청 완료'), findsOneWidget);
      await store.clear();
      final restarted = StartupPermissionService(
        store: LocalMedicationStore(await SharedPreferences.getInstance()),
        gateway: gateway,
      );
      addTearDown(restarted.dispose);
      await restarted.requestOnFirstLaunch();
      expect(gateway.calls, hasLength(notifications.isAndroid ? 3 : 2));
      debugPrint('PILLNOTE_STARTUP_PERMISSIONS_QA_VERIFIED');
    },
  );
}

class RecordingStartupStore extends LocalMedicationStore {
  RecordingStartupStore(super.prefs);
  @override
  Future<void> setStartupPermissionsRequested() async {
    debugPrint('PILLNOTE_STARTUP_COMPLETION_SAVE_START');
    await super.setStartupPermissionsRequested();
    debugPrint('PILLNOTE_STARTUP_COMPLETION_SAVE_DONE');
  }
}

class RecordingStartupGateway extends NativeStartupPermissionGateway {
  RecordingStartupGateway(super.notifications);
  final calls = <StartupPermission>[];
  @override
  Future<void> request(StartupPermission permission) async {
    calls.add(permission);
    debugPrint('PILLNOTE_STARTUP_PERMISSION_REQUEST $permission');
    await super.request(permission);
  }
}
