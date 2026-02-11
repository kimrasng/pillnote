import 'package:flutter/material.dart';
import 'package:pillnote/screen/AppBar.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "약 목록"),
    );
  }
}
