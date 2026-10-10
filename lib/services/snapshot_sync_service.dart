import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/domain/snapshot_merger.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

/// Coordinates debounced uploads, revisions, and conflict resolution.
class SnapshotSyncService extends ChangeNotifier {
  SnapshotSyncService({
    required this._store,
    required this._api,
    required this._sessions,
    DateTime Function()? now,
    Future<String?> Function()? resolveTimeZone,
    this._onSnapshotApplied,
    this._debounce = const Duration(milliseconds: 800),
  }) : _now = now ?? DateTime.now,
       _resolveTimeZone = resolveTimeZone ?? _deviceTimeZone {
    _sessions.addSignInPreparation(_prepareSignIn);
  }

  static Future<String?> _deviceTimeZone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // Offset metadata still supports devices without the native plugin.
      return null;
    }
  }

  final MedicationStore _store;
  final ApiClient _api;
  final SessionStore _sessions;
  final DateTime Function() _now;
  final Duration _debounce;
  final Future<String?> Function() _resolveTimeZone;
  final Future<void> Function()? _onSnapshotApplied;
  String? _timeZoneIdentifier;
  int _localChanges = 0;
  bool _hasPendingChanges = false;
  Timer? _pendingSync;
  Future<void> _operations = Future.value();
  Future<void> _localWrites = Future.value();
  int _dataGeneration = 0;
  bool _disposed = false;

  DateTime? get lastSyncedAt =>
      _store.readLastSyncedAt(_sessions.session?.userId);

  Map<String, dynamic> buildSnapshot() => {
    'schemaVersion': 1,
    'deviceId': _store.deviceId,
    'timeZone': {
      if (_timeZoneIdentifier != null) 'identifier': _timeZoneIdentifier,
      'utcOffsetMinutes': _now().timeZoneOffset.inMinutes,
    },
    'pills': _store.readPills(),
    'groups': _store.readGroups(),
    'intakeHistory': _store.readHistory(),
    'settings': _store.readSettings(),
  };

  void scheduleSync() {
    if (!_sessions.isLoggedIn || _disposed) return;
    _localChanges++;
    _hasPendingChanges = true;
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

  /// Flush edits before suspension; failed uploads remain pending for retry.
  Future<void> flushPendingChanges() async {
    if (!_hasPendingChanges) return;
    cancelPendingSync();
    await syncToServer();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessions.removeSignInPreparation(_prepareSignIn);
    _dataGeneration++;
    cancelPendingSync();
    super.dispose();
  }

  /// Prevent an old download from restoring data after a local reset.
  Future<void> invalidateAndWait() async {
    _dataGeneration++;
    cancelPendingSync();
    await _operations;
    await _localWrites;
    _hasPendingChanges = false;
  }

  Future<void> _prepareSignIn(UserSession session) async {
    // Old network requests can finish later, but their contexts are invalid.
    // Wait only for local writes so an offline old account cannot delay login.
    _dataGeneration++;
    cancelPendingSync();
    _hasPendingChanges = false;
    _operations = Future.value();
    if (_disposed) return;
    await _writeLocally(() => _activateAccount(session.userId));
  }

  /// Bind legacy data to a restored session before the first local frame.
  Future<void> prepareCurrentAccount() async {
    final context = _context;
    if (context == null) return;
    if (!_store.hasExplicitDataOwner) {
      await _store.saveDataOwnerId(context.userId);
    }
    await _enqueue(context, () async {});
  }

  Future<void> _activateAccount(String userId) async {
    final previousOwner = _store.dataOwnerId;
    if (previousOwner == userId && _store.hasExplicitDataOwner) return;
    if (previousOwner != null && previousOwner != userId) {
      // Never merge a former account's cache into the new account, even when
      // the new account has no backup or its first download fails.
      cancelPendingSync();
      _hasPendingChanges = false;
      await _store.clear(userId: previousOwner);
      await _store.clearSyncMetadata(userId);
    }
    await _store.saveDataOwnerId(userId);
    if (previousOwner != null && previousOwner != userId) {
      await _onSnapshotApplied?.call();
      if (!_disposed) notifyListeners();
    }
  }

  Future<int?> reconcileWithServer() async {
    final context = _context;
    if (context == null) return null;
    return _enqueue(context, () async {
      final remote = await _api.fetchSnapshot();
      await _mergeRemote(remote, context);
      await _setRevision(_remoteRevision(remote), context);
      return _uploadSnapshot(context);
    });
  }

  Future<int?> syncToServer() async {
    final context = _context;
    if (context == null) return null;
    return _enqueue(context, () => _uploadSnapshot(context));
  }

  Future<void> deleteCloudBackup() async {
    final context = _context;
    if (context == null) return;
    final changes = _localChanges;
    cancelPendingSync();
    await _enqueue(context, () async {
      final remote = await _api.fetchSnapshot();
      _ensureActive(context);
      await _api.deleteSnapshot(_remoteRevision(remote));
      await _setRevision(0, context);
      await _writeLocally(
        () => _store.clearLastSyncedAt(context.userId),
        context,
      );
      if (changes == _localChanges) _hasPendingChanges = false;
    });
  }

  Future<T> _enqueue<T>(_SyncContext context, Future<T> Function() operation) {
    final pending = _operations.then((_) async {
      _ensureActive(context);
      await _writeLocally(() => _activateAccount(context.userId), context);
      _ensureActive(context);
      return operation();
    });
    _operations = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  Future<void> _writeLocally(
    Future<void> Function() write, [
    _SyncContext? context,
  ]) {
    final pending = _localWrites.then((_) async {
      if (context != null) _ensureActive(context);
      await write();
      if (context != null) _ensureActive(context);
    });
    _localWrites = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  Future<int> _uploadSnapshot(_SyncContext context) async {
    _ensureActive(context);
    var revision = _store.readSyncRevision(context.userId);
    if (revision == null) {
      final remote = await _api.fetchSnapshot();
      // First upload on a new device must retain the existing cloud records.
      await _mergeRemote(remote, context);
      revision = _remoteRevision(remote);
      await _setRevision(revision, context);
    }
    try {
      return await _saveSnapshot(revision, context);
    } on ApiException catch (error) {
      if (error.code != 'SYNC_CONFLICT') rethrow;
      _ensureActive(context);
      final remote = await _api.fetchSnapshot();
      await _mergeRemote(remote, context);
      return _saveSnapshot(_remoteRevision(remote), context);
    }
  }

  Future<int> _saveSnapshot(int revision, _SyncContext context) async {
    _ensureActive(context);
    _timeZoneIdentifier = await _resolveTimeZone();
    _ensureActive(context);
    final changes = _localChanges;
    final saved = await _api.saveSnapshot(
      baseRevision: revision,
      snapshot: buildSnapshot(),
    );
    final next = (saved['revision'] as num?)?.toInt() ?? revision + 1;
    await _setRevision(next, context);
    _ensureActive(context);
    await _writeLocally(
      () => _store.saveLastSyncedAt(context.userId, _now()),
      context,
    );
    if (changes == _localChanges) _hasPendingChanges = false;
    return next;
  }

  Future<void> _mergeRemote(
    Map<String, dynamic> remote,
    _SyncContext context,
  ) async {
    _ensureActive(context);
    final snapshot = remote['snapshot'];
    if (snapshot is! Map) return;
    await _writeLocally(() async {
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
        _store.saveSettings(
          Map<String, dynamic>.from(merged['settings'] as Map),
        ),
      ]);
    }, context);
    _ensureActive(context);
    await _onSnapshotApplied?.call();
    _ensureActive(context);
    notifyListeners();
  }

  _SyncContext? get _context {
    final session = _sessions.session;
    if (session == null || _disposed) return null;
    return _SyncContext(session.userId, _sessions.generation, _dataGeneration);
  }

  void _ensureActive(_SyncContext context) {
    if (_disposed ||
        context.sessionGeneration != _sessions.generation ||
        context.dataGeneration != _dataGeneration ||
        context.userId != _sessions.session?.userId) {
      throw const ApiException(
        statusCode: 0,
        code: 'SYNC_CANCELLED',
        message: '로그인 상태 또는 로컬 데이터가 변경되어 동기화를 중단했습니다.',
      );
    }
  }

  Future<void> _setRevision(int revision, _SyncContext context) async {
    _ensureActive(context);
    await _writeLocally(
      () => _store.saveSyncRevision(context.userId, revision),
      context,
    );
  }

  static int _remoteRevision(Map<String, dynamic> remote) =>
      (remote['revision'] as num?)?.toInt() ?? 0;

  static List<Map<String, dynamic>> _mapList(Object? value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
}

class _SyncContext {
  const _SyncContext(this.userId, this.sessionGeneration, this.dataGeneration);
  final String userId;
  final int sessionGeneration;
  final int dataGeneration;
}
