import 'package:flutter/material.dart';
import 'package:pillnote/widgets/custom_text_field.dart';

class Pillsearch extends StatefulWidget {
  const Pillsearch({super.key});

  @override
  State<Pillsearch> createState() => _PillsearchState();
}

class _PillsearchState extends State<Pillsearch> {
  late final size = MediaQuery.of(context).size;
  late final double screenWidth = size.width;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: screenWidth * 0.9,
          child: Column(
            children: [
              const SizedBox(height: 10),
              const CustomTextField(
                label: '약 검색',
                hint: "약 이름을 입력 해주세요.",
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: 30,
                  separatorBuilder: (context, index) => SizedBox(height: 10),
                  itemBuilder: (context, index) => Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        "data",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
