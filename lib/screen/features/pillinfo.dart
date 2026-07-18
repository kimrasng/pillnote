import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/widgets/item_row.dart';

class Pillinfo extends StatefulWidget {
  final String pillSEQ;

  const Pillinfo({super.key, required this.pillSEQ});

  @override
  State<Pillinfo> createState() => _PillinfoState();
}

class _PillinfoState extends State<Pillinfo> {
  Map<String, dynamic>? pillData;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPillData();
  }

  Future<void> _fetchPillData() async {
    final apiKey = dotenv.env['API_KEY'];
    final url = Uri.parse(
      'https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03'
      '?serviceKey=$apiKey'
      '&item_seq=${widget.pillSEQ}'
      '&type=json',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['body']['items'] as List?;

        if (items != null && items.isNotEmpty) {
          setState(() {
            pillData = items[0];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = "정보를 찾을 수 없습니다.";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "데이터를 불러오는 데 실패했습니다. (${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "오류가 발생했습니다: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('약 정보')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('약 정보')),
        body: Center(child: Text(errorMessage!)),
      );
    }

    final item = pillData!;
    final imageUrl = item['ITEM_IMAGE'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item['ITEM_NAME'] ?? '약 정보',
          style: TextStyle(fontSize: screenWidth * 0.05),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.04,
                screenWidth * 0.04,
                screenWidth * 0.04,
                screenHeight * 0.15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: screenHeight * 0.25,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.broken_image,
                            size: screenWidth * 0.2,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    item['ITEM_NAME'] ?? '이름 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.05,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    item['ENTP_NAME'] ?? '업체명 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Divider(height: screenHeight * 0.04),
                  ItemRow('분류명', item['CLASS_NAME']),
                  ItemRow('성상', item['COLOR_CLASS1']),
                  ItemRow('모양', item['DRUG_SHAPE']),
                  ItemRow('표시앞', item['PRINT_FRONT']),
                  ItemRow('표시뒤', item['PRINT_BACK']),
                ],
              ),
            ),
            Positioned(
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              bottom: 0,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                  await Controller.addPill(item);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('약이 추가되었습니다.')),
                    );
                    Navigator.pop(context);
                  }
                },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: Colors.black26,
                  ),
                  child: Text(
                    "약 추가하기",
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
