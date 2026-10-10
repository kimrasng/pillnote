import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/services/api/public_api_cache.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response searchResponse() => http.Response(
  jsonEncode({
    'data': [
      {'itemSeq': '123', 'name': 'Example drug'},
    ],
    'meta': {'stale': false},
  }),
  200,
);

http.Response detailResponse({Map<String, dynamic>? meta}) => http.Response(
  jsonEncode({
    'data': {
      'itemSeq': '123',
      'name': 'Example drug',
      'identification': {'shape': 'round'},
      'consumerInfo': {'usage': 'Example usage'},
      'meta': meta ?? {'stale': false},
    },
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'search cache survives restart and separates pages and limits',
    () async {
      var requests = 0;
      ApiClient client() => ApiClient(
        baseUrl: 'https://cache.test',
        client: MockClient((_) async {
          requests++;
          return searchResponse();
        }),
        cache: PublicApiCache(),
      );
      final first = client();
      final results = await first.searchDrugs('  Example   drug  ');
      results.single['ITEM_NAME'] = 'Changed by the screen';
      expect(
        (await first.searchDrugs('Example drug')).single['ITEM_NAME'],
        'Example drug',
      );
      final restarted = client();
      expect(
        (await restarted.searchDrugs('Example drug')).single['ITEM_SEQ'],
        '123',
      );
      expect(requests, 1);
      await restarted.searchDrugs('Example drug', page: 2);
      await restarted.searchDrugs('Example drug', limit: 20);
      expect(requests, 3);
    },
  );

  test(
    'detail cache survives restart with independent nested copies',
    () async {
      var requests = 0;
      ApiClient client() => ApiClient(
        baseUrl: 'https://cache.test',
        client: MockClient((_) async {
          requests++;
          return detailResponse();
        }),
      );
      final first = client();
      final detail = await first.drugDetail('123');
      (detail['consumerInfo'] as Map)['usage'] = 'Changed by the screen';
      expect(
        (await first.drugDetail('123'))['consumerInfo']['usage'],
        'Example usage',
      );
      expect((await client().drugDetail('123'))['ITEM_NAME'], 'Example drug');
      expect(requests, 1);
    },
  );

  test('search expires after one hour and details after one day', () async {
    var now = DateTime.utc(2026, 10, 11);
    var searches = 0, details = 0;
    final client = ApiClient(
      baseUrl: 'https://cache.test',
      cache: PublicApiCache.inMemory(now: () => now),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/search')) {
          searches++;
          return searchResponse();
        }
        details++;
        return detailResponse();
      }),
    );
    await client.searchDrugs('Example drug');
    await client.drugDetail('123');
    now = now.add(const Duration(hours: 1));
    await client.searchDrugs('Example drug');
    await client.drugDetail('123');
    expect(searches, 2);
    expect(details, 1);
    now = now.add(const Duration(hours: 23));
    await client.drugDetail('123');
    expect(details, 2);
  });

  test('concurrent misses share a request but failures are retried', () async {
    var requests = 0;
    final response = Completer<http.Response>();
    final client = ApiClient(
      baseUrl: 'https://cache.test',
      cache: PublicApiCache.inMemory(),
      client: MockClient((_) {
        requests++;
        return requests == 1 ? response.future : Future.value(detailResponse());
      }),
    );
    final first = client.drugDetail('123');
    final second = client.drugDetail('123');
    final assertions = Future.wait([
      expectLater(first, throwsA(isA<ApiException>())),
      expectLater(second, throwsA(isA<ApiException>())),
    ]);
    response.complete(
      http.Response('{"error":{"message":"unavailable"}}', 503),
    );
    await assertions;
    expect(requests, 1);
    final results = await Future.wait([
      client.drugDetail('123'),
      client.drugDetail('123'),
    ]);
    expect(requests, 2);
    (results.first['consumerInfo'] as Map)['usage'] = 'Edited';
    expect(results.last['consumerInfo']['usage'], 'Example usage');
  });

  for (final meta in [
    {'stale': true},
    {'consumerInfoAvailable': false},
    {'identificationAvailable': false},
  ]) {
    test('incomplete or stale detail $meta is not retained', () async {
      var requests = 0;
      final client = ApiClient(
        baseUrl: 'https://cache.test',
        cache: PublicApiCache.inMemory(),
        client: MockClient((_) async {
          requests++;
          return detailResponse(meta: meta);
        }),
      );
      await client.drugDetail('123');
      await client.drugDetail('123');
      expect(requests, 2);
    });
  }

  test(
    'a damaged disk cache does not prevent loading and repairing it',
    () async {
      SharedPreferences.setMockInitialValues({
        PublicApiCache.storageKey: 'damaged JSON',
      });
      final client = ApiClient(
        baseUrl: 'https://cache.test',
        client: MockClient((_) async => detailResponse()),
      );
      expect((await client.drugDetail('123'))['ITEM_SEQ'], '123');
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(PublicApiCache.storageKey)!),
        isA<Map>(),
      );
    },
  );

  test(
    'disk storage failure still caches successful responses in memory',
    () async {
      var requests = 0;
      final client = ApiClient(
        baseUrl: 'https://cache.test',
        cache: PublicApiCache(
          preferences: () async => throw StateError('disk unavailable'),
        ),
        client: MockClient((_) async {
          requests++;
          return detailResponse();
        }),
      );
      await client.drugDetail('123');
      await client.drugDetail('123');
      expect(requests, 1);
    },
  );

  test('least recently used results are evicted at the entry limit', () async {
    final requests = <String>[];
    final client = ApiClient(
      baseUrl: 'https://cache.test',
      cache: PublicApiCache.inMemory(maxEntries: 2),
      client: MockClient((request) async {
        requests.add(request.url.path);
        return detailResponse();
      }),
    );
    await client.drugDetail('1');
    await client.drugDetail('2');
    await client.drugDetail('1');
    await client.drugDetail('3');
    await client.drugDetail('1');
    await client.drugDetail('2');
    expect(requests, [
      '/v1/drugs/1',
      '/v1/drugs/2',
      '/v1/drugs/3',
      '/v1/drugs/2',
    ]);
  });

  test(
    'disk cache stays within its byte limit and skips oversized results',
    () async {
      final cache = PublicApiCache(maxBytes: 700);
      var loads = 0;
      Future<Map<String, dynamic>> read(String key, {int size = 150}) =>
          cache.getOrLoad(
            key: key,
            ttl: const Duration(hours: 1),
            load: () async {
              loads++;
              return {'text': 'a' * size};
            },
            cacheable: (_) => true,
          );
      for (var index = 0; index < 10; index++) {
        await read('$index');
      }
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(PublicApiCache.storageKey)!;
      expect(utf8.encode(saved).length, lessThanOrEqualTo(700));
      await read('huge', size: 1000);
      await read('huge', size: 1000);
      expect(loads, 12);
      expect(prefs.getString(PublicApiCache.storageKey), saved);
      await read('9');
      expect(loads, 12);
    },
  );

  test('cache keys isolate API servers', () async {
    final cache = PublicApiCache.inMemory();
    var requests = 0;
    ApiClient client(String host) => ApiClient(
      baseUrl: 'https://$host',
      cache: cache,
      client: MockClient((_) async {
        requests++;
        return detailResponse();
      }),
    );
    await client('production.test').drugDetail('123');
    await client('development.test').drugDetail('123');
    expect(requests, 2);
  });

  test(
    'account information and snapshots always come from the server',
    () async {
      var requests = 0;
      final sessions = SessionStore.inMemory();
      await sessions.save(
        const UserSession(
          userId: 'user',
          email: 'user@example.test',
          accessToken: 'access',
          refreshToken: 'refresh',
          accessTokenExpiresIn: 900,
          refreshTokenExpiresIn: 2592000,
        ),
      );
      final client = ApiClient(
        baseUrl: 'https://cache.test',
        sessionStore: sessions,
        client: MockClient((_) async {
          requests++;
          return http.Response('{"data":{}}', 200);
        }),
      );
      for (var index = 0; index < 2; index++) {
        await client.me();
        await client.fetchSnapshot();
      }
      expect(requests, 4);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(PublicApiCache.storageKey), isFalse);
    },
  );
}
