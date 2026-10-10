import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/domain/dose_reminder_plan.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class PendingDoseReminder {
  const PendingDoseReminder(this.id, this.payload);
  final int id;
  final String? payload;
  bool get isDoseReminder =>
      payload?.startsWith(DoseReminder.payloadPrefix) == true;
}

abstract interface class DoseReminderGateway {
  bool get isSupported;
  bool get isAndroid;
  int get pendingLimit;
  Future<void> initialize();
  Future<tz.Location> location();
  Future<bool> permission({bool request = false});
  Future<bool> exactPermission({bool request = false});
  Future<List<PendingDoseReminder>> pending();
  Future<void> schedule(DoseReminder reminder, {required bool exact});
  Future<void> cancel(int id);
  Future<bool> openSettings();
}

class NativeDoseReminderGateway implements DoseReminderGateway {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  @override
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  @override
  int get pendingLimit => isAndroid ? 400 : 60;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final ready = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_dose_reminder'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    // iOS returns the permission request result, including false when all
    // requests are disabled. Initialization itself still completes normally.
    // Permission is checked/requested separately before enabling reminders.
    if (ready == null || (isAndroid && ready != true)) {
      throw StateError('Local notifications initialization failed');
    }
    _initialized = true;
  }

  @override
  Future<tz.Location> location() async =>
      tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier);

  @override
  Future<bool> permission({bool request = false}) async {
    if (isAndroid) {
      if (request) await _android!.requestNotificationsPermission();
      return await _android!.areNotificationsEnabled() ?? false;
    }
    if (request) {
      await _ios!.requestPermissions(alert: true, badge: true, sound: true);
    }
    final settings = await _ios!.checkPermissions();
    return settings?.isEnabled == true ||
        settings?.isProvisionalEnabled == true;
  }

  @override
  Future<bool> exactPermission({bool request = false}) async {
    if (!isAndroid) return true;
    if (request) await _android!.requestExactAlarmsPermission();
    return await _android!.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<List<PendingDoseReminder>> pending() async => [
    for (final item in await _plugin.pendingNotificationRequests())
      PendingDoseReminder(item.id, item.payload),
  ];

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> schedule(DoseReminder reminder, {required bool exact}) =>
      _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: reminder.at,
        payload: reminder.payload(exact: exact),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'pillnote_dose_reminders',
            '복용 시간 알림',
            channelDescription: '저장한 복용 일정에 맞춰 알려드려요.',
            icon: 'ic_dose_reminder',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
            threadIdentifier: 'pillnote-dose-reminders',
          ),
        ),
      );

  @override
  Future<bool> openSettings() async {
    if (isAndroid) {
      return await _android!.openAppNotificationSettings() ?? false;
    } else {
      return await _ios!.openAppNotificationSettings() ?? false;
    }
  }
}

/// Isolated AppServices instances can run without native plugins.
class UnsupportedDoseReminderGateway implements DoseReminderGateway {
  const UnsupportedDoseReminderGateway();
  @override
  bool get isSupported => false;
  @override
  bool get isAndroid => false;
  @override
  int get pendingLimit => 0;
  @override
  Future<void> initialize() async {}
  @override
  Future<tz.Location> location() async => tz.UTC;
  @override
  Future<bool> permission({bool request = false}) async => false;
  @override
  Future<bool> exactPermission({bool request = false}) async => false;
  @override
  Future<List<PendingDoseReminder>> pending() async => [];
  @override
  Future<void> schedule(DoseReminder reminder, {required bool exact}) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<bool> openSettings() async => false;
}

