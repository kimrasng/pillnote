import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:pillnote/widgets/schedule_fields.dart';

class MedicationForm extends StatefulWidget {
  const MedicationForm({super.key, this.pill, this.editing = false});
  final Map<String, dynamic>? pill;
  final bool editing;
  @override
  State<MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<MedicationForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _strength, _stock;
  late final ScheduleDraft _schedule;
  late bool _trackStock, _scheduleEnabled;
  bool _saving = false;
  late String _unit;

  @override
  void initState() {
    super.initState();
    final pill = widget.pill;
    _name = TextEditingController(
      text: pill == null ? '' : Medication.name(pill),
    );
    _strength = TextEditingController(text: '${pill?['strength'] ?? ''}');
    _stock = TextEditingController(
      text: pill != null && Medication.tracksStock(pill)
          ? Medication.quantity(pill['stock'] as num)
          : '',
    );
    _trackStock = pill != null && Medication.tracksStock(pill);
    _schedule = ScheduleDraft(pill);
    if (pill != null && _schedule.times.isEmpty) _schedule.times = ['08:00'];
    _scheduleEnabled =
        !widget.editing || Medication.times(pill?['times']).isNotEmpty;
    _unit = pill == null ? '정' : Medication.unit(pill);
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final stock = _trackStock ? num.tryParse(_stock.text.trim()) : null;
    final error = _name.text.trim().isEmpty
        ? '약 이름을 입력하세요.'
        : _scheduleEnabled &&
              (!_schedule.dosage.isFinite || _schedule.dosage <= 0)
        ? '복용 수량은 0보다 커야 해요.'
        : _trackStock && (stock == null || !stock.isFinite || stock < 0)
        ? '보유 수량을 0 이상으로 입력하세요.'
        : null;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_scheduleEnabled && _schedule.times.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복용 시간을 하나 이상 선택하세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        ...?widget.pill,
        'ITEM_NAME': _name.text.trim(),
        'strength': _strength.text.trim(),
        'unit': _unit,
        ..._schedule.data,
        if (!_scheduleEnabled) 'times': <String>[],
        'trackStock': _trackStock,
        'stock': _trackStock ? num.parse(_stock.text.trim()) : null,
      };
      if (widget.editing) {
        await AppServices.instance.medications.updatePill(
          widget.pill!['id'].toString(),
          data,
        );
      } else {
        await AppServices.instance.medications.addPill(
          data,
          data['stock'] as num?,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: Form(
      key: _form,
      child: PageScrollView(
        title: widget.editing ? '약 · 일정 수정' : '약 등록',
        subtitle: widget.editing ? '내 생활에 맞게 복용 일정을 바꿔요.' : '이 약을 언제 복용하시나요?',
        showBackButton: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: '약 이름'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '약 이름을 입력하세요.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _strength,
            decoration: const InputDecoration(
              labelText: '함량 또는 구분 (선택)',
              hintText: '예: 500mg · 흰색 캡슐',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            items: {'정', '캡슐', '포', 'mL', '회', _unit}
                .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                .toList(),
            onChanged: (value) => setState(() => _unit = value!),
            decoration: const InputDecoration(labelText: '수량 단위'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          SwitchListTile.adaptive(
            activeTrackColor: blue,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '복용 일정 설정',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('설정한 시간에 홈에서 복용을 체크해요.'),
            value: _scheduleEnabled,
            onChanged: (value) => setState(() => _scheduleEnabled = value),
          ),
          if (_scheduleEnabled) ScheduleFields(draft: _schedule, unit: _unit),
          const SizedBox(height: 24),
          const Divider(),
          SwitchListTile.adaptive(
            activeTrackColor: blue,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '남은 약 수량 관리',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('선택 사항이에요. 나중에 설정해도 돼요.'),
            value: _trackStock,
            onChanged: (value) => setState(() => _trackStock = value),
          ),
          if (_trackStock) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _stock,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: '현재 보유 수량',
                suffixText: _unit,
              ),
              validator: (value) {
                if (!_trackStock) return null;
                final stock = num.tryParse(value?.trim() ?? '');
                return stock == null || !stock.isFinite || stock < 0
                    ? '0 이상의 수량을 입력하세요.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              '복용 체크에 따라 수량이 줄어들어요. 수량이 부족해도 복용 기록은 남길 수 있어요.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ],
        ],
      ),
    ),
    bottomNavigationBar: BottomAction(
      label: widget.editing ? '변경 사항 저장' : '내 약 상자에 등록',
      onPressed: _save,
      busy: _saving,
    ),
  );
}
