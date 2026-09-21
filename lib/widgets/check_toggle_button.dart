import 'package:flutter/material.dart';

class CheckToggleButton extends StatefulWidget {
  final bool isCheck;
  final ValueChanged<bool>? onChanged;
  final IconData icon;
  final double size;

  const CheckToggleButton({
    super.key,
    required this.isCheck,
    this.onChanged,
    required this.icon,
    this.size = 24,
  });

  @override
  State<CheckToggleButton> createState() => _CheckToggleButtonState();
}

class _CheckToggleButtonState extends State<CheckToggleButton> {
  late bool _currentCheck;

  @override
  void initState() {
    super.initState();
    _currentCheck = widget.isCheck;
  }

  @override
  void didUpdateWidget(covariant CheckToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCheck != widget.isCheck) {
      _currentCheck = widget.isCheck;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      isSelected: _currentCheck,
      iconSize: widget.size,
      icon: Icon(widget.icon),
      selectedIcon: Icon(widget.icon),
      onPressed: () {
        setState(() {
          _currentCheck = !_currentCheck;
        });
        widget.onChanged?.call(_currentCheck);
      },
    );
  }
}
