import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

UserSession session(String id, {String token = 'old'}) => UserSession(
  userId: id,
  email: '$id@example.com',
  accessToken: token,
  refreshToken: '$token-refresh',
  accessTokenExpiresIn: 900,
  refreshTokenExpiresIn: 2592000,
);
http.Response refreshed(String id) => http.Response(
  jsonEncode({
    'data': {
      'user': {'id': id, 'email': '$id@example.com'},
      'accessToken': 'new',
      'refreshToken': 'new-refresh',
      'accessTokenExpiresIn': 900,
      'refreshTokenExpiresIn': 2592000,
    },
  }),
  200,
);
http.Response unauthorized() =>
    http.Response('{"error":{"code":"EXPIRED_TOKEN"}}', 401);

void main() {
  for (final switchAccount in [false, true]) {
    test(
      'pending refresh cannot ${switchAccount ? 'replace a new account' : 'restore a logged-out session'}',
      () async {
        final store = SessionStore.inMemory();
        await store.save(session('owner'));
        final started = Completer<void>();
        final finish = Completer<http.Response>();
        final client = ApiClient(
          sessionStore: store,
          baseUrl: 'https://test.invalid',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/refresh')) {
              started.complete();
              return finish.future;
            }
            return unauthorized();
          }),
        );
        final pending = expectLater(client.me(), throwsA(isA<ApiException>()));
        await started.future;
        await store.clear();
        if (switchAccount) await store.save(session('other', token: 'other'));
        finish.complete(refreshed('owner'));
        await pending;
        expect(store.session?.userId, switchAccount ? 'other' : null);
        if (switchAccount) expect(store.session?.accessToken, 'other');
      },
    );
  }

  test(
    'a late 401 reuses the already refreshed token without another rotation',
    () async {
      final store = SessionStore.inMemory();
      await store.save(session('owner'));
      final late = Completer<http.Response>();
      final lateStarted = Completer<void>();
      var oldRequests = 0;
      var rotations = 0;
      final client = ApiClient(
        sessionStore: store,
        baseUrl: 'https://test.invalid',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            rotations++;
            return refreshed('owner');
          }
          if (request.headers['authorization'] == 'Bearer old') {
            if (++oldRequests == 2) {
              lateStarted.complete();
              return late.future;
            }
            return unauthorized();
          }
          expect(request.headers['authorization'], 'Bearer new');
          return http.Response('{"data":{"id":"owner"}}', 200);
        }),
      );
      final first = client.me();
      final second = client.me();
      await lateStarted.future;
      await first;
      late.complete(unauthorized());
      await second;
      expect(rotations, 1);
    },
  );

  test(
    'an old successful response is discarded after account switching',
    () async {
      final store = SessionStore.inMemory();
      await store.save(session('owner'));
      final started = Completer<void>();
      final finish = Completer<http.Response>();
      final client = ApiClient(
        sessionStore: store,
        client: MockClient((_) {
          started.complete();
          return finish.future;
        }),
      );
      final pending = expectLater(
        client.me(),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      await started.future;
      await store.save(session('other'));
      finish.complete(http.Response('{"data":{"id":"owner"}}', 200));
      await pending;
      expect(store.session?.userId, 'other');
    },
  );

  test('logout-all failure preserves the current session for retry', () async {
    final store = SessionStore.inMemory();
    await store.save(session('owner'));
    final client = ApiClient(
      sessionStore: store,
      client: MockClient(
        (_) async =>
            http.Response('{"error":{"code":"SERVICE_UNAVAILABLE"}}', 503),
      ),
    );
    await expectLater(client.logoutAll(), throwsA(isA<ApiException>()));
    expect(store.session?.userId, 'owner');
  });

  test(
    'email resend waits use the server value and legacy responses default to 60 seconds',
    () async {
      var current = '{"data":{"resendAfterSeconds":90}}';
      final client = ApiClient(
        client: MockClient((_) async => http.Response(current, 202)),
      );
      await client.startEmailLogin('owner@example.com');
      expect(client.emailResendCooldownSeconds, 90);
      current = '{"data":{}}';
      await client.startEmailLogin('owner@example.com');
      expect(client.emailResendCooldownSeconds, 60);
    },
  );
}
