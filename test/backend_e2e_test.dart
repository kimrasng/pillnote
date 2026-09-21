import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

void main() {
  test(
    'mobile client completes the real backend auth, sync, guardian, and push flow',
    () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      final databaseDirectory = await Directory.systemTemp.createTemp(
        'pillnote-mobile-e2e-',
      );
      final process = await Process.start(
        'node',
        ['src/server.js'],
        workingDirectory: '${Directory.current.parent.path}/pillnotebackend',
        environment: {
          ...Platform.environment,
          'NODE_ENV': 'test',
          'HOST': '127.0.0.1',
          'PORT': '$port',
          'DATABASE_PATH': '${databaseDirectory.path}/e2e.sqlite',
          'JWT_SECRET':
              'mobile-e2e-secret-that-is-at-least-thirty-two-characters',
          'DATA_ENCRYPTION_KEY_BASE64':
              'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          'MFDS_SERVICE_KEY': 'test-key',
          'RATE_LIMIT_MAX': '1000',
          'AUTH_RATE_LIMIT_MAX': '1000',
        },
      );
      final output = <String>[];
      final stdoutSubscription = process.stdout
          .transform(const SystemEncoding().decoder)
          .listen(output.add);
      final stderrSubscription = process.stderr
          .transform(const SystemEncoding().decoder)
          .listen(output.add);

      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
        await stdoutSubscription.cancel();
        await stderrSubscription.cancel();
        if (databaseDirectory.existsSync()) {
          await databaseDirectory.delete(recursive: true);
        }
      });

      final baseUrl = 'http://127.0.0.1:$port';
      await _waitUntilHealthy(baseUrl, output);

      final owner = ApiClient(
        baseUrl: baseUrl,
        sessionStore: SessionStore.inMemory(),
      );
      final guardian = ApiClient(
        baseUrl: baseUrl,
        sessionStore: SessionStore.inMemory(),
      );
      await _login(owner, 'mobile-owner@example.com');
      await _login(guardian, 'mobile-guardian@example.com');

      final saved = await owner.saveSnapshot(
        baseRevision: 0,
        snapshot: {
          'schemaVersion': 1,
          'deviceId': 'mobile-e2e-device',
          'pills': [],
          'groups': [],
          'intakeHistory': {},
          'settings': {'reminderMinutes': 30},
        },
      );
      expect(saved['revision'], 1);
      expect((await owner.fetchSnapshot())['revision'], 1);

      await guardian.registerDevice(
        deviceId: 'guardian-e2e-phone',
        platform: 'android',
        pushToken: 'e2e-fcm-token-that-is-long-enough',
      );
      final invitation = await owner.inviteGuardian(
        email: 'mobile-guardian@example.com',
        name: '보호자',
      );
      final pending = await guardian.guardianInvitations();
      expect(pending.single['id'], invitation['id']);
      await guardian.respondToGuardianInvitation(
        invitation['id'].toString(),
        accept: true,
      );
      expect((await owner.guardians()).single['status'], 'accepted');

      await owner.sendMissedDoseAlert(
        eventKey: 'mobile-e2e-missed-dose',
        medicationName: '테스트약',
        scheduledAt: DateTime.parse('2026-09-18T08:00:00+09:00'),
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<void> _login(ApiClient client, String email) async {
  final code = await client.startEmailLogin(email);
  expect(code, matches(RegExp(r'^\d{6}$')));
  final session = await client.verifyEmail(email, code!);
  expect(session.email, email);
}

Future<void> _waitUntilHealthy(String baseUrl, List<String> output) async {
  for (var attempt = 0; attempt < 50; attempt += 1) {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      if (response.statusCode == 200) return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  fail('백엔드가 시작되지 않았습니다.\n${output.join()}');
}
