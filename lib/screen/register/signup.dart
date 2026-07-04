import 'package:flutter/material.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/main.dart';
import 'package:pillnote/widgets/custom_text_field.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  void _handleSignup() {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("모든 항목을 입력해주세요.")),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("비밀번호가 일치하지 않습니다.")),
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
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.02),
              Text(
                "편리한 복약 관리,",
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: screenWidth * 0.065,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              Text(
                "필노트와 함께 시작해보세요!",
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: screenWidth * 0.065,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              SizedBox(height: screenHeight * 0.05),

              CustomTextField(
                label: '이름',
                hint: '이름을 입력해주세요.',
                controller: nameController,
              ),
              SizedBox(height: screenHeight * 0.02),
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
              SizedBox(height: screenHeight * 0.02),
              CustomTextField(
                label: '비밀번호 확인',
                hint: '비밀번호를 다시 입력해주세요.',
                isPassword: true,
                controller: confirmPasswordController,
              ),

              SizedBox(height: screenHeight * 0.07),

              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.065,
                child: ElevatedButton(
                  onPressed: _handleSignup,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: Text(
                    "회원가입 완료",
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _startWithoutLogin,
                    child: Text(
                      "로그인 없이 시작하기",
                      style: TextStyle(
                        color: const Color(0XFF7CA5FF),
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 12,
                    color: Colors.grey.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      "로그인",
                      style: TextStyle(
                        color: const Color(0XFF7CA5FF),
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth * 0.035,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.05),
            ],
          ),
        ),
      ),
    );
  }
}