/// Reconciles only our own alarms with persisted local data, without a session.
class DoseReminderService extends ChangeNotifier {
  DoseReminderService({
    required this._store,
    required this._gateway,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MedicationStore _store;
  final DoseReminderGateway _gateway;
  final DateTime Function() _now;
  Future<void> _operations = Future.value();
  bool _disposed = false;
  bool isBusy = false;
  bool? permissionGranted;
  bool? exactPermissionGranted;
  int pendingCount = 0;
  DateTime? nextScheduledAt;
  DateTime? lastScheduledAt;
  String? lastError;
  bool get isSupported => _gateway.isSupported;
  bool get isAndroid => _gateway.isAndroid;
  bool get isEnabled => _store.doseRemindersEnabled;
  int get pendingLimit => _gateway.pendingLimit;

  String get statusMessage {
    if (!isSupported) return '복용 시간 알림은 iPhone과 Android에서 사용할 수 있어요.';
    if (lastError != null) return lastError!;
    if (!isEnabled) return '알림을 켜면 앱을 열지 않아도 복용 시간을 알려드려요.';
    if (permissionGranted == false) return '기기 설정에서 PillNote 알림을 허용해주세요.';
    if (pendingCount == 0) return '예정된 알림이 없어요. 약이나 묶음에 복용 시간을 저장해주세요.';
    return '복용 시간 알림 $pendingCount건이 예약되어 있어요.';
  }

  Future<void> refresh() => isSupported ? _enqueue(_refresh) : Future.value();

  Future<void> setEnabled(bool enabled) => _enqueue(() async {
    if (!isSupported) return;
    await _gateway.initialize();
    if (enabled && !await _gateway.permission(request: true)) {
      permissionGranted = false;
      lastError = '알림 권한이 꺼져 있어요. 기기 설정에서 PillNote 알림을 허용해주세요.';
      return;
    }
    await _store.setDoseRemindersEnabled(enabled);
    if (enabled && isAndroid) {
      await _gateway.exactPermission(request: true);
    }
    await _refresh();
  });

  Future<void> requestExactPermission() => _enqueue(() async {
    if (!isSupported || !isAndroid) return;
    await _gateway.initialize();
    await _gateway.exactPermission(request: true);
    await _refresh();
  });

  Future<void> openSettings() => _enqueue(() async {
    if (!isSupported) return;
    await _gateway.initialize();
    await _gateway.openSettings();
  });

  Future<void> _refresh() async {
    if (!isSupported || _disposed) return;
    await _gateway.initialize();
    permissionGranted = await _gateway.permission();
    exactPermissionGranted = await _gateway.exactPermission();
    final pending = (await _gateway.pending())
        .where((item) => item.isDoseReminder)
        .toList();
    final plan = isEnabled && permissionGranted == true
        ? DoseReminderPlan.build(
            now: _now(),
            location: await _gateway.location(),
            pills: _store.readPills(),
            groups: _store.readGroups(),
            history: _store.readHistory(),
            limit: pendingLimit,
          )
        : <DoseReminder>[];
    final desired = {for (final reminder in plan) reminder.id: reminder};
    final existing = {for (final item in pending) item.id: item.payload};
    // Remove obsolete reservations first, preserving FCM and unrelated alerts.
    for (final item in pending) {
      if (_disposed) return;
      if (!desired.containsKey(item.id)) await _gateway.cancel(item.id);
    }
    for (final reminder in plan) {
      if (_disposed) return;
      if (existing[reminder.id] !=
          reminder.payload(exact: exactPermissionGranted == true)) {
        await _gateway.schedule(
          reminder,
          exact: exactPermissionGranted == true,
        );
      }
    }
    if (_disposed) return;
    // Read back reservations rather than equating successful calls with readiness.
    final confirmed = {
      for (final item in await _gateway.pending())
        if (item.isDoseReminder) item.id: item.payload,
    };
    final reserved = plan
        .where(
          (item) =>
              confirmed[item.id] ==
              item.payload(exact: exactPermissionGranted == true),
        )
        .toList();
    pendingCount = reserved.length;
    nextScheduledAt = reserved.firstOrNull?.at;
    lastScheduledAt = reserved.lastOrNull?.at;
    lastError = reserved.length == plan.length
        ? null
        : '일부 복용 알림을 예약하지 못했어요. 다시 시도해주세요.';
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    if (_disposed) return Future.value();
    final pending = _operations.then((_) async {
      if (_disposed) return;
      isBusy = true;
      notifyListeners();
      try {
        await operation();
      } catch (error, stackTrace) {
        lastError = '복용 알림 예약을 완료하지 못했어요. 알림 상태를 다시 확인해주세요.';
        debugPrint('복용 시간 알림 예약 실패: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      } finally {
        isBusy = false;
        if (!_disposed) notifyListeners();
      }
    });
    _operations = pending;
    return pending;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
