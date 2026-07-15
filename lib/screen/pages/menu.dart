import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/widgets/menubar_itme.dart';
import '../register/register.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "메뉴",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: screenWidth * 0.9,
              child: Column(
                children: [
                  SizedBox(height: 20),
                  if (Controller.isLoggedIn())
                    MenubarItme(
                      title: "내 계정",
                      iconsvg: Icons.person_outline,
                      itemName: ["내 정보 수정", "로그아웃"],
                      pages: [],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (context) => const Register()),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                        child: Text(
                          "로그인",
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 15),
                  MenubarItme(
                    title: "알림 설정",
                    iconsvg: Icons.notifications_none,
                    itemName: ["푸시 알림", "알림 시간 설정"],
                    pages: [],
                  ),
                  SizedBox(height: 15),
                  MenubarItme(
                    title: "기타",
                    iconsvg: Icons.info_outline,
                    itemName: ["버전 정보"],
                    pages: [],
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
