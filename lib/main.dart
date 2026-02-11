import 'package:flutter/material.dart';

import 'package:pillnote/screen/add.dart';
import 'package:pillnote/screen/list.dart';
import 'package:pillnote/screen/taking.dart';


void main() => runApp(const NavigationBarApp());

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: NavigationExample());
  }
}

class NavigationExample extends StatefulWidget {
  const NavigationExample({super.key});

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Colors.transparent,
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.medication_liquid_rounded),
            label: '복용 기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.add),
            label: '추가',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: '약 목록',
          ),
        ],
      ),
      body: <Widget>[
        TakingScreen(),
        AddScreen(),
        ListScreen()
      ][currentPageIndex],
    );
  }
}