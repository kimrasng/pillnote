import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'session_race_test.dart' show session;

class FakeMessaging implements PushMessagingGateway {
  final tokens = StreamController<String>.broadcast();
  AuthorizationStatus status = AuthorizationStatus.authorized;
  int initializations = 0;
  @override
  bool get isIos => false;
  @override
  String get platform => 'android';
  @override
  Future<void> initialize() async {
    initializations++;
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Stream<String> get tokenRefresh => tokens.stream;
  @override
  Stream<RemoteMessage> get messages => const Stream.empty();
  @override
  Future<AuthorizationStatus> permission({bool request = false}) async =>
      status;
  @override
  Future<String?> token() async => 'fcm-token';
  @override
  Future<String?> apnsToken() async => 'apns-token';
}

void main() {
  late SessionStore sessions;
  late FakeMessaging messaging;
  setUp(() async {
    sessions = SessionStore.inMemory();
    await sessions.save(session('owner'));
    messaging = FakeMessaging();
  });
  PushNotificationService serviceWith(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final service = PushNotificationService(
      messaging: messaging,
      sessions: sessions,
      configured: true,
      deviceId: () => 'push-test',
      api: ApiClient(sessionStore: sessions, client: MockClient(handler)),
    );
    addTearDown(() async {
      await service.dispose();
      await messaging.tokens.close();
    });
    return service;
  }

  Future<void> drain() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('concurrent initialization installs only one FCM listener', () async {
    var registrations = 0;
    final service = serviceWith((_) async {
      registrations++;
      return http.Response('', 204);
    });
    await Future.wait([
      service.initialize(),
      service.initialize(),
      service.initialize(),
    ]);
    expect(messaging.initializations, 1);
    messaging.tokens.add('rotated');
    await drain();
    expect(registrations, 1);
    expect(service.isRegistered, true);
  });
  test('denied permission suppresses token-refresh registration', () async {
    var registrations = 0;
    messaging.status = AuthorizationStatus.denied;
    final service = serviceWith((_) async {
      registrations++;
      return http.Response('', 204);
    });
    await service.initialize();
    messaging.tokens.add('rotated');
    await drain();
    expect(registrations, 0);
    expect(service.permissionGranted, false);
    expect(service.isRegistered, false);
  });
  test(
    'unregistering an absent device resets state and suppresses token refresh',
    () async {
      var registrations = 0;
      final service = serviceWith((request) async {
        if (request.method == 'DELETE') {
          return http.Response('{"error":{"code":"DEVICE_NOT_FOUND"}}', 404);
        }
        registrations++;
        return http.Response('', 204);
      });
      expect(await service.registerCurrentDevice(), true);
      await service.unregisterCurrentDevice();
      messaging.tokens.add('rotated');
      await drain();
      expect(service.isRegistered, false);
      expect(registrations, 1);
    },
  );
  test(
    'unregister waits for pending registration so a late token cannot recreate the device',
    () async {
      final started = Completer<void>();
      final finish = Completer<http.Response>();
      final requests = <String>[];
      final service = serviceWith((request) async {
        requests.add(request.method);
        if (request.method == 'PUT') {
          started.complete();
          return finish.future;
        }
        return http.Response('', 204);
      });
      final registering = service.registerCurrentDevice();
      await started.future;
      final unregistering = service.unregisterCurrentDevice();
      finish.complete(http.Response('', 204));
      expect(await registering, false);
      await unregistering;
      expect(requests, ['PUT', 'DELETE']);
      expect(service.isRegistered, false);
    },
  );
  test('server registration errors remain actionable in the UI', () async {
    final service = serviceWith(
      (_) async => http.Response(
        '{"error":{"code":"DEVICE_LIMIT_REACHED","message":"등록 가능한 기기 수를 초과했습니다."}}',
        409,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    expect(await service.registerCurrentDevice(), false);
    expect(service.lastError, '등록 가능한 기기 수를 초과했습니다.');
    expect(service.isRegistered, false);
  });
  test(
    'logout resets registration state and rejects later token refresh',
    () async {
      var requests = 0;
      final service = serviceWith((_) async {
        requests++;
        return http.Response('', 204);
      });
      expect(await service.registerCurrentDevice(), true);
      await sessions.clear();
      messaging.tokens.add('rotated');
      await drain();
      expect(service.isRegistered, false);
      expect(requests, 1);
    },
  );
}
