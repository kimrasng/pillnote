import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/services/snapshot_sync_service.dart';
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
  late final SnapshotSyncService _sync;
  final _dateScrollController = ScrollController();
  late final DateTime _calendarStart;
  static const _calendarDays = 21;
  static const _dateCardMargin = 6.0;

  @override
  void initState() {
    super.initState();
    _sync = AppServices.instance.sync;
    _sync.addListener(_onSynced);
    _calendarStart = DateTime(_date.year, _date.month, _date.day - 10);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToDate(animate: false);
    });
  }

  void _onSynced() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sync.removeListener(_onSynced);
    _dateScrollController.dispose();
    super.dispose();
  }

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

  void _selectDate(DateTime date) {
    setState(() => _date = date);
    _scrollToDate();
  }

  void _scrollToDate({bool animate = true}) {
    if (!_dateScrollController.hasClients) return;
    final position = _dateScrollController.position;
    final width = position.viewportDimension;
    final itemExtent = width * 0.156 + _dateCardMargin * 2;
    final index = DateTime.utc(_date.year, _date.month, _date.day)
        .difference(
          DateTime.utc(
            _calendarStart.year,
            _calendarStart.month,
            _calendarStart.day,
          ),
        )
        .inDays;
    final offset = (width * 0.04 + (index + 0.5) * itemExtent - width / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _dateScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _dateScrollController.jumpTo(offset);
    }
  }

  Widget _buildCalendar(DateTime today) {
    final size = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final weekdayFontSize = size.width * 0.032;
    final dayFontSize = size.width * 0.048;
    final height = math.max(
      size.height * 0.13,
      textScaler.scale(weekdayFontSize) * 1.4 +
          textScaler.scale(dayFontSize) * 1.4 +
          46,
    );
    return SizedBox(
      height: height,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
        itemExtent: size.width * 0.156 + _dateCardMargin * 2,
        itemCount: _calendarDays,
        itemBuilder: (context, index) {
          final day = DateTime(
            _calendarStart.year,
            _calendarStart.month,
            _calendarStart.day + index,
          );
          final selected = DateUtils.isSameDay(day, _date);
          final isToday = DateUtils.isSameDay(day, today);
          return Semantics(
            selected: selected,
            button: true,
            label: '${day.month}월 ${day.day}일${isToday ? ', 오늘' : ''}',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _dateCardMargin,
                vertical: 8,
              ),
              child: InkWell(
                onTap: () => _selectDate(day),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected
                        ? blue
                        : isToday
                        ? blue.withValues(alpha: 0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? blue
                          : isToday
                          ? blue.withValues(alpha: 0.3)
                          : Colors.grey.shade100,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ['월', '화', '수', '목', '금', '토', '일'][day.weekday - 1],
                        style: TextStyle(
                          color: selected ? Colors.white70 : Colors.black38,
                          fontSize: weekdayFontSize,
                          height: 1.4,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: dayFontSize,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageScrollView(
        title: isToday ? '오늘의 복용' : '복용 기록',
        subtitle: isToday ? '한 번의 체크로, 꾸준한 하루를 만들어요.' : '날짜별 일정과 복용 기록을 확인해요.',
        trailing: IconButton(
          tooltip: '오늘로 돌아가기',
          onPressed: () => _selectDate(today),
          style: IconButton.styleFrom(
            backgroundColor: blue.withValues(alpha: 0.1),
            foregroundColor: blue,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.today_rounded, size: 26),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '${_date.year}년 ${_date.month}월',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _buildCalendar(today),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
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
