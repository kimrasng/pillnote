import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:pillnote/app/app_services.dart';
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
    (label: '내 약 상자', icon: 'assets/icon/pill.svg'),
    (label: '약국', icon: 'assets/icon/distance.svg'),
    (label: '설정', icon: 'assets/icon/menu.svg'),
  ];

  final List<Widget> _pages = const [Home(), Pill(), Distanc(), Menu()];

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
    if (state == AppLifecycleState.resumed) unawaited(_refreshAfterResume());
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_flushBeforeBackground());
    }
  }

  Future<void> _flushBeforeBackground() async {
    try {
      await AppServices.instance.sync.flushPendingChanges();
    } catch (_) {
      // The OS can stop the app; unsent records retry on the next resume.
    }
  }

  Future<void> _refreshAfterResume() async {
    try {
      await AppServices.instance.sync.reconcileWithServer();
    } catch (_) {
      // Retry failed offline edits when the app returns to the foreground.
    }
    if (mounted) await _checkMissedDoses();
  }

  Future<void> _checkMissedDoses() async {
    await AppServices.instance.reminders.refresh();
    try {
      await AppServices.instance.sync.flushPendingChanges();
      await AppServices.instance.alerts.checkAndSend();
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
      resizeToAvoidBottomInset: false,
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
