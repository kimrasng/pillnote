import 'package:flutter/material.dart';

class ItemRow extends StatelessWidget {
  final String label;
  final String? value;

  const ItemRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: .symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontWeight: .bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '-',
              style: TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
