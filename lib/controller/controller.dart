import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/pill.dart';

class Controller {
  late SharedPreferences _prefs;

  List<Pill> _pills = [];
  List<UserPill> _userPills = [];
  List<PillTakeLog> _pillTakeLogs = [];

  List<Pill> get pills => _pills;
  List<UserPill> get userPills => _userPills;
  List<PillTakeLog> get pillTakeLogs => _pillTakeLogs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPills();
  }

  void _loadPills() {
    final pillsJson = _prefs.getString('pills');
    if (pillsJson != null) {
      final List<dynamic> pillsData = jsonDecode(pillsJson);
      _pills = pillsData.map((data) => Pill.fromJson(data)).toList();
    }
  }

  Future<void> _savePills() async {
    final pillsData = _pills.map((pill) => pill.toJson()).toList();
    await _prefs.setString('pills', jsonEncode(pillsData));
  }

  Future<void> addPill(Pill pill) async {
    _pills.add(pill);
    await _savePills();
  }

  Future<void> updatePill(Pill pill) async {
    final index = _pills.indexWhere((p) => p.id == pill.id);
    if (index != -1) {
      _pills[index] = pill;
      await _savePills();
    }
  }

  Future<void> deletePill(int pillId) async {
    _pills.removeWhere((p) => p.id == pillId);
    await _savePills();
  }

  Pill? getPillById(int id) {
    try {
      return _pills.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  UserPill.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        pillId = json['pillId'],
        startDate = DateTime.parse(json['startDate']),
        endDate = json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
        dosePerTake = json['dosePerTake'],
        timesPerDay = json['timesPerDay'],
        alarmTimes = (json['alarmTimes'] as List)
            .map((timeStr) => TimeOfDay(
                hour: int.parse(timeStr.split(':')[0]),
                minute: int.parse(timeStr.split(':')[1])))
            .toList(),
        isActive = json['isActive'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'pillId': pillId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'dosePerTake': dosePerTake,
        'timesPerDay': timesPerDay,
        'alarmTimes': alarmTimes.map((time) => '${time.hour}:${time.minute}').toList(),
        'isActive': isActive,
      };
}
