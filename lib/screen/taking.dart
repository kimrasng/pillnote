import 'package:flutter/material.dart';
import 'package:pillnote/screen/AppBar.dart';

class TakingScreen extends StatelessWidget {
  const TakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "복용 기록"),
      body: Center(child: Column()),
    );
  }
}