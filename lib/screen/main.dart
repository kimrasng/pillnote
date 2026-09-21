import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/pages/distanc.dart';
import 'package:pillnote/screen/pages/home.dart';
import 'package:pillnote/screen/pages/pill.dart';
import 'package:pillnote/screen/pages/menu.dart';

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _missedDoseTimer;

  final List<({String label, String icon})> _navItems = [
    (label: '홈', icon: 'assets/icon/home.svg'),
    (label: '약국', icon: 'assets/icon/distance.svg'),
    (label: '약 관리', icon: 'assets/icon/pill.svg'),
    (label: '메뉴', icon: 'assets/icon/menu.svg'),
  ];

  final List<Widget> _pages = const [Home(), Distanc(), Pill(), Menu()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkMissedDoses();
    _missedDoseTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkMissedDoses(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkMissedDoses();
  }

  Future<void> _checkMissedDoses() async {
    try {
      await Controller.checkAndSendMissedDoseAlerts();
    } catch (_) {
      // 로컬 복약 화면은 네트워크 장애와 무관하게 계속 동작합니다.
    }
  }

  @override
  void dispose() {
    _missedDoseTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 0,
        height: 70,
        indicatorColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: SvgPicture.asset(
                  item.icon,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    Colors.black54,
                    BlendMode.srcIn,
                  ),
                ),
                selectedIcon: SvgPicture.asset(
                  item.icon,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    const Color(0xFF2563EB),
                    BlendMode.srcIn,
                  ),
                ),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
