import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/services/startup_permission_service.dart';
import 'package:pillnote/widgets/startup_permission_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'helpers/fake_dose_reminder_gateway.dart';

class FakeStartupPermissionGateway implements StartupPermissionGateway {
  bool supported = true;
  bool android = false;
  final calls = <StartupPermission>[];
  final blockers = <StartupPermission, Completer<void>>{};
  final grants = <StartupPermission, bool>{};
  final checks = <StartupPermission>[];
  StartupPermission? failing;
  StartupPermission? failingCheck;
  FutureOr<void> Function(StartupPermission)? onRequest;
  int settingsOpened = 0;
  final settingsPermissions = <List<StartupPermission>>[];
  bool canOpenSettings = true;
  Completer<void>? finishSettings;
  @override
  bool get isSupported => supported;
  @override
  bool get isAndroid => android;
  @override
  Future<void> request(StartupPermission permission) async {
    calls.add(permission);
    await blockers[permission]?.future;
    if (failing == permission) throw StateError('Simulated permission failure');
    await onRequest?.call(permission);
  }

  @override
  Future<bool> isGranted(StartupPermission permission) async {
    checks.add(permission);
    if (failingCheck == permission || failing == permission) {
      throw StateError('Simulated status failure');
    }
    return grants[permission] ?? true;
  }

