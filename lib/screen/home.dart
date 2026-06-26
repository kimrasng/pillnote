import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;

  final List<({String label, String icon})> _navItems = [
    (label: '홈', icon: 'assets/icon/home.svg'),
    (label: '약국', icon: 'assets/icon/distance.svg'),
    (label: '약 관리', icon: 'assets/icon/pill.svg'),
    (label: '기록', icon: 'assets/icon/reorder.svg'),
  ];

  final List<Widget> _pages = [
    const Center(child: Text('홈 화면')),
    const Center(child: Text('약국 찾기')),
    const Center(child: Text('내 약 관리')),
    const Center(child: Text('복약 기록')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // 네비게이션 바 뒤로 콘텐츠가 보이게 설정
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    if (Platform.isIOS) {
      // Apple Liquid Glass 스타일 정밀 구현
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 34), // iOS 하단 바 여백 최적화
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_navItems.length, (i) => _buildIosNavItem(i)),
              ),
            ),
          ),
        ),
      );
    } else {
      // Android Material 3 표준 스타일
      return NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
        destinations: _navItems.map((item) => NavigationDestination(
          icon: SvgPicture.asset(
            item.icon,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(
                _currentIndex == _navItems.indexOf(item) ? const Color(0xFF2563EB) : Colors.black54,
                BlendMode.srcIn
            ),
          ),
          label: item.label,
        )).toList(),
      );
    }
  }

  Widget _buildIosNavItem(int index) {
    final isSelected = _currentIndex == index;
    final item = _navItems[index];

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            item.icon,
            width: 26,
            height: 26,
            colorFilter: ColorFilter.mode(
              isSelected ? const Color(0xFF007AFF) : CupertinoColors.secondaryLabel.withValues(alpha: 0.5),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? const Color(0xFF007AFF) : CupertinoColors.secondaryLabel.withValues(alpha: 0.5),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
