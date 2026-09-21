import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:pillnote/firebase_options.dart';

class AppConfig {
  AppConfig._();

  static const _defaultApiBaseUrl = 'https://pillnote.kimrasng.kr';
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    final configured = _configuredApiBaseUrl.trim();
    if (configured.isNotEmpty) return _withoutTrailingSlash(configured);
    return _defaultApiBaseUrl;
  }

  static bool get isFirebaseConfigured =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static FirebaseOptions? get firebaseOptions {
    if (!isFirebaseConfigured) return null;
    return DefaultFirebaseOptions.currentPlatform;
  }

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
