import 'package:flutter/material.dart';
import '../../controller/controller.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late DateTime _selectedDate;
  late DateTime _startDate;
  late DateTime _endDate;
  late int _totalDays;
  late int _todayIndex;
  late ScrollController _scrollController;

  final List<String> _weekDays = ['월', '화', '수', '목', '금', '토', '일'];
  final double _itemMargin = 4.0;
  late double _itemWidth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.subtract(const Duration(days: 10));
    _endDate = today.add(const Duration(days: 10));

    _totalDays = _endDate.difference(_startDate).inDays + 1;
    _todayIndex = today.difference(_startDate).inDays;

    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _itemWidth = MediaQuery.of(context).size.width * 0.12;
      _scrollToIndex(_todayIndex, isAnimated: false);
    });
  }

  void _scrollToIndex(int index, {bool isAnimated = true}) {
    if (!_scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final itemTotalWidth = (_itemWidth * 1.3) + (_itemMargin * 3);
    double targetOffset =
        (index * itemTotalWidth) - (screenWidth / 2) + (itemTotalWidth / 2);

    final maxScroll = _scrollController.position.maxScrollExtent;
    final minScroll = _scrollController.position.minScrollExtent;
    targetOffset = targetOffset.clamp(minScroll, maxScroll);

    if (isAnimated) {
      if ((_scrollController.offset - targetOffset).abs() < 1.0) return;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    _itemWidth = screenWidth * 0.12;

    final allPills = Controller.getPills();
    final allGroups = Controller.getGroups();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(screenWidth, screenHeight),
            _buildCalendar(screenWidth, screenHeight),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: _buildTimeGroupedChecklist(
                  allPills,
                  allGroups,
                  screenWidth,
                  screenHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight) {
    return Padding(
      padding: EdgeInsets.fromLTRB(screenWidth * 0.06, screenWidth * 0.06, screenWidth * 0.06, screenWidth * 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_selectedDate.year}년 ${_selectedDate.month}월",
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "복용 확인",
                style: TextStyle(
                  fontSize: screenWidth * 0.075,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                final now = DateTime.now();
                setState(() => _selectedDate = now);
                _scrollToIndex(_todayIndex);
              },
              icon: Icon(
                Icons.today_rounded,
                color: const Color(0xFF2563EB),
                size: screenWidth * 0.07,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(double screenWidth, double screenHeight) {
    return SizedBox(
      height: screenHeight * 0.13,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
        itemCount: _totalDays,
        itemBuilder: (context, index) {
          DateTime date = _startDate.add(Duration(days: index));

          bool isSelected =
              date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          bool isToday =
              date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
              _scrollToIndex(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _itemWidth * 1.3,
              margin: EdgeInsets.symmetric(
                horizontal: _itemMargin * 1.5,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : (isToday
                        ? const Color(0xFF2563EB).withValues(alpha: 0.05)
                        : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isToday
                          ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                          : Colors.grey.shade100),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekDays[date.weekday - 1],
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.black38,
                      fontSize: screenWidth * 0.032,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.048,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeGroupedChecklist(
    List<Map<String, dynamic>> pills,
    List<Map<String, dynamic>> groups,
    double screenWidth,
    double screenHeight,
  ) {
    final dateStr = _selectedDate.toString().split(' ')[0];
    final history = Controller.getHistoryByDate(dateStr);

    final activePills = pills.where((p) {
      if (p['startDate'] == null || p['endDate'] == null) return false;
      return dateStr.compareTo(p['startDate']) >= 0 &&
          dateStr.compareTo(p['endDate']) <= 0;
    }).toList();

    final activeGroups = groups.where((g) {
      if (g['startDate'] == null || g['endDate'] == null) return false;
      return dateStr.compareTo(g['startDate']) >= 0 &&
          dateStr.compareTo(g['endDate']) <= 0;
    }).toList();

    Map<String, List<dynamic>> timeGroups = {};

    for (var pill in activePills) {
      final times = pill['times'] as List? ?? [];
      for (var time in times) {
        timeGroups.putIfAbsent(time.toString(), () => []).add({'type': 'pill', 'data': pill});
      }
    }

    for (var group in activeGroups) {
      final times = group['times'] as List? ?? [];
      for (var time in times) {
        timeGroups.putIfAbsent(time.toString(), () => []).add({'type': 'group', 'data': group});
      }
    }

    if (timeGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.08),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication_liquid_outlined,
                size: screenWidth * 0.18,
                color: Colors.grey.shade200,
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
            Text(
              "복용할 약이 없습니다.",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: screenWidth * 0.042,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final sortedTimes = timeGroups.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        screenWidth * 0.05,
        screenWidth * 0.05,
        screenWidth * 0.05,
        screenHeight * 0.15,
      ),
      itemCount: sortedTimes.length,
      itemBuilder: (context, index) {
        final time = sortedTimes[index];
        final items = timeGroups[time]!;
        return _buildTimeSlotCard(time, items, history, pills, dateStr, screenWidth, screenHeight);
      },
    );
  }

  Widget _buildTimeSlotCard(
    String time,
    List<dynamic> items,
    List<Map<String, dynamic>> history,
    List<Map<String, dynamic>> allPills,
    String dateStr,
    double screenWidth,
    double screenHeight,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.03),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(screenWidth * 0.06, screenWidth * 0.05, screenWidth * 0.06, 0),
            child: Row(
              children: [
                Icon(Icons.access_time_filled, color: const Color(0xFF2563EB), size: screenWidth * 0.05),
                SizedBox(width: screenWidth * 0.02),
                Text(
                  "$time 복용",
                  style: TextStyle(
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32, indent: 24, endIndent: 24),
          ...items.map((item) {
            if (item['type'] == 'pill') {
              return _buildIndividualPillRow(item['data'], time, dateStr, history, screenWidth, screenHeight);
            } else {
              return _buildGroupPillBlock(item['data'], time, dateStr, history, allPills, screenWidth, screenHeight);
            }
          }).toList(),
          SizedBox(height: screenHeight * 0.02),
        ],
      ),
    );
  }

  Widget _buildIndividualPillRow(
    Map<String, dynamic> pill,
    String time,
    String dateStr,
    List<Map<String, dynamic>> history,
    double screenWidth,
    double screenHeight,
  ) {
    final isTaken = history.any((h) => h['pillId'] == pill['id'] && h['scheduledTime'] == time);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.005),
      child: _buildCheckItem(
        title: pill['ITEM_NAME'] ?? '약',
        subtitle: "1회 ${pill['dosage'] ?? 1.0}정",
        isTaken: isTaken,
        onTap: () async {
          if (isTaken) return;
          final double currentStock = (pill['stock'] ?? 0).toDouble();
          final double dosage = (pill['dosage'] ?? 1.0).toDouble();
          if (currentStock < dosage) {
            _showStockWarning(screenWidth, screenHeight);
            return;
          }
          await Controller.recordIntake(pill['id'], time, date: dateStr);
          setState(() {});
        },
        screenWidth: screenWidth,
      ),
    );
  }

  Widget _buildGroupPillBlock(
    Map<String, dynamic> group,
    String time,
    String dateStr,
    List<Map<String, dynamic>> history,
    List<Map<String, dynamic>> allPills,
    double screenWidth,
    double screenHeight,
  ) {
    final List<dynamic> pillIds = group['pillIds'] ?? [];
    final takenCount = pillIds.where((pid) => history.any((h) => h['pillId'] == pid.toString() && h['scheduledTime'] == time)).length;
    final allTaken = takenCount == pillIds.length;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
      padding: EdgeInsets.all(screenWidth * 0.03),
      decoration: BoxDecoration(
        color: allTaken ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: allTaken ? const Color(0xFFBBF7D0) : const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group['name'] ?? '처방전',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                    color: allTaken ? const Color(0xFF16A34A) : const Color(0xFF1E3A8A),
                  ),
                ),
                if (pillIds.isNotEmpty)
                  Text(
                    "$takenCount / ${pillIds.length} 완료",
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      fontWeight: FontWeight.bold,
                      color: allTaken ? const Color(0xFF16A34A) : Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
          ...pillIds.map((pid) {
            final pill = allPills.firstWhere((p) => p['id'] == pid.toString(), orElse: () => {});
            if (pill.isEmpty) return const SizedBox.shrink();
            final isTaken = history.any((h) => h['pillId'] == pill['id'] && h['scheduledTime'] == time);
            return _buildCheckItem(
              title: pill['ITEM_NAME'] ?? '약',
              subtitle: "1회 ${pill['dosage'] ?? 1.0}정",
              isTaken: isTaken,
              onTap: () async {
                if (isTaken) return;
                final double currentStock = (pill['stock'] ?? 0).toDouble();
                final double dosage = (pill['dosage'] ?? 1.0).toDouble();
                if (currentStock < dosage) {
                  _showStockWarning(screenWidth, screenHeight);
                  return;
                }
                await Controller.recordIntake(pill['id'], time, date: dateStr);
                setState(() {});
              },
              screenWidth: screenWidth,
              isSmall: true,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required bool isTaken,
    required VoidCallback onTap,
    required double screenWidth,
    bool isSmall = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 8 : 12),
        child: Row(
          children: [
            Icon(
              isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isTaken ? const Color(0xFF16A34A) : Colors.grey.shade400,
              size: isSmall ? screenWidth * 0.06 : screenWidth * 0.07,
            ),
            SizedBox(width: screenWidth * 0.03),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmall ? screenWidth * 0.038 : screenWidth * 0.042,
                      fontWeight: isTaken ? FontWeight.normal : FontWeight.bold,
                      color: isTaken ? Colors.black38 : Colors.black87,
                      decoration: isTaken ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      color: isTaken ? Colors.black26 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (isTaken)
              Text(
                "기록됨",
                style: TextStyle(
                  color: const Color(0xFF16A34A),
                  fontSize: screenWidth * 0.032,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showStockWarning(double screenWidth, double screenHeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "약이 부족합니다",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("남은 약이 거의 없습니다. 새로 처방받거나 준비가 필요합니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }
}
