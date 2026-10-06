import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/management/pilmanagement.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final Set<String> _busy = {};
  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggle(ScheduledDose dose, bool taken) async {
    if (_busy.contains(dose.key)) return;
    setState(() => _busy.add(dose.key));
    final date = Medication.dateKey(_date);
    if (taken) {
      await AppServices.instance.intakes.undoIntake(
        dose.pillId,
        dose.time,
        date: date,
      );
    } else {
      await AppServices.instance.intakes.recordIntake(
        dose.pillId,
        dose.time,
        date: date,
      );
    }
    if (!mounted) return;
    setState(() => _busy.remove(dose.key));
    if (!taken) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('복용을 기록했어요.'),
            action: SnackBarAction(
              label: '실행 취소',
              onPressed: () async {
                await AppServices.instance.intakes.undoIntake(
                  dose.pillId,
                  dose.time,
                  date: date,
                );
                if (mounted) setState(() {});
              },
            ),
          ),
        );
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(_date, today);
    final future = _date.isAfter(today);
    final plan = AppServices.instance.dailyDosePlan(_date);
    final pills = AppServices.instance.medications.getPills();
    final doses = plan.doses;
    final pending = plan.pending;
    final completed = plan.completed;
    final next = plan.next;
    final progress = plan.progress;
    final weekStart = _date.subtract(Duration(days: _date.weekday - 1));
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageScrollView(
        title: isToday ? '오늘의 복용' : '복용 기록',
        subtitle: isToday ? '한 번의 체크로, 꾸준한 하루를 만들어요.' : '날짜별 일정과 복용 기록을 확인해요.',
        trailing: IconButton(
          tooltip: '날짜 선택',
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 22),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '지난주',
                      onPressed: () => setState(
                        () => _date = _date.subtract(const Duration(days: 7)),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_date.year}년 ${_date.month}월',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (!isToday)
                      TextButton(
                        onPressed: () => setState(() => _date = today),
                        child: const Text('오늘'),
                      ),
                    IconButton(
                      tooltip: '다음 주',
                      onPressed: () => setState(
                        () => _date = _date.add(const Duration(days: 7)),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(7, (index) {
                    final day = weekStart.add(Duration(days: index));
                    final selected = DateUtils.isSameDay(day, _date);
                    return Expanded(
                      child: Semantics(
                        selected: selected,
                        label: '${day.month}월 ${day.day}일',
                        child: InkWell(
                          onTap: () => setState(() => _date = day),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  ['월', '화', '수', '목', '금', '토', '일'][index],
                                  style: TextStyle(
                                    color: selected ? Colors.white70 : muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : ink,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: DateUtils.isSameDay(day, today)
                                        ? (selected ? Colors.white : blue)
                                        : Colors.transparent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                if (doses.isNotEmpty)
                  SoftPanel(
                    color: const Color(0xFFEFF5FF),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next == null
                              ? '예정된 복용을 모두 마쳤어요'
                              : future
                              ? '예정된 복용'
                              : '다음으로 확인할 복용',
                          style: const TextStyle(
                            color: blue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          next == null
                              ? '오늘도 잘 챙기셨어요'
                              : '${next.time}  ${Medication.name(next.pill)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Semantics(
                            container: true,
                            child: LinearProgressIndicator(
                              semanticsLabel:
                                  '복용 진행, ${completed.length}/${doses.length}회 완료',
                              value: progress,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFDCE8FF),
                              color: blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${completed.length} / ${doses.length}회 완료',
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                if (doses.isEmpty)
                  EmptyState(
                    title: pills.isEmpty ? '복용할 약을 등록해요' : '이날의 복용 일정이 없어요',
                    description: pills.isEmpty
                        ? '약을 추가하고 시간을 정하면\n오늘의 복용이 여기에 표시돼요.'
                        : '내 약 상자에서 약의 일정을 설정하거나\n새로운 약을 등록해 보세요.',
                    action: FilledButton.icon(
                      onPressed: () => _open(const Pillsearch()),
                      icon: const Icon(Icons.add),
                      label: const Text('약 등록하기'),
                    ),
                  ),
                if (pending.isNotEmpty) ...[
                  SectionLabel(
                    future ? '복용 예정' : '확인할 복용',
                    trailing: Text(
                      '${pending.length}회',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                  ..._doseRows(pending, false, future),
                ],
                if (completed.isNotEmpty) ...[
                  SectionLabel(
                    '복용 완료',
                    trailing: Text(
                      '${completed.length}회',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                  ..._doseRows(completed, true, future),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _doseRows(List<ScheduledDose> doses, bool taken, bool future) {
    String? lastTime;
    return doses.map((dose) {
      final showTime = lastTime != dose.time;
      lastTime = dose.time;
      final dosage = (dose.pill['dosage'] as num?) ?? 1;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                dose.time,
                style: TextStyle(
                  color: taken ? muted : ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _open(Pilmanagement(pillId: dose.pillId)),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        PillAvatar(dose.pill, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Medication.name(dose.pill),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: taken ? muted : ink,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${Medication.quantity(dosage)}${Medication.unit(dose.pill)}${dose.groups.isEmpty ? '' : ' · ${dose.groups.join(' · ')}'}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                container: true,
                excludeSemantics: true,
                enabled: !future && !_busy.contains(dose.key),
                onTap: future || _busy.contains(dose.key)
                    ? null
                    : () => _toggle(dose, taken),
                label:
                    '${Medication.name(dose.pill)} ${dose.time} ${taken ? '복용 취소' : '복용 체크'}',
                button: true,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: ValueKey('dose-${dose.key}'),
                    tooltip: taken
                        ? '복용 취소'
                        : future
                        ? '예정일에 체크할 수 있어요'
                        : '복용 체크',
                    onPressed: future || _busy.contains(dose.key)
                        ? null
                        : () => _toggle(dose, taken),
                    icon: _busy.contains(dose.key)
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            taken
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color: taken
                                ? blue
                                : future
                                ? line
                                : muted,
                            size: 30,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      );
    }).toList();
  }
}
