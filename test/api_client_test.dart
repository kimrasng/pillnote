import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

void main() {
  test('email verification saves the returned passwordless session', () async {
    final store = SessionStore.inMemory();
    await store.initialize();
    final client = ApiClient(
      baseUrl: 'https://api.pillnote.test',
      sessionStore: store,
      client: MockClient((request) async {
        expect(request.url.path, '/v1/auth/email/verify');
        expect(jsonDecode(request.body), {
          'email': 'user@example.com',
          'code': '123456',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'user': {'id': 'user-1', 'email': 'user@example.com'},
              'accessToken': 'access-token',
              'refreshToken': 'refresh-token',
              'accessTokenExpiresIn': 900,
              'refreshTokenExpiresIn': 2592000,
            },
          }),
          200,
        );
      }),
    );

    final session = await client.verifyEmail('user@example.com', '123456');
    expect(session.userId, 'user-1');
    expect(store.session?.accessToken, 'access-token');
  });

  test(
    'an expired access token refreshes once and retries the request',
    () async {
      final store = SessionStore.inMemory();
      await store.save(
        const UserSession(
          userId: 'user-1',
          email: 'user@example.com',
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          accessTokenExpiresIn: 1,
          refreshTokenExpiresIn: 100,
        ),
      );
      var requestCount = 0;
      final client = ApiClient(
        baseUrl: 'https://api.pillnote.test',
        sessionStore: store,
        client: MockClient((request) async {
          requestCount += 1;
          if (request.url.path == '/v1/auth/refresh') {
            expect(jsonDecode(request.body)['refreshToken'], 'old-refresh');
            return http.Response(
              jsonEncode({
                'data': {
                  'user': {'id': 'user-1', 'email': 'user@example.com'},
                  'accessToken': 'new-access',
                  'refreshToken': 'new-refresh',
                  'accessTokenExpiresIn': 900,
                  'refreshTokenExpiresIn': 2592000,
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.headers['authorization'] == 'Bearer old-access') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'EXPIRED_TOKEN', 'message': 'expired'},
              }),
              401,
            );
          }
          expect(request.headers['authorization'], 'Bearer new-access');
          return http.Response(
            jsonEncode({
              'data': {'id': 'user-1', 'email': 'user@example.com'},
            }),
            200,
          );
        }),
      );

      final me = await client.me();
      expect(me['email'], 'user@example.com');
      expect(store.session?.refreshToken, 'new-refresh');
      expect(requestCount, 3);
    },
  );

  test('concurrent unauthorized requests share one refresh rotation', () async {
    final store = SessionStore.inMemory();
    await store.save(
      const UserSession(
        userId: 'user-1',
        email: 'user@example.com',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        accessTokenExpiresIn: 1,
        refreshTokenExpiresIn: 100,
      ),
    );
    var refreshRequests = 0;
    final client = ApiClient(
      baseUrl: 'https://api.pillnote.test',
      sessionStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/v1/auth/refresh') {
          refreshRequests += 1;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode({
              'data': {
                'user': {'id': 'user-1', 'email': 'user@example.com'},
                'accessToken': 'new-access',
                'refreshToken': 'new-refresh',
                'accessTokenExpiresIn': 900,
                'refreshTokenExpiresIn': 2592000,
              },
            }),
            200,
          );
        }
        if (request.headers['authorization'] == 'Bearer old-access') {
          return http.Response(
            jsonEncode({
              'error': {'code': 'EXPIRED_TOKEN', 'message': 'expired'},
            }),
            401,
          );
        }
        expect(request.headers['authorization'], 'Bearer new-access');
        return http.Response(
          jsonEncode({
            'data': {'id': 'user-1', 'email': 'user@example.com'},
          }),
          200,
        );
      }),
    );

    final results = await Future.wait([client.me(), client.me()]);
    expect(results, hasLength(2));
    expect(refreshRequests, 1);
    expect(store.session?.refreshToken, 'new-refresh');
  });

  test('revoked refresh token clears the session as expired', () async {
    final store = SessionStore.inMemory();
    await store.save(
      const UserSession(
        userId: 'user-1',
        email: 'user@example.com',
        accessToken: 'revoked-access',
        refreshToken: 'revoked-refresh',
        accessTokenExpiresIn: 900,
        refreshTokenExpiresIn: 2592000,
      ),
    );
    final expiration = store.changes.firstWhere(
      (change) => change.reason == SessionChangeReason.expired,
    );
    final client = ApiClient(
      baseUrl: 'https://api.pillnote.test',
      sessionStore: store,
      client: MockClient((request) async {
        final code = request.url.path == '/v1/auth/refresh'
            ? 'INVALID_REFRESH_TOKEN'
            : 'INVALID_ACCESS_TOKEN';
        return http.Response(
          jsonEncode({
            'error': {'code': code, 'message': 'revoked'},
          }),
          401,
        );
      }),
    );

    await expectLater(client.me(), throwsA(isA<ApiException>()));
    expect((await expiration).reason, SessionChangeReason.expired);
    expect(store.session, isNull);
  });

  test('temporary refresh failure preserves the session and error', () async {
    final store = SessionStore.inMemory();
    await store.save(
      const UserSession(
        userId: 'user-1',
        email: 'user@example.com',
        accessToken: 'old-access',
        refreshToken: 'old-refresh',
        accessTokenExpiresIn: 900,
        refreshTokenExpiresIn: 2592000,
      ),
    );
    final client = ApiClient(
      baseUrl: 'https://api.pillnote.test',
      sessionStore: store,
      client: MockClient((request) async {
        if (request.url.path == '/v1/auth/refresh') {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'SERVICE_UNAVAILABLE',
                'message': '잠시 후 다시 시도해주세요.',
              },
            }),
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'error': {'code': 'EXPIRED_TOKEN', 'message': 'expired'},
          }),
          401,
        );
      }),
    );

    await expectLater(
      client.me(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 503)
            .having((error) => error.code, 'code', 'SERVICE_UNAVAILABLE'),
      ),
    );
    expect(store.session?.refreshToken, 'old-refresh');
  });

  test(
    'drug and guardian responses are mapped for existing app screens',
    () async {
      final store = SessionStore.inMemory();
      await store.save(
        const UserSession(
          userId: 'user-1',
          email: 'user@example.com',
          accessToken: 'access',
          refreshToken: 'refresh',
          accessTokenExpiresIn: 900,
          refreshTokenExpiresIn: 2592000,
        ),
      );
      final client = ApiClient(
        baseUrl: 'https://api.pillnote.test',
        sessionStore: store,
        client: MockClient((request) async {
          if (request.url.path == '/v1/drugs/search') {
            expect(request.url.queryParameters['name'], '타이레놀');
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'itemSeq': '123',
                    'name': '타이레놀정',
                    'manufacturer': '테스트제약',
                    'imageUrl': 'https://image.test/pill.png',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.url.path, '/v1/guardians');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'guardian-1', 'status': 'accepted'},
              ],
            }),
            200,
          );
        }),
      );

      final drugs = await client.searchDrugs('타이레놀');
      expect(drugs.single['ITEM_SEQ'], '123');
      expect(drugs.single['ITEM_NAME'], '타이레놀정');
      final guardians = await client.guardians();
      expect(guardians.single['status'], 'accepted');
    },
  );

  test(
    'pharmacy search uses the PillNote backend without a client API key',
    () async {
      final client = ApiClient(
        baseUrl: 'https://api.pillnote.test',
        sessionStore: SessionStore.inMemory(),
        client: MockClient((request) async {
          expect(request.url.path, '/v1/pharmacies/search');
          expect(request.url.queryParameters, {
            'lat': '37.5665',
            'lng': '126.978',
            'radius': '3000',
            'limit': '100',
          });
          expect(
            request.url.queryParameters.containsKey('serviceKey'),
            isFalse,
          );
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'pharmacy-1',
                  'name': '테스트약국',
                  'address': '서울특별시 테스트로 1',
                  'phone': '02-1234-5678',
                  'latitude': 37.567,
                  'longitude': 126.979,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final pharmacies = await client.searchPharmacies(
        latitude: 37.5665,
        longitude: 126.978,
      );
      expect(pharmacies.single['name'], '테스트약국');
      expect(pharmacies.single['latitude'], 37.567);
    },
  );

  test('structured API errors are exposed to the UI', () async {
    final client = ApiClient(
      baseUrl: 'https://api.pillnote.test',
      sessionStore: SessionStore.inMemory(),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'INVALID_EMAIL',
              'message': '올바른 이메일 주소를 입력해주세요.',
            },
          }),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.startEmailLogin('bad'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'INVALID_EMAIL')
            .having((error) => error.statusCode, 'status', 400),
      ),
    );
  });
}
