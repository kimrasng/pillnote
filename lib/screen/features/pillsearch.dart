import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/screen/features/pillinfo.dart';
import 'package:pillnote/screen/management/medication_form.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Pillsearch extends StatefulWidget {
  const Pillsearch({super.key});
  @override
  State<Pillsearch> createState() => _PillsearchState();
}

class _PillsearchState extends State<Pillsearch> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false, _searched = false;
  String? _error;
  int _request = 0;
  void _changed(String value) {
    _debounce?.cancel();
    _request++;
    setState(() {
      _results = [];
      _searched = false;
      _loading = false;
      _error = null;
    });
    if (value.trim().length >= 2) {
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => _searchPills(value),
      );
    }
  }

  Future<void> _searchPills(String query) async {
    _debounce?.cancel();
    final normalized = query.trim();
    if (normalized.length < 2) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ApiClient.instance.searchDrugs(normalized);
      if (mounted && request == _request) {
        setState(() {
          _results = results;
          _searched = true;
        });
      }
    } catch (error) {
      if (mounted && request == _request) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : '검색에 연결하지 못했어요. 직접 입력할 수도 있어요.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: PageScrollView(
      title: '약 추가',
      subtitle: '어떤 약을 복용하시나요? 약 이름을 검색하고, 복용 시간을 정해요.',
      showBackButton: true,
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: _changed,
                  onSubmitted: _searchPills,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: '약 이름',
                    hintText: '두 글자 이상 입력',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => _searchPills(_search.text),
                      child: const Text('다시 검색'),
                    ),
                  ],
                ),
              ),
            )
          else if (_results.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                title: _searched ? '검색 결과가 없어요' : '포장에 적힌 이름으로 찾아보세요',
                description: _searched
                    ? '검색되지 않는 약이나 영양제는\n아래에서 직접 입력할 수 있어요.'
                    : '검색이 어려우면 직접 입력해도 돼요.',
                icon: Icons.search,
              ),
            )
          else
            SliverList.separated(
              itemCount: _results.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (_, index) {
                final pill = _results[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  leading: PillAvatar(pill),
                  title: Text(
                    Medication.name(pill),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${pill['ENTP_NAME'] ?? ''}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(
                    Pillinfo(pillSEQ: '${pill['ITEM_SEQ']}', isLocal: false),
                  ),
                );
              },
            ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      maintainBottomViewPadding: true,
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: OutlinedButton.icon(
          onPressed: () => _open(
            MedicationForm(
              pill: _search.text.trim().isEmpty
                  ? null
                  : {'ITEM_NAME': _search.text.trim()},
            ),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('검색 없이 직접 입력'),
        ),
      ),
    ),
  );
}
