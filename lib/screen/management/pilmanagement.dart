import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/screen/features/pillinfo.dart';
import 'package:pillnote/screen/management/medication_form.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Pilmanagement extends StatefulWidget {
  const Pilmanagement({super.key, required this.pillId});
  final String pillId;
  @override
  State<Pilmanagement> createState() => _PilmanagementState();
}

class _PilmanagementState extends State<Pilmanagement> {
  Future<void> _edit(Map<String, dynamic> pill) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationForm(pill: pill, editing: true),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _stock(Map<String, dynamic> pill) async {
    final changes = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _StockEditor(pill: pill),
    );
    if (changes == null) return;
    await AppServices.instance.medications.updatePill(widget.pillId, changes);
    if (mounted) setState(() {});
  }

  Future<void> _archive(Map<String, dynamic> pill) async {
    final archived = pill['archived'] == true;
    if (!archived) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('이 약을 보관할까요?'),
          content: const Text(
            '앞으로의 복용 일정에서 제외됩니다. 지난 기록과 약 정보는 보관되며 언제든 다시 꺼낼 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('보관'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    await AppServices.instance.medications.archivePill(
      widget.pillId,
      !archived,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pill = AppServices.instance.medications
        .getPills()
        .where((p) => p['id'] == widget.pillId)
        .firstOrNull;
    if (pill == null) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: const Text('내 약')),
        body: const Center(child: Text('약을 찾을 수 없어요.')),
      );
    }
    final groups = AppServices.instance.medications.getGroups();
    final times = Medication.times(pill['times']);
    final memberships = groups
        .where((g) => (g['pillIds'] as List? ?? []).contains(pill['id']))
        .toList();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageScrollView(
        title: '내 약',
        showBackButton: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PillAvatar(pill, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Medication.name(pill),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if ('${pill['strength'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${pill['strength']}',
                        style: const TextStyle(color: muted),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${pill['ENTP_NAME'] ?? '직접 등록한 약'}',
                      style: const TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (pill['archived'] == true) ...[
            const SoftPanel(
              child: Text('보관 중인 약이에요. 지난 기록은 유지되며 홈의 복용 일정에는 표시되지 않아요.'),
            ),
            const SizedBox(height: 20),
          ],
          SectionLabel(
            '복용 일정',
            trailing: TextButton(
              onPressed: () => _edit(pill),
              child: const Text('수정'),
            ),
          ),
          SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  times.isEmpty ? '개별 일정이 없어요' : '매일 ${times.join(' · ')}',
                  style: TextStyle(
                    color: times.isEmpty ? muted : ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '한 번에 ${Medication.quantity((pill['dosage'] as num?) ?? 1)}${Medication.unit(pill)}',
                  style: const TextStyle(color: muted),
                ),
                if (pill['startDate'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${pill['startDate']}부터 · ${pill['endDate'] == null ? '계속 복용' : '${pill['endDate']}까지'}',
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
                if (Medication.isEnded(pill)) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '복용 기간이 끝났어요. 다시 복용하려면 기간을 수정하세요.',
                    style: TextStyle(color: Color(0xFFB45309)),
                  ),
                ],
                if (memberships.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  ...memberships.map(
                    (g) => Text(
                      '${g['name']} · ${Medication.times(g['times']).join(' · ')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: blue,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '묶음 일정도 홈에 표시돼요. 같은 시간은 한 번만 체크해요.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionLabel(
            '남은 약',
            trailing: TextButton(
              onPressed: () => _stock(pill),
              child: Text(Medication.tracksStock(pill) ? '수량 수정' : '설정'),
            ),
          ),
          SoftPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Medication.tracksStock(pill)
                      ? '${Medication.quantity(pill['stock'] as num)}${Medication.unit(pill)} 남았어요'
                      : '수량을 관리하지 않고 있어요',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  Medication.isLowStock(pill)
                      ? '몇 회분 남지 않았어요. 보유 수량을 확인하세요.'
                      : '수량은 선택 사항이에요. 복용 체크는 언제든 가능해요.',
                  style: TextStyle(
                    color: Medication.isLowStock(pill)
                        ? const Color(0xFFB45309)
                        : muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline, color: muted),
            title: const Text('약 정보 · 복용 안내'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => Pillinfo(pillSEQ: widget.pillId, isLocal: true),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              pill['archived'] == true
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
              color: muted,
            ),
            title: Text(pill['archived'] == true ? '다시 관리하기' : '이 약 보관하기'),
            subtitle: const Text('지난 복용 기록을 유지해요.'),
            onTap: () => _archive(pill),
          ),
        ],
      ),
    );
  }
}

class _StockEditor extends StatefulWidget {
  const _StockEditor({required this.pill});
  final Map<String, dynamic> pill;
  @override
  State<_StockEditor> createState() => _StockEditorState();
}

class _StockEditorState extends State<_StockEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _stock;
  late bool _tracking;
  @override
  void initState() {
    super.initState();
    _tracking = Medication.tracksStock(widget.pill);
    _stock = TextEditingController(
      text: _tracking ? Medication.quantity(widget.pill['stock'] as num) : '',
    );
  }

  @override
  void dispose() {
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '남은 약 수량',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              activeTrackColor: blue,
              contentPadding: EdgeInsets.zero,
              title: const Text('수량 관리'),
              value: _tracking,
              onChanged: (value) => setState(() => _tracking = value),
            ),
            if (_tracking)
              TextFormField(
                controller: _stock,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: '현재 보유 수량',
                  suffixText: Medication.unit(widget.pill),
                ),
                validator: (value) {
                  final n = num.tryParse(value?.trim() ?? '');
                  return n == null || !n.isFinite || n < 0
                      ? '0 이상의 수량을 입력하세요.'
                      : null;
                },
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, {
                  'trackStock': _tracking,
                  'stock': _tracking ? num.parse(_stock.text.trim()) : null,
                });
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    ),
  );
}
