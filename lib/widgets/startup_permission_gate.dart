import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pillnote/services/startup_permission_service.dart';
import 'package:pillnote/widgets/app_ui.dart';

class StartupPermissionGate extends StatefulWidget {
  const StartupPermissionGate({
    super.key,
    required this.service,
    required this.child,
    this.onCompleted,
  });

  final StartupPermissionService service;
  final Widget child;
  final VoidCallback? onCompleted;

  @override
  State<StartupPermissionGate> createState() => _StartupPermissionGateState();
}

class _StartupPermissionGateState extends State<StartupPermissionGate>
    with WidgetsBindingObserver {
  late bool _ready = !widget.service.needsRequest;
  bool _review = false;
  bool _continuing = false;
  bool _refreshOnIdle = false;
  bool get _busy => widget.service.isBusy || _continuing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _request());
    }
  }

  Future<void> _request() async {
    if (!mounted) return;
    await widget.service.requestOnFirstLaunch();
    _resolvePermissions();
  }

  Future<void> _retry() async {
    await widget.service.retryMissingPermissions();
    await _resolveAfterAction();
  }

  Future<void> _openSettings(StartupPermission permission) async {
    await widget.service.openPermissionSettings(permission);
    await _resolveAfterAction();
  }

  Future<void> _resolveAfterAction() async {
    if (mounted && !_ready && _refreshOnIdle) {
      _refreshOnIdle = false;
      await _refreshAfterResume();
    } else {
      _resolvePermissions();
    }
  }

  Future<void> _refreshAfterResume() async {
    await widget.service.refreshPermissions();
    _resolvePermissions();
  }

  void _resolvePermissions() {
    if (!mounted || _ready) return;
    if (widget.service.missingPermissions.isEmpty) {
      _showApp();
    } else {
      setState(() => _review = true);
    }
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _continuing = true);
    await widget.service.completeSetup();
    _showApp();
  }

  void _showApp() {
    if (!mounted || _ready) return;
    setState(() => _ready = true);
    widget.onCompleted?.call();
    if (widget.service.lastError case final String error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _review &&
        !_ready &&
        !_continuing) {
      if (widget.service.isBusy) {
        _refreshOnIdle = true;
      } else {
        unawaited(_refreshAfterResume());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => ListenableBuilder(
              listenable: widget.service,
              builder: (context, _) => ListView(
                padding: EdgeInsets.zero,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _review
                              ? _reviewContent()
                              : _requestContent(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _requestContent() => [
    const Icon(Icons.verified_user_outlined, size: 48, color: blue),
    const SizedBox(height: 24),
    const Text(
      '처음에 필요한 권한을 확인해요',
      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink),
    ),
    const SizedBox(height: 16),
    const Text('권한 요청 창이 차례로 표시돼요. 각 항목을 확인해주세요.'),
    const SizedBox(height: 24),
    const ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.notifications_none_rounded, color: blue),
      title: Text('알림'),
      subtitle: Text('복용 시간과 보호자 복약 알림을 받을 때 사용해요.'),
    ),
    const ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.location_on_outlined, color: blue),
      title: Text('위치'),
      subtitle: Text('앱을 사용하는 동안 주변 약국을 찾을 때 사용해요.'),
    ),
    if (widget.service.isAndroid)
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.alarm_rounded, color: blue),
        title: Text('알람 및 리마인더'),
        subtitle: Text('복용 알림을 정확한 시각에 보내기 위해 사용해요. 설정 화면에서 허용한 뒤 앱으로 돌아와주세요.'),
      ),
    const SizedBox(height: 24),
    const Text(
      '허용하지 않아도 기본 복약 관리는 사용할 수 있어요. 나중에 기기 설정에서 변경할 수 있어요.',
      style: TextStyle(color: muted),
    ),
    const SizedBox(height: 28),
    const Center(child: CircularProgressIndicator()),
    const SizedBox(height: 16),
    Text(widget.service.progressMessage, textAlign: TextAlign.center),
  ];

  List<Widget> _reviewContent() => [
    const Icon(Icons.info_outline_rounded, size: 48, color: blue),
    const SizedBox(height: 24),
    const Text(
      '권한을 한 번 더 확인해주세요',
      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink),
    ),
    const SizedBox(height: 16),
    const Text('아래 권한이 아직 허용되지 않았거나 확인되지 않았어요. 권한 없이도 기본 복약 관리는 이용할 수 있어요.'),
    const SizedBox(height: 24),
    for (final permission in widget.service.missingPermissions)
      _permissionNotice(permission),
    const SizedBox(height: 8),
    const Text(
      '각 항목의 설정 버튼으로 PillNote 설정을 바로 열 수 있어요. 위치는 열린 화면에서 권한 또는 위치 항목을 선택해주세요. 허용한 뒤 앱으로 돌아오면 자동으로 확인해요.',
      style: TextStyle(color: muted, height: 1.5),
    ),
    if (widget.service.lastError case final String error) ...[
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: muted, height: 1.5)),
    ],
    const SizedBox(height: 28),
    FilledButton(
      onPressed: _busy ? null : _retry,
      child: _busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('다시 권한 허용하기'),
    ),
    const SizedBox(height: 8),
    TextButton(
      onPressed: _busy ? null : _continue,
      child: const Text('그냥 이용하기'),
    ),
  ];

  Widget _permissionNotice(StartupPermission permission) {
    final (title, description, icon) = switch (permission) {
      StartupPermission.notifications => (
        '알림',
        '복용 시간 알림과 보호자 복약 알림을 이 기기에서 받을 수 없어요.',
        Icons.notifications_off_outlined,
      ),
      StartupPermission.location => (
        '위치',
        '현재 위치를 기준으로 주변 약국을 찾을 수 없어요. 지역을 직접 선택하면 약국을 볼 수 있어요.',
        Icons.location_off_outlined,
      ),
      StartupPermission.exactAlarms => (
        '알람 및 리마인더',
        '복용 알림이 정해진 시각보다 늦게 도착할 수 있어요.',
        Icons.alarm_off_outlined,
      ),
    };
    final status = widget.service.statusOf(permission);
    final settingsLabel = switch (permission) {
      StartupPermission.notifications => '알림 설정 열기',
      StartupPermission.location => '위치 설정 열기',
      StartupPermission.exactAlarms => '알람 및 리마인더 설정 열기',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$title · ${status == StartupPermissionStatus.denied ? '미허용' : '확인 필요'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status == StartupPermissionStatus.unknown
                        ? '권한 상태를 확인하지 못했어요. 이 권한이 없으면 $description'
                        : description,
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => _openSettings(permission),
                    child: Text(settingsLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
