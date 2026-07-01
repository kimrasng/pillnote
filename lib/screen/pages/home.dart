import 'package:flutter/material.dart';
import 'package:pillnote/widgets/check_toggle_button.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool pill1 = false;
  bool pill2 = false;
  bool pill3 = false;
  bool pill4 = false;
  bool pill5 = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            Column(
              children: [
                CheckToggleButton(
                  size: 40,
                  isCheck: pill1,
                  onChanged: (value) => setState(() => pill1 = value),
                  icon: Icons.check_circle_outline,
                ),
                Text("기상")
              ],
            ),
            CheckToggleButton(
              size: 40,
              isCheck: pill2,
              onChanged: (value) => setState(() => pill2 = value),
              icon: Icons.check_circle_outline,
            ),
            CheckToggleButton(
              size: 40,
              isCheck: pill3,
              onChanged: (value) => setState(() => pill3 = value),
              icon: Icons.check_circle_outline,
            ),
            CheckToggleButton(
              size: 40,
              isCheck: pill4,
              onChanged: (value) => setState(() => pill4 = value),
              icon: Icons.check_circle_outline,
            ),
            CheckToggleButton(
              size: 40,
              isCheck: pill5,
              onChanged: (value) => setState(() => pill5 = value),
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
      ],
    );
  }
}
