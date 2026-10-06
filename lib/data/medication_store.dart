/// Persistence boundary for local medication data and account sync metadata.
/// Groups and history include deletion/cancellation markers for synchronization.
abstract interface class MedicationStore {
  String get deviceId;
  bool get onboardingCompleted;
  Future<void> setOnboardingCompleted(bool completed);

  List<Map<String, dynamic>> readPills();
  List<Map<String, dynamic>> readGroups();
  Map<String, dynamic> readHistory();
  Map<String, dynamic> readSettings();

  Future<void> savePills(List<Map<String, dynamic>> pills);
  Future<void> saveGroups(List<Map<String, dynamic>> groups);
  Future<void> saveHistory(Map<String, dynamic> history);
  Future<void> saveSettings(Map<String, dynamic> settings);

  int? readSyncRevision(String userId);
  Future<void> saveSyncRevision(String userId, int revision);
  DateTime? readLastSyncedAt(String? userId);
  Future<void> saveLastSyncedAt(String? userId, DateTime at);
  Future<void> clearLastSyncedAt(String? userId);
  Future<void> clear({String? userId});
}
