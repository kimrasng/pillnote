import 'package:flutter/material.dart';
import 'package:pillnote/screen/register/register.dart';
import 'package:pillnote/widgets/app_ui.dart';

class Onboarding extends StatelessWidget {
  const Onboarding({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: SafeArea(
      maintainBottomViewPadding: true,
      child: LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 28, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Column(
                        key: const ValueKey('onboarding-introduction'),
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/images/onboarding-img.png',
                            height: (constraints.maxHeight * .28).clamp(
                              140,
                              240,
                            ),
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '복약 관리의 시작\nPillNote',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '복용할 약을 등록하고,\n오늘의 복용을 하나씩 체크해요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const Register(),
                          ),
                        ),
                        child: const Text('시작하기'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
