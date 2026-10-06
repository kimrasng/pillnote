import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:pillnote/widgets/schedule_fields.dart';

class PillGroupEdit extends StatefulWidget {
  const PillGroupEdit({super.key, this.group});
  final Map<String, dynamic>? group;
  @override
  State<PillGroupEdit> createState() => _PillGroupEditState();
}

class _PillGroupEditState extends State<PillGroupEdit> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final ScheduleDraft _schedule;
  late Set<String> _ids;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.group?['name'] ?? ''}');
    _schedule = ScheduleDraft(widget.group);
    _ids = (widget.group?['pillIds'] as List? ?? [])
        .map((id) => id.toString())
        .toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      _message('묶음 이름을 입력하세요.');
      return;
    }
    if (_ids.isEmpty) {
      _message('함께 복용할 약을 하나 이상 선택하세요.');
      return;
    }
    if (_schedule.times.isEmpty) {
      _message('복용 시간을 하나 이상 정하세요.');
      return;
    }
    setState(() => _saving = true);
    await AppServices.instance.medications.saveGroup({
      ...?widget.group,
      'name': _name.text.trim(),
      'pillIds': _ids.toList(),
      ..._schedule.data,
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('약 묶음을 삭제할까요?'),
        content: const Text('묶음의 공통 일정만 삭제됩니다. 포함된 약과 지난 복용 기록은 유지돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AppServices.instance.medications.removeGroup(
      '${widget.group!['id']}',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pills = AppServices.instance.medications
        .getPills()
        .where((p) => p['archived'] != true || _ids.contains('${p['id']}'))
        .toList();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Form(
        key: _form,
        child: PageScrollView(
          title: widget.group == null ? '약 묶음 만들기' : '약 묶음 수정',
          subtitle: '함께 복용하는 약과 공통 일정을 정해요.',
          showBackButton: true,
          trailing: widget.group == null
              ? null
              : IconButton(
                  tooltip: '묶음 삭제',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '묶음 이름',
                hintText: '예: 아침에 먹는 약',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '묶음 이름을 입력하세요.' : null,
            ),
            const SizedBox(height: 20),
            SectionLabel(
              '포함할 약',
              trailing: Text(
                '${_ids.length}개 선택',
                style: const TextStyle(color: blue, fontSize: 13),
              ),
            ),
            if (pills.isEmpty)
              const SoftPanel(child: Text('내 약 상자에서 먼저 약을 추가하세요.')),
            ...pills.map(
              (pill) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(Medication.name(pill)),
                subtitle: Text(
                  pill['archived'] == true
                      ? '보관 중 · 홈 일정에서 제외됨'
                      : '${pill['strength'] ?? pill['ENTP_NAME'] ?? ''}',
                ),
                value: _ids.contains('${pill['id']}'),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _ids.add('${pill['id']}');
                  } else {
                    _ids.remove('${pill['id']}');
                  }
                }),
              ),
            ),
            const SizedBox(height: 20),
            const SoftPanel(
              child: Text(
                '묶음의 공통 일정이 개별 일정에 더해져요. 같은 약의 같은 시간은 한 번만 표시되고, 복용량은 각 약의 설정을 따릅니다.',
                style: TextStyle(color: muted, height: 1.6),
              ),
            ),
            const SizedBox(height: 16),
            ScheduleFields(draft: _schedule, showDosage: false),
          ],
        ),
      ),
      bottomNavigationBar: BottomAction(
        label: '약 묶음 저장',
        onPressed: _save,
        busy: _saving,
      ),
    );
  }
}
