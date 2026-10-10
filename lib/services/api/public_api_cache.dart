import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bounded, persistent cache for public drug information, separate from accounts.
/// Expired entries are never served; concurrent misses share one network load.
class PublicApiCache {
  PublicApiCache({
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
    this.maxEntries = 100,
    this.maxBytes = 2 * 1024 * 1024,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  PublicApiCache.inMemory({
    DateTime Function()? now,
    this.maxEntries = 100,
    this.maxBytes = 2 * 1024 * 1024,
  }) : _preferences = null,
       _now = now ?? DateTime.now;

  static const storageKey = 'public_drug_api_cache_v1';
  final Future<SharedPreferences> Function()? _preferences;
  final DateTime Function() _now;
  final int maxEntries, maxBytes;
  final _entries = <String, _CacheEntry>{};
  final _pending = <String, Future<String>>{};
  SharedPreferences? _prefs;
  Future<void>? _initialization;
  Future<void> _writes = Future.value();

  Future<Map<String, dynamic>> getOrLoad({
    required String key,
    required Duration ttl,
    required Future<Map<String, dynamic>> Function() load,
    required bool Function(Map<String, dynamic>) cacheable,
  }) async {
    await (_initialization ??= _restore());
    final entry = _entries.remove(key);
    if (entry != null && entry.isFresh(_now())) {
      _entries[key] = entry;
      return _decode(entry.payload);
    }
    final pending = _pending[key] ??= _load(key, ttl, load, cacheable);
    try {
      // Each reader gets its own copy: UI edits cannot alter future responses.
      return _decode(await pending);
    } finally {
      if (identical(_pending[key], pending)) _pending.remove(key);
    }
  }

  Future<String> _load(
    String key,
    Duration ttl,
    Future<Map<String, dynamic>> Function() load,
    bool Function(Map<String, dynamic>) cacheable,
  ) async {
    final response = await load();
    final payload = jsonEncode(response);
    if (ttl > Duration.zero && cacheable(response)) {
      final created = _now();
      final entry = _CacheEntry(payload, created, created.add(ttl));
      // Oversized results remain usable without evicting the entire cache.
      if (utf8.encode(jsonEncode({key: entry.toJson()})).length <= maxBytes) {
        _entries.remove(key);
        _entries[key] = entry;
        _trim();
        await _persist();
      }
    }
    return payload;
  }

  Future<void> _restore() async {
    try {
      final preferences = _preferences;
      if (preferences == null) return;
      _prefs = await preferences();
      final saved = _prefs!.getString(storageKey);
      if (saved == null || utf8.encode(saved).length > maxBytes) return;
      final entries = jsonDecode(saved);
      if (entries is! Map) return;
      for (final item in entries.entries) {
        try {
          if (item.key is! String || item.value is! Map) continue;
          final value = item.value as Map;
          final entry = _CacheEntry(
            value['payload'] as String,
            DateTime.fromMillisecondsSinceEpoch(value['createdAt'] as int),
            DateTime.fromMillisecondsSinceEpoch(value['expiresAt'] as int),
          );
          if (entry.isFresh(_now())) {
            _decode(entry.payload);
            _entries[item.key as String] = entry;
          }
        } catch (_) {
          // A damaged entry must not discard the other cached results.
        }
      }
      _trim();
    } catch (_) {
      // Missing or damaged disk storage falls back to the in-memory cache.
    }
  }

  String _serialize() => jsonEncode({
    for (final entry in _entries.entries) entry.key: entry.value.toJson(),
  });

  void _trim() {
    _entries.removeWhere((_, entry) => !entry.isFresh(_now()));
    while (_entries.isNotEmpty &&
        (_entries.length > maxEntries ||
            utf8.encode(_serialize()).length > maxBytes)) {
      _entries.remove(_entries.keys.first);
    }
  }

  Future<void> _persist() {
    _writes = _writes.then((_) async {
      try {
        await _prefs?.setString(storageKey, _serialize());
      } catch (_) {
        // Cache storage failure never turns a successful API call into an error.
      }
    });
    return _writes;
  }

  static Map<String, dynamic> _decode(String payload) =>
      Map<String, dynamic>.from(jsonDecode(payload) as Map);
}

class _CacheEntry {
  const _CacheEntry(this.payload, this.createdAt, this.expiresAt);
  final String payload;
  final DateTime createdAt, expiresAt;

  bool isFresh(DateTime now) =>
      !createdAt.isAfter(now) && expiresAt.isAfter(now);

  Map<String, dynamic> toJson() => {
    'payload': payload,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };
}
