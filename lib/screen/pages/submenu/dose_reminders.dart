import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:pillnote/widgets/app_ui.dart';

class DoseReminders extends StatefulWidget {
  const DoseReminders({super.key, this.service});
  final DoseReminderService? service;

  @override
  State<DoseReminders> createState() => _DoseRemindersState();
}

class _DoseRemindersState extends State<DoseReminders> {
  DoseReminderService get _service =>
      widget.service ?? AppServices.instance.reminders;

  @override
  void initState() {
    super.initState();
    unawaited(_service.refresh());
  }

  String _stamp(DateTime date) =>
      '${date.year}년 ${date.month}월 ${date.day}일 '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _service,
    builder: (context, _) {
      final reminders = _service;
      return Scaffold(
        body: PageScrollView(
          title: '내 복용 시간 알림',
          compactHeading: true,
          subtitle: '약 먹을 시간, 휴대폰이 알려드려요.',
          showBackButton: true,
          children: [
            const Text(
              '약이나 묶음에 저장한 복용 시간에 이 기기로 알려드려요. '
              '로그인이나 인터넷 연결 없이, 앱을 열지 않아도 예약된 알림을 받을 수 있어요.',
              style: TextStyle(color: muted, height: 1.6),
            ),
            const SizedBox(height: 20),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: blue,
              title: const Text('복용 시간에 알림 받기'),
              subtitle: const Text('이 기기에서 사용할 알림 설정이에요.'),
              value: reminders.isEnabled,
              onChanged: reminders.isBusy || !reminders.isSupported
                  ? null
                  : (value) => reminders.setEnabled(value),
            ),
            const SizedBox(height: 20),
            SoftPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminders.statusMessage,
                    style: TextStyle(
                      color: reminders.lastError == null
                          ? blue
                          : Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                  if (reminders.nextScheduledAt != null) ...[
                    const SizedBox(height: 12),
                    Text('다음 알림 · ${_stamp(reminders.nextScheduledAt!)}'),
                    const SizedBox(height: 8),
                    Text(
                      '예약된 마지막 알림 · ${_stamp(reminders.lastScheduledAt!)}',
                      style: const TextStyle(color: muted, height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '앱을 열면 이후 일정을 자동으로 이어서 예약해요. '
                      '예약된 마지막 날짜 전에 앱을 한 번 열어주세요.',
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                  ],
                  if (reminders.isBusy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            if (reminders.isEnabled &&
                reminders.isAndroid &&
                reminders.exactPermissionGranted == false) ...[
              const SizedBox(height: 20),
              const Text(
                '정해진 시각에 받으려면 알람 및 리마인더 권한을 허용해주세요. '
                '허용하지 않으면 절전 상태에서 알림이 늦게 올 수 있어요.',
                style: TextStyle(color: muted, height: 1.6),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: reminders.isBusy
                    ? null
                    : reminders.requestExactPermission,
                icon: const Icon(Icons.alarm_outlined),
                label: const Text('정확한 시간 알림 허용'),
              ),
            ],
            if (reminders.isSupported) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: reminders.isBusy ? null : reminders.refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('알림 상태 확인'),
                  ),
                  TextButton(
                    onPressed: reminders.isBusy ? null : reminders.openSettings,
                    child: const Text('기기 알림 설정'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              '같은 시간의 약은 한 번에 알려드려요. 복용을 미리 기록한 일정은 건너뛰고, '
              '시간 변경이나 약 보관·삭제도 반영해요. '
              '보호자에게 보내는 놓친 복용 알림은 별도로 설정할 수 있어요.',
              style: TextStyle(color: muted, height: 1.6),
            ),
          ],
        ),
      );
    },
  );
}
