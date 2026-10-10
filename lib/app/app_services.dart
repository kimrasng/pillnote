import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/domain/dose_schedule.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/repositories/medication_repository.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/intake_service.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:pillnote/services/missed_dose_alert_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/services/snapshot_sync_service.dart';
import 'package:pillnote/services/startup_permission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Composition root: modules receive their dependencies instead of finding globals.
/// Screens use [instance]; tests can construct an isolated set of services.
class AppServices {
  AppServices({
    required MedicationStore store,
    required ApiClient api,
    required SessionStore sessions,
    DateTime Function()? now,
    DoseReminderGateway? reminderGateway,
    StartupPermissionGateway? permissionGateway,
  }) : _store = store,
       _sessions = sessions,
       _now = now ?? DateTime.now {
    reminders = DoseReminderService(
      store: store,
      gateway: reminderGateway ?? const UnsupportedDoseReminderGateway(),
      now: now,
    );
    permissions = StartupPermissionService(
      store: store,
      gateway: permissionGateway ?? const UnsupportedStartupPermissionGateway(),
    );
    sync = SnapshotSyncService(
      store: store,
      api: api,
      sessions: sessions,
      now: now,
      onSnapshotApplied: reminders.refresh,
    );
    medications = MedicationRepository(
      store: store,
      onChanged: _localDataChanged,
      now: now,
    );
    intakes = IntakeService(
      store: store,
      onChanged: _localDataChanged,
      now: now,
    );
    alerts = MissedDoseAlertService(
      store: store,
      api: api,
      sessions: sessions,
      now: now,
    );
  }

  static AppServices? _instance;
  static AppServices get instance =>
      _instance ??
      (throw StateError('AppServices.initialize() must run first.'));

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _instance?.dispose();
    final reminders = NativeDoseReminderGateway();
    _instance = AppServices(
      store: LocalMedicationStore(prefs),
      api: ApiClient.instance,
      sessions: SessionStore.instance,
      reminderGateway: reminders,
      permissionGateway: NativeStartupPermissionGateway(reminders),
    );
    await _instance!.sync.prepareCurrentAccount();
  }

  final MedicationStore _store;
  final SessionStore _sessions;
  final DateTime Function() _now;
  late final MedicationRepository medications;
  late final IntakeService intakes;
  late final SnapshotSyncService sync;
  late final MissedDoseAlertService alerts;
  late final DoseReminderService reminders;
  late final StartupPermissionService permissions;

  Future<void> _localDataChanged() async {
    sync.scheduleSync();
    await reminders.refresh();
  }

  bool get shouldShowOnboarding => !_store.onboardingCompleted;
  bool get isLoggedIn => _sessions.isLoggedIn;
  String get deviceId => _store.deviceId;

  Future<void> setOnboardingCompleted(bool completed) =>
      _store.setOnboardingCompleted(completed);

  Map<String, dynamic> getSettings() => _store.readSettings();

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _store.saveSettings({
      ...settings,
      'updatedAt': _now().toUtc().toIso8601String(),
    });
    sync.scheduleSync();
  }

  List<ScheduledDose> scheduledDoses(DateTime date) => DoseSchedule.forDate(
    date: date,
    pills: medications.getPills(),
    groups: medications.getGroups(),
  );

  DailyDosePlan dailyDosePlan(DateTime date) => DoseSchedule.dailyPlan(
    date: date,
    pills: medications.getPills(),
    groups: medications.getGroups(),
    history: intakes.getHistoryByDate(Medication.dateKey(date)),
  );

  Future<void> clearLocalData({String? userId}) async {
    final ownerId = userId ?? _sessions.session?.userId;
    await sync.invalidateAndWait();
    await _store.clear(userId: ownerId);
    await reminders.refresh();
  }

  void dispose() {
    permissions.dispose();
    reminders.dispose();
    sync.dispose();
  }
}
