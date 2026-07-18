import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pillnote/widgets/custom_text_field.dart';
import 'package:http/http.dart' as http;
import 'package:pillnote/screen/features/pillinfo.dart';

class Pillsearch extends StatefulWidget {
  const Pillsearch({super.key});

  @override
  State<Pillsearch> createState() => _PillsearchState();
}

class _PillsearchState extends State<Pillsearch> {
  final searchController = TextEditingController();
  final String _apiKey = dotenv.get('API_KEY');

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchPills(query);
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _searchPills(String itemName) async {
    if (itemName.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
      'https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03?serviceKey=$_apiKey&pageNo=1&numOfRows=100&type=json&item_name=${Uri.encodeComponent(itemName)}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['body']?['items'];
        setState(() {
          if (items is List) {
            _searchResults = items;
          } else if (items == null) {
            _searchResults = [];
          } else {
            _searchResults = [items];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('에러 발생: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: screenWidth * 0.05,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: screenWidth * 0.9,
          child: Column(
            children: [
              CustomTextField(
                label: '약 검색',
                hint: "약 이름을 입력 해주세요.",
                controller: searchController,
                onChanged: _onSearchChanged,
                onSubmitted: _searchPills,
              ),
              SizedBox(height: screenHeight * 0.02),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          "검색 결과가 없습니다.",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.04,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: screenHeight * 0.015),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final imageUrl = item['ITEM_IMAGE'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      Pillinfo(pillSEQ: item['ITEM_SEQ']),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(screenWidth * 0.03),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: screenWidth * 0.25,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      width: screenWidth * 0.25,
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey,
                                                        size: screenWidth * 0.08,
                                                      ),
                                                    ),
                                          )
                                        : Container(
                                            width: screenWidth * 0.25,
                                            color: Colors.grey.shade100,
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                              size: screenWidth * 0.08,
                                            ),
                                          ),
                                  ),
                                  SizedBox(width: screenWidth * 0.04),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['ITEM_NAME'] ?? '이름 없음',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: screenWidth * 0.04,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: screenHeight * 0.005),
                                        Text(
                                          item['ENTP_NAME'] ?? '업체명 없음',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: screenWidth * 0.035,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
