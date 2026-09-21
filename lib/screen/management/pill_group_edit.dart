import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';

class PillGroupEdit extends StatefulWidget {
  final Map<String, dynamic>? group;

  const PillGroupEdit({super.key, this.group});

  @override
  State<PillGroupEdit> createState() => _PillGroupEditState();
}

class _PillGroupEditState extends State<PillGroupEdit> {
  final _nameController = TextEditingController();
  List<String> _selectedPillIds = [];
  String? _startDate;
  String? _endDate;
  List<String> _times = ["08:00", "13:00", "19:00"];

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _nameController.text = widget.group!['name'] ?? '';
      _selectedPillIds = List<String>.from(widget.group!['pillIds'] ?? []);
      _startDate = widget.group!['startDate'];
      _endDate = widget.group!['endDate'];
      _times = List<String>.from(
        widget.group!['times'] ?? ["08:00", "13:00", "19:00"],
      );
    }
  }

  void _showScheduleDialog() async {
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null
          ? DateTimeRange(
              start: DateTime.parse(_startDate!),
              end: DateTime.parse(_endDate!),
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

    List<String> tempTimes = List<String>.from(_times);

    List<String>? finalTimes = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                "복용 시간 설정",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: tempTimes.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              tempTimes[index],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => setDialogState(
                                () => tempTimes.removeAt(index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    TextButton.icon(
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
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("시간 추가"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소"),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, tempTimes),
                  child: const Text("확인"),
                ),
              ],
            );
          },
        );
      },
    );

    if (finalTimes != null) {
      setState(() {
        _startDate = pickedRange.start.toString().split(' ')[0];
        _endDate = pickedRange.end.toString().split(' ')[0];
        _times = finalTimes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pills = Controller.getPills();
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.group == null ? "처방전 묶음 만들기" : "처방전 수정",
          style: TextStyle(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (widget.group != null)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: screenWidth * 0.06,
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("묶음 삭제"),
                    content: const Text("이 처방전 묶음을 삭제하시겠습니까?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("취소"),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text("삭제"),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await Controller.removeGroup(widget.group!['id']);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(screenWidth * 0.06),
        children: [
          _buildLabel("묶음 이름", screenWidth),
          TextField(
            controller: _nameController,
            style: TextStyle(fontSize: screenWidth * 0.045),
            decoration: InputDecoration(
              hintText: "예: 아침 처방약",
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.all(screenWidth * 0.04),
            ),
          ),
          SizedBox(height: screenHeight * 0.04),
          _buildLabel("포함할 약 선택", screenWidth),
          if (pills.isEmpty)
            Container(
              padding: EdgeInsets.all(screenWidth * 0.05),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                "등록된 약이 없습니다. 먼저 개별 약을 등록해주세요.",
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.red.shade700,
                ),
              ),
            )
          else
            Material(
              color: const Color(0xFFF8FAFC),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade100),
              ),
              child: Column(
                children: pills.map((pill) {
                  final isSelected = _selectedPillIds.contains(pill['id']);
                  return Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      title: Text(
                        pill['ITEM_NAME'] ?? '',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        pill['ENTP_NAME'] ?? '',
                        style: TextStyle(fontSize: screenWidth * 0.032),
                      ),
                      value: isSelected,
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedPillIds.add(pill['id']);
                          } else {
                            _selectedPillIds.remove(pill['id']);
                          }
                        });
                      },
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  );
                }).toList(),
              ),
            ),
          SizedBox(height: screenHeight * 0.04),
          _buildLabel("복용 일정", screenWidth),
          Material(
            color: const Color(0xFFF0FDF4),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFDCFCE7)),
            ),
            child: InkWell(
              onTap: _showScheduleDialog,
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.05),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF16A34A),
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_startDate == null)
                            Text(
                              "날짜와 시간을 설정하세요",
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else ...[
                            Text(
                              "$_startDate ~ $_endDate",
                              style: TextStyle(
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "시간: ${_times.join(', ')}",
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_outlined,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.06),
          SizedBox(
            height: screenHeight * 0.07,
            child: FilledButton(
              onPressed: () async {
                if (_nameController.text.isEmpty) {
                  _showError("묶음 이름을 입력해주세요");
                  return;
                }
                if (_selectedPillIds.isEmpty) {
                  _showError("최소 하나 이상의 약을 선택해주세요");
                  return;
                }
                if (_startDate == null) {
                  _showError("복용 일정을 설정해주세요");
                  return;
                }

                final groupData = {
                  if (widget.group != null) 'id': widget.group!['id'],
                  'name': _nameController.text,
                  'pillIds': _selectedPillIds,
                  'startDate': _startDate,
                  'endDate': _endDate,
                  'times': _times,
                };

                await Controller.saveGroup(groupData);
                if (context.mounted) Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                "저장하기",
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.05),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: screenWidth * 0.042,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