  @override
  Future<bool> openSettings(List<StartupPermission> permissions) async {
    settingsOpened++;
    settingsPermissions.add(List.of(permissions));
    await finishSettings?.future;
    return canOpenSettings;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalMedicationStore store;
  late FakeStartupPermissionGateway gateway;
  late StartupPermissionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalMedicationStore(await SharedPreferences.getInstance());
    gateway = FakeStartupPermissionGateway();
    service = StartupPermissionService(store: store, gateway: gateway);
  });
  tearDown(() => service.dispose());

  test(
    'iOS asks notifications then location once, independent of onboarding',
    () async {
      await store.setOnboardingCompleted(true);
      await store.setDoseRemindersEnabled(false);
      await service.requestOnFirstLaunch();
      expect(gateway.calls, [
        StartupPermission.notifications,
        StartupPermission.location,
      ]);
      expect(store.startupPermissionsRequested, isTrue);
      expect(service.needsRequest, isFalse);
      await service.requestOnFirstLaunch();
      expect(gateway.calls, hasLength(2));
      expect(store.doseRemindersEnabled, isFalse);
    },
  );

  test(
    'Android prompts are sequential and simultaneous launches share one operation',
    () async {
      gateway.android = true;
      final notification = Completer<void>();
      final location = Completer<void>();
      final exact = Completer<void>();
      gateway.blockers.addAll({
        StartupPermission.notifications: notification,
        StartupPermission.location: location,
        StartupPermission.exactAlarms: exact,
      });
      final first = service.requestOnFirstLaunch();
      final second = service.requestOnFirstLaunch();
      expect(identical(first, second), isTrue);
      expect(gateway.calls, [StartupPermission.notifications]);
      notification.complete();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, [
        StartupPermission.notifications,
        StartupPermission.location,
      ]);
      expect(store.startupPermissionsRequested, isFalse);
      location.complete();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls.last, StartupPermission.exactAlarms);
      expect(service.currentPermission, StartupPermission.exactAlarms);
      expect(store.startupPermissionsRequested, isFalse);
      exact.complete();
      await first;
      expect(store.startupPermissionsRequested, isTrue);
      expect(service.currentPermission, isNull);
    },
  );

  test(
    'completion survives local data deletion and installation store restart',
    () async {
      await service.requestOnFirstLaunch();
      await store.saveDataOwnerId('A');
      await store.clear(userId: 'A');
      final restarted = LocalMedicationStore(
        await SharedPreferences.getInstance(),
      );
      final freshGateway = FakeStartupPermissionGateway()..android = true;
      final restored = StartupPermissionService(
        store: restarted,
        gateway: freshGateway,
      );
      addTearDown(restored.dispose);
      await restored.requestOnFirstLaunch();
      expect(restored.needsRequest, isFalse);
      expect(freshGateway.calls, isEmpty);
    },
  );

  test(
    'one failed permission does not prevent later requests or app use',
    () async {
      gateway.android = true;
      gateway.failing = StartupPermission.notifications;
      await service.requestOnFirstLaunch();
      expect(gateway.calls, StartupPermission.values);
      expect(service.lastError, isNotNull);
      expect(
        service.statusOf(StartupPermission.notifications),
        StartupPermissionStatus.unknown,
      );
      expect(store.startupPermissionsRequested, isFalse);
      await service.completeSetup();
      expect(store.startupPermissionsRequested, isTrue);
    },
  );

  test(
    'denied permissions remain visible until a user choice completes setup',
    () async {
      gateway.grants[StartupPermission.location] = false;
      await service.requestOnFirstLaunch();
      expect(
        service.statusOf(StartupPermission.notifications),
        StartupPermissionStatus.granted,
      );
      expect(
        service.statusOf(StartupPermission.location),
        StartupPermissionStatus.denied,
      );
      expect(service.missingPermissions, [StartupPermission.location]);
      expect(store.startupPermissionsRequested, isFalse);
      expect(service.needsRequest, isTrue);
      await service.requestOnFirstLaunch();
      expect(gateway.calls, hasLength(2));
      await service.completeSetup();
      expect(service.needsRequest, isFalse);
    },
  );

  test(
    'retry only asks missing permissions and preserves existing grants',
    () async {
      gateway.grants[StartupPermission.location] = false;
      await service.requestOnFirstLaunch();
      gateway.onRequest = (permission) => gateway.grants[permission] = true;
      await service.retryMissingPermissions();
      expect(gateway.calls, [
        StartupPermission.notifications,
        StartupPermission.location,
        StartupPermission.location,
      ]);
      expect(gateway.settingsOpened, 0);
      expect(service.missingPermissions, isEmpty);
      expect(store.startupPermissionsRequested, isTrue);
    },
  );

  test(
    'blocked retries open settings once and return checks do not request again',
    () async {
      gateway.grants.addAll({
        StartupPermission.notifications: false,
        StartupPermission.location: false,
      });
      await service.requestOnFirstLaunch();
      await service.retryMissingPermissions();
      expect(gateway.settingsOpened, 1);
      expect(gateway.settingsPermissions.single, [
        StartupPermission.notifications,
        StartupPermission.location,
      ]);
      expect(service.missingPermissions, [
        StartupPermission.notifications,
        StartupPermission.location,
      ]);
      expect(store.startupPermissionsRequested, isFalse);
      gateway.grants.updateAll((_, _) => true);
      await service.refreshPermissions();
      expect(gateway.calls, hasLength(4));
      expect(service.missingPermissions, isEmpty);
      expect(store.startupPermissionsRequested, isTrue);
    },
  );

  test(
    'retry reads settings first and skips a permission granted outside the app',
    () async {
      gateway.grants[StartupPermission.location] = false;
      await service.requestOnFirstLaunch();
      gateway.grants[StartupPermission.location] = true;
      await service.retryMissingPermissions();
      expect(gateway.calls, hasLength(2));
      expect(gateway.settingsOpened, 0);
      expect(service.missingPermissions, isEmpty);
    },
  );

  test(
    'unavailable settings and failed checks still allow explicit continuation',
    () async {
      gateway.failingCheck = StartupPermission.location;
      gateway.canOpenSettings = false;
      await service.requestOnFirstLaunch();
      expect(
        service.statusOf(StartupPermission.location),
        StartupPermissionStatus.unknown,
      );
      await service.retryMissingPermissions();
      expect(service.lastError, contains('기기 설정을 열지 못했어요'));
      expect(service.isBusy, isFalse);
      await service.completeSetup();
      expect(store.startupPermissionsRequested, isTrue);
    },
  );

  test(
    'concurrent retries share one request and one settings opening',
    () async {
      gateway.grants[StartupPermission.location] = false;
      await service.requestOnFirstLaunch();
      final finish = Completer<void>();
      gateway.blockers[StartupPermission.location] = finish;
      final first = service.retryMissingPermissions();
      final second = service.retryMissingPermissions();
      expect(identical(first, second), isTrue);
      expect(service.isBusy, isTrue);
      finish.complete();
      await first;
      expect(gateway.calls, hasLength(3));
      expect(gateway.settingsOpened, 1);
      expect(service.isBusy, isFalse);
    },
  );

  test(
    'Android exact-alarm retry uses its permission page without general settings',
    () async {
      gateway.android = true;
      gateway.grants[StartupPermission.exactAlarms] = false;
      await service.requestOnFirstLaunch();
      await service.retryMissingPermissions();
      expect(gateway.calls, [
        ...StartupPermission.values,
        StartupPermission.exactAlarms,
      ]);
      expect(gateway.settingsOpened, 0);
      expect(service.missingPermissions, [StartupPermission.exactAlarms]);
    },
  );

  test('desktop and web skip native permission requests', () async {
    gateway.supported = false;
    await service.requestOnFirstLaunch();
    expect(gateway.calls, isEmpty);
    expect(store.startupPermissionsRequested, isFalse);
  });

  test(
    'disposed setup finishes the active dialog but requests nothing else',
    () async {
      final finish = Completer<void>();
      gateway.blockers[StartupPermission.notifications] = finish;
      final request = service.requestOnFirstLaunch();
      service.dispose();
      finish.complete();
      await request;
      expect(gateway.calls, [StartupPermission.notifications]);
      expect(store.startupPermissionsRequested, isFalse);
      // The usual tearDown still needs a live instance.
      service = StartupPermissionService(store: store, gateway: gateway);
    },
  );

  group('native permission routing', () {
    const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');
    late List<MethodCall> locationCalls;
    late FakeDoseReminderGateway notifications;
    LocationPermission locationPermission = LocationPermission.denied;
    setUp(() {
      locationCalls = [];
      locationPermission = LocationPermission.denied;
      notifications = FakeDoseReminderGateway(tz.UTC)..android = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(locationChannel, (call) async {
            locationCalls.add(call);
            if (call.method == 'checkPermission' ||
                call.method == 'requestPermission') {
              return locationPermission.index;
            }
            if (call.method == 'openAppSettings') return true;
            throw StateError(
              'Startup must not obtain coordinates: ${call.method}',
            );
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(locationChannel, null);
    });

    test(
      'notification-only settings use app notification settings on both platforms',
      () async {
        for (final android in [false, true]) {
          notifications.android = android;
          final native = NativeStartupPermissionGateway(notifications);
          expect(
            await native.openSettings([StartupPermission.notifications]),
            isTrue,
          );
        }
        expect(notifications.settingsOpened, 2);
        expect(locationCalls, isEmpty);
      },
    );

    test(
      'unavailable notification settings fall back to this app settings',
      () async {
        notifications.canOpenSettings = false;
        final native = NativeStartupPermissionGateway(notifications);
        expect(
          await native.openSettings([StartupPermission.notifications]),
          isTrue,
        );
        expect(notifications.settingsOpened, 1);
        expect(locationCalls.map((call) => call.method), ['openAppSettings']);
      },
    );

    test(
      'location and multiple permissions open app settings on both platforms',
      () async {
        for (final android in [false, true]) {
          notifications.android = android;
          final native = NativeStartupPermissionGateway(notifications);
          expect(
            await native.openSettings([StartupPermission.location]),
            isTrue,
          );
          expect(
            await native.openSettings([
              StartupPermission.notifications,
              StartupPermission.location,
            ]),
            isTrue,
          );
        }
        expect(notifications.settingsOpened, 0);
        expect(
          locationCalls.map((call) => call.method),
          List.filled(4, 'openAppSettings'),
        );
      },
    );

    test(
      'exact alarm settings use the app-specific Android permission page',
      () async {
        final native = NativeStartupPermissionGateway(notifications);
        expect(
          await native.openSettings([StartupPermission.exactAlarms]),
          isTrue,
        );
        expect(notifications.exactRequests, 1);
        expect(notifications.settingsOpened, 0);
        expect(locationCalls, isEmpty);
      },
    );

    test(
      'refusals still finish all prompts without changing reminder preference or obtaining location',
      () async {
        notifications.granted = false;
        notifications.exact = false;
        final native = StartupPermissionService(
          store: store,
          gateway: NativeStartupPermissionGateway(notifications),
        );
        addTearDown(native.dispose);
        await native.requestOnFirstLaunch();
        expect(notifications.permissionRequests, 1);
        expect(notifications.exactRequests, 1);
        expect(locationCalls.map((call) => call.method), [
          'checkPermission',
          'requestPermission',
          'checkPermission',
        ]);
        expect(store.startupPermissionsRequested, isFalse);
        expect(native.missingPermissions, StartupPermission.values);
        await native.completeSetup();
        expect(store.startupPermissionsRequested, isTrue);
        expect(store.doseRemindersEnabled, isTrue);
        expect(native.lastError, isNull);
      },
    );

    test(
      'already allowed permissions are checked without showing prompts again',
      () async {
        locationPermission = LocationPermission.whileInUse;
        final native = StartupPermissionService(
          store: store,
          gateway: NativeStartupPermissionGateway(notifications),
        );
        addTearDown(native.dispose);
        await native.requestOnFirstLaunch();
        expect(notifications.permissionRequests, 0);
        expect(notifications.exactRequests, 0);
        expect(locationCalls.map((call) => call.method), [
          'checkPermission',
          'checkPermission',
        ]);
      },
    );

    test(
      'retry of permanently denied location opens app settings without fetching coordinates',
      () async {
        locationPermission = LocationPermission.deniedForever;
        final native = StartupPermissionService(
          store: store,
          gateway: NativeStartupPermissionGateway(notifications),
        );
        addTearDown(native.dispose);
        await native.requestOnFirstLaunch();
        await native.retryMissingPermissions();
        expect(
          locationCalls.where((call) => call.method == 'requestPermission'),
          isEmpty,
        );
        expect(
          locationCalls.where((call) => call.method == 'openAppSettings'),
          hasLength(1),
        );
        expect(native.missingPermissions, [StartupPermission.location]);
        expect(notifications.permissionRequests, 0);
        expect(store.startupPermissionsRequested, isFalse);
      },
    );

    test(
      'permanently denied location does not attempt another OS prompt',
      () async {
        locationPermission = LocationPermission.deniedForever;
        final native = NativeStartupPermissionGateway(notifications);
        await native.request(StartupPermission.location);
        expect(locationCalls.map((call) => call.method), ['checkPermission']);
      },
    );
  });

  testWidgets(
    'individual settings buttons target only the selected permission',
    (tester) async {
      gateway.grants.addAll({
        StartupPermission.notifications: false,
        StartupPermission.location: false,
      });
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('알림 설정 열기'));
      await tester.tap(find.text('알림 설정 열기'));
      await tester.pumpAndSettle();
      expect(gateway.settingsPermissions.last, [
        StartupPermission.notifications,
      ]);
      await tester.ensureVisible(find.text('위치 설정 열기'));
      await tester.tap(find.text('위치 설정 열기'));
      await tester.pumpAndSettle();
      expect(gateway.settingsPermissions.last, [StartupPermission.location]);
      expect(gateway.calls, hasLength(2));
      expect(find.text('홈'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first frame requests automatically and then reveals the existing app',
    (tester) async {
      final finish = Completer<void>();
      gateway.blockers[StartupPermission.notifications] = finish;
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            onCompleted: () => completed++,
            child: const Scaffold(body: Text('기존 온보딩')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('처음에 필요한 권한을 확인해요'), findsOneWidget);
      expect(find.text('기존 온보딩'), findsNothing);
      expect(gateway.calls, [StartupPermission.notifications]);
      finish.complete();
      await tester.pumpAndSettle();
      expect(find.text('기존 온보딩'), findsOneWidget);
      expect(completed, 1);
      expect(gateway.calls, hasLength(2));
    },
  );

  testWidgets(
    'completed setup shows the app directly and does not run callbacks',
    (tester) async {
      await store.setStartupPermissionsRequested();
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            onCompleted: () => completed = true,
            child: const Scaffold(body: Text('기존 홈')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('기존 홈'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      expect(completed, isFalse);
    },
  );

  testWidgets('permission guidance scrolls on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    gateway.android = true;
    final finish = Completer<void>();
    gateway.blockers[StartupPermission.notifications] = finish;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: StartupPermissionGate(
          service: service,
          child: const Scaffold(body: Text('홈')),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pump();
    expect(find.text('알람 및 리마인더'), findsOneWidget);
    expect(tester.takeException(), isNull);
    finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsOneWidget);
  });

  testWidgets(
    'denied permissions explain each limitation and require an explicit choice',
    (tester) async {
      gateway.grants.addAll({
        StartupPermission.notifications: false,
        StartupPermission.location: false,
      });
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            onCompleted: () => completed++,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsNothing);
      expect(completed, 0);
      expect(find.text('알림 · 미허용'), findsOneWidget);
      expect(find.text('위치 · 미허용'), findsOneWidget);
      expect(
        find.textContaining('복용 시간 알림과 보호자 복약 알림을 이 기기에서 받을 수 없어요.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('현재 위치를 기준으로 주변 약국을 찾을 수 없어요.'),
        findsOneWidget,
      );
      expect(find.text('다시 권한 허용하기'), findsOneWidget);
      expect(store.startupPermissionsRequested, isFalse);
      await tester.ensureVisible(find.text('그냥 이용하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('그냥 이용하기'));
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);
      expect(completed, 1);
      expect(store.startupPermissionsRequested, isTrue);
    },
  );

  testWidgets(
    'a single refusal only shows its limitation and retry can enter the app',
    (tester) async {
      gateway.grants[StartupPermission.location] = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('위치 · 미허용'), findsOneWidget);
      expect(find.text('알림 · 미허용'), findsNothing);
      gateway.onRequest = (permission) => gateway.grants[permission] = true;
      await tester.ensureVisible(find.text('다시 권한 허용하기'));
      await tester.tap(find.text('다시 권한 허용하기'));
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);
      expect(
        gateway.calls.where(
          (permission) => permission == StartupPermission.notifications,
        ),
        hasLength(1),
      );
      expect(gateway.settingsOpened, 0);
    },
  );

  testWidgets(
    'returning from settings rechecks grants and completes without another prompt',
    (tester) async {
      gateway.grants[StartupPermission.location] = false;
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            onCompleted: () => completed++,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('다시 권한 허용하기'));
      await tester.tap(find.text('다시 권한 허용하기'));
      await tester.pumpAndSettle();
      expect(gateway.settingsOpened, 1);
      expect(find.text('홈'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      gateway.grants[StartupPermission.location] = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);
      expect(completed, 1);
      expect(gateway.calls, hasLength(3));
      expect(store.startupPermissionsRequested, isTrue);
    },
  );

  testWidgets(
    'resuming with a refusal keeps the choice screen and does not request again',
    (tester) async {
      gateway.grants[StartupPermission.notifications] = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('알림 · 미허용'), findsOneWidget);
      expect(find.text('그냥 이용하기'), findsOneWidget);
      expect(gateway.calls, hasLength(2));
      expect(store.startupPermissionsRequested, isFalse);
    },
  );

  testWidgets(
    'retry buttons cannot overlap requests while a permission dialog is pending',
    (tester) async {
      gateway.grants[StartupPermission.location] = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finish = Completer<void>();
      gateway.blockers[StartupPermission.location] = finish;
      await tester.ensureVisible(find.text('다시 권한 허용하기'));
      await tester.tap(find.text('다시 권한 허용하기'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '그냥 이용하기'))
            .onPressed,
        isNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(gateway.calls, hasLength(3));
      finish.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(gateway.settingsOpened, 1);
    },
  );

  testWidgets(
    'a settings return during an active retry still reflects changed permissions',
    (tester) async {
      gateway.grants[StartupPermission.location] = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StartupPermissionGate(
            service: service,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finish = Completer<void>();
      gateway.finishSettings = finish;
      await tester.ensureVisible(find.text('다시 권한 허용하기'));
      await tester.tap(find.text('다시 권한 허용하기'));
      await tester.pump();
      expect(gateway.settingsOpened, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      gateway.grants[StartupPermission.location] = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      finish.complete();
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);
      expect(store.startupPermissionsRequested, isTrue);
    },
  );

  testWidgets(
    'all Android denial details and both choices stay accessible with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      gateway.android = true;
      gateway.grants.addAll({
        for (final permission in StartupPermission.values) permission: false,
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: StartupPermissionGate(
            service: service,
            child: const Scaffold(body: Text('홈')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('알람 및 리마인더 · 미허용'), findsOneWidget);
      await tester.ensureVisible(find.text('다시 권한 허용하기'));
      await tester.pumpAndSettle();
      expect(find.text('다시 권한 허용하기').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('그냥 이용하기'));
      await tester.pumpAndSettle();
      expect(find.text('그냥 이용하기').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('그냥 이용하기'));
      await tester.pumpAndSettle();
      expect(find.text('홈'), findsOneWidget);
    },
  );
}
