import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Controller {
  static late SharedPreferences _prefs;
  static final String _onboardingKey = 'onboarding_completed';
  static final String _sessionKey = 'session_token';
  static final String _pillsKey = 'user_pills';
  static final String _historyKey = 'intake_history';
  static final String _groupsKey = 'pill_groups';

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

  static Future<void> addPill(Map<String, dynamic> pill, int stock) async {
    final pills = getPills();
    pills.add({
      ...pill,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'createdAt': DateTime.now().toIso8601String(),
      'startDate': null,
      'endDate': null,
      'times': [], 
      'stock': stock, 
      'dosage': 1.0,  
    });
    await _prefs.setString(_pillsKey, jsonEncode(pills));
  }

  static Future<void> updatePillSchedule(String pillId, String? startDate, String? endDate, List<String> times, double dosage) async {
    final pills = getPills();
    final index = pills.indexWhere((p) => p['id'] == pillId);
    if (index != -1) {
      pills[index]['startDate'] = startDate;
      pills[index]['endDate'] = endDate;
      pills[index]['times'] = times;
      pills[index]['dosage'] = dosage;
      await _prefs.setString(_pillsKey, jsonEncode(pills));
    }
  }

  static Future<void> removePill(String pillId) async {
    final pills = getPills();
    pills.removeWhere((p) => p['id'] == pillId);
    await _prefs.setString(_pillsKey, jsonEncode(pills));
  }

  static Future<void> removePillFromGroups(String pillId) async {
    final groups = getGroups();
    bool changed = false;
    final List<int> indicesToRemove = [];

    for (int i = 0; i < groups.length; i++) {
      if (groups[i]['pillIds'] is List) {
        final List pillIds = groups[i]['pillIds'];
        if (pillIds.contains(pillId)) {
          pillIds.remove(pillId);
          changed = true;
          if (pillIds.isEmpty) {
            indicesToRemove.add(i);
          }
        }
      }
    }

    if (indicesToRemove.isNotEmpty) {
      // 뒤에서부터 삭제해야 인덱스가 꼬이지 않음
      for (var i in indicesToRemove.reversed) {
        groups.removeAt(i);
      }
    }

    if (changed) {
      await _prefs.setString(_groupsKey, jsonEncode(groups));
    }
  }

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

  static Future<void> recordIntake(String pillId, String scheduledTime, {String? date}) async {
    final String targetDate = date ?? DateTime.now().toString().split(' ')[0];
    final String? jsonString = _prefs.getString(_historyKey);
    
    Map<String, dynamic> fullHistory = {};
    if (jsonString != null) {
      fullHistory = Map<String, dynamic>.from(jsonDecode(jsonString));
    }

    final List<dynamic> dayHistory = fullHistory[targetDate] ?? [];
    dayHistory.add({
      'pillId': pillId,
      'scheduledTime': scheduledTime,
      'takenAt': DateTime.now().toIso8601String(),
    });

    fullHistory[targetDate] = dayHistory;
    await _prefs.setString(_historyKey, jsonEncode(fullHistory));

    final pills = getPills();
    final index = pills.indexWhere((p) => p['id'] == pillId);
    if (index != -1) {
      final double dosage = (pills[index]['dosage'] ?? 1.0).toDouble();
      final double currentStock = (pills[index]['stock'] ?? 0).toDouble();
      pills[index]['stock'] = currentStock - dosage;
      await _prefs.setString(_pillsKey, jsonEncode(pills));
    }
  }

  static bool isLoggedIn() {
    final token = getSessionToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await _prefs.remove(_sessionKey);
  }

  static List<Map<String, dynamic>> getGroups() {
    final String? jsonString = _prefs.getString(_groupsKey);
    if (jsonString == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveGroup(Map<String, dynamic> group) async {
    final groups = getGroups();
    if (group['id'] == null) {
      group['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      groups.add(group);
    } else {
      final index = groups.indexWhere((g) => g['id'] == group['id']);
      if (index != -1) {
        groups[index] = group;
      } else {
        groups.add(group);
      }
    }
    await _prefs.setString(_groupsKey, jsonEncode(groups));
  }

  static Future<void> removeGroup(String groupId) async {
    final groups = getGroups();
    groups.removeWhere((g) => g['id'] == groupId);
    await _prefs.setString(_groupsKey, jsonEncode(groups));
  }

  static Future<void> recordGroupIntake(String groupId, String scheduledTime, {String? date}) async {
    final groups = getGroups();
    final group = groups.firstWhere((g) => g['id'] == groupId, orElse: () => {});
    if (group.isEmpty) return;

    final List<dynamic> pillIds = group['pillIds'] ?? [];
    for (final pillId in pillIds) {
      await recordIntake(pillId.toString(), scheduledTime, date: date);
    }

    final String targetDate = date ?? DateTime.now().toString().split(' ')[0];
    final String? jsonString = _prefs.getString(_historyKey);
    Map<String, dynamic> fullHistory = {};
    if (jsonString != null) {
      fullHistory = Map<String, dynamic>.from(jsonDecode(jsonString));
    }
    final List<dynamic> dayHistory = fullHistory[targetDate] ?? [];
    dayHistory.add({
      'groupId': groupId,
      'scheduledTime': scheduledTime,
      'takenAt': DateTime.now().toIso8601String(),
    });
    fullHistory[targetDate] = dayHistory;
    await _prefs.setString(_historyKey, jsonEncode(fullHistory));
  }
}
