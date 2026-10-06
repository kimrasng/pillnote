import 'package:flutter/foundation.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/domain/dose_schedule.dart';
import 'package:pillnote/domain/snapshot_merger.dart';
import 'package:pillnote/models/medication.dart';

/// Compatibility facade for existing consumers. New code uses the focused
/// repositories and services composed by [AppServices].
class Controller {
  Controller._();

  static AppServices get _app => AppServices.instance;

  static Future<void> init() => AppServices.initialize();

  static Future<void> setOnboardingCompleted(bool completed) =>
      _app.setOnboardingCompleted(completed);
  static bool shouldShowOnboarding() => _app.shouldShowOnboarding;
  static bool isLoggedIn() => _app.isLoggedIn;
  static String get deviceId => _app.deviceId;

  static List<Map<String, dynamic>> getPills() => _app.medications.getPills();
  static List<Map<String, dynamic>> getGroups() => _app.medications.getGroups();
  static Map<String, dynamic> getFullHistory() => _app.intakes.getFullHistory();
  static List<Map<String, dynamic>> getHistoryByDate(String date) =>
      _app.intakes.getHistoryByDate(date);
  static Map<String, dynamic> getSettings() => _app.getSettings();
  static Future<void> saveSettings(Map<String, dynamic> settings) =>
      _app.saveSettings(settings);

  static Future<void> addPill(Map<String, dynamic> pill, num? stock) =>
      _app.medications.addPill(pill, stock);
  static Future<void> updatePill(String id, Map<String, dynamic> changes) =>
      _app.medications.updatePill(id, changes);
  static Future<void> archivePill(String id, bool archived) =>
      _app.medications.archivePill(id, archived);
  static Future<void> updatePillSchedule(
    String pillId,
    String? startDate,
    String? endDate,
    List<String> times,
    double dosage,
  ) => _app.medications.updatePillSchedule(
    pillId,
    startDate,
    endDate,
    times,
    dosage,
  );
  static Future<void> removePill(String pillId) =>
      _app.medications.removePill(pillId);
  static Future<void> removePillFromGroups(String pillId) =>
      _app.medications.removePillFromGroups(pillId);
  static Future<void> saveGroup(Map<String, dynamic> group) =>
      _app.medications.saveGroup(group);
  static Future<void> removeGroup(String groupId) =>
      _app.medications.removeGroup(groupId);

  static List<ScheduledDose> scheduledDoses(DateTime date) =>
      _app.scheduledDoses(date);
  static DailyDosePlan dailyDosePlan(DateTime date) => _app.dailyDosePlan(date);
  static Future<void> recordIntake(
    String pillId,
    String scheduledTime, {
    String? date,
  }) => _app.intakes.recordIntake(pillId, scheduledTime, date: date);
  static Future<void> undoIntake(String pillId, String time, {String? date}) =>
      _app.intakes.undoIntake(pillId, time, date: date);
  static Future<void> recordGroupIntake(
    String groupId,
    String scheduledTime, {
    String? date,
  }) => _app.intakes.recordGroupIntake(groupId, scheduledTime, date: date);

  static Map<String, dynamic> buildSnapshot() => _app.sync.buildSnapshot();
  static Future<int?> reconcileWithServer() => _app.sync.reconcileWithServer();
  static Future<int?> syncToServer() => _app.sync.syncToServer();
  static Future<void> deleteCloudBackup() => _app.sync.deleteCloudBackup();
  static DateTime? get lastSyncedAt => _app.sync.lastSyncedAt;
  static Future<void> checkAndSendMissedDoseAlerts({DateTime? at}) =>
      _app.alerts.checkAndSend(at: at);
  static Future<void> clearLocalData() => _app.clearLocalData();

  @visibleForTesting
  static Map<String, dynamic> mergeSnapshots(
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) => SnapshotMerger.merge(remote, local);
}
