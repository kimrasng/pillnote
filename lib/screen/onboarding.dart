import 'package:flutter/material.dart';
import 'package:pillnote/screen/register/register.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Image.asset(
                'assets/images/onboarding-img.png',
                width: screenWidth * 0.6,
                fit: .contain,
              ),
              const Spacer(flex: 2),
              Text(
                "복약 관리의 시작\nPillNote",
                textAlign: .center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: screenWidth * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "매일 챙겨야 하는 약과 영양제\n이제 잊지 말고 관리하세요",
                textAlign: .center,
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: screenHeight * 0.07,
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (context) => Register()),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(screenWidth * 0.04),
                    ),
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  child: Text(
                    "시작하기",
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.06),
            ],
          ),
        ),
      ),
    );
  }
}
