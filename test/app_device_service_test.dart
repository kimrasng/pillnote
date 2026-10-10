import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/app_device_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const user = UserSession(
  userId: 'user-1',
  email: 'test@example.com',
  accessToken: 'access',
  refreshToken: 'refresh',
  accessTokenExpiresIn: 900,
  refreshTokenExpiresIn: 2592000,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'signed-in devices report even without messaging and diagnostic collection is opt-in',
    () async {
      final sessions = SessionStore.inMemory();
      await sessions.save(user);
      final bodies = <Map<String, dynamic>>[];
      var reads = 0;
      final api = ApiClient(
        sessionStore: sessions,
        baseUrl: 'https://api.test',
        client: MockClient((r) async {
          expect(r.url.path, '/v1/app-devices/random-installation');
          bodies.add(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
          return http.Response('{"data":{"registered":true}}', 200);
        }),
      );
      final service = AppDeviceService(
        api: api,
        sessions: sessions,
        deviceId: () => 'random-installation',
        platform: 'ios',
        metadata: () async {
          reads++;
          return {
            'model': 'iPhone17,3',
            'osVersion': '26.0',
            'appVersion': '1.0.0',
            'appBuild': '1',
            'serialNumber': 'must-not-send',
          };
        },
      );
      expect(await service.register(), true);
      expect(reads, 0);
      expect(bodies.single['detailsConsent'], false);
      expect(bodies.single.containsKey('model'), false);
      expect(await service.register(), true);
      expect(bodies.length, 1);
      expect(await service.setDetailsConsent(true), true);
      expect(reads, 1);
      expect(bodies.last['model'], 'iPhone17,3');
      expect(bodies.last.containsKey('serialNumber'), false);
      expect(await service.setDetailsConsent(false), true);
      expect(bodies.last['detailsConsent'], false);
      expect(bodies.last.containsKey('model'), false);
      await service.dispose();
    },
  );
  test(
    'a logout or account switch during metadata reading must not report stale device data',
    () async {
      final sessions = SessionStore.inMemory();
      await sessions.save(user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('device_details_consent_v1_user-1', true);
      final started = Completer<void>(),
          details = Completer<Map<String, String>>();
      var calls = 0;
      final api = ApiClient(
        sessionStore: sessions,
        baseUrl: 'https://api.test',
        client: MockClient((r) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      final service = AppDeviceService(
        api: api,
        sessions: sessions,
        deviceId: () => 'installation',
        platform: 'android',
        metadata: () {
          started.complete();
          return details.future;
        },
      );
      final pending = service.register();
      await started.future;
      await sessions.clear();
      details.complete({'model': 'private'});
      expect(await pending, false);
      expect(calls, 0);
      await service.dispose();
    },
  );
  test(
    'new sign-in triggers reporting, failures preserve login and do not set success throttle',
    () async {
      final sessions = SessionStore.inMemory();
      var calls = 0;
      final sent = Completer<void>();
      final api = ApiClient(
        sessionStore: sessions,
        baseUrl: 'https://api.test',
        client: MockClient((r) async {
          calls++;
          if (!sent.isCompleted) sent.complete();
          throw http.ClientException('offline');
        }),
      );
      final service = AppDeviceService(
        api: api,
        sessions: sessions,
        deviceId: () => 'installation',
        platform: 'ios',
      );
      service.initialize();
      await sessions.save(user);
      await sent.future;
      expect(await service.register(), false);
      expect(calls, 2);
      expect(sessions.isLoggedIn, true);
      await service.dispose();
    },
  );
}
