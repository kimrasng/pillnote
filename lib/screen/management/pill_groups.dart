import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/screen/management/pill_group_edit.dart';
import 'package:pillnote/widgets/app_ui.dart';

class PillGroups extends StatefulWidget {
  const PillGroups({super.key});
  @override
  State<PillGroups> createState() => _PillGroupsState();
}

class _PillGroupsState extends State<PillGroups> {
  Future<void> _edit([Map<String, dynamic>? group]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PillGroupEdit(group: group)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final groups = AppServices.instance.medications.getGroups();
    final pills = AppServices.instance.medications.getPills();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageScrollView(
        title: '약 묶음',
        subtitle: '함께 먹는 약을 한 번에 관리해요. 개별 약의 일정과 겹쳐도 복용 체크는 한 번만 해요.',
        showBackButton: true,
        children: [
          if (groups.isEmpty)
            const EmptyState(
              title: '아직 약 묶음이 없어요',
              description: '먼저 약을 등록하고, 함께 복용하는 약을 선택하세요.',
              icon: Icons.layers_outlined,
            ),
          ...groups.map((group) {
            final ids = group['pillIds'] as List? ?? [];
            final members = pills.where((p) => ids.contains(p['id']));
            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  title: Text(
                    '${group['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${members.map(Medication.name).join(' · ')}\n${Medication.times(group['times']).join(' · ')}${Medication.isEnded(group) ? ' · 복용 종료' : ''}',
                    style: const TextStyle(height: 1.7),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(group),
                ),
                const Divider(),
              ],
            );
          }),
        ],
      ),
      bottomNavigationBar: BottomAction(
        label: '약 묶음 만들기',
        onPressed: () => _edit(),
      ),
    );
  }
}
