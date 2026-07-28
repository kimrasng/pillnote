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
        const SnackBar(content: Text("인증번호를 입력해주세요")),
      );
      return;
    }

    Controller.setOnboardingCompleted(true);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (context) => Main()),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.04),
              Text(
                "인증번호 입력",
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: screenWidth * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "입력하신 이메일로 발송된 6자리 번호를 입력하세요",
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: screenHeight * 0.06),
              CustomTextField(
                label: '인증번호',
                hint: '000000',
                keyboardType: TextInputType.number,
                controller: codeController,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.07,
                child: FilledButton(
                  onPressed: _handleVerify,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  child: Text(
                    "인증 완료",
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.08),
            ],
          ),
        ),
      ),
    );
  }
}
