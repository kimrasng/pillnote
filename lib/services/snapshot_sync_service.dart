import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/domain/snapshot_merger.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

/// Coordinates debounced uploads, revisions, and conflict resolution.
class SnapshotSyncService {
  SnapshotSyncService({
    required this._store,
    required this._api,
    required this._sessions,
    DateTime Function()? now,
    this._debounce = const Duration(milliseconds: 800),
  }) : _now = now ?? DateTime.now;

  final MedicationStore _store;
  final ApiClient _api;
  final SessionStore _sessions;
  final DateTime Function() _now;
  final Duration _debounce;
  Timer? _pendingSync;
  bool _syncing = false;
  bool _syncAgain = false;

  DateTime? get lastSyncedAt =>
      _store.readLastSyncedAt(_sessions.session?.userId);

  Map<String, dynamic> buildSnapshot() => {
    'schemaVersion': 1,
    'deviceId': _store.deviceId,
    'pills': _store.readPills(),
    'groups': _store.readGroups(),
    'intakeHistory': _store.readHistory(),
    'settings': _store.readSettings(),
  };

  void scheduleSync() {
    if (!_sessions.isLoggedIn) return;
    cancelPendingSync();
    _pendingSync = Timer(_debounce, () async {
      try {
        await syncToServer();
      } catch (error) {
        debugPrint('백그라운드 동기화 실패: $error');
      }
    });
  }

  void cancelPendingSync() {
    _pendingSync?.cancel();
    _pendingSync = null;
  }

  void dispose() => cancelPendingSync();

  Future<int?> reconcileWithServer() async {
    if (!_sessions.isLoggedIn) return null;
    final remote = await _api.fetchSnapshot();
    await _mergeRemote(remote);
    await _setRevision(_remoteRevision(remote));
    return syncToServer();
  }

  Future<int?> syncToServer() async {
    if (!_sessions.isLoggedIn) return null;
    if (_syncing) {
      _syncAgain = true;
      return _revision;
    }
    _syncing = true;
    try {
      int? revision;
      do {
        _syncAgain = false;
        revision = await _uploadSnapshot();
      } while (_syncAgain);
      return revision;
    } finally {
      _syncing = false;
    }
  }

  Future<void> deleteCloudBackup() async {
    if (!_sessions.isLoggedIn) return;
    cancelPendingSync();
    final remote = await _api.fetchSnapshot();
    await _api.deleteSnapshot(_remoteRevision(remote));
    await _setRevision(0);
    await _store.clearLastSyncedAt(_sessions.session?.userId);
  }

  Future<int> _uploadSnapshot() async {
    var revision = _revision;
    if (revision == null) {
      final remote = await _api.fetchSnapshot();
      revision = _remoteRevision(remote);
      await _setRevision(revision);
    }
    try {
      return await _saveSnapshot(revision);
    } on ApiException catch (error) {
      if (error.code != 'SYNC_CONFLICT') rethrow;
      final remote = await _api.fetchSnapshot();
      await _mergeRemote(remote);
      return _saveSnapshot(_remoteRevision(remote));
    }
  }

  Future<int> _saveSnapshot(int revision) async {
    final saved = await _api.saveSnapshot(
      baseRevision: revision,
      snapshot: buildSnapshot(),
    );
    final next = (saved['revision'] as num?)?.toInt() ?? revision + 1;
    await _setRevision(next);
    await _store.saveLastSyncedAt(_sessions.session?.userId, _now());
    return next;
  }

  Future<void> _mergeRemote(Map<String, dynamic> remote) async {
    final snapshot = remote['snapshot'];
    if (snapshot is! Map) return;
    final merged = SnapshotMerger.merge(
      Map<String, dynamic>.from(snapshot),
      buildSnapshot(),
    );
    await Future.wait([
      _store.savePills(_mapList(merged['pills'])),
      _store.saveGroups(_mapList(merged['groups'])),
      _store.saveHistory(
        Map<String, dynamic>.from(merged['intakeHistory'] as Map),
      ),
      _store.saveSettings(Map<String, dynamic>.from(merged['settings'] as Map)),
    ]);
  }

  int? get _revision {
    final session = _sessions.session;
    return session == null ? null : _store.readSyncRevision(session.userId);
  }

  Future<void> _setRevision(int revision) async {
    final session = _sessions.session;
    if (session != null) {
      await _store.saveSyncRevision(session.userId, revision);
    }
  }

  static int _remoteRevision(Map<String, dynamic> remote) =>
      (remote['revision'] as num?)?.toInt() ?? 0;

  static List<Map<String, dynamic>> _mapList(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
}
