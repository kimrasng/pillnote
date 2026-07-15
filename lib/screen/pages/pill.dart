import 'package:flutter/material.dart';
import 'package:pillnote/screen/features/pillsearch.dart';

class Pill extends StatefulWidget {
  const Pill({super.key});

  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  late final size = MediaQuery.of(context).size;
  late final double screenWidth = size.width;

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
            child: Column(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.medication_liquid,
                      size: screenWidth * 0.15,
                      color: Colors.black12,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "등록된 약이 없습니다.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (context) => const Pillsearch()),
                  ),
                  child: const Text("약 검색"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
