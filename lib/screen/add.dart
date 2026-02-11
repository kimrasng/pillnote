import 'package:flutter/material.dart';

class AddScreen extends StatelessWidget {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("약 추가", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Center(
        child: Text("약 추가"),
      ),
    );
  }
}
