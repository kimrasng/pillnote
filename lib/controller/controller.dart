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
    _loadUserPills();
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

  void _loadUserPills() {
    final userPillsJson = _prefs.getString('userPills');
    if (userPillsJson != null) {
      final List<dynamic> userPillsData = jsonDecode(userPillsJson);
      _userPills = userPillsData.map((data) => UserPill.fromJson(data)).toList();
    }
  }

  Future<void> _saveUserPills() async {
    final userPillsData = _userPills.map((userPill) => userPill.toJson()).toList();
    await _prefs.setString('userPills', jsonEncode(userPillsData));
  }

  Future<void> addUserPill(UserPill userPill) async {
    _userPills.add(userPill);
    await _saveUserPills();
  }
}
