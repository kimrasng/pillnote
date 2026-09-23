import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:pillnote/config/app_config.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';

@pragma('vm:entry-point')
Future<void> pillNoteFirebaseBackgroundHandler(RemoteMessage message) async {
  final options = AppConfig.firebaseOptions;
  if (options != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  final _foregroundMessages = StreamController<RemoteMessage>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  bool _initialized = false;
  String? lastError;

  bool get isConfigured => AppConfig.isFirebaseConfigured;
  bool get isInitialized => _initialized;
  Stream<RemoteMessage> get foregroundMessages => _foregroundMessages.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!isConfigured) {
      lastError = 'Firebase 앱 설정이 없습니다. Firebase iOS/Android 앱 설정을 먼저 추가해주세요.';
      return;
    }
    try {
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
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _foregroundMessages.add,
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
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
    if (!SessionStore.instance.isLoggedIn) return;
    try {
      await _registerToken(token);
      lastError = null;
    } catch (error) {
      lastError = _friendlyError(error);
      debugPrint('FCM 토큰 서버 등록 실패: $error');
    }
  }

  Future<bool> registerCurrentDevice() async {
    if (!SessionStore.instance.isLoggedIn) {
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
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        lastError = '알림 권한이 거부되었습니다.';
        return false;
      }
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        lastError = '알림 권한을 확인하지 못했습니다. 시스템 설정에서 알림을 허용해주세요.';
        return false;
      }

      if (Platform.isIOS && await _waitForApnsToken() == null) {
        lastError =
            'APNs 기기 토큰을 받지 못했습니다. iOS Push Notifications 설정과 APNs 키를 확인해주세요.';
        return false;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        lastError = 'FCM 기기 토큰을 받지 못했습니다.';
        return false;
      }
      await _registerToken(token);
      lastError = null;
      return true;
    } catch (error) {
      lastError = _friendlyError(error);
      debugPrint('Push 기기 등록 실패: $error');
      return false;
    }
  }

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final token = await FirebaseMessaging.instance.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return null;
  }

  String _friendlyError(Object error) {
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
    if (!SessionStore.instance.isLoggedIn) return;
    try {
      await ApiClient.instance.unregisterDevice(Controller.deviceId);
    } on ApiException catch (error) {
      if (error.code != 'DEVICE_NOT_FOUND') rethrow;
    }
  }

  Future<void> _registerToken(String token) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await ApiClient.instance.registerDevice(
      deviceId: Controller.deviceId,
      platform: Platform.isIOS ? 'ios' : 'android',
      pushToken: token,
    );
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _foregroundMessages.close();
  }
}
