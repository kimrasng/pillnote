import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';

class Alarmtime extends StatefulWidget {
  const Alarmtime({super.key});

  @override
  State<Alarmtime> createState() => _AlarmtimeState();
}

class _AlarmtimeState extends State<Alarmtime> {
  late double _reminderMinutes;
  late bool _guardianAlertsEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = Controller.getSettings();
    _reminderMinutes = ((settings['reminderMinutes'] as num?)?.toDouble() ?? 30)
        .clamp(0, 120);
    _guardianAlertsEnabled = settings['guardianAlertsEnabled'] != false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Controller.saveSettings({
      ...Controller.getSettings(),
      'reminderMinutes': _reminderMinutes.round(),
      'guardianAlertsEnabled': _guardianAlertsEnabled,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('알림 설정을 저장했습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('미복용 판정 시간')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '예정 시각 이후 대기 시간',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_reminderMinutes.round()}분 동안 복약 기록이 없으면 미복용으로 판단합니다.',
                    style: const TextStyle(color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: _reminderMinutes,
                    min: 0,
                    max: 120,
                    divisions: 24,
                    label: '${_reminderMinutes.round()}분',
                    onChanged: (value) =>
                        setState(() => _reminderMinutes = value),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [Text('즉시'), Text('60분'), Text('120분')],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.all(16),
              title: const Text(
                '보호자 미복용 Push 알림',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('연결된 보호자에게 미복용 알림을 전송합니다.'),
              value: _guardianAlertsEnabled,
              onChanged: (value) =>
                  setState(() => _guardianAlertsEnabled = value),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('저장'),
          ),
          const SizedBox(height: 16),
          const Text(
            '앱이 실행 중이거나 다시 열렸을 때 미복용 상태를 확인합니다. 동일한 복약 건은 서버에서 한 번만 전송됩니다.',
            style: TextStyle(color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }
}
