import 'package:flutter/material.dart';
import '../../controller/controller.dart';
import '../../widgets/item_row.dart';

class Pilmanagement extends StatefulWidget {
  final Map pill;

  const Pilmanagement({super.key, required this.pill});

  @override
  State<Pilmanagement> createState() => _PilmanagementState();
}

class _PilmanagementState extends State<Pilmanagement> {
  void _showScheduleDialog(BuildContext context) async {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;

    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: widget.pill['startDate'] != null
          ? DateTimeRange(
              start: DateTime.parse(widget.pill['startDate']),
              end: DateTime.parse(widget.pill['endDate']),
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2563EB),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange == null) return;
    if (!mounted) return;

    final TextEditingController dosageController = TextEditingController(
      text: (widget.pill['dosage'] ?? 1.0).toString(),
    );
    List<String> tempTimes = List<String>.from(
      widget.pill['times'] ?? ["08:00", "13:00", "19:00"],
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                "복용 일정 설정",
                style: TextStyle(
                  fontSize: screenWidth * 0.05,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dosageController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(fontSize: screenWidth * 0.045),
                      decoration: InputDecoration(
                        labelText: "1회 복용량",
                        labelStyle: TextStyle(fontSize: screenWidth * 0.04),
                        suffixText: "정",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "복용 시간",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth * 0.045,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            TimeOfDay? pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              final String formatted =
                                  "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
                              if (!tempTimes.contains(formatted)) {
                                setDialogState(() {
                                  tempTimes.add(formatted);
                                  tempTimes.sort();
                                });
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: tempTimes.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              tempTimes[index],
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                setDialogState(() => tempTimes.removeAt(index));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "취소",
                    style: TextStyle(fontSize: screenWidth * 0.04),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'times': tempTimes,
                    'dosage': double.tryParse(dosageController.text) ?? 1.0,
                  }),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "저장하기",
                    style: TextStyle(fontSize: screenWidth * 0.04),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await Controller.updatePillSchedule(
        widget.pill['id'],
        pickedRange.start.toString().split(' ')[0],
        pickedRange.end.toString().split(' ')[0],
        result['times'],
        result['dosage'],
      );

      setState(() {
        widget.pill['startDate'] = pickedRange.start.toString().split(' ')[0];
        widget.pill['endDate'] = pickedRange.end.toString().split(' ')[0];
        widget.pill['times'] = result['times'];
        widget.pill['dosage'] = result['dosage'];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("복용 일정이 저장되었습니다."),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

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
          "약 상세 정보",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.05,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                screenWidth * 0.06,
                screenWidth * 0.04,
                screenWidth * 0.06,
                screenHeight * 0.25,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isNotEmpty)
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: screenHeight * 0.28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: double.infinity,
                                  height: screenHeight * 0.28,
                                  color: Colors.grey.shade50,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: screenWidth * 0.2,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: screenHeight * 0.04),
                  Text(
                    pill['ITEM_NAME'] ?? '이름 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.065,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    pill['ENTP_NAME'] ?? '회사 정보 없음',
                    style: TextStyle(
                      fontSize: screenWidth * 0.042,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader("남은 수량", screenWidth),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Text(
                      "${pill['stock'] ?? 0} 정/캡슐 남음",
                      style: TextStyle(
                        fontSize: screenWidth * 0.05,
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (pill['startDate'] != null) ...[
                    const SizedBox(height: 32),
                    _buildSectionHeader("복용 일정", screenWidth),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(screenWidth * 0.05),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.calendar_today_outlined,
                            "기간",
                            "${pill['startDate']} ~ ${pill['endDate']}",
                            screenWidth,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.scale_outlined,
                            "용량",
                            "1회 ${pill['dosage'] ?? 1.0}정",
                            screenWidth,
                            isBold: true,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.access_time_outlined,
                            "시간",
                            (pill['times'] as List).join(", "),
                            screenWidth,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  Text(
                    "기본 정보",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.045,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ItemRow('분류', pill['CLASS_NAME'] ?? '-'),
                  ItemRow('색상', pill['COLOR_CLASS1'] ?? '-'),
                  ItemRow('모양', pill['DRUG_SHAPE'] ?? '-'),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Positioned(
              left: screenWidth * 0.06,
              right: screenWidth * 0.06,
              bottom: 30,
              child: Column(
                mainAxisSize: .min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.07,
                    child: FilledButton(
                      onPressed: () => _showScheduleDialog(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        pill['startDate'] == null ? "복용 일정 등록" : "복용 일정 수정",
                        style: TextStyle(
                          fontSize: screenWidth * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.07,
                    child: FilledButton(
                      onPressed: () async {
                        final confirm = await _showDeleteConfirmDialog(
                          context,
                          screenWidth,
                        );
                        if (confirm == true) {
                          await Controller.removePill(pill['id']);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("삭제되었습니다."),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            Navigator.pop(context);
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        "이 약 삭제하기",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
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

  Widget _buildSectionHeader(String title, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: screenWidth * 0.045,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    double screenWidth, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: screenWidth * 0.045, color: Colors.black45),
        const SizedBox(width: 12),
        Text(
          "$label: ",
          style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.black54),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _showDeleteConfirmDialog(
    BuildContext context,
    double screenWidth,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "삭제 확인",
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "이 약을 목록에서 삭제하시겠습니까?",
          style: TextStyle(fontSize: screenWidth * 0.04),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("취소", style: TextStyle(fontSize: screenWidth * 0.04)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "삭제",
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
