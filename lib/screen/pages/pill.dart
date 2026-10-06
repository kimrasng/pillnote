import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/management/pilmanagement.dart';
import 'package:pillnote/screen/management/pill_groups.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Pill extends StatefulWidget {
  const Pill({super.key});
  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  bool _showArchived = false;
  String _query = '';
  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pills = AppServices.instance.medications.getPills();
    final groups = AppServices.instance.medications.getGroups();
    bool stored(Map<String, dynamic> p) => isStoredMedication(p, groups);
    final active = pills.where((p) => !stored(p)).toList();
    final archived = pills.where(stored).toList();
    final displayed = (_showArchived ? archived : active)
        .where(
          (p) =>
              Medication.name(p).toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final attention = active
        .where(
          (p) =>
              Medication.isLowStock(p) ||
              scheduleSummary(p, groups) == '일정 설정하기',
        )
        .length;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageScrollView(
        title: '내 약 상자',
        subtitle: '약과 복용 일정을 한눈에 확인해요.',
        padding: pills.isEmpty
            ? const EdgeInsets.symmetric(horizontal: 24)
            : const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: pills.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const EmptyState(
                        title: '첫 번째 약을 등록해요',
                        description:
                            '약 이름을 검색하거나 직접 입력하면\n복용 일정까지 바로 설정할 수 있어요.',
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                      const SizedBox(height: 24),
                      _groupManagement(),
                    ],
                  ),
                ),
              )
            : null,
        children: [
          if (pills.isNotEmpty) ...[
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '내 약 이름 찾기',
                prefixIcon: const Icon(Icons.search, size: 22, color: muted),
                filled: true,
                fillColor: wash,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: blue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('관리 중 ${active.length}'),
                  selected: !_showArchived,
                  onSelected: (_) => setState(() => _showArchived = false),
                ),
                ChoiceChip(
                  label: Text('보관 · 종료 ${archived.length}'),
                  selected: _showArchived,
                  onSelected: (_) => setState(() => _showArchived = true),
                ),
              ],
            ),
            if (attention > 0 && !_showArchived && _query.isEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '일정 또는 수량 확인이 필요한 약 $attention개',
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
          if (pills.isNotEmpty && displayed.isEmpty)
            EmptyState(
              title: _query.isNotEmpty
                  ? '찾는 약이 없어요'
                  : _showArchived
                  ? '보관한 약이 없어요'
                  : '관리 중인 약이 없어요',
              description: _query.isNotEmpty
                  ? '다른 이름으로 검색해 보세요.'
                  : '추가한 약과 복용 기록은 여기서 관리할 수 있어요.',
            ),
          ...displayed.map((pill) => _row(pill, groups)),
          const SizedBox(height: 24),
          _groupManagement(),
        ],
      ),
      bottomNavigationBar: BottomAction(
        label: '약 추가',
        onPressed: () => _open(const Pillsearch()),
      ),
    );
  }

  Widget _groupManagement() => Material(
    color: wash,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: const Icon(Icons.layers_outlined, color: blue),
      title: const Text(
        '약 묶음 관리',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        '함께 먹는 약의 공통 일정',
        style: TextStyle(color: muted, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: muted),
      onTap: () => _open(const PillGroups()),
    ),
  );

  Widget _row(Map<String, dynamic> pill, List<Map<String, dynamic>> groups) {
    final summary = scheduleSummary(pill, groups);
    final archived = pill['archived'] == true;
    final ended = isStoredMedication(pill, groups) && !archived;
    final memberships = groups
        .where((g) => (g['pillIds'] as List? ?? []).contains(pill['id']))
        .map((g) => g['name'])
        .join(' · ');
    return Column(
      children: [
        InkWell(
          onTap: () => _open(Pilmanagement(pillId: pill['id'].toString())),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillAvatar(pill),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Medication.name(pill),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      if ('${pill['strength'] ?? ''}'.isNotEmpty)
                        Text(
                          '${pill['strength']}',
                          style: const TextStyle(color: muted),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        archived
                            ? '보관 중 · 기록 유지'
                            : ended
                            ? '복용 기간 종료 · 일정 수정 가능'
                            : summary,
                        style: TextStyle(
                          color: summary == '일정 설정하기' && !archived && !ended
                              ? blue
                              : muted,
                          fontWeight: summary == '일정 설정하기'
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                      if (!archived &&
                          !ended &&
                          Medication.tracksStock(pill)) ...[
                        const SizedBox(height: 5),
                        Text(
                          '남은 약 ${Medication.quantity(pill['stock'] as num)}${Medication.unit(pill)}${Medication.isLowStock(pill) ? ' · 수량 확인' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Medication.isLowStock(pill)
                                ? const Color(0xFFB45309)
                                : muted,
                          ),
                        ),
                      ],
                      if (memberships.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          memberships,
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(Icons.chevron_right, color: muted, size: 20),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
