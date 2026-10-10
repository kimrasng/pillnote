import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:pillnote/config/app_config.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

@pragma('vm:entry-point')
Future<void> pillNoteFirebaseBackgroundHandler(RemoteMessage message) async {
  final options = AppConfig.firebaseOptions;
  if (options != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
}

/// Native messaging boundary; tests exercise registration without real FCM.
abstract interface class PushMessagingGateway {
  bool get isIos;
  String? get platform;
  Future<void> initialize();
  Stream<String> get tokenRefresh;
  Stream<RemoteMessage> get messages;
  Future<AuthorizationStatus> permission({bool request = false});
  Future<String?> token();
  Future<String?> apnsToken();
}

class FirebasePushMessagingGateway implements PushMessagingGateway {
  @override
  bool get isIos => Platform.isIOS;
  @override
  String? get platform => Platform.isIOS
      ? 'ios'
      : Platform.isAndroid
      ? 'android'
      : null;
  @override
  Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
    }
    FirebaseMessaging.onBackgroundMessage(pillNoteFirebaseBackgroundHandler);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  @override
  Stream<String> get tokenRefresh => FirebaseMessaging.instance.onTokenRefresh;
  @override
  Stream<RemoteMessage> get messages => FirebaseMessaging.onMessage;
  @override
  Future<AuthorizationStatus> permission({bool request = false}) async {
    final settings = request
        ? await FirebaseMessaging.instance.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  }

  @override
  Future<String?> token() => FirebaseMessaging.instance.getToken();
  @override
  Future<String?> apnsToken() => FirebaseMessaging.instance.getAPNSToken();
}

class PushNotificationService {
  PushNotificationService({
    PushMessagingGateway? messaging,
    ApiClient? api,
    SessionStore? sessions,
    String Function()? deviceId,
    this._configured,
  }) : _messaging = messaging ?? FirebasePushMessagingGateway(),
       _api = api ?? ApiClient.instance,
       _sessions = sessions ?? SessionStore.instance,
       _deviceId = deviceId ?? (() => AppServices.instance.deviceId) {
    _sessionSubscription = _sessions.changes.listen((change) {
      if (change.reason != SessionChangeReason.signedIn) {
        _registrationEnabled = false;
        isRegistered = false;
      }
    });
  }

  static final instance = PushNotificationService();
  final PushMessagingGateway _messaging;
  final ApiClient _api;
  final SessionStore _sessions;
  final String Function() _deviceId;
  final bool? _configured;
  StreamSubscription<SessionChange>? _sessionSubscription;
  Future<void>? _initializing;
  Future<void> _deviceOperations = Future.value();
  bool _registrationEnabled = true;

  final _foregroundMessages = StreamController<RemoteMessage>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _initialized = false;
  bool isRegistered = false;
  bool? permissionGranted;
  String? lastError;

  bool get isConfigured => _configured ?? AppConfig.isFirebaseConfigured;
  bool get isInitialized => _initialized;
  Stream<RemoteMessage> get foregroundMessages => _foregroundMessages.stream;

  String get statusMessage {
    if (!isConfigured) return '현재 환경에서는 기기 알림을 사용할 수 없어요.';
    if (permissionGranted == false) return '기기 설정에서 PillNote 알림을 허용하세요.';
    if (isRegistered) return '이 기기에서 알림을 받을 준비가 되었어요.';
    return '알림을 켜면 보호자 알림을 받을 수 있어요.';
  }

  Future<void> refreshPermissionStatus() async {
    if (!isConfigured) return;
    await initialize();
    if (!_initialized) return;
    try {
      final status = await _messaging.permission();
      permissionGranted =
          status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
      if (permissionGranted != true) isRegistered = false;
    } catch (_) {
      permissionGranted = null;
    }
  }

  Future<void> initialize() {
    if (_initialized) return Future.value();
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _initialize();
    _initializing = operation;
    return operation.whenComplete(() {
      if (identical(_initializing, operation)) _initializing = null;
    });
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    if (!isConfigured) {
      lastError = 'Firebase 앱 설정이 없습니다. Firebase iOS/Android 앱 설정을 먼저 추가해주세요.';
      return;
    }
    try {
      await _messaging.initialize();
      _messageSubscription = _messaging.messages.listen(
        _foregroundMessages.add,
      );
      _tokenSubscription = _messaging.tokenRefresh.listen(
        (token) => unawaited(_handleTokenRefresh(token)),
        onError: (Object error) {
          lastError = _friendlyError(error);
          debugPrint('FCM 토큰 갱신 실패: $error');
        },
      );
      _initialized = true;
      lastError = null;
    } catch (error) {
      lastError = _friendlyError(error);
      debugPrint('Firebase 초기화 실패: $error');
    }
  }

