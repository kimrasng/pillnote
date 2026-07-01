import 'package:flutter/material.dart';
import 'package:pillnote/screen/features/pillsearch.dart';

class Pill extends StatefulWidget {
  const Pill({super.key});

  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const Pillsearch()),
            ),
            child: const Text("약 검색"),
          ),
        ],
      ),
    );
  }
}
