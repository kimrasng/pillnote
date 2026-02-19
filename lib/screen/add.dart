import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:pillnote/screen/AppBar.dart';
import 'package:pillnote/screen/component/photoAdd.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  List<dynamic> _items = [];
  bool _isLoading = false;
  String _error = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPill(text);
    });
  }

  Future<void> _searchPill(String text) async {
    if (text.isEmpty) {
      setState(() {
        _items = [];
        _error = '';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final serviceKey = dotenv.env['API_KEY'];
      final uri = Uri.parse(
        'https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/'
            'getMdcinGrnIdntfcInfoList03'
            '?serviceKey=$serviceKey'
            '&pageNo=1'
            '&numOfRows=10'
            '&type=json'
            '&item_name=$text',
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(res.body);

        final body = json['body'];

        if (body['totalCount'] == 0) {
          setState(() {
            _items = [];
            _error = '검색 결과가 없습니다.';
          });
          return;
        }

        final List<dynamic> items = body?['items'] ?? [];

        setState(() {
          _items = items;
        });
      } else {
        setState(() {
          _error = '서버 오류: ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = '요청 실패: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "약 추가"),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            _PillAdd(onChanged: _onSearchChanged),
            const SizedBox(height: 16),
            Expanded(
              child: _PillAutoSearch(items: _items, isLoading: _isLoading, error: _error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => const photoAdd(),
                  ),
                );
              },
              child: const Text(
                "사진으로 추가하기",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillAdd extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _PillAdd({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        labelText: "약 이름",
      ),
      onChanged: onChanged,
    );
  }
}

class _PillAutoSearch extends StatelessWidget {
  final List<dynamic> items;
  final bool isLoading;
  final String error;

  const _PillAutoSearch({
    required this.items,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(error, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index] as Map<String, dynamic>;
        final name = item['ITEM_NAME'] ?? '이름 없음';
        final imageUrl = item['ITEM_IMAGE'];
        final entpName = item['ENTP_NAME'] ?? '';
        final className = item['CLASS_NAME'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (imageUrl != null && imageUrl.toString().isNotEmpty)
                Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Text('이미지 오류', textAlign: TextAlign.center),
                    );
                  },
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  alignment: Alignment.center,
                  child: const Text('이미지 없음', textAlign: TextAlign.center),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('제품명 : $name',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('회사 : $entpName'),
                    Text('분류 : $className'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
