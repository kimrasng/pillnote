import 'package:flutter/material.dart';
import 'package:pillnote/screen/register/signin.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/onboarding-img.png'),
          Text(
            "약과 영양제를 더 쉽게",
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 26,
              fontWeight: .w600,
            ),
          ),
          Text(
            "복용 알림부터 기록까지 PillNote 하나로",
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: .w600,
            ),
          ),
          SizedBox(height: 90),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => const Signin()),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Color(0xFF7A9A99),
              foregroundColor: Colors.white,
            ),
            child: Container(
              alignment: .center,
              width: 300,
              height: 60,
              child: Text(
                "다음",
                style: TextStyle(fontFamily: 'Pretendard', fontSize: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
