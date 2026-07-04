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
    _startDate = DateTime(now.year, now.month - 1, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    
    _totalDays = _endDate.difference(_startDate).inDays + 1;
    _todayIndex = DateTime(now.year, now.month, now.day).difference(_startDate).inDays;

    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _itemWidth = MediaQuery.of(context).size.width * 0.12;
      _scrollToIndex(_todayIndex, isAnimated: false);
    });
  }

  void _scrollToIndex(int index, {bool isAnimated = true}) {
    if (!_scrollController.hasClients) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final itemTotalWidth = _itemWidth + (_itemMargin * 2);
    final offset = (index * itemTotalWidth) - (screenWidth / 2) + (itemTotalWidth / 2);
    
    if (isAnimated) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _scrollController.jumpTo(offset);
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
    _itemWidth = screenWidth * 0.12;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.05),
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
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "오늘의 복약",
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() => _selectedDate = now);
                      _scrollToIndex(_todayIndex);
                    },
                    icon: Icon(
                      Icons.today, 
                      color: const Color(0xFF2563EB),
                      size: screenWidth * 0.07,
                    ),
                  )
                ],
              ),
            ),

            SizedBox(
              height: 90,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _totalDays,
                itemBuilder: (context, index) {
                  DateTime date = _startDate.add(Duration(days: index));

                  bool isSelected = date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;

                  bool isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = date);
                      _scrollToIndex(index);
                    },
                    child: Container(
                      width: _itemWidth,
                      margin: EdgeInsets.symmetric(horizontal: _itemMargin),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isToday ? const Color(0xFF2563EB) : Colors.grey.shade100),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekDays[date.weekday - 1],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_liquid, 
                      size: screenWidth * 0.15, 
                      color: Colors.black12
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "해당 날짜의 복약 기록이 없습니다.", 
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: screenWidth * 0.035,
                      )
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
