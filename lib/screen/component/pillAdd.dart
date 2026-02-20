import 'package:flutter/material.dart';

class pillAdd extends StatefulWidget {
  final String itemSeq;

  const pillAdd({super.key, required this.itemSeq});

  @override
  State<pillAdd> createState() => _pillAdd();
}

class _pillAdd extends State<pillAdd> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('약 정보'),
      ),
      body: Column(
        children: [
          Text("전달받은 약품 일련번호: ${widget.itemSeq}")
        ],
      ),
    );
  }
}
