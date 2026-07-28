import 'package:flutter/material.dart';

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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.06),
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
                        "오늘 먹을 약",
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
            ),

            SizedBox(
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
                      margin: EdgeInsets.symmetric(horizontal: _itemMargin * 1.5, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isToday ? const Color(0xFF2563EB).withValues(alpha: 0.05) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isToday ? const Color(0xFF2563EB).withValues(alpha: 0.3) : Colors.grey.shade100),
                          width: 1.5,
                        ),
                        boxShadow: const [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekDays[date.weekday - 1],
                            style: TextStyle(
                              color: isSelected ? Colors.white70 : Colors.black38,
                              fontSize: screenWidth * 0.032,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            ),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Center(
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
                        "오늘 복약 기록이 없어요.",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: screenWidth * 0.042,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
