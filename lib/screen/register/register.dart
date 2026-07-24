import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/main.dart';
import 'package:pillnote/screen/register/verification.dart';
import 'package:pillnote/widgets/custom_text_field.dart';

class Register extends StatefulWidget {
  Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final emailController = TextEditingController();

  void _handleRegister() {
    if (emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("이메일을 입력해주세요.")),
      );
      return;
    }

    // Controller.setOnboardingCompleted(true);
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => Verification()),
    );
  }

  void _startWithoutLogin() {
    Controller.setOnboardingCompleted(true);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (context) => Main()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: .symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  Row(
                    crossAxisAlignment: .center,
                    children: [
                      Text(
                        "안녕하세요!",
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: screenWidth * 0.07,
                          fontWeight: .bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Image.asset(
                        'assets/images/wave.gif',
                        width: screenWidth * 0.1,
                        errorBuilder: (context, error, stackTrace) => SizedBox(),
                      ),
                    ],
                  ),
                  Text(
                    "PillNote에 오신것을 환영합니다.",
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: screenWidth * 0.06,
                      fontWeight: .bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  CustomTextField(
                    label: '이메일',
                    hint: 'example@email.com',
                    keyboardType: TextInputType.emailAddress,
                    controller: emailController,
                  ),
                  SizedBox(height: screenHeight * 0.2), // 버튼 공간 확보
                ],
              ),
            ),
            Positioned(
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              bottom: screenHeight * 0.04,
              child: Column(
                mainAxisSize: .min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.07,
                    child: ElevatedButton(
                      onPressed: _handleRegister,
                     style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: .circular(15),
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
                          fontWeight: .bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Row(
                    mainAxisAlignment: .center,
                    children: [
                      TextButton(
                        onPressed: _startWithoutLogin,
                        child: Text(
                          "로그인 없이 시작하기",
                          style: TextStyle(
                            color: Color(0XFF7CA5FF),
                            fontWeight: .bold,
                            fontSize: screenWidth * 0.035,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
