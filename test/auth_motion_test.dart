import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/register/register.dart';
import 'package:pillnote/screen/register/verification.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/widgets/app_ui.dart';
import 'package:pillnote/widgets/auth_step_route.dart';
import 'package:pillnote/widgets/home_entry_route.dart';
import 'package:pillnote/widgets/verification_code_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

Color? cellColor(WidgetTester tester, int index, {Finder? within}) {
  final cell = find.byKey(ValueKey('code-cell-$index'));
  final target = within == null
      ? cell
      : find.descendant(of: within, matching: cell);
  return (tester.widget<Container>(target).decoration! as BoxDecoration).color;
}

Future<void> openLogin(
  WidgetTester tester,
  ApiClient api, {
  bool reduceMotion = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => Register(apiClient: api)),
            ),
            child: const Text('로그인 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('로그인 열기'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'home entry ${reduceMotion ? 'respects reduced motion' : 'zooms forward and clears login history'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: Builder(
              builder: (context) => HomeDepthTransition(
                outgoing: true,
                animation: ModalRoute.of(context)!.secondaryAnimation!,
                child: Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      HomeEntryRoute(
                        animate: !reduceMotion,
                        builder: (_) =>
                            const Scaffold(body: Center(child: Text('홈 화면'))),
                      ),
                      (_) => false,
                    ),
                    child: const Text('로그인 완료'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('로그인 완료'));
        await tester.pump();
        if (!reduceMotion) {
          await tester.pump(const Duration(milliseconds: 280));
          final homeTransition = find.ancestor(
            of: find.text('홈 화면'),
            matching: find.byType(HomeDepthTransition),
          );
          final homeScale = tester
              .widget<Transform>(
                find
                    .descendant(
                      of: homeTransition,
                      matching: find.byType(Transform),
                    )
                    .first,
              )
              .transform
              .entry(0, 0);
          expect(homeScale, allOf(greaterThan(.88), lessThan(1)));
          final outgoingScale = tester
              .widget<Transform>(
                find
                    .ancestor(
                      of: find.text('로그인 완료'),
                      matching: find.byType(Transform),
                    )
                    .first,
              )
              .transform
              .entry(0, 0);
          expect(outgoingScale, greaterThan(1));
        }
        await tester.pumpAndSettle();
        expect(find.text('홈 화면'), findsOneWidget);
        expect(find.text('로그인 완료'), findsNothing);
        expect(Navigator.canPop(tester.element(find.text('홈 화면'))), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('wave repeats on filled cells and stops only when disabled', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Widget field(int sequence, {bool enabled = true}) => MaterialApp(
      home: Scaffold(
        body: VerificationCodeField(
          controller: controller,
          autofocus: false,
          enabled: enabled,
          arrivalDelay: Duration.zero,
          arrivalSequence: sequence,
        ),
      ),
    );
    await tester.pumpWidget(field(0));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 550));
    expect(cellColor(tester, 0), isNot(wash));
    expect(cellColor(tester, 5), wash);
    await tester.pump(const Duration(milliseconds: 1700));
    expect(cellColor(tester, 0), wash);
    expect(cellColor(tester, 5), isNot(wash));
    await tester.pump(const Duration(milliseconds: 750));
    for (var index = 0; index < 6; index++) {
      expect(cellColor(tester, index), wash);
    }
    await tester.pump(const Duration(milliseconds: 1550));
    expect(cellColor(tester, 0), isNot(wash));
    await tester.pumpWidget(field(1));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 550));
    expect(cellColor(tester, 0), isNot(wash));
    controller.text = '123456';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));
    expect(cellColor(tester, 5), isNot(wash));
    expect(find.text('6'), findsOneWidget);
    await tester.pumpWidget(field(1, enabled: false));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    controller.text = '';
    await tester.pumpWidget(field(1));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 550));
    expect(cellColor(tester, 0), isNot(wash));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('every filled cell has exactly one brightness peak per cycle', (
    tester,
  ) async {
    final controller = TextEditingController(text: '123456');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerificationCodeField(
            controller: controller,
            arrivalDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    final previous = List<double>.filled(6, 0);
    final rising = List<bool>.filled(6, false);
    final peaks = List<int>.filled(6, 0);
    for (var frame = 0; frame < 100; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      for (var index = 0; index < 6; index++) {
        final intensity = wash.r - cellColor(tester, index)!.r;
        if (intensity > previous[index] + .000001) rising[index] = true;
        if (intensity < previous[index] - .000001 && rising[index]) {
          peaks[index]++;
          rising[index] = false;
        }
        previous[index] = intensity;
      }
    }
    expect(peaks, List.filled(6, 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('selection does not add another background or cursor animation', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VerificationCodeField(
            controller: controller,
            arrivalDelay: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 550));
    final selectedColor = cellColor(tester, 0);
    final field = tester.widget<TextField>(find.byType(TextField));
    final cursor = find.byKey(const ValueKey('code-cursor'));
    final opacity = tester.widget<Opacity>(cursor).opacity;
    field.focusNode!.unfocus();
    await tester.pump();
    expect(cellColor(tester, 0), selectedColor);
    field.focusNode!.requestFocus();
    await tester.pump();
    expect(cellColor(tester, 0), selectedColor);
    final colors = List.generate(6, (index) => cellColor(tester, index));
    controller.text = '12';
    await tester.pump();
    expect(List.generate(6, (index) => cellColor(tester, index)), colors);
    await tester.pump(const Duration(milliseconds: 2450));
    expect(cellColor(tester, 0), wash);
    expect(tester.widget<Opacity>(cursor).opacity, opacity);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reduced motion skips the arrival wave and delayed work disposes',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: VerificationCodeField(
                controller: controller,
                autofocus: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      for (var index = 0; index < 6; index++) {
        expect(cellColor(tester, index), wash);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VerificationCodeField(
              controller: controller,
              autofocus: false,
            ),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login changes content with a stationary shell and preserves email on back',
    (tester) async {
      var requests = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          requests++;
          expect(jsonDecode(request.body)['email'], 'hello@example.com');
          return http.Response('{"data":{}}', 200);
        }),
      );
      await openLogin(tester, api);
      expect(find.byTooltip('뒤로'), findsOneWidget);
      expect(find.text('로그인 없이 시작하기'), findsOneWidget);
      expect(find.text('돌아가기'), findsNothing);
      expect(find.text('PillNote'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Hello@Example.COM');
      await tester.tap(find.text('인증번호 받기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final outgoing = tester.widget<ContentReveal>(
        find.byKey(const ValueKey('auth-fields-reveal')),
      );
      expect(outgoing.animation.value, allOf(greaterThan(0), lessThan(1)));
      expect(find.byTooltip('뒤로'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 90));
      await tester.pump();
      final verification = find.byType(Verification);
      expect(verification, findsOneWidget);
      expect(ModalRoute.of(tester.element(verification)), isA<AuthStepRoute>());
      await tester.pump(const Duration(milliseconds: 210));
      final incoming = tester.widget<ContentReveal>(
        find.descendant(
          of: verification,
          matching: find.byKey(const ValueKey('auth-fields-reveal')),
        ),
      );
      expect(incoming.animation.value, allOf(greaterThan(0), lessThan(1)));
      expect(
        find.descendant(of: verification, matching: find.byTooltip('뒤로')),
        findsNothing,
      );
      expect(find.text('PillNote'), findsNothing);
      final scaffold = find.descendant(
        of: verification,
        matching: find.byType(Scaffold),
      );
      expect(tester.getTopLeft(scaffold), Offset.zero);
      await tester.pump(const Duration(milliseconds: 300));
      expect(requests, 1);
      await tester.enterText(
        find.descendant(of: verification, matching: find.byType(TextField)),
        '123456',
      );
      await tester.pump();
      await tester.tap(find.text('이메일 다시 입력'));
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      final returning = tester.widget<ContentReveal>(
        find.descendant(
          of: find.byType(Register),
          matching: find.byKey(const ValueKey('auth-fields-reveal')),
        ),
      );
      expect(returning.animation.value, allOf(greaterThan(0), lessThan(1)));
      expect(find.byType(Verification), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('로그인'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hello@Example.COM',
      );
      expect(find.text('인증번호 받기'), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final leaving = tester.widget<ContentReveal>(
        find.byKey(const ValueKey('auth-fields-reveal')),
      );
      expect(leaving.animation.value, allOf(greaterThan(0), lessThan(1)));
      await tester.pumpAndSettle();
      expect(find.text('로그인 열기'), findsOneWidget);
      expect(find.byType(Register), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('login can be cancelled while its email request is pending', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;
    final api = ApiClient(
      client: MockClient((_) {
        requests++;
        return response.future;
      }),
    );
    await openLogin(tester, api);
    await tester.enterText(find.byType(TextField), 'hello@example.com');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pump();
    expect(requests, 1);
    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.text('로그인 열기'), findsOneWidget);
    response.complete(http.Response('{"data":{}}', 200));
    await tester.pumpAndSettle();
    expect(find.byType(Verification), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion changes auth steps immediately', (tester) async {
    final api = ApiClient(
      client: MockClient((_) async => http.Response('{"data":{}}', 200)),
    );
    await openLogin(tester, api, reduceMotion: true);
    await tester.enterText(find.byType(TextField), 'hello@example.com');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pumpAndSettle();
    final verification = find.byType(Verification);
    expect(verification, findsOneWidget);
    final route = ModalRoute.of(tester.element(verification))! as AuthStepRoute;
    expect(route.transitionDuration, Duration.zero);
    final fields = tester.widget<ContentReveal>(
      find.descendant(
        of: verification,
        matching: find.byKey(const ValueKey('auth-fields-reveal')),
      ),
    );
    expect(fields.animation.value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final successful in [true, false]) {
    testWidgets(
      'resend ${successful ? 'replays arrival and clears old digits' : 'failure preserves digits'}',
      (tester) async {
        var requests = 0;
        final api = ApiClient(
          client: MockClient((_) async {
            requests++;
            return successful
                ? http.Response('{"data":{"debugCode":"654321"}}', 200)
                : http.Response('{"error":{"message":"다시 시도해주세요."}}', 400);
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Verification(email: 'hello@example.com', apiClient: api),
          ),
        );
        await tester.enterText(find.byType(TextField), '12');
        await tester.pump(const Duration(seconds: 61));
        await tester.tap(find.text('인증번호 다시 받기'));
        await tester.pump();
        await tester.pump();
        final field = tester.widget<VerificationCodeField>(
          find.byType(VerificationCodeField),
        );
        expect(requests, 1);
        expect(field.arrivalSequence, successful ? 1 : 0);
        expect(field.controller.text, successful ? '' : '12');
        if (successful) {
          expect(find.text('60초 후 다시 받기'), findsOneWidget);
          expect(find.text('개발 환경 인증번호: 654321'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
