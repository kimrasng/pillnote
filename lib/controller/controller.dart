import 'package:shared_preferences/shared_preferences.dart';

class Controller {
  static late SharedPreferences _prefs;
  static const String _onboardingKey = 'onboarding_completed';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_onboardingKey, completed);
  }

  static bool shouldShowOnboarding() {
    return !(_prefs.getBool(_onboardingKey) ?? false);
  }
}