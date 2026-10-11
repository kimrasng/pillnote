import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:pillnote/widgets/app_ui.dart';

/// One device-wide setting, shown where a medication's schedule is configured.
class MedicationReminderStatus extends StatefulWidget {
  const MedicationReminderStatus({super.key, this.pillId, this.service});
  final String? pillId;
  final DoseReminderService? service;

  @override
  State<MedicationReminderStatus> createState() =>
      _MedicationReminderStatusState();
}

class _MedicationReminderStatusState extends State<MedicationReminderStatus>
    with WidgetsBindingObserver {
  DoseReminderService get _service =>
      widget.service ?? AppServices.instance.reminders;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_service.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_service.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _enable() async {
    setState(() => _requested = true);
    await _service.setEnabled(true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _service,
    builder: (context, _) {
      final service = _service;
      final saved = widget.pillId != null;
      final next = widget.pillId == null
          ? null
          : service.nextScheduledForPill(widget.pillId!);
      final String title;
      final String description;
      if (!service.isSupported) {
        title = '이 기기에서는 복용 알림을 사용할 수 없어요';
        description =
            '복용 일정은 ${saved ? '저장됐어요' : '저장할 수 있어요'}. '
            'iPhone이나 Android에서 알림을 이용해주세요.';
      } else if (service.isBusy) {
        title = '알림 상태를 확인하고 있어요';
        description = '기기에 예약된 알림을 확인해요.';
      } else if (!service.isEnabled) {
        title = '복용 알림이 꺼져 있어요';
        description =
            '약과 일정은 ${saved ? '저장됐어요' : '저장할 수 있어요'}. '
            '알림을 켜면 복용 시간에 알려드려요.';
      } else if (service.permissionGranted == false) {
        title = '알림 권한이 필요해요';
        description =
            '약과 일정은 ${saved ? '저장됐어요' : '저장할 수 있어요'}. '
            '복용 알림을 받으려면 기기에서 알림을 허용해주세요.';
      } else if (service.lastError != null) {
        title = '알림 예약을 확인해주세요';
        description = service.lastError!;
      } else if (service.permissionGranted != true) {
        title = '알림 상태를 확인해주세요';
        description = '알림 상태를 다시 확인한 뒤 예약 결과를 안내해요.';
      } else if (widget.pillId == null) {
        title = '복용 시간에 알림을 받아요';
        description = '복용 시간을 저장하면 이 기기에 알림이 자동으로 예약돼요.';
      } else if (next != null) {
        title = '이 약의 알림이 예약됐어요';
        description =
            '다음 알림 · ${next.month}월 ${next.day}일 '
            '${next.hour.toString().padLeft(2, '0')}:'
            '${next.minute.toString().padLeft(2, '0')}';
      } else {
        title = '이 약의 예정된 알림이 없어요';
        description =
            '복용 기간이 끝났거나 아직 예약할 수 있는 기간 밖이에요. '
            '일정은 저장됐으며 앱을 열면 이후 알림을 다시 확인해요.';
      }
      return SoftPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: muted, height: 1.5),
            ),
            if (service.isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (service.isSupported) ...[
              const SizedBox(height: 12),
              const Text(
                '알림 설정은 이 기기의 모든 복용 일정에 적용돼요.',
                style: TextStyle(color: muted, fontSize: 13, height: 1.5),
              ),
              if (!service.isEnabled || service.permissionGranted == false)
                TextButton.icon(
                  onPressed: service.isBusy
                      ? null
                      : _requested && service.permissionGranted == false
                      ? service.openSettings
                      : _enable,
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text(
                    _requested && service.permissionGranted == false
                        ? '기기 알림 설정'
                        : service.permissionGranted == false
                        ? '알림 허용하기'
                        : '복용 알림 켜기',
                  ),
                )
              else if (service.lastError != null ||
                  service.permissionGranted != true)
                TextButton.icon(
                  onPressed: service.isBusy ? null : service.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('알림 다시 확인'),
                ),
              if (service.isEnabled &&
                  service.isAndroid &&
                  service.exactPermissionGranted == false) ...[
                const SizedBox(height: 8),
                const Text(
                  '정확한 시간 알림 권한이 없어 알림이 늦게 올 수 있어요.',
                  style: TextStyle(color: muted, height: 1.5),
                ),
                TextButton(
                  onPressed: service.isBusy
                      ? null
                      : service.requestExactPermission,
                  child: const Text('정확한 시간 알림 허용'),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}
