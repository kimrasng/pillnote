import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class pillAdd extends StatefulWidget {
  final String itemSeq;

  const pillAdd({super.key, required this.itemSeq});

  @override
  State<pillAdd> createState() => _pillAdd();
}

class _pillAdd extends State<pillAdd> {
  Map<String, dynamic>? _pillData;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPillDetails();
  }

  Future<void> _fetchPillDetails() async {
    final serviceKey = dotenv.env['API_KEY'];
    final uri = Uri.parse(
      'https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/'
          'getMdcinGrnIdntfcInfoList03'
          '?serviceKey=$serviceKey'
          '&pageNo=1'
          '&numOfRows=1'
          '&type=json'
          '&item_seq=${widget.itemSeq}',
    );

    try {
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(res.body);
        final body = json['body'];
        if (body != null && body['items'] != null && (body['items'] as List).isNotEmpty) {
          setState(() {
            _pillData = (body['items'] as List).first;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = '약을 찾을 수 없습니다.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = '서버 오류 : ${res.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('약 추가'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: TextStyle(color: Colors.red)));
    }
    if (_pillData == null) {
      return Center(child: Text('약 정보를 불러올 수 없습니다.'));
    }

    final name = _pillData!['ITEM_NAME'] ?? '이름 없음';
    final imageUrl = _pillData!['ITEM_IMAGE'];
    final entpName = _pillData!['ENTP_NAME'] ?? '';
    final className = _pillData!['CLASS_NAME'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.toString().isNotEmpty)
            Center(
              child: Image.network(
                imageUrl,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: const Text('이미지 오류', textAlign: TextAlign.center),
                  );
                },
              ),
            ),
          SizedBox(height: 16),
          Text(name, style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 8),
          Text('제조사: $entpName'),
          SizedBox(height: 8),
          Text('분류: $className'),
        ],
      ),
    );
  }
}
