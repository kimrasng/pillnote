import 'package:flutter/material.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/screen/management/medication_form.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Pillinfo extends StatefulWidget {
  const Pillinfo({super.key, required this.pillSEQ, required this.isLocal});
  final String pillSEQ;
  final bool isLocal;
  @override
  State<Pillinfo> createState() => _PillinfoState();
}

class _PillinfoState extends State<Pillinfo> {
  Map<String, dynamic>? _pill;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.isLocal) {
      final pill = AppServices.instance.medications
          .getPills()
          .where(
            (p) => p['id'] == widget.pillSEQ || p['ITEM_SEQ'] == widget.pillSEQ,
          )
          .firstOrNull;
      if (pill != null) {
        setState(() {
          _pill = pill;
          _loading = false;
        });
        return;
      }
    }
    try {
      final pill = await ApiClient.instance.drugDetail(widget.pillSEQ);
      if (mounted) setState(() => _pill = pill);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : '약 정보를 불러오지 못했어요.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MedicationForm(pill: _pill)),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final pill = _pill;
    final consumer = Map<String, dynamic>.from(
      pill?['consumerInfo'] as Map? ?? {},
    );
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _loading || pill == null || _error != null
          ? AppBar(title: const Text('약 정보'))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pill == null || _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? '약 정보를 찾지 못했어요.'),
                  TextButton(onPressed: _load, child: const Text('다시 시도')),
                ],
              ),
            )
          : PageScrollView(
              title: '약 정보',
              showBackButton: true,
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
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                          if ('${pill['strength'] ?? ''}'.isNotEmpty)
                            Text(
                              '${pill['strength']}',
                              style: const TextStyle(color: muted),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '${pill['ENTP_NAME'] ?? '직접 등록한 약'}',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (consumer.isEmpty)
                  const SoftPanel(
                    child: Text(
                      '제공된 복용 안내가 없어요. 약 포장이나 처방전의 안내를 확인하세요.',
                      style: TextStyle(color: muted, height: 1.6),
                    ),
                  )
                else ...[
                  _section('효능 · 효과', consumer['efficacy']),
                  _section('복용 방법', consumer['usage']),
                  _section(
                    '주의사항',
                    consumer['precautions'] ?? consumer['warning'],
                  ),
                  _section('부작용', consumer['sideEffects']),
                  _section('보관 방법', consumer['storage']),
                ],
                const SizedBox(height: 12),
                const Divider(),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 16),
                  title: const Text(
                    '모양 · 색상 등 식별 정보',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    if ('${pill['ITEM_IMAGE'] ?? ''}'.isNotEmpty)
                      Image.network(
                        '${pill['ITEM_IMAGE']}',
                        height: 160,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    _detail('분류', pill['CLASS_NAME']),
                    _detail('모양', pill['DRUG_SHAPE']),
                    _detail('색상', pill['COLOR_CLASS1']),
                    _detail('앞면 표시', pill['PRINT_FRONT']),
                    _detail('뒷면 표시', pill['PRINT_BACK']),
                  ],
                ),
              ],
            ),
      bottomNavigationBar:
          !widget.isLocal && pill != null && !_loading && _error == null
          ? BottomAction(label: '이 약 선택 · 일정 설정', onPressed: _register)
          : null,
    );
  }

  Widget _section(String title, dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(title),
          Text(text, style: const TextStyle(height: 1.7)),
        ],
      ),
    );
  }

  Widget _detail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: muted)),
        ),
        Expanded(child: Text('${value ?? '정보 없음'}')),
      ],
    ),
  );
}
