import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:pillnote/widgets/medication_reminder_status.dart';
import 'package:pillnote/widgets/schedule_fields.dart';

enum MedicationFormResult { saved, addAnother }

class MedicationForm extends StatefulWidget {
  const MedicationForm({
    super.key,
    this.pill,
    this.editing = false,
    this.reminderService,
    this.startWithSchedule = false,
  });
  final Map<String, dynamic>? pill;
  final bool editing;
  final DoseReminderService? reminderService;
  final bool startWithSchedule;
  @override
  State<MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<MedicationForm> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final TextEditingController _name, _strength, _stock;
  late final ScheduleDraft _schedule;
  late bool _trackStock, _scheduleEnabled;
  bool _saving = false, _extrasOpen = false;
  String? _stockError;
  Map<String, dynamic>? _savedPill;
  late String _unit;

  bool get _fromCatalogue => '${widget.pill?['ITEM_SEQ'] ?? ''}'.isNotEmpty;

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
    _scheduleEnabled =
        widget.startWithSchedule ||
        !widget.editing ||
        _schedule.times.isNotEmpty;
    _unit = pill == null ? '정' : Medication.unit(pill);
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _stock.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (_saving || _savedPill != null) return;
    final stock = _trackStock ? num.tryParse(_stock.text.trim()) : null;
    if (_trackStock && (stock == null || !stock.isFinite || stock < 0)) {
      setState(() {
        _extrasOpen = true;
        _stockError = '0 이상의 수량을 입력하세요.';
      });
      _revealExtraError();
      _message('보유 수량을 0 이상으로 입력하세요.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _extrasOpen = true);
      _revealExtraError();
      _message('약 이름을 입력하세요.');
      return;
    }
    if (_scheduleEnabled &&
        (!_schedule.dosage.isFinite || _schedule.dosage <= 0)) {
      _message('복용 수량은 0보다 커야 해요.');
      return;
    }
    if (_scheduleEnabled && _schedule.times.isEmpty) {
      _message('복용 시간을 선택하거나 나중에 시간 설정을 선택해주세요.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final data = {
        ...?widget.pill,
        'ITEM_NAME': _name.text.trim(),
        'strength': _strength.text.trim(),
        'unit': _unit,
        ..._schedule.data,
        if (!_scheduleEnabled) 'times': <String>[],
        if (!_scheduleEnabled &&
            (!_schedule.dosage.isFinite || _schedule.dosage <= 0))
          'dosage': (widget.pill?['dosage'] as num?) ?? 1,
        'trackStock': _trackStock,
        'stock': stock,
      };
      if (widget.editing) {
        await AppServices.instance.medications.updatePill(
          widget.pill!['id'].toString(),
          data,
        );
        if (mounted) Navigator.pop(context, MedicationFormResult.saved);
      } else {
        final id = await AppServices.instance.medications.addPill(data, stock);
        if (mounted) setState(() => _savedPill = {...data, 'id': id});
      }
    } catch (_) {
      if (mounted) _message('약을 저장하지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _revealExtraError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  List<Map<String, dynamic>> get _copySources => AppServices
      .instance
      .medications
      .getPills()
      .where(
        (pill) =>
            pill['id'] != widget.pill?['id'] &&
            pill['archived'] != true &&
            !Medication.isEnded(pill) &&
            Medication.times(pill['times']).isNotEmpty,
      )
      .toList();

  Future<void> _copyTimes() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final times = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .5,
        minChildSize: .3,
        maxChildSize: .85,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            const SectionLabel('기존 약과 같은 시간 사용'),
            const Text(
              '복용 시간만 가져와요. 이 약의 복용량과 기간은 따로 정해주세요.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final pill in _copySources)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(Medication.name(pill)),
                subtitle: Text(Medication.times(pill['times']).join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.pop(context, Medication.times(pill['times'])),
              ),
          ],
        ),
      ),
    );
    if (times != null && mounted) {
      setState(() {
        _schedule.times = times;
        _scheduleEnabled = true;
      });
    }
  }

  Widget _pillSummary(Map<String, dynamic> pill) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PillAvatar(pill, size: 48),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Medication.name(pill),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            if ('${pill['ENTP_NAME'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${pill['ENTP_NAME']}',
                style: const TextStyle(color: muted),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _nameField() => TextFormField(
    controller: _name,
    decoration: const InputDecoration(labelText: '약 이름'),
    validator: (value) =>
        value == null || value.trim().isEmpty ? '약 이름을 입력하세요.' : null,
  );

  List<Widget> _extraFields() => [
    if (_fromCatalogue) ...[_nameField(), const SizedBox(height: 16)],
    TextFormField(
      controller: _strength,
      decoration: const InputDecoration(
        labelText: '함량 또는 구분 (선택)',
        hintText: '예: 500mg · 흰색 캡슐',
      ),
    ),
    const SizedBox(height: 16),
    if (!_scheduleEnabled) ...[
      DropdownButtonFormField<String>(
        initialValue: _unit,
        items: {'정', '캡슐', '포', 'mL', '회', _unit}
            .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
            .toList(),
        onChanged: (value) => setState(() => _unit = value!),
        decoration: const InputDecoration(labelText: '복용 단위'),
      ),
      const SizedBox(height: 16),
    ],
    SwitchListTile.adaptive(
      activeTrackColor: blue,
      contentPadding: EdgeInsets.zero,
      title: const Text('남은 약 수량 관리'),
      subtitle: const Text('선택 사항이에요. 나중에 설정해도 돼요.'),
      value: _trackStock,
      onChanged: (value) => setState(() => _trackStock = value),
    ),
    if (_trackStock) ...[
      const SizedBox(height: 12),
      TextFormField(
        controller: _stock,
        forceErrorText: _stockError,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: '현재 보유 수량', suffixText: _unit),
        onChanged: (_) {
          if (_stockError != null) setState(() => _stockError = null);
        },
        validator: (value) {
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
  ];

  @override
  Widget build(BuildContext context) {
    if (_savedPill case final Map<String, dynamic> pill) {
      return _completion(pill);
    }
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _form,
            child: PageScrollView(
              controller: _scroll,
              title: widget.editing ? '약 · 일정 수정' : '복용 시간 설정',
              compactHeading: true,
              subtitle: widget.editing
                  ? '내 생활에 맞게 복용 일정을 바꿔요.'
                  : '2단계 · 복용 시간을 정하면 약 등록이 끝나요.',
              showBackButton: true,
              children: [
                if (_fromCatalogue)
                  _pillSummary({...?widget.pill, 'ITEM_NAME': _name.text})
                else
                  _nameField(),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('나중에 시간 설정'),
                  value: !_scheduleEnabled,
                  onChanged: (later) =>
                      setState(() => _scheduleEnabled = later != true),
                ),
                if (_scheduleEnabled) ...[
                  if (_copySources.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _copyTimes,
                        icon: const Icon(Icons.schedule),
                        label: const Text('기존 약과 같은 시간 사용'),
                      ),
                    ),
                  ScheduleFields(
                    draft: _schedule,
                    unit: _unit,
                    compactPeriod: true,
                    onUnitChanged: (value) => setState(() => _unit = value),
                  ),
                  const SizedBox(height: 20),
                  MedicationReminderStatus(service: widget.reminderService),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '약만 먼저 등록해요. 내 약 상자에서 복용 시간과 알림을 설정할 수 있어요.',
                      style: TextStyle(color: muted, height: 1.5),
                    ),
                  ),
                const SizedBox(height: 20),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('추가 설정'),
                  subtitle: Text(
                    _trackStock ? '함량 메모 · 남은 약 수량 관리 중' : '함량 메모 · 남은 약 수량 관리',
                  ),
                  trailing: Icon(
                    _extrasOpen ? Icons.expand_less : Icons.expand_more,
                  ),
                  onTap: () => setState(() => _extrasOpen = !_extrasOpen),
                ),
                if (_extrasOpen) ..._extraFields(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAction(
          label: widget.editing ? '변경 사항 저장' : '등록하기',
          onPressed: _save,
          busy: _saving,
        ),
      ),
    );
  }

  Future<void> _editSavedSchedule() async {
    final pill = _savedPill!;
    await Navigator.push<MedicationFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationForm(
          pill: pill,
          editing: true,
          reminderService: widget.reminderService,
          startWithSchedule: true,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _savedPill = AppServices.instance.medications.getPills().firstWhere(
        (stored) => stored['id'] == pill['id'],
        orElse: () => pill,
      );
    });
  }

  Widget _completion(Map<String, dynamic> pill) {
    final times = Medication.times(pill['times']);
    return Scaffold(
      body: PageScrollView(
        key: const ValueKey('medication-registration-complete'),
        title: '등록 완료',
        compactHeading: true,
        subtitle: '약을 내 약 상자에 등록했어요.',
        children: [
          _pillSummary(pill),
          const SizedBox(height: 24),
          Text(
            times.isEmpty
                ? '복용 시간은 나중에 설정하기로 했어요.'
                : '매일 ${times.join(' · ')}\n'
                      '한 번에 ${Medication.quantity(pill['dosage'] as num)}${Medication.unit(pill)}',
            style: const TextStyle(fontSize: 17, height: 1.6),
          ),
          if (times.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${pill['startDate']}부터 · '
              '${pill['endDate'] == null ? '종료일 없이' : '${pill['endDate']}까지'}',
              style: const TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            MedicationReminderStatus(
              pillId: '${pill['id']}',
              service: widget.reminderService,
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _editSavedSchedule,
              child: Text(times.isEmpty ? '복용 시간 설정' : '복용 시간 수정'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, MedicationFormResult.saved),
                child: const Text('완료'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, MedicationFormResult.addAnother),
                child: const Text('다른 약 추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
