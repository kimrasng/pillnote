import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:pillnote/screen/AppBar.dart';
import 'package:pillnote/screen/component/photoAdd.dart';

class AddScreen extends StatelessWidget {
  const AddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "약 추가"),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              _PillAdd(),
              _PillAutoSearch(),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const photoAdd(),
                    ),
                  );
                },
                child: Text(
                  "사진으로 추가하기",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _PillAutoSearch() =>
      Column(
        children: [
          Row(
            children: [
              Image.network(
                "https://common.health.kr/shared/images/sb_photo/big3/201902280008004.jpg",
                width: 100,
              ),
              SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("제품명 : 아세요정"),
                  Text("성분 및 함량 : Aceclofenac 100mg")
                ],
              )
            ],
          ),
        ],
      );

  Widget _PillAdd() => Column(
    children: [
      TextField(
        decoration: const InputDecoration(
          labelText: "약 이름",
        ),
        onChanged: (text) async {
          final serviceKey = dotenv.env['API_KEY'];
          var res = await http.get(Uri.parse('https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService03/getMdcinGrnIdntfcInfoList03?serviceKey=$serviceKey&pageNo=1&numOfRows=100&type=json&item_name=$text'));
          print(res.body);
        },
      ),
    ],
  );
}
