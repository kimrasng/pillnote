import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillnote/screen/register/verification.dart';
import 'package:pillnote/widgets/verification_code_field.dart';

void main() {
  testWidgets(
    'filters input, fills six cells, supports autofill and submission',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VerificationCodeField(
              controller: controller,
              onSubmitted: (code) => submitted = code,
            ),
          ),
        ),
      );
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      await tester.enterText(find.byType(TextField), '12a345678');
      await tester.pump();
      expect(controller.text, '123456');
      final fieldSemantics = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(fieldSemantics.label, '인증번호');
      expect(fieldSemantics.value, '123456');
      semantics.dispose();
      for (var index = 0; index < 6; index++) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('code-cell-$index')),
            matching: find.text('${index + 1}'),
          ),
          findsOneWidget,
        );
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, '123456');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pasting a full code replaces partially entered digits', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VerificationCodeField(controller: controller)),
      ),
    );
    await tester.enterText(find.byType(TextField), '12');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '12987654',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );
    await tester.pump();
    expect(controller.text, '987654');
    expect(controller.selection, const TextSelection.collapsed(offset: 6));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'tapping a filled cell replaces its digit and backspace updates cells',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VerificationCodeField(controller: controller)),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      tester.widget<TextField>(find.byType(TextField)).focusNode!.unfocus();
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('code-cell-2'))),
      );
      await tester.pump();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 3),
      );
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '129456',
          selection: TextSelection.collapsed(offset: 3),
        ),
      );
      await tester.pump();
      expect(controller.text, '129456');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '12456',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();
      expect(controller.text, '12456');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('code-cell-5')),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('code-cell-5'))),
      );
      await tester.pump();
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
      expect(find.byKey(const ValueKey('code-cursor')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('waiting cursor stays steady and filled cells keep animating', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: VerificationCodeField(controller: controller)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final cursor = find.byKey(const ValueKey('code-cursor'));
    final before = tester.widget<Opacity>(cursor).opacity;
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<Opacity>(cursor).opacity, before);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(cursor, findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'reduced motion keeps a steady cursor and disabled input stops it',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      Widget page({required bool enabled}) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: VerificationCodeField(
              controller: controller,
              enabled: enabled,
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(enabled: true));
      await tester.pumpAndSettle();
      final cursor = find.byKey(const ValueKey('code-cursor'));
      final opacity = tester.widget<Opacity>(cursor).opacity;
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<Opacity>(cursor).opacity, opacity);
      await tester.pumpWidget(page(enabled: false));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(cursor, findsNothing);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'compact verification supports large text and keyboard scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const Verification(email: 'long.email.address@example.com'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 360);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('인증 완료', skipOffstage: false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getBottomLeft(find.text('인증 완료')).dy,
        lessThanOrEqualTo(280),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
