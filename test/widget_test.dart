import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/main.dart';
import 'package:pillnote/screen/register/register.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
  });

  testWidgets('onboarding opens the email-only login flow', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('복약 관리의 시작\nPillNote'), findsOneWidget);
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('이메일 주소'), findsOneWidget);
    expect(find.text('인증번호 받기'), findsOneWidget);
  });

  testWidgets('login validates an empty email without contacting the server', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Register()));
    await tester.tap(find.text('인증번호 받기'));
    await tester.pump();
    expect(find.text('올바른 이메일을 입력해주세요.'), findsOneWidget);
  });
}
