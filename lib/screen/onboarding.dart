import 'package:flutter/material.dart';
import 'package:pillnote/screen/register/register.dart';

class Onboarding extends StatefulWidget {
  Onboarding({super.key});

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
          padding: .symmetric(horizontal: screenWidth * 0.08),
          child: Column(
            mainAxisAlignment: .center,
            children: [
              Spacer(flex: 2),
              Image.asset(
                'assets/images/onboarding-img.png',
                width: screenWidth * 0.7,
                fit: .contain,
              ),
              Spacer(),
              Text(
                "약과 영양제를 더 쉽게\nPillNote 하나로",
                textAlign: .center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: screenWidth * 0.08,
                  fontWeight: .bold,
                  color: Colors.black,
                ),
              ),
              Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (context) => Register()),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: .circular(15),
                    ),
                    backgroundColor: Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: Text(
                    "시작하기",
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: screenWidth * 0.05,
                      fontWeight: .bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
