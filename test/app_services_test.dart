import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/services/snapshot_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalMedicationStore store;
  late SessionStore sessions;
  final now = DateTime(2026, 10, 4, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'device_id': 'test-device'});
    store = LocalMedicationStore(await SharedPreferences.getInstance());
    sessions = SessionStore.inMemory();
  });

  ApiClient apiWith(Future<http.Response> Function(http.Request) handler) =>
      ApiClient(
        baseUrl: 'https://api.pillnote.test',
        sessionStore: sessions,
        client: MockClient(handler),
      );

  Future<void> signIn() => sessions.save(
    const UserSession(
      userId: 'owner',
      email: 'owner@example.com',
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresIn: 900,
      refreshTokenExpiresIn: 2592000,
    ),
  );

  test(
    'isolated guest services record group doses without using the network',
    () async {
      var requests = 0;
      final app = AppServices(
        store: store,
        sessions: sessions,
        now: () => now,
        api: apiWith((_) async {
          requests++;
          return http.Response('', 500);
        }),
      );
      addTearDown(app.dispose);
      await app.medications.addPill({
        'ITEM_NAME': '테스트약',
        'times': ['08:00'],
      }, .5);
      final id = app.medications.getPills().single['id'].toString();
      await app.medications.saveGroup({
        'id': 'group-1',
        'pillIds': [id],
        'times': ['08:00'],
      });
      await app.intakes.recordGroupIntake('group-1', '08:00');
      await app.intakes.recordGroupIntake('group-1', '08:00');

      expect(app.medications.getPills().single['stock'], 0);
      expect(app.dailyDosePlan(now).completed, hasLength(1));
      expect(app.intakes.getHistoryByDate('2026-10-04'), hasLength(2));
      await app.intakes.undoIntake(id, '08:00');
      expect(app.medications.getPills().single['stock'], .5);
      expect(app.dailyDosePlan(now).pending, hasLength(1));
      expect(await app.sync.syncToServer(), isNull);
      await app.alerts.checkAndSend();
      expect(requests, 0);
    },
  );

  test(
    'a sync conflict merges newer local records before retrying the revision',
    () async {
      await signIn();
      await store.saveSyncRevision('owner', 3);
      await store.savePills([
        {'id': 'pill-1', 'stock': 10, 'updatedAt': '2026-10-04'},
      ]);
      await store.saveGroups([
        {'id': 'group-1', 'deleted': true, 'updatedAt': '2026-10-04'},
      ]);
      await store.saveHistory({
        '2026-10-03': [
          {
            'pillId': 'pill-1',
            'scheduledTime': '08:00',
            'cancelled': true,
            'updatedAt': '2026-10-04',
          },
        ],
      });
      var uploads = 0;
      final sync = SnapshotSyncService(
        store: store,
        sessions: sessions,
        now: () => now,
        api: apiWith((request) async {
          expect(request.url.path, '/v1/sync');
          if (request.method == 'GET') {
            return _data({
              'revision': 4,
              'snapshot': {
                'pills': [
                  {'id': 'pill-1', 'stock': 9, 'updatedAt': '2026-10-03'},
                  {'id': 'remote-pill', 'updatedAt': '2026-10-03'},
                ],
                'groups': [
                  {
                    'id': 'group-1',
                    'deleted': false,
                    'updatedAt': '2026-10-03',
                  },
                ],
                'intakeHistory': {
                  '2026-10-03': [
                    {
                      'pillId': 'pill-1',
                      'scheduledTime': '08:00',
                      'updatedAt': '2026-10-03',
                    },
                  ],
                },
              },
            });
          }
          uploads++;
          final body = jsonDecode(request.body) as Map;
          if (uploads == 1) {
            expect(body['baseRevision'], 3);
            return http.Response(
              jsonEncode({
                'error': {'code': 'SYNC_CONFLICT'},
              }),
              409,
            );
          }
          expect(body['baseRevision'], 4);
          final snapshot = body['snapshot'] as Map;
          expect(snapshot['pills'], hasLength(2));
          expect((snapshot['pills'] as List).first['stock'], 10);
          expect((snapshot['groups'] as List).single['deleted'], isTrue);
          expect(
            (snapshot['intakeHistory']['2026-10-03'] as List)
                .single['cancelled'],
            isTrue,
          );
          return _data({'revision': 5});
        }),
      );
      addTearDown(sync.dispose);

      expect(await sync.syncToServer(), 5);
      expect(uploads, 2);
      expect(store.readSyncRevision('owner'), 5);
      expect(sync.lastSyncedAt, now);
    },
  );

  test(
    'edits during an upload trigger a second upload without concurrency',
    () async {
      await signIn();
      await store.saveSyncRevision('owner', 1);
      final started = Completer<void>();
      final finish = Completer<void>();
      var uploads = 0;
      var active = 0;
      final sync = SnapshotSyncService(
        store: store,
        sessions: sessions,
        api: apiWith((request) async {
          expect(request.method, 'PUT');
          active++;
          expect(active, 1);
          uploads++;
          final body = jsonDecode(request.body) as Map;
          if (uploads == 1) {
            expect(body['baseRevision'], 1);
            started.complete();
            await finish.future;
          } else {
            expect(body['baseRevision'], 2);
            expect(body['snapshot']['pills'].single['id'], 'new-pill');
          }
          active--;
          return _data({'revision': uploads + 1});
        }),
      );
      addTearDown(sync.dispose);

      final initial = sync.syncToServer();
      await started.future;
      await store.savePills([
        {'id': 'new-pill'},
      ]);
      expect(await sync.syncToServer(), 1);
      finish.complete();
      expect(await initial, 3);
      expect(uploads, 2);
    },
  );

  test(
    'failed uploads leave local data and revision available for retry',
    () async {
      await signIn();
      await store.saveSyncRevision('owner', 1);
      await store.savePills([
        {'id': 'pill-1'},
      ]);
      var fail = true;
      final sync = SnapshotSyncService(
        store: store,
        sessions: sessions,
        api: apiWith(
          (_) async => fail
              ? http.Response(
                  jsonEncode({
                    'error': {'code': 'SERVICE_UNAVAILABLE'},
                  }),
                  503,
                )
              : _data({'revision': 2}),
        ),
      );
      addTearDown(sync.dispose);

      await expectLater(sync.syncToServer(), throwsA(isA<ApiException>()));
      expect(store.readPills().single['id'], 'pill-1');
      expect(store.readSyncRevision('owner'), 1);
      expect(sync.lastSyncedAt, isNull);
      fail = false;
      expect(await sync.syncToServer(), 2);
    },
  );

  test(
    'guardian settings suppress sending and overlapping doses send once',
    () async {
      await signIn();
      final events = <String>[];
      final app = AppServices(
        store: store,
        sessions: sessions,
        now: () => now,
        api: apiWith((request) async {
          expect(request.url.path, '/v1/guardian-alerts');
          events.add('${jsonDecode(request.body)['eventKey']}');
          return _data({'accepted': true});
        }),
      );
      addTearDown(app.dispose);
      await store.savePills([
        {
          'id': 'pill-1',
          'times': ['08:00'],
        },
      ]);
      await store.saveGroups([
        {
          'pillIds': ['pill-1'],
          'times': ['08:00'],
        },
      ]);
      await store.saveSettings({'guardianAlertsEnabled': false});
      await app.alerts.checkAndSend();
      expect(events, isEmpty);
      await store.saveSettings({'guardianAlertsEnabled': true});
      await app.alerts.checkAndSend();
      expect(events, ['pill-1:20261004:0800']);
      await app.intakes.recordIntake('pill-1', '08:00');
      app.sync.cancelPendingSync();
      await app.alerts.checkAndSend();
      expect(events, hasLength(1));
    },
  );

  testWidgets('disposing a service cancels its scheduled upload', (
    tester,
  ) async {
    await signIn();
    var requests = 0;
    final sync = SnapshotSyncService(
      store: store,
      sessions: sessions,
      api: apiWith((_) async {
        requests++;
        return _data({'revision': 1});
      }),
    );
    sync.scheduleSync();
    sync.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 0);
  });
}

http.Response _data(Map<String, dynamic> value) => http.Response(
  jsonEncode({'data': value}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
