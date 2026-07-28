import 'package:flutter/material.dart';

class PillCount extends StatefulWidget {
  const PillCount({super.key});

  @override
  State<PillCount> createState() => _PillCountState();
}

class _PillCountState extends State<PillCount> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('보유 수량', style: TextStyle(fontSize: screenWidth * 0.05)),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SafeArea(child: Stack(children: [])),
    );
  }
}
