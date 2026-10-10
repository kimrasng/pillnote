import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  IOSFlutterLocalNotificationsPlugin.registerWith();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final now = DateTime.now().toUtc().add(const Duration(days: 1));
  late FlutterLocalNotificationsPlatform previousPlatform;
  late LocalMedicationStore store;
  late NativeDoseReminderGateway gateway;
  late DoseReminderService service;
  late List<MethodCall> calls;
  late Map<int, Map<String, Object?>> reservations;
  bool? initializeResult;
  bool granted = false;
  PlatformException? initializeError;

  setUp(() async {
    previousPlatform = FlutterLocalNotificationsPlatform.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    store = LocalMedicationStore(await SharedPreferences.getInstance());
    await store.savePills([
      {
        'id': 'p1',
        'times': ['18:00'],
      },
    ]);
    gateway = TestNativeDoseReminderGateway();
    service = DoseReminderService(
      store: store,
      gateway: gateway,
      now: () => now,
    );
    calls = [];
    reservations = {};
    initializeResult = false;
    initializeError = null;
    granted = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(timezone, (_) async => 'Asia/Seoul');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          if (initializeError != null) throw initializeError!;
          return initializeResult;
        case 'checkPermissions':
          return {'isEnabled': granted, 'isProvisionalEnabled': false};
        case 'requestPermissions':
          return granted;
        case 'openAppNotificationSettings':
          return true;
        case 'pendingNotificationRequests':
          return reservations.values.toList();
        case 'zonedSchedule':
          final data = Map<String, Object?>.from(call.arguments as Map);
          reservations[data['id']! as int] = {
            for (final key in ['id', 'title', 'body', 'payload'])
              key: data[key],
          };
          return null;
        case 'cancel':
          reservations.remove(call.arguments);
          return null;
        default:
          throw StateError('Unexpected notification method: ${call.method}');
      }
    });
  });

  tearDown(() {
    service.dispose();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(timezone, null);
    FlutterLocalNotificationsPlatform.instance = previousPlatform;
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'notification settings use the native app-specific route on iOS and Android',
    () async {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        if (platform == TargetPlatform.android) {
          AndroidFlutterLocalNotificationsPlugin.registerWith();
        }
        expect(await gateway.openSettings(), isTrue);
      }
      expect(calls.map((call) => call.method), [
        'openAppNotificationSettings',
        'openAppNotificationSettings',
      ]);
    },
  );

  test(
    'iOS false initialization without a permission request is successful and cached',
    () async {
      await service.refresh();
      await service.refresh();
      expect(service.lastError, isNull);
      expect(service.permissionGranted, isFalse);
      expect(service.isEnabled, isTrue);
      expect(reservations, isEmpty);
      expect(calls.where((call) => call.method == 'initialize'), hasLength(1));
      expect(
        calls.where((call) => call.method == 'requestPermissions'),
        isEmpty,
      );
      final settings = calls.first.arguments as Map;
      expect(settings['requestAlertPermission'], isFalse);
      expect(settings['requestBadgePermission'], isFalse);
      expect(settings['requestSoundPermission'], isFalse);
    },
  );

  test(
    'iOS default reminders reserve alarms after false initialization without prompting',
    () async {
      granted = true;
      await service.refresh();
      expect(service.lastError, isNull);
      expect(service.pendingCount, 60);
      expect(service.nextScheduledAt!.hour, 18);
      expect(reservations, hasLength(60));
      expect(
        calls.where((call) => call.method == 'requestPermissions'),
        isEmpty,
      );
      await service.refresh();
      expect(
        calls.where((call) => call.method == 'zonedSchedule'),
        hasLength(60),
      );
    },
  );

  test(
    'iOS can request permission and enable alarms after false initialization',
    () async {
      granted = true;
      await store.setDoseRemindersEnabled(false);
      await service.setEnabled(true);
      expect(service.lastError, isNull);
      expect(service.isEnabled, isTrue);
      expect(service.pendingCount, 60);
      expect(
        calls.where((call) => call.method == 'requestPermissions'),
        hasLength(1),
      );
    },
  );

  test(
    'iOS permission refusal is reported as permission state rather than initialization failure',
    () async {
      await service.setEnabled(true);
      expect(service.lastError, contains('권한'));
      expect(service.isEnabled, isTrue);
      expect(reservations, isEmpty);
      expect(
        calls.where((call) => call.method == 'requestPermissions'),
        hasLength(1),
      );
    },
  );

  test(
    'Android false initialization remains a failure and can be retried',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      await expectLater(gateway.initialize(), throwsStateError);
      initializeResult = true;
      await gateway.initialize();
      await gateway.initialize();
      expect(calls.where((call) => call.method == 'initialize'), hasLength(2));
    },
  );

  test(
    'iOS native initialization exceptions are still propagated and retryable',
    () async {
      initializeError = PlatformException(code: 'initialization_error');
      await expectLater(
        gateway.initialize(),
        throwsA(isA<PlatformException>()),
      );
      initializeError = null;
      await gateway.initialize();
      expect(calls.where((call) => call.method == 'initialize'), hasLength(2));
    },
  );

  test('a missing native initialization result is still a failure', () async {
    initializeResult = null;
    await expectLater(gateway.initialize(), throwsStateError);
  });
}

// Override only the host OS check; notification calls still use the real plugin.
class TestNativeDoseReminderGateway extends NativeDoseReminderGateway {
  @override
  bool get isSupported => true;

  @override
  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
}
