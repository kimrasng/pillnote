import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pillnote/screen/pages/distanc.dart';
import 'package:pillnote/screen/pages/home.dart';
import 'package:pillnote/screen/pages/pill.dart';
import 'package:pillnote/screen/pages/menu.dart';

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  int _currentIndex = 0;

  final List<({String label, String icon})> _navItems = [
    (label: '홈', icon: 'assets/icon/home.svg'),
    (label: '약국', icon: 'assets/icon/distance.svg'),
    (label: '약 관리', icon: 'assets/icon/pill.svg'),
    (label: '메뉴', icon: 'assets/icon/menu.svg'),
  ];

  final List<Widget> _pages = [
    const Home(),
    const Distanc(),
    const Pill(),
    const Menu(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
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
