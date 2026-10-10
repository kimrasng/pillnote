import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/management/medication_form.dart';
import 'package:pillnote/screen/management/pill_group_edit.dart';
import 'package:pillnote/screen/management/pilmanagement.dart';
import 'package:pillnote/screen/onboarding.dart';
import 'package:pillnote/screen/register/register.dart';
import 'package:pillnote/screen/register/verification.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
  });

  void screen(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }

  Widget app(Widget page, {double scale = 1}) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: page,
  );

  for (final size in [const Size(390, 844), const Size(320, 640)]) {
    testWidgets('onboarding centers its introduction on $size', (tester) async {
      screen(tester, size);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      await tester.pumpWidget(app(const Onboarding()));
      await tester.pumpAndSettle();
      final introduction = tester.getRect(
        find.byKey(const ValueKey('onboarding-introduction')),
      );
      final action = tester.getRect(find.byType(FilledButton));
      final spaceAbove = introduction.top - 24 - 28;
      final spaceBelow = action.top - 24 - introduction.bottom;
      expect(spaceAbove, closeTo(spaceBelow, .01));
      expect(introduction.center.dx, closeTo(size.width / 2, .01));
      expect(action.bottom, closeTo(size.height - 34 - 24, .01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact onboarding scrolls with large text', (tester) async {
    screen(tester, const Size(320, 568));
    await tester.pumpWidget(app(const Onboarding(), scale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final page in <Widget>[
    const Register(),
    const Verification(email: 'test@example.com'),
    const MedicationForm(),
    const PillGroupEdit(),
  ]) {
    testWidgets('$page keeps bottom actions in place above scrolling content', (
      tester,
    ) async {
      screen(tester, const Size(390, 844));
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
      await tester.pumpWidget(app(page));
      await tester.pumpAndSettle();
      final action = find.byType(FilledButton).last;
      final original = tester.getRect(action);
      tester.view.padding = const FakeViewPadding(top: 24);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.getRect(action), original);
      if (page is Register || page is Verification) {
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(524));
        expect(action.hitTestable(), findsOneWidget);
      }
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.getRect(action), original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('covered inputs scroll above the keyboard on focus changes', (
    tester,
  ) async {
    screen(tester, const Size(360, 720));
    final controller = ScrollController();
    addTearDown(controller.dispose);
    const first = ValueKey('first-input');
    const second = ValueKey('second-input');
    await tester.pumpWidget(
      app(
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: PageScrollView(
            title: '입력 화면',
            controller: controller,
            children: const [
              SizedBox(height: 360),
              TextField(key: first),
              SizedBox(height: 100),
              TextField(key: second),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(first), '첫 번째');
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    tester.view.viewInsets = const FakeViewPadding(bottom: 330);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(first)).bottom, lessThanOrEqualTo(370));
    final offset = controller.offset;
    await tester.enterText(find.byKey(second), '두 번째');
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(offset));
    expect(tester.getRect(find.byKey(second)).bottom, lessThanOrEqualTo(370));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stock editor stays usable with a keyboard and large text', (
    tester,
  ) async {
    screen(tester, const Size(320, 640));
    await Controller.addPill({
      'ITEM_NAME': '테스트약',
      'times': ['08:00'],
    }, 10);
    final pillId = '${Controller.getPills().single['id']}';
    await tester.pumpWidget(app(Pilmanagement(pillId: pillId), scale: 1.5));
    await tester.ensureVisible(find.text('수량 수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수량 수정'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '12');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, '저장');
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(300));
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(Controller.getPills().single['stock'], 12);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
