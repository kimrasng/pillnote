import 'package:flutter/material.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/widgets/app_ui.dart';

class ScheduleDraft {
  ScheduleDraft([Map<String, dynamic>? item]) {
    start = DateTime.tryParse('${item?['startDate']}') ?? DateTime.now();
    end = DateTime.tryParse('${item?['endDate']}');
    times = item == null ? ['08:00'] : Medication.times(item['times']);
    dosage = ((item?['dosage'] as num?) ?? 1).toDouble();
  }
  late DateTime start;
  DateTime? end;
  late List<String> times;
  late double dosage;
  Map<String, dynamic> get data => {
    'startDate': Medication.dateKey(start),
    'endDate': end == null ? null : Medication.dateKey(end!),
    'times': times,
    'dosage': dosage,
  };
}

class ScheduleFields extends StatefulWidget {
  const ScheduleFields({
    super.key,
    required this.draft,
    this.showDosage = true,
    this.unit = '정',
  });
  final ScheduleDraft draft;
  final bool showDosage;
  final String unit;
  @override
  State<ScheduleFields> createState() => _ScheduleFieldsState();
}

class _ScheduleFieldsState extends State<ScheduleFields> {
  ScheduleDraft get draft => widget.draft;
  Future<void> _pickDate(bool isEnd) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (draft.end ?? draft.start) : draft.start,
      firstDate: isEnd ? DateUtils.dateOnly(draft.start) : DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isEnd) {
        draft.end = picked;
      } else {
        draft.start = picked;
        if (draft.end != null && draft.end!.isBefore(picked)) {
          draft.end = picked;
        }
      }
    });
  }

  Future<void> _pickTime([String? old]) async {
    final pieces = (old ?? '08:00').split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(pieces[0]),
        minute: int.parse(pieces[1]),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (old != null) draft.times.remove(old);
      draft.times = Medication.times([
        ...draft.times,
        '${picked.hour}:${picked.minute.toString().padLeft(2, '0')}',
      ]);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('복용 시간'),
      const Text('매일 복용할 시간을 선택하세요.', style: TextStyle(color: muted)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...draft.times.map(
            (time) => InputChip(
              label: Text(time),
              onPressed: () => _pickTime(time),
              onDeleted: () => setState(() => draft.times.remove(time)),
              deleteButtonTooltipMessage: '$time 삭제',
            ),
          ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('시간 추가'),
            onPressed: _pickTime,
          ),
        ],
      ),
      if (widget.showDosage) ...[
        const SizedBox(height: 20),
        TextFormField(
          initialValue: Medication.quantity(draft.dosage),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '한 번에 복용할 수량',
            suffixText: widget.unit,
          ),
          validator: (value) {
            final n = double.tryParse(value ?? '');
            return n == null || !n.isFinite || n <= 0
                ? '0보다 큰 수량을 입력하세요.'
                : null;
          },
          onChanged: (value) => draft.dosage = double.tryParse(value) ?? 0,
        ),
      ],
      const SizedBox(height: 20),
      const SectionLabel('복용 기간'),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('시작일'),
        subtitle: Text(Medication.dateKey(draft.start)),
        trailing: const Icon(Icons.calendar_today_outlined, size: 20),
        onTap: () => _pickDate(false),
      ),
      SwitchListTile.adaptive(
        activeTrackColor: blue,
        contentPadding: EdgeInsets.zero,
        title: const Text('종료일 없이 계속 복용'),
        value: draft.end == null,
        onChanged: (ongoing) => setState(
          () => draft.end = ongoing ? null : DateUtils.dateOnly(draft.start),
        ),
      ),
      if (draft.end != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('종료일'),
          subtitle: Text(Medication.dateKey(draft.end!)),
          trailing: const Icon(Icons.calendar_today_outlined, size: 20),
          onTap: () => _pickDate(true),
        ),
    ],
  );
}
