import 'package:flutter/material.dart';

import '../../controller/controller.dart';
import '../../widgets/item_row.dart';

class Pilmanagement extends StatefulWidget {
  final Map pill;

  Pilmanagement({super.key, required this.pill});

  @override
  State<Pilmanagement> createState() => _PilmanagementState();
}

class _PilmanagementState extends State<Pilmanagement> {
  @override
  Widget build(BuildContext context) {
    final pill = widget.pill;
    final String imageUrl = pill['ITEM_IMAGE'] ?? '';

    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "약 관리",
          style: TextStyle(color: Colors.black, fontWeight: .bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: .fromLTRB(
                screenWidth * 0.04,
                screenWidth * 0.04,
                screenWidth * 0.04,
                screenHeight * 0.25,
              ),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if (imageUrl.isNotEmpty)
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: .circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: .circular(12),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: screenHeight * 0.25,
                            fit: .contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.broken_image,
                              size: screenWidth * 0.2,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    pill['ITEM_NAME'] ?? '이름 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.055,
                      fontWeight: .bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    pill['ENTP_NAME'] ?? '업체명 정보 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.04,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Padding(
                    padding: .symmetric(vertical: 16.0),
                    child: Divider(thickness: 1),
                  ),
                  ItemRow('분류명', pill['CLASS_NAME'] ?? '-'),
                  ItemRow('성상', pill['COLOR_CLASS1'] ?? '-'),
                  ItemRow('모양', pill['DRUG_SHAPE'] ?? '-'),
                  ItemRow('표시앞', pill['PRINT_FRONT'] ?? '-'),
                  ItemRow('표시뒤', pill['PRINT_BACK'] ?? '-'),
                ],
              ),
            ),
            Positioned(
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              bottom: 20,
              child: Column(
                mainAxisSize: .min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {},
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: .circular(15),
                        ),
                        backgroundColor: Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      child: Text(
                        "복용 일정 관리하기",
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: .bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("약 삭제"),
                            content: Text("이 약을 목록에서 삭제하시겠습니까?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text("취소"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  "삭제",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await Controller.removePill(pill['id']);
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: .circular(15),
                        ),
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      child: Text(
                        "약 삭제하기",
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: .bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
