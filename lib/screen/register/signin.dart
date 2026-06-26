import 'package:flutter/material.dart';
import 'package:pillnote/screen/register/signup.dart';
import 'package:pillnote/widgets/custom_text_field.dart';

import '../home.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.02),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "안녕하세요!",
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: screenWidth * 0.07,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Image.asset(
                    'assets/images/wave.gif',
                    width: screenWidth * 0.1,
                  ),
                ],
              ),
              Text(
                "PillNote에 오신것을 환영합니다.",
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenHeight * 0.08),
              const CustomTextField(
                label: '이메일',
                hint: 'example@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: screenHeight * 0.02),
              const CustomTextField(
                label: '비밀번호',
                hint: '비밀번호를 입력해주세요.',
                isPassword: true,
              ),
              SizedBox(height: screenHeight * 0.3),
              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.07,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: Color(0xFF2563EB),
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
              SizedBox(height: screenHeight * 0.01),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const Home(),
                      ),
                      (Route<dynamic> route) => false,
                    ),
                    child: Text(
                      "로그인 없이 시작하기",
                      style: TextStyle(
                        color: Color(0XFF7CA5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (context) => Signup()),
                    ),
                    child: Text(
                      "회원가입",
                      style: TextStyle(
                        color: Color(0XFF7CA5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
