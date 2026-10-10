import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'helpers/fake_dose_reminder_gateway.dart';

UserSession account(String id) => UserSession(
  userId: id,
  email: '$id@example.test',
  accessToken: id,
  refreshToken: '$id-refresh',
  accessTokenExpiresIn: 900,
  refreshTokenExpiresIn: 2592000,
);

http.Response response(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'data': data}), 200);

Map<String, dynamic> snapshot(String id) => {
  'pills': [
    {
      'id': '$id-pill',
      'times': ['18:00'],
      'stock': 10,
    },
  ],
  'groups': [
    {
      'id': '$id-group',
      'pillIds': ['$id-pill'],
      'times': ['18:00'],
    },
  ],
  'intakeHistory': {
    '2026-10-07': [
      {'pillId': '$id-pill', 'scheduledTime': '18:00'},
    ],
  },
  'settings': {'reminderMinutes': 60, 'guardianAlertsEnabled': false},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  late LocalMedicationStore store;
  late SessionStore sessions;
  late AppServices app;
  late ApiClient api;
  late FakeDoseReminderGateway reminders;
  late Map<String, Map<String, dynamic>?> server;
  late List<Map<String, dynamic>> uploads;
  Future<http.Response> Function(http.Request)? override;
  final now = DateTime.utc(2026, 10, 8, 8);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'same-device',
      'onboarding_completed': true,
    });
    store = LocalMedicationStore(await SharedPreferences.getInstance());
    sessions = SessionStore.inMemory();
    reminders = FakeDoseReminderGateway(tz.getLocation('Asia/Seoul'))
      ..pendingLimit = 2;
    server = {'A': snapshot('A'), 'B': snapshot('B')};
    uploads = [];
    override = null;
    api = ApiClient(
      sessionStore: sessions,
      baseUrl: 'https://isolation.invalid',
      client: MockClient((request) async {
        if (override != null) return override!(request);
        if (request.url.path == '/v1/auth/logout') {
          return http.Response('', 204);
        }
        if (request.url.path == '/v1/auth/email/verify') {
          final id = (jsonDecode(request.body)['email'] as String)
              .split('@')
              .first;
          return response({
            'user': {'id': id, 'email': '$id@example.test'},
            'accessToken': id,
            'refreshToken': '$id-refresh',
            'accessTokenExpiresIn': 900,
            'refreshTokenExpiresIn': 2592000,
          });
        }
        final id = request.headers['authorization']!.split(' ').last;
        if (request.method == 'GET') {
          return response({
            'revision': server[id] == null ? 0 : 1,
            'snapshot': server[id],
          });
        }
        final saved = Map<String, dynamic>.from(
          jsonDecode(request.body)['snapshot'] as Map,
        );
        uploads.add({'account': id, 'snapshot': saved});
        server[id] = saved;
        return response({'revision': 2});
      }),
    );
    app = AppServices(
      store: store,
      sessions: sessions,
      api: api,
      now: () => now,
      reminderGateway: reminders,
    );
  });
  tearDown(() => app.dispose());

  Future<void> seed(Map<String, dynamic> data) async {
    await store.savePills(
      List<Map<String, dynamic>>.from(data['pills'] as List),
    );
    await store.saveGroups(
      List<Map<String, dynamic>>.from(data['groups'] as List),
    );
    await store.saveHistory(
      Map<String, dynamic>.from(data['intakeHistory'] as Map),
    );
    await store.saveSettings(
      Map<String, dynamic>.from(data['settings'] as Map),
    );
  }

  void expectEmpty() {
    expect(store.readPills(), isEmpty);
    expect(store.readGroups(), isEmpty);
    expect(store.readHistory(), isEmpty);
    expect(store.readSettings()['reminderMinutes'], 30);
    expect(store.readSettings()['guardianAlertsEnabled'], isTrue);
  }

  Future<void> signInA() async {
    await sessions.save(account('A'));
    await app.sync.reconcileWithServer();
  }

  test(
    'first guest login migrates records into A and remembers ownership',
    () async {
      await seed(snapshot('guest'));
      await api.verifyEmail('A@example.test', '123456');
      expect(store.dataOwnerId, 'A');
      expect(store.readPills().single['id'], 'guest-pill');
      await app.sync.reconcileWithServer();
      expect((server['A']!['pills'] as List).map((p) => p['id']).toSet(), {
        'A-pill',
        'guest-pill',
      });
      expect((server['A']!['groups'] as List).map((g) => g['id']).toSet(), {
        'A-group',
        'guest-group',
      });
      expect(
        (server['A']!['intakeHistory'] as Map)['2026-10-07'],
        hasLength(2),
      );
    },
  );

  test(
    'A is erased before B sign-in is published or B server data is requested',
    () async {
      await signInA();
      await app.reminders.setEnabled(true);
      expect(reminders.items, isNotEmpty);
      await api.logout();
      expect(store.dataOwnerId, 'A');
      final subscription = sessions.changes.listen((change) {
        if (change.reason == SessionChangeReason.signedIn &&
            change.session!.userId == 'B') {
          expectEmpty();
          expect(reminders.items, isEmpty);
        }
      });
      addTearDown(subscription.cancel);
      await api.verifyEmail('B@example.test', '123456');
      expectEmpty();
      expect(store.dataOwnerId, 'B');
      expect(store.readSyncRevision('A'), isNull);
      expect(store.readLastSyncedAt('A'), isNull);
      expect(store.deviceId, 'same-device');
      expect(store.onboardingCompleted, isTrue);
      expect(store.doseRemindersEnabled, isTrue);
      await app.sync.reconcileWithServer();
      expect(store.readPills().single['id'], 'B-pill');
      expect(store.readGroups().single['id'], 'B-group');
      expect(
        (store.readHistory()['2026-10-07'] as List).single['pillId'],
        'B-pill',
      );
      expect((server['B']!['pills'] as List).single['id'], 'B-pill');
      expect(reminders.items, isNotEmpty);
    },
  );

  for (final missing in [true, false]) {
    test(
      'B ${missing ? 'without a backup' : 'with an empty backup'} stays completely empty',
      () async {
        await signInA();
        await api.logout();
        server['B'] = missing
            ? null
            : {'pills': [], 'groups': [], 'intakeHistory': {}, 'settings': {}};
        await sessions.save(account('B'));
        expectEmpty();
        await app.sync.reconcileWithServer();
        expectEmpty();
        expect(server['B']!['pills'], isEmpty);
        expect(server['B']!['groups'], isEmpty);
        expect(server['B']!['intakeHistory'], isEmpty);
        final bUploads = uploads.where((u) => u['account'] == 'B');
        expect(bUploads, hasLength(1));
        expect(bUploads.single['snapshot']['pills'], isEmpty);
      },
    );
  }

  test(
    'a failed B download stays empty and never restores or uploads A',
    () async {
      await signInA();
      await api.logout();
      await sessions.save(account('B'));
      override = (_) async =>
          http.Response('{"error":{"code":"SERVICE_UNAVAILABLE"}}', 503);
      await expectLater(
        app.sync.reconcileWithServer(),
        throwsA(isA<ApiException>()),
      );
      expectEmpty();
      expect(sessions.session!.userId, 'B');
      expect(uploads.where((u) => u['account'] == 'B'), isEmpty);
      await app.sync.flushPendingChanges();
      expectEmpty();
    },
  );

  test(
    'same-account login retains unsynced local changes and alarm opt-in',
    () async {
      await signInA();
      await app.reminders.setEnabled(true);
      await api.logout();
      await app.medications.updatePill('A-pill', {'stock': 7});
      final generation = store.dataGeneration;
      await sessions.save(account('A'));
      expect(store.readPills().single['stock'], 7);
      expect(store.dataGeneration, generation);
      expect(store.doseRemindersEnabled, isTrue);
      await app.sync.reconcileWithServer();
      expect((server['A']!['pills'] as List).single['stock'], 7);
    },
  );

  test(
    'A -> B -> A reloads A from its server rather than reusing B records',
    () async {
      await signInA();
      await api.logout();
      await sessions.save(account('B'));
      await app.sync.reconcileWithServer();
      await api.logout();
      await sessions.save(account('A'));
      expectEmpty();
      await app.sync.reconcileWithServer();
      expect(store.readPills().single['id'], 'A-pill');
      expect((server['A']!['pills'] as List).single['id'], 'A-pill');
    },
  );

  test(
    'owner metadata survives logout and restarting the local store',
    () async {
      await signInA();
      await api.logout();
      app.dispose();
      store = LocalMedicationStore(await SharedPreferences.getInstance());
      app = AppServices(
        store: store,
        sessions: sessions,
        api: api,
        now: () => now,
      );
      expect(store.dataOwnerId, 'A');
      await sessions.save(account('B'));
      expectEmpty();
      await app.sync.reconcileWithServer();
      expect(store.readPills().single['id'], 'B-pill');
    },
  );

  test(
    'old legacy A sync metadata blocks accidental guest migration into B',
    () async {
      await seed(snapshot('A'));
      await store.saveSyncRevision('A', 4);
      await store.saveLastSyncedAt('A', now);
      expect(store.hasExplicitDataOwner, isFalse);
      await sessions.save(account('B'));
      expectEmpty();
      expect(store.hasExplicitDataOwner, isTrue);
      await app.sync.reconcileWithServer();
      expect((server['B']!['pills'] as List).single['id'], 'B-pill');
    },
  );

  test(
    'restored legacy A session binds existing local data before startup sync',
    () async {
      await seed(snapshot('A'));
      await store.saveSyncRevision('old-account', 1);
      app.dispose();
      await sessions.save(account('A'));
      app = AppServices(
        store: store,
        sessions: sessions,
        api: api,
        now: () => now,
      );
      await app.sync.prepareCurrentAccount();
      expect(store.dataOwnerId, 'A');
      expect(store.readPills().single['id'], 'A-pill');
      expect(store.readHistory(), isNotEmpty);
    },
  );

  test(
    'session expiration keeps the owner marker so a different login clears A',
    () async {
      await signInA();
      await sessions.clear(reason: SessionChangeReason.expired);
      expect(store.dataOwnerId, 'A');
      await sessions.save(account('B'));
      expectEmpty();
    },
  );

  test('startup clears a cache whose explicit owner differs from B', () async {
    await signInA();
    app.dispose();
    await sessions.save(account('B'));
    app = AppServices(
      store: store,
      sessions: sessions,
      api: api,
      now: () => now,
    );
    await app.sync.prepareCurrentAccount();
    expectEmpty();
    expect(store.dataOwnerId, 'B');
    server['B'] = null;
    await app.sync.reconcileWithServer();
    expectEmpty();
  });

  test('a failed local clear prevents publishing or persisting B', () async {
    await signInA();
    app.dispose();
    store = FailingClearStore(await SharedPreferences.getInstance());
    app = AppServices(
      store: store,
      sessions: sessions,
      api: api,
      now: () => now,
    );
    final published = <String>[];
    final subscription = sessions.changes.listen((change) {
      if (change.session != null) published.add(change.session!.userId);
    });
    addTearDown(subscription.cancel);
    await expectLater(sessions.save(account('B')), throwsStateError);
    expect(published, isEmpty);
    expect(sessions.isLoggedIn, isFalse);
    expect(store.dataOwnerId, 'A');
    await sessions.initialize();
    expect(sessions.session!.userId, 'A');
    expect(uploads.where((u) => u['account'] == 'B'), isEmpty);
  });

  test('late A downloads cannot delay B login or replace B records', () async {
    await signInA();
    final started = Completer<void>();
    final oldResponse = Completer<http.Response>();
    override = (request) {
      if (request.headers['authorization'] == 'Bearer A') {
        started.complete();
        return oldResponse.future;
      }
      return Future.value(response({'revision': 1, 'snapshot': snapshot('B')}));
    };
    final oldSync = expectLater(
      app.sync.reconcileWithServer(),
      throwsA(isA<ApiException>()),
    );
    await started.future;
    await sessions.save(account('B')).timeout(const Duration(seconds: 1));
    expectEmpty();
    oldResponse.complete(
      response({'revision': 8, 'snapshot': snapshot('late-A')}),
    );
    await oldSync;
    override = null;
    await app.sync.reconcileWithServer();
    expect(store.readPills().single['id'], 'B-pill');
    expect(store.readSyncRevision('A'), isNull);
  });

  test(
    'late A uploads cannot restore deleted metadata after B login',
    () async {
      await signInA();
      final started = Completer<void>();
      final oldResponse = Completer<http.Response>();
      override = (_) {
        started.complete();
        return oldResponse.future;
      };
      final oldSync = expectLater(
        app.sync.syncToServer(),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      await sessions.save(account('B')).timeout(const Duration(seconds: 1));
      expectEmpty();
      oldResponse.complete(response({'revision': 10}));
      await oldSync;
      expect(store.readSyncRevision('A'), isNull);
      expect(store.readSyncRevision('B'), isNull);
      expect(store.readLastSyncedAt('A'), isNull);
    },
  );

  test(
    'a late A token refresh cannot deadlock login preparation or replace B',
    () async {
      await signInA();
      final started = Completer<void>();
      final refresh = Completer<http.Response>();
      override = (request) {
        if (request.url.path.endsWith('/refresh')) {
          started.complete();
          return refresh.future;
        }
        return Future.value(
          http.Response('{"error":{"code":"EXPIRED_TOKEN"}}', 401),
        );
      };
      final oldSync = expectLater(
        app.sync.reconcileWithServer(),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      await sessions.save(account('B')).timeout(const Duration(seconds: 1));
      refresh.complete(
        response({
          'user': {'id': 'A', 'email': 'A@example.test'},
          'accessToken': 'new-A',
          'refreshToken': 'new-A-refresh',
          'accessTokenExpiresIn': 900,
          'refreshTokenExpiresIn': 2592000,
        }),
      );
      await oldSync;
      expect(sessions.session!.userId, 'B');
      expectEmpty();
    },
  );

  test(
    'an A intake pending across the switch cannot restore A stock or group records',
    () async {
      await signInA();
      app.dispose();
      final blocked = BlockingHistoryStore(
        await SharedPreferences.getInstance(),
      );
      store = blocked;
      app = AppServices(
        store: store,
        sessions: sessions,
        api: api,
        now: () => now,
      );
      final intake = app.intakes.recordGroupIntake('A-group', '18:00');
      await blocked.started.future;
      await sessions.save(account('B'));
      expectEmpty();
      blocked.finish.complete();
      await intake;
      expectEmpty();
      await app.sync.reconcileWithServer();
      expect(store.readPills().single['id'], 'B-pill');
      expect((server['B']!['intakeHistory'] as Map)['2026-10-08'], isNull);
    },
  );
}

class BlockingHistoryStore extends LocalMedicationStore {
  BlockingHistoryStore(super.prefs);
  final started = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<void> saveHistory(Map<String, dynamic> history) async {
    await super.saveHistory(history);
    if (!started.isCompleted) {
      started.complete();
      await finish.future;
    }
  }
}

class FailingClearStore extends LocalMedicationStore {
  FailingClearStore(super.prefs);

  @override
  Future<void> clear({String? userId}) async {
    throw StateError('Simulated storage failure');
  }
}
