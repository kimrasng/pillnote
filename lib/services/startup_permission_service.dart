import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pillnote/data/medication_store.dart';
import 'package:pillnote/services/dose_reminder_service.dart';

enum StartupPermission { notifications, location, exactAlarms }

enum StartupPermissionStatus { granted, denied, unknown }

abstract interface class StartupPermissionGateway {
  bool get isSupported;
  bool get isAndroid;
  Future<void> request(StartupPermission permission);
  Future<bool> isGranted(StartupPermission permission);
  Future<bool> openSettings(List<StartupPermission> permissions);
}

class NativeStartupPermissionGateway implements StartupPermissionGateway {
  NativeStartupPermissionGateway(this._notifications);
  final DoseReminderGateway _notifications;

  @override
  bool get isSupported => _notifications.isSupported;
  @override
  bool get isAndroid => _notifications.isAndroid;

  @override
  Future<void> request(StartupPermission permission) async {
    switch (permission) {
      case StartupPermission.notifications:
        await _notifications.initialize();
        if (!await _notifications.permission()) {
          await _notifications.permission(request: true);
        }
      case StartupPermission.location:
        final current = await Geolocator.checkPermission();
        if (current == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
      case StartupPermission.exactAlarms:
        await _notifications.initialize();
        if (isAndroid && !await _notifications.exactPermission()) {
          // Android opens its app-specific settings page and completes on return.
          await _notifications.exactPermission(request: true);
        }
    }
  }

  @override
  Future<bool> isGranted(StartupPermission permission) async {
    switch (permission) {
      case StartupPermission.notifications:
        await _notifications.initialize();
        return _notifications.permission();
      case StartupPermission.location:
        final current = await Geolocator.checkPermission();
        return current == LocationPermission.whileInUse ||
            current == LocationPermission.always;
      case StartupPermission.exactAlarms:
        await _notifications.initialize();
        return _notifications.exactPermission();
    }
  }

  @override
  Future<bool> openSettings(List<StartupPermission> permissions) async {
    if (permissions.isEmpty) return false;
    if (permissions.length == 1 &&
        permissions.single == StartupPermission.notifications) {
      await _notifications.initialize();
      if (await _notifications.openSettings()) return true;
    } else if (permissions.length == 1 &&
        permissions.single == StartupPermission.exactAlarms &&
        isAndroid) {
      await _notifications.initialize();
      await _notifications.exactPermission(request: true);
      return true;
    }
    // Location and multiple missing permissions use this app's own settings
    // page. Neither platform offers a public location-permission deep link.
    return Geolocator.openAppSettings();
  }
}

class UnsupportedStartupPermissionGateway implements StartupPermissionGateway {
  const UnsupportedStartupPermissionGateway();
  @override
  bool get isSupported => false;
  @override
  bool get isAndroid => false;
  @override
  Future<void> request(StartupPermission permission) async {}
  @override
  Future<bool> isGranted(StartupPermission permission) async => false;
  @override
  Future<bool> openSettings(List<StartupPermission> permissions) async => false;
}

/// Installation-level setup; users can retry refusals or explicitly continue.
class StartupPermissionService extends ChangeNotifier {
  StartupPermissionService({required this._store, required this._gateway});

  final MedicationStore _store;
  final StartupPermissionGateway _gateway;
  Future<void>? _requesting;
  bool _attempted = false;
  bool _disposed = false;
  final _statuses = <StartupPermission, StartupPermissionStatus>{};
  StartupPermission? currentPermission;
  String? lastError;
  bool isBusy = false;
  bool get isAndroid => _gateway.isAndroid;
  bool get needsRequest =>
      _gateway.isSupported && !_store.startupPermissionsRequested;
  List<StartupPermission> get _permissions => [
    StartupPermission.notifications,
    StartupPermission.location,
    if (isAndroid) StartupPermission.exactAlarms,
  ];
  StartupPermissionStatus statusOf(StartupPermission permission) =>
      _statuses[permission] ?? StartupPermissionStatus.unknown;
  List<StartupPermission> get missingPermissions => _permissions
      .where(
        (permission) => statusOf(permission) != StartupPermissionStatus.granted,
      )
      .toList();

