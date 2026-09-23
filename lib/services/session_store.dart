import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SessionChangeReason { signedIn, signedOut, expired }

class SessionChange {
  const SessionChange({required this.reason, required this.session});

  final SessionChangeReason reason;
  final UserSession? session;
}

class UserSession {
  const UserSession({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresIn,
    required this.refreshTokenExpiresIn,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final int accessTokenExpiresIn;
  final int refreshTokenExpiresIn;

  factory UserSession.fromApi(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] as Map? ?? const {});
    return UserSession(
      userId: user['id']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      accessTokenExpiresIn:
          (json['accessTokenExpiresIn'] as num?)?.toInt() ?? 0,
      refreshTokenExpiresIn:
          (json['refreshTokenExpiresIn'] as num?)?.toInt() ?? 0,
    );
  }
}

class SessionStore {
  SessionStore._secure()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.unlocked_this_device,
          synchronizable: false,
        ),
        aOptions: AndroidOptions(migrateWithBackup: true),
      ),
      _memory = null;

  SessionStore.inMemory() : _storage = null, _memory = <String, String>{};

  static final SessionStore instance = SessionStore._secure();

  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;
  final _changes = StreamController<SessionChange>.broadcast(sync: true);

  static const _userIdKey = 'session_user_id';
  static const _emailKey = 'session_email';
  static const _accessTokenKey = 'session_access_token';
  static const _refreshTokenKey = 'session_refresh_token';
  static const _accessTtlKey = 'session_access_ttl';
  static const _refreshTtlKey = 'session_refresh_ttl';

  UserSession? _session;

  UserSession? get session => _session;
  bool get isLoggedIn => _session != null;
  Stream<SessionChange> get changes => _changes.stream;

  Future<void> initialize() async {
    final values = _memory ?? await _storage!.readAll();
    final accessToken = values[_accessTokenKey] ?? '';
    final refreshToken = values[_refreshTokenKey] ?? '';
    final userId = values[_userIdKey] ?? '';
    final email = values[_emailKey] ?? '';
    if (accessToken.isEmpty ||
        refreshToken.isEmpty ||
        userId.isEmpty ||
        email.isEmpty) {
      _session = null;
      return;
    }
    _session = UserSession(
      userId: userId,
      email: email,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresIn: int.tryParse(values[_accessTtlKey] ?? '') ?? 0,
      refreshTokenExpiresIn: int.tryParse(values[_refreshTtlKey] ?? '') ?? 0,
    );
  }

  Future<void> save(UserSession session) async {
    if (session.userId.isEmpty ||
        session.email.isEmpty ||
        session.accessToken.isEmpty ||
        session.refreshToken.isEmpty) {
      throw ArgumentError('완전한 사용자 세션만 저장할 수 있습니다.');
    }
    await Future.wait([
      _write(_userIdKey, session.userId),
      _write(_emailKey, session.email),
      _write(_accessTokenKey, session.accessToken),
      _write(_refreshTokenKey, session.refreshToken),
      _write(_accessTtlKey, session.accessTokenExpiresIn.toString()),
      _write(_refreshTtlKey, session.refreshTokenExpiresIn.toString()),
    ]);
    _session = session;
    _changes.add(
      SessionChange(reason: SessionChangeReason.signedIn, session: session),
    );
  }

  Future<void> clear({
    SessionChangeReason reason = SessionChangeReason.signedOut,
  }) async {
    final hadSession = _session != null;
    _session = null;
    try {
      await Future.wait([
        _delete(_userIdKey),
        _delete(_emailKey),
        _delete(_accessTokenKey),
        _delete(_refreshTokenKey),
        _delete(_accessTtlKey),
        _delete(_refreshTtlKey),
      ]);
    } finally {
      if (hadSession) {
        _changes.add(SessionChange(reason: reason, session: null));
      }
    }
  }

  Future<void> _write(String key, String value) async {
    if (_memory != null) {
      _memory[key] = value;
      return;
    }
    await _storage!.write(key: key, value: value);
  }

  Future<void> _delete(String key) async {
    if (_memory != null) {
      _memory.remove(key);
      return;
    }
    await _storage!.delete(key: key);
  }
}
