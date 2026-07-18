import 'package:flutter/material.dart';
import '../../controller/controller.dart';
import '../../widgets/custom_text_field.dart';
import '../main.dart';

class Verification extends StatefulWidget {
  const Verification({super.key});

  @override
  State<Verification> createState() => _VerificationState();
}

class _VerificationState extends State<Verification> {
  final codeController = TextEditingController();

  void _handleVerify() {
    if (codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("인증번호를 입력해주세요.")),
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
    codeController.dispose();
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
        child: Stack(
          children: [
            SingleChildScrollView(
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
                    "인증번호를 입력해주세요.",
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  CustomTextField(
                    label: '인증번호',
                    hint: '000000',
                    keyboardType: TextInputType.number,
                    controller: codeController,
                  ),
                  // 하단 버튼 공간 확보를 위한 여백
                  SizedBox(height: screenHeight * 0.2),
                ],
              ),
            ),
            Positioned(
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              bottom: screenHeight * 0.04,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: screenHeight * 0.07,
                    child: ElevatedButton(
                      onPressed: _handleVerify,
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
