import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/main.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/management/medication_form.dart';
import 'package:pillnote/screen/management/pill_group_edit.dart';
import 'package:pillnote/screen/pages/home.dart';
import 'package:pillnote/screen/pages/menu.dart';
import 'package:pillnote/screen/pages/pill.dart';
import 'package:pillnote/screen/register/register.dart';
import 'package:pillnote/screen/register/verification.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
  });
  testWidgets(
    'manual registration connects search to schedule and saves without stock',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Pillsearch()));
      await tester.tap(find.text('검색 없이 직접 입력'));
      await tester.pumpAndSettle();
      final name = find.widgetWithText(TextFormField, '약 이름');
      await tester.enterText(name, '직접 등록한 약');
      await tester.tap(find.text('내 약 상자에 등록'));
      await tester.pumpAndSettle();
      expect(Controller.getPills().single['ITEM_NAME'], '직접 등록한 약');
      expect(Controller.getPills().single['times'], ['08:00']);
      expect(Controller.getPills().single['stock'], isNull);
    },
  );
  testWidgets(
    'tapping medication opens details, only check records, undo restores stock',
    (tester) async {
      await Controller.addPill({
        'ITEM_NAME': '테스트약',
        'times': ['08:00'],
      }, 10);
      final id = '${Controller.getPills().single['id']}';
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(home: Home()));
      final doseSemantics = tester.getSemantics(
        find.byKey(ValueKey('dose-$id|08:00')),
      );
      expect(doseSemantics.label, '테스트약 08:00 복용 체크');
      expect(
        doseSemantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
      // Use the dose row rather than the summary's medication name.
      await tester.tap(find.text('테스트약'));
      await tester.pumpAndSettle();
      expect(
        Controller.getHistoryByDate(Medication.dateKey(DateTime.now())),
        isEmpty,
      );
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('dose-$id|08:00')));
      await tester.pumpAndSettle();
      expect(Controller.getPills().single['stock'], 9);
      await tester.tap(find.text('실행 취소'));
      await tester.pumpAndSettle();
      expect(Controller.getPills().single['stock'], 10);
      expect(
        Controller.getHistoryByDate(Medication.dateKey(DateTime.now())),
        isEmpty,
      );
    },
  );
  testWidgets('empty stock input cannot silently save as zero', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MedicationForm()));
    await tester.enterText(find.widgetWithText(TextFormField, '약 이름'), '테스트약');
    final stockToggle = find.widgetWithText(SwitchListTile, '남은 약 수량 관리');
    await tester.scrollUntilVisible(
      find.text('남은 약 수량 관리'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(stockToggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 약 상자에 등록'));
    await tester.pumpAndSettle();
    expect(Controller.getPills(), isEmpty);
    expect(find.text('0 이상의 수량을 입력하세요.'), findsOneWidget);
  });
  testWidgets('compact screens support large text and login keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await Controller.addPill({
      'ITEM_NAME': '이름이 아주 긴 약물 500mg 캡슐',
      'times': ['08:00', '13:00'],
    }, 2);
    for (final page in [
      const Home(),
      const Pill(),
      const Menu(),
      const PillGroupEdit(),
      const MedicationForm(),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: page,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$page');
    }
    await tester.pumpWidget(const MaterialApp(home: Register()));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('인증번호 받기'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('login bottom actions stay in place when the keyboard opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(const MaterialApp(home: Register()));
    await tester.pumpAndSettle();
    ScrollPosition position() =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position().maxScrollExtent, 0);
    final actionPosition = tester.getTopLeft(find.text('인증번호 받기'));
    final guestPosition = tester.getTopLeft(find.text('로그인 없이 시작하기'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    await tester.pumpAndSettle();
    expect(position().maxScrollExtent, greaterThan(0));
    expect(position().pixels, 0);
    expect(tester.getTopLeft(find.text('인증번호 받기')), actionPosition);
    expect(tester.getTopLeft(find.text('로그인 없이 시작하기')), guestPosition);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(position().maxScrollExtent, 0);
    expect(position().pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'verification accepts only six digits and disposes resend countdown',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Verification(email: 'test@example.com')),
      );
      await tester.enterText(find.byType(TextField), '12a345678');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '123456',
      );
      expect(find.text('60초 후 다시 받기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'main navigation uses home, medications, pharmacy, settings order',
    (tester) async {
      await Controller.setOnboardingCompleted(true);
      await tester.pumpWidget(const MyApp());
      final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(
        nav.destinations.cast<NavigationDestination>().map((d) => d.label),
        ['홈', '내 약 상자', '약국', '설정'],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
