import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Controller {
  static late SharedPreferences _prefs;
  static const String _onboardingKey = 'onboarding_completed';
  static const String _sessionKey = 'session_token';
  static const String _pillsKey = 'user_pills';
  static const String _historyKey = 'intake_history';

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

  // 리스트 가져오기
  static List<Map<String, dynamic>> getPills() {
    final String? jsonString = _prefs.getString(_pillsKey);
    if (jsonString == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // 약 추가
  static Future<void> addPill(Map<String, dynamic> pill) async {
    final pills = getPills();
    pills.add({
      ...pill,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _prefs.setString(_pillsKey, jsonEncode(pills));
  }

  /// 약 삭제
  static Future<void> removePill(String pillId) async {
    final pills = getPills();
    pills.removeWhere((p) => p['id'] == pillId);
    await _prefs.setString(_pillsKey, jsonEncode(pills));
  }

  // 특정 날짜의 복약 기록 가져오기
  static List<Map<String, dynamic>> getHistoryByDate(String date) {
    final String? jsonString = _prefs.getString(_historyKey);
    if (jsonString == null) return [];
    try {
      final Map<String, dynamic> fullHistory = jsonDecode(jsonString);
      final List<dynamic>? dayHistory = fullHistory[date];
      if (dayHistory == null) return [];
      return dayHistory.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 복약 체크
  static Future<void> recordIntake(String pillId, String scheduledTime) async {
    final String date = DateTime.now().toString().split(' ')[0];
    final String? jsonString = _prefs.getString(_historyKey);
    
    Map<String, dynamic> fullHistory = {};
    if (jsonString != null) {
      fullHistory = Map<String, dynamic>.from(jsonDecode(jsonString));
    }

    final List<dynamic> dayHistory = fullHistory[date] ?? [];
    dayHistory.add({
      'pillId': pillId,
      'scheduledTime': scheduledTime,
      'takenAt': DateTime.now().toIso8601String(),
    });

    fullHistory[date] = dayHistory;
    await _prefs.setString(_historyKey, jsonEncode(fullHistory));
  }

  static bool isLoggedIn() {
    final token = getSessionToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await _prefs.remove(_sessionKey);
  }
}