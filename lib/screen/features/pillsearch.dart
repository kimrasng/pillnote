import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/widgets/custom_text_field.dart';
import 'package:pillnote/screen/features/pillinfo.dart';

class Pillsearch extends StatefulWidget {
  const Pillsearch({super.key});

  @override
  State<Pillsearch> createState() => _PillsearchState();
}

class _PillsearchState extends State<Pillsearch> {
  final searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().length >= 2) {
        _searchPills(query);
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
          _errorMessage = null;
        });
      }
    });
  }

  Future<void> _searchPills(String itemName) async {
    if (itemName.trim().length < 2) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await ApiClient.instance.searchDrugs(itemName.trim());
      if (!mounted) return;
      setState(() => _searchResults = results);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = '서버에 연결할 수 없습니다.');
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
        title: Text(
          "약 검색",
          style: TextStyle(
            color: Colors.black,
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: screenWidth * 0.9,
          child: Column(
            children: [
              CustomTextField(
                label: '약 이름',
                hint: "검색어를 입력하세요",
                controller: searchController,
                onChanged: _onSearchChanged,
                onSubmitted: _searchPills,
              ),
              SizedBox(height: screenHeight * 0.02),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () =>
                                  _searchPills(searchController.text),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          "검색 결과가 없습니다",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: screenWidth * 0.045,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: screenHeight * 0.02),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final imageUrl = item['ITEM_IMAGE'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Pillinfo(
                                    pillSEQ: item['ITEM_SEQ'],
                                    isLocal: false,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(screenWidth * 0.04),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  screenWidth * 0.03,
                                ),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      screenWidth * 0.02,
                                    ),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: screenWidth * 0.2,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => Container(
                                                  width: screenWidth * 0.2,
                                                  color: Colors.grey.shade100,
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                    size: screenWidth * 0.08,
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            width: screenWidth * 0.2,
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
                                            fontSize: screenWidth * 0.042,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: screenHeight * 0.005),
                                        Text(
                                          item['ENTP_NAME'] ?? '업체명 정보 없음',
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
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade300,
                                    size: screenWidth * 0.05,
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
