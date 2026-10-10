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
import 'session_race_test.dart' show session;

http.Response data(Map<String, dynamic> payload) =>
    http.Response(jsonEncode({'data': payload}), 200);
Map<String, dynamic> remote() => {
  'revision': 4,
  'snapshot': {
    'schemaVersion': 1,
    'pills': [
      {'id': 'remote-pill'},
    ],
    'groups': [],
    'intakeHistory': {},
    'settings': {
      'reminderMinutes': 60,
      'guardianAlertsEnabled': false,
      'updatedAt': '2026-10-06T00:00:00Z',
    },
  },
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalMedicationStore store;
  late SessionStore sessions;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'device_id': 'sync-test'});
    store = LocalMedicationStore(await SharedPreferences.getInstance());
    sessions = SessionStore.inMemory();
    await sessions.save(session('owner'));
  });
  AppServices appWith(Future<http.Response> Function(http.Request) handler) {
    final app = AppServices(
      store: store,
      sessions: sessions,
      api: ApiClient(sessionStore: sessions, client: MockClient(handler)),
    );
    addTearDown(app.dispose);
    return app;
  }

  test(
    'first upload retains remote pills and settings while merging local additions',
    () async {
      await store.savePills([
        {'id': 'local-pill'},
      ]);
      final app = appWith((request) async {
        if (request.method == 'GET') return data(remote());
        final body = jsonDecode(request.body) as Map;
        expect(body['baseRevision'], 4);
        expect(
          body['snapshot']['pills'].map((p) => p['id']),
          containsAll(['remote-pill', 'local-pill']),
        );
        expect(body['snapshot']['settings']['reminderMinutes'], 60);
        expect(body['snapshot']['settings']['guardianAlertsEnabled'], false);
        return data({'revision': 5});
      });
      expect(await app.sync.syncToServer(), 5);
    },
  );
  test(
    'cloud deletion waits for an upload and removes the latest revision',
    () async {
      await store.saveSyncRevision('owner', 1);
      final started = Completer<void>();
      final finish = Completer<http.Response>();
      final requests = <String>[];
      final app = appWith((request) async {
        requests.add(request.method);
        if (request.method == 'PUT') {
          started.complete();
          return finish.future;
        }
        if (request.method == 'GET') return data({'revision': 2});
        expect(request.url.queryParameters['baseRevision'], '2');
        return http.Response('', 204);
      });
      final upload = app.sync.syncToServer();
      await started.future;
      final deletion = app.sync.deleteCloudBackup();
      expect(requests, ['PUT']);
      finish.complete(data({'revision': 2}));
      await upload;
      await deletion;
      expect(requests, ['PUT', 'GET', 'DELETE']);
      expect(store.readSyncRevision('owner'), 0);
      expect(app.sync.lastSyncedAt, isNull);
    },
  );
  test(
    'cloud deletion cancels pending edits so lifecycle flush cannot recreate it',
    () async {
      final requests = <String>[];
      final app = appWith((request) async {
        requests.add(request.method);
        if (request.method == 'GET') return data({'revision': 1});
        if (request.method == 'DELETE') return http.Response('', 204);
        fail(
          'Deleted backup must not be uploaded by a pending lifecycle flush',
        );
      });
      app.sync.scheduleSync();
      await app.sync.deleteCloudBackup();
      await app.sync.flushPendingChanges();
      expect(requests, ['GET', 'DELETE']);
    },
  );
  test(
    'local deletion invalidates a pending download so it cannot restore data',
    () async {
      final started = Completer<void>();
      final finish = Completer<http.Response>();
      final app = appWith((_) {
        started.complete();
        return finish.future;
      });
      final pending = expectLater(
        app.sync.reconcileWithServer(),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      final deletion = app.clearLocalData();
      finish.complete(data(remote()));
      await pending;
      await deletion;
      expect(store.readPills(), isEmpty);
      expect(store.readSyncRevision('owner'), isNull);
    },
  );
  test(
    'a pending upload never stamps another account with the old revision',
    () async {
      await store.saveSyncRevision('owner', 1);
      final started = Completer<void>();
      final finish = Completer<http.Response>();
      final app = appWith((_) {
        started.complete();
        return finish.future;
      });
      final pending = expectLater(
        app.sync.syncToServer(),
        throwsA(isA<ApiException>()),
      );
      await started.future;
      await sessions.save(session('other'));
      finish.complete(data({'revision': 2}));
      await pending;
      expect(store.readSyncRevision('other'), isNull);
      expect(store.readLastSyncedAt('other'), isNull);
      expect(store.readSyncRevision('owner'), isNull);
      expect(store.dataOwnerId, 'other');
    },
  );
  test(
    'deleting an account clears its metadata even after the session is gone',
    () async {
      await store.saveSyncRevision('owner', 3);
      await store.saveLastSyncedAt('owner', DateTime(2026));
      final app = appWith((_) async => http.Response('', 204));
      await sessions.clear();
      await app.clearLocalData(userId: 'owner');
      expect(store.readSyncRevision('owner'), isNull);
      expect(store.readLastSyncedAt('owner'), isNull);
    },
  );
}
