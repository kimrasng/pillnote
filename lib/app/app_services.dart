import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/domain/dose_schedule.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/repositories/medication_repository.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/intake_service.dart';
import 'package:pillnote/services/missed_dose_alert_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/services/snapshot_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Composition root: modules receive their dependencies instead of finding globals.
/// Screens use [instance]; tests can construct an isolated set of services.
class AppServices {
  AppServices({
    required MedicationStore store,
    required ApiClient api,
    required SessionStore sessions,
    DateTime Function()? now,
  }) : _store = store,
       _sessions = sessions {
    sync = SnapshotSyncService(
      store: store,
      api: api,
      sessions: sessions,
      now: now,
    );
    medications = MedicationRepository(
      store: store,
      onChanged: sync.scheduleSync,
      now: now,
    );
    intakes = IntakeService(
      store: store,
      onChanged: sync.scheduleSync,
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
    _instance = AppServices(
      store: LocalMedicationStore(prefs),
      api: ApiClient.instance,
      sessions: SessionStore.instance,
    );
  }

  final MedicationStore _store;
  final SessionStore _sessions;
  late final MedicationRepository medications;
  late final IntakeService intakes;
  late final SnapshotSyncService sync;
  late final MissedDoseAlertService alerts;

  bool get shouldShowOnboarding => !_store.onboardingCompleted;
  bool get isLoggedIn => _sessions.isLoggedIn;
  String get deviceId => _store.deviceId;

  Future<void> setOnboardingCompleted(bool completed) =>
      _store.setOnboardingCompleted(completed);

  Map<String, dynamic> getSettings() => _store.readSettings();

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _store.saveSettings(settings);
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

  Future<void> clearLocalData() async {
    sync.cancelPendingSync();
    await _store.clear(userId: _sessions.session?.userId);
  }

  void dispose() => sync.dispose();
}
