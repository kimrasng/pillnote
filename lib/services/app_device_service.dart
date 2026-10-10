import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Separate from FCM: denied notifications must not hide signed-in installations.
class AppDeviceService {
  AppDeviceService({
    required this.api,
    required this.sessions,
    required this.deviceId,
    required this.platform,
    Future<Map<String, String>> Function()? metadata,
  }) : _metadata = metadata ?? _nativeMetadata;

  static final instance = AppDeviceService(
    api: ApiClient.instance,
    sessions: SessionStore.instance,
    deviceId: () => AppServices.instance.deviceId,
    platform: kIsWeb
        ? null
        : Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
        ? 'android'
        : null,
  );
  static const _channel = MethodChannel('kr.kimrasng.pillnote/device_metadata');
  final ApiClient api;
  final SessionStore sessions;
  final String Function() deviceId;
  final String? platform;
  final Future<Map<String, String>> Function() _metadata;
  StreamSubscription<SessionChange>? _subscription;
  Future<void> _pending = Future.value();
  DateTime? _lastSuccess;
  int? _lastGeneration;

  static Future<Map<String, String>> _nativeMetadata() async {
    final values = await _channel.invokeMapMethod<String, dynamic>(
      'getMetadata',
    );
    return {
      for (final key in ['model', 'osVersion', 'appVersion', 'appBuild'])
        if (values?[key] is String) key: values![key] as String,
    };
  }

  void initialize() {
    _subscription ??= sessions.changes.listen((change) {
      if (change.reason == SessionChangeReason.signedIn) {
        unawaited(register(force: true));
      } else {
        _lastSuccess = null;
        _lastGeneration = null;
      }
    });
  }

  Future<bool> detailsConsent() async {
    final userId = sessions.session?.userId;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('device_details_consent_v1_$userId') ?? false;
  }

  Future<bool> setDetailsConsent(bool enabled) async {
    final userId = sessions.session?.userId;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('device_details_consent_v1_$userId', enabled);
    return register(force: true);
  }

  Future<bool> register({bool force = false}) {
    final generation = sessions.generation;
    final completion = Completer<bool>();
    _pending = _pending.then((_) async {
      if (platform == null ||
          !sessions.isLoggedIn ||
          generation != sessions.generation) {
        completion.complete(false);
        return;
      }
      if (!force &&
          _lastGeneration == generation &&
          _lastSuccess != null &&
          DateTime.now().difference(_lastSuccess!) <
              const Duration(minutes: 5)) {
        completion.complete(true);
        return;
      }
      try {
        final consent = await detailsConsent();
        Map<String, String> details = {};
        if (consent) {
          try {
            details = await _metadata();
          } catch (_) {
            /* Platform only still counts. */
          }
        }
        if (generation != sessions.generation) {
          completion.complete(false);
          return;
        }
        await api.registerAppDevice(
          deviceId: deviceId(),
          platform: platform!,
          detailsConsent: consent,
          details: details,
          generation: generation,
        );
        if (generation == sessions.generation) {
          _lastSuccess = DateTime.now();
          _lastGeneration = generation;
        }
        completion.complete(generation == sessions.generation);
      } catch (_) {
        // Counting failure must never block login or offline local medication use.
        completion.complete(false);
      }
    });
    return completion.future;
  }

  Future<void> dispose() async => _subscription?.cancel();
}
