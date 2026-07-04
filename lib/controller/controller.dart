import 'package:shared_preferences/shared_preferences.dart';

class Controller {
  static late SharedPreferences _prefs;
  static const String _onboardingKey = 'onboarding_completed';
  static const String _sessionKey = 'session_token';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_onboardingKey, completed);
  }

  static bool shouldShowOnboarding() {
    return !(_prefs.getBool(_onboardingKey) ?? false);
  }

  static Future<void> setSessionToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _prefs.remove(_sessionKey);
    } else {
      await _prefs.setString(_sessionKey, token);
    }
  }

  static String? getSessionToken() {
    return _prefs.getString(_sessionKey);
  }

  static bool isLoggedIn() {
    final token = getSessionToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await _prefs.remove(_sessionKey);
  }
}