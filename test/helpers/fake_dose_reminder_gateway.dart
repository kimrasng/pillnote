import 'dart:async';

import 'package:pillnote/domain/dose_reminder_plan.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeDoseReminderGateway implements DoseReminderGateway {
  FakeDoseReminderGateway(this.zone);
  tz.Location zone;
  bool granted = true;
  bool exact = true;
  bool android = false;
  bool dropSchedules = false;
  bool failSchedules = false;
  int schedules = 0;
  int permissionRequests = 0;
  int exactRequests = 0;
  int settingsOpened = 0;
  bool canOpenSettings = true;
  Completer<void>? scheduleStarted;
  Completer<void>? finishSchedule;
  final items = <int, PendingDoseReminder>{};
  final reminders = <int, DoseReminder>{};
  final cancelled = <int>[];
  @override
  bool get isSupported => true;
  @override
  bool get isAndroid => android;
  @override
  int pendingLimit = 60;
  @override
  Future<void> initialize() async {}
  @override
  Future<tz.Location> location() async => zone;
  @override
  Future<bool> permission({bool request = false}) async {
    if (request) permissionRequests++;
    return granted;
  }

  @override
  Future<bool> exactPermission({bool request = false}) async {
    if (request) exactRequests++;
    return exact;
  }

  @override
  Future<List<PendingDoseReminder>> pending() async => items.values.toList();
  @override
  Future<void> schedule(DoseReminder reminder, {required bool exact}) async {
    schedules++;
    if (scheduleStarted?.isCompleted == false) scheduleStarted!.complete();
    await finishSchedule?.future;
    if (failSchedules) throw StateError('provider unavailable');
    if (!dropSchedules) {
      reminders[reminder.id] = reminder;
      items[reminder.id] = PendingDoseReminder(
        reminder.id,
        reminder.payload(exact: exact),
      );
    }
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    items.remove(id);
    reminders.remove(id);
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return canOpenSettings;
  }
}