  String get progressMessage => switch (currentPermission) {
    StartupPermission.notifications => '알림 권한을 확인하고 있어요.',
    StartupPermission.location => '위치 권한을 확인하고 있어요.',
    StartupPermission.exactAlarms => '정확한 알람 권한을 확인하고 있어요.',
    null => '필요한 권한을 확인하고 있어요.',
  };

  Future<void> requestOnFirstLaunch() {
    if (_requesting != null) return _requesting!;
    if (!needsRequest || _attempted || _disposed) return Future.value();
    return _run(_requestAll);
  }

  Future<void> _requestAll() async {
    _attempted = true;
    for (final permission in _permissions) {
      if (_disposed) return;
      await _requestAndCheck(permission);
    }
    if (!_disposed && missingPermissions.isEmpty) await completeSetup();
  }

  Future<void> retryMissingPermissions() => _run(() async {
    await _checkAll();
    for (final permission in missingPermissions) {
      if (_disposed) return;
      await _requestAndCheck(permission);
    }
    if (_disposed) return;
    if (missingPermissions.isEmpty) {
      await completeSetup();
    } else if (missingPermissions.any(
      (permission) => permission != StartupPermission.exactAlarms,
    )) {
      await _openSettings(
        missingPermissions
            .where((permission) => permission != StartupPermission.exactAlarms)
            .toList(),
      );
    }
  });

  Future<void> openPermissionSettings(StartupPermission permission) =>
      _run(() => _openSettings([permission]));

  Future<void> _openSettings(List<StartupPermission> permissions) async {
    var settingsUnavailable = false;
    try {
      settingsUnavailable = !await _gateway.openSettings(permissions);
    } catch (error) {
      settingsUnavailable = true;
      debugPrint('권한 설정 열기 실패: $error');
    }
    // Some platforms deliver this result only after returning to the app.
    await _checkAll();
    if (settingsUnavailable) {
      lastError = '기기 설정을 열지 못했어요. 휴대폰 설정에서 PillNote 권한을 변경해주세요.';
    }
    if (!_disposed && missingPermissions.isEmpty) await completeSetup();
  }

  /// Read settings changes on app return without showing another permission UI.
  Future<void> refreshPermissions() => _run(() async {
    await _checkAll();
    if (!_disposed && missingPermissions.isEmpty) await completeSetup();
  });

  Future<void> _requestAndCheck(StartupPermission permission) async {
    currentPermission = permission;
    notifyListeners();
    try {
      // Await each OS dialog before requesting another permission.
      await _gateway.request(permission);
    } catch (error, stackTrace) {
      _reportFailure(permission, error, stackTrace);
    }
    if (!_disposed) await _check(permission);
  }

  Future<void> _checkAll() async {
    for (final permission in _permissions) {
      if (_disposed) return;
      await _check(permission);
    }
  }

  Future<void> _check(StartupPermission permission) async {
    try {
      _statuses[permission] = await _gateway.isGranted(permission)
          ? StartupPermissionStatus.granted
          : StartupPermissionStatus.denied;
    } catch (error, stackTrace) {
      _statuses[permission] = StartupPermissionStatus.unknown;
      _reportFailure(permission, error, stackTrace);
    }
  }

  void _reportFailure(
    StartupPermission permission,
    Object error,
    StackTrace stackTrace,
  ) {
    lastError = '일부 권한을 확인하지 못했어요. 다시 확인하거나 그대로 이용할 수 있어요.';
    debugPrint('권한 확인 실패 ($permission): $error');
    if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
  }

  Future<void> _run(Future<void> Function() operation) {
    if (_requesting != null) return _requesting!;
    if (!_gateway.isSupported || _disposed) return Future.value();
    isBusy = true;
    lastError = null;
    notifyListeners();
    return _requesting = Future<void>.sync(operation).whenComplete(() {
      _requesting = null;
      currentPermission = null;
      isBusy = false;
      if (!_disposed) notifyListeners();
    });
  }

  /// Persist only after all grants, or after the user chooses to continue.
  Future<void> completeSetup() async {
    if (_disposed) return;
    try {
      await _store.setStartupPermissionsRequested();
    } catch (error) {
      lastError = '권한 안내 완료 상태를 저장하지 못했어요. 다음 실행에 다시 안내할 수 있어요.';
      debugPrint('첫 실행 권한 요청 상태 저장 실패: $error');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
