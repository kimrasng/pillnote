import 'package:flutter/material.dart';

void addDialog(BuildContext context, Map<String, dynamic> pillData) {
  final name = pillData['ITEM_NAME'] ?? '이름 없음';
  final imageUrl = pillData['ITEM_IMAGE'];
  final entpName = pillData['ENTP_NAME'] ?? '';
  final className = pillData['CLASS_NAME'] ?? '';

  bool mChecked = false;
  bool lChecked = false;
  bool dChecked = false;

  int day = 3;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            title: const Text("약 정보"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null && imageUrl.toString().isNotEmpty)
                  Center(
                    child: Image.network(
                      imageUrl,
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 150,
                          height: 150,
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Text(
                            '이미지 오류',
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Text('이미지 없음', textAlign: TextAlign.center),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  '제품명 : $name',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('회사 : $entpName'),
                Text('분류 : $className'),
                Row(
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: mChecked,
                              onChanged: (bool? value) {
                                setState(() {
                                  mChecked = value!;
                                });
                              },
                            ),
                            const Text('아침'),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: lChecked,
                              onChanged: (bool? value) {
                                setState(() {
                                  lChecked = value!;
                                });
                              },
                            ),
                            const Text('점심'),
                          ],
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: dChecked,
                              onChanged: (bool? value) {
                                setState(() {
                                  dChecked = value!;
                                });
                              },
                            ),
                            const Text('저녁'),
                          ],
                        ),
                      ],
                    ),
                    Column(children: []),
                  ],
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('취소'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('추가'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}
