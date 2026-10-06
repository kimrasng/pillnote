import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Alarmtime extends StatefulWidget {
  const Alarmtime({super.key});
  @override
  State<Alarmtime> createState() => _AlarmtimeState();
}

class _AlarmtimeState extends State<Alarmtime> {
  late double _minutes;
  late bool _enabled;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final settings = AppServices.instance.getSettings();
    _minutes = ((settings['reminderMinutes'] as num?)?.toDouble() ?? 30).clamp(
      0,
      120,
    );
    _enabled = settings['guardianAlertsEnabled'] != false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppServices.instance.saveSettings({
      ...AppServices.instance.getSettings(),
      'reminderMinutes': _minutes.round(),
      'guardianAlertsEnabled': _enabled,
    });
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('알림 설정을 저장했어요.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: PageScrollView(
      title: '놓친 복용 알림',
      subtitle: '조금 늦어도 괜찮은 시간을 정해요.',
      showBackButton: true,
      children: [
        SoftPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_minutes.round()}분',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '예정 시각에서 이만큼 지난 뒤에도 복용 기록이 없으면 연결된 보호자에게 알려요.',
                style: TextStyle(color: muted, height: 1.6),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [15, 30, 60]
                    .map(
                      (m) => ChoiceChip(
                        label: Text('$m분'),
                        selected: _minutes.round() == m,
                        onSelected: (_) =>
                            setState(() => _minutes = m.toDouble()),
                      ),
                    )
                    .toList(),
              ),
              Slider(
                value: _minutes,
                min: 0,
                max: 120,
                divisions: 24,
                label: '${_minutes.round()}분',
                onChanged: (v) => setState(() => _minutes = v),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('즉시', style: TextStyle(color: muted)),
                  Text('120분', style: TextStyle(color: muted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SwitchListTile.adaptive(
          activeTrackColor: blue,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '보호자에게 알림 보내기',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('초대를 수락한 보호자가 필요해요.'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 20),
        const Text(
          '앱이 열려 있거나 다시 열렸을 때 놓친 복용을 확인해요. 앱이 닫혀 있는 동안에는 자동으로 확인하지 않아요.',
          style: TextStyle(color: muted, height: 1.7),
        ),
      ],
    ),
    bottomNavigationBar: BottomAction(
      label: '알림 설정 저장',
      onPressed: _save,
      busy: _saving,
    ),
  );
}
