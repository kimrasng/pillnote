import 'package:flutter/material.dart';

class TakingScreen extends StatelessWidget {
  const TakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(
            "복용 기록",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          actions: [
      ],
    ),
    body: Center(child: Text("복용"
    )
    )
    ,
    );
  }
}
