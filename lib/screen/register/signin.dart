import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/main.dart';
import 'package:pillnote/screen/register/signup.dart';
import 'package:pillnote/widgets/custom_text_field.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  State<Signin> createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void _handleSignin() {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이메일과 비밀번호를 입력해주세요.")),
      );
      return;
    }

    Controller.setOnboardingCompleted(true);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (context) => const Main()),
      (route) => false,
    );
  }

  void _startWithoutLogin() {
    Controller.setOnboardingCompleted(true);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (context) => const Main()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
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
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/wave.gif',
                    width: screenWidth * 0.1,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
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
              CustomTextField(
                label: '이메일',
                hint: 'example@email.com',
                keyboardType: TextInputType.emailAddress,
                controller: emailController,
              ),
              SizedBox(height: screenHeight * 0.02),
              CustomTextField(
                label: '비밀번호',
                hint: '비밀번호를 입력해주세요.',
                isPassword: true,
                controller: passwordController,
              ),
              SizedBox(height: screenHeight * 0.25),
              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.07,
                child: ElevatedButton(
                  onPressed: _handleSignin,
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
              SizedBox(height: screenHeight * 0.01),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _startWithoutLogin,
                    child: Text(
                      "로그인 없이 시작하기",
                      style: TextStyle(
                        color: const Color(0XFF7CA5FF),
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (context) => const Signup()),
                    ),
                    child: Text(
                      "회원가입",
                      style: TextStyle(
                        color: const Color(0XFF7CA5FF),
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