  static String foregroundMessageText(RemoteMessage message) {
    return switch (message.data['type']) {
      'missed-dose' => '확인이 필요한 복약 알림이 도착했습니다.',
      _ => '새로운 알림이 도착했습니다.',
    };
  }

  Future<void> _handleTokenRefresh(String token) async {
    if (!_sessions.isLoggedIn || !_registrationEnabled) return;
    final generation = _sessions.generation;
    try {
      await refreshPermissionStatus();
      if (permissionGranted != true ||
          !_registrationEnabled ||
          generation != _sessions.generation) {
        return;
      }
      await _registerToken(token, generation);
      lastError = null;
    } catch (error) {
      lastError = _friendlyError(error);
      debugPrint('FCM 토큰 서버 등록 실패: $error');
    }
  }

  Future<bool> registerCurrentDevice() async {
    if (!_sessions.isLoggedIn) {
      lastError = 'Push 알림을 등록하려면 먼저 로그인해주세요.';
      return false;
    }
    if (!isConfigured) {
      lastError = 'Firebase 앱 설정이 없습니다. Firebase 프로젝트에 iOS/Android 앱을 등록해주세요.';
      return false;
    }
    await initialize();
    if (!_initialized) return false;
    try {
      final generation = _sessions.generation;
      _registrationEnabled = true;
      final status = await _messaging.permission(request: true);
      permissionGranted =
          status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
      if (status == AuthorizationStatus.denied) {
        lastError = '알림 권한이 거부되었습니다.';
        return false;
      }
      if (status == AuthorizationStatus.notDetermined) {
        lastError = '알림 권한을 확인하지 못했습니다. 시스템 설정에서 알림을 허용해주세요.';
        return false;
      }

      if (_messaging.isIos && await _waitForApnsToken() == null) {
        lastError =
            'APNs 기기 토큰을 받지 못했습니다. iOS Push Notifications 설정과 APNs 키를 확인해주세요.';
        return false;
      }

      final token = await _messaging.token();
      if (token == null || token.isEmpty) {
        lastError = 'FCM 기기 토큰을 받지 못했습니다.';
        return false;
      }
      if (generation != _sessions.generation || !_registrationEnabled) {
        return false;
      }
      await _registerToken(token, generation);
      lastError = null;
      return isRegistered && generation == _sessions.generation;
    } catch (error) {
      lastError = _friendlyError(error);
      debugPrint('Push 기기 등록 실패: $error');
      return false;
    }
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final token = await _messaging.apnsToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return null;
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    final raw = error.toString();
    if (raw.contains('apns-token-not-set')) {
      return 'APNs 토큰이 아직 준비되지 않았습니다. 잠시 후 다시 시도해주세요.';
    }
    if (raw.contains('no-app') || raw.contains('configuration-not-found')) {
      return 'Firebase 앱 설정을 찾을 수 없습니다. Firebase 프로젝트 설정을 확인해주세요.';
    }
    if (raw.contains('permission-blocked') ||
        raw.contains('permission-denied')) {
      return '알림 권한이 차단되어 있습니다. 시스템 설정에서 PillNote 알림을 허용해주세요.';
    }
    return 'Push 알림을 초기화하지 못했습니다. Firebase 및 APNs 설정을 확인해주세요.';
  }

  Future<void> unregisterCurrentDevice() async {
    _registrationEnabled = false;
    isRegistered = false;
    if (!_sessions.isLoggedIn) return;
    final generation = _sessions.generation;
    await _serializeDeviceOperation(() async {
      if (generation != _sessions.generation) return;
      try {
        await _api.unregisterDevice(_deviceId());
      } on ApiException catch (error) {
        if (error.code != 'DEVICE_NOT_FOUND') rethrow;
      }
    });
  }

  Future<void> _registerToken(String token, int generation) =>
      _serializeDeviceOperation(() async {
        final platform = _messaging.platform;
        if (platform == null ||
            !_registrationEnabled ||
            generation != _sessions.generation) {
          return;
        }
        await _api.registerDevice(
          deviceId: _deviceId(),
          platform: platform,
          pushToken: token,
        );
        if (generation != _sessions.generation || !_registrationEnabled) return;
        isRegistered = true;
      });

  Future<void> _serializeDeviceOperation(Future<void> Function() operation) {
    final pending = _deviceOperations.then((_) => operation());
    _deviceOperations = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  Future<void> dispose() async {
    _registrationEnabled = false;
    await _sessionSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _foregroundMessages.close();
  }
}
