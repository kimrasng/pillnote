import 'package:flutter/material.dart';
import 'package:pillnote/screen/onboarding.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: Onboarding(), backgroundColor: Colors.white,),
    );
  }
}
