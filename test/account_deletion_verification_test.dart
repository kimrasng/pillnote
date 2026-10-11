import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/pages/menu.dart';
import 'package:pillnote/screen/register/verification.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/widgets/auth_layout.dart';
import 'package:pillnote/widgets/auth_step_route.dart';
import 'package:pillnote/widgets/verification_code_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SessionStore> signedInSessions() async {
  final sessions = SessionStore.inMemory();
  await sessions.save(
    const UserSession(
      userId: 'owner',
      email: 'owner@example.com',
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresIn: 900,
      refreshTokenExpiresIn: 2592000,
    ),
  );
  return sessions;
}

Widget app(Widget page) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: page,
);

void main() {
  testWidgets('menu opens shared verification and cancellation keeps account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
    final sessions = await signedInSessions();
    final requests = <http.Request>[];
    final api = ApiClient(
      sessionStore: sessions,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{"data":{"debugCode":"123456","resendAfterSeconds":90}}',
          202,
        );
      }),
    );
    await tester.pumpWidget(app(Menu(apiClient: api, sessionStore: sessions)));
    await tester.scrollUntilVisible(
      find.text('계정 삭제'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AuthLayout), findsOneWidget);
    expect(find.byType(VerificationCodeField), findsOneWidget);
    expect(find.text('계정 삭제 인증'), findsOneWidget);
    expect(find.text('90초 후 다시 받기'), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(Verification))),
      isA<AuthStepRoute>(),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body), {'purpose': 'delete-account'});

    await tester.ensureVisible(find.text('취소'));
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(Verification), findsNothing);
    expect(sessions.isLoggedIn, isTrue);
    expect(requests, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirmed deletion clears local data and returns to login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
    await Controller.addPill({'ITEM_NAME': '테스트약', 'times': <String>[]}, 10);
    final sessions = await signedInSessions();
    final requests = <http.Request>[];
    final api = ApiClient(
      sessionStore: sessions,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"data":{}}', 200);
      }),
    );
    await tester.pumpWidget(app(Menu(apiClient: api, sessionStore: sessions)));
    await tester.scrollUntilVisible(
      find.text('계정 삭제'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    expect(requests, hasLength(1));
    final confirm = find.widgetWithText(FilledButton, '계정 삭제');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests.last.method, 'DELETE');
    expect(jsonDecode(requests.last.body), {'verificationCode': '123456'});
    expect(sessions.isLoggedIn, isFalse);
    expect(Controller.getPills(), isEmpty);
    expect(find.byType(Verification), findsNothing);
    expect(find.byType(Menu), findsNothing);
    expect(find.text('로그인 없이 시작하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'deletion requires confirmation and keeps failed codes editable',
    (tester) async {
      final sessions = await signedInSessions();
      final requests = <http.Request>[];
      final response = Completer<http.Response>();
      final api = ApiClient(
        sessionStore: sessions,
        client: MockClient((request) {
          requests.add(request);
          return response.future;
        }),
      );
      await tester.pumpWidget(
        app(
          Verification.accountDeletion(
            email: 'owner@example.com',
            apiClient: api,
            onDeleteAccount: api.deleteAccount,
          ),
        ),
      );
      final field = find.byType(TextField);
      final confirm = find.widgetWithText(FilledButton, '계정 삭제');
      await tester.enterText(field, '123');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(requests, isEmpty);
      expect(find.text('6자리 인증번호를 입력해주세요.'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(field)).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.enterText(field, '123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(requests, isEmpty);
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(requests, hasLength(1));
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/v1/me');
      expect(jsonDecode(requests.single.body), {'verificationCode': '123456'});
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope))
            .canPop,
        isFalse,
      );

      response.complete(
        http.Response(
          '{"error":{"message":"인증번호가 일치하지 않습니다."}}',
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('인증번호가 일치하지 않습니다.'), findsOneWidget);
      expect(tester.widget<TextField>(field).enabled, isTrue);
      expect(tester.widget<TextField>(field).controller!.text, '123456');
      expect(sessions.isLoggedIn, isTrue);
      ScaffoldMessenger.of(tester.element(field)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.enterText(field, '123457');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(jsonDecode(requests.last.body), {'verificationCode': '123457'});
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final successful in [true, false]) {
    testWidgets(
      'deletion resend ${successful ? 'uses server cooldown and clears digits' : 'failure preserves digits'}',
      (tester) async {
        final sessions = await signedInSessions();
        final requests = <http.Request>[];
        final api = ApiClient(
          sessionStore: sessions,
          client: MockClient((request) async {
            requests.add(request);
            return successful
                ? http.Response(
                    '{"data":{"debugCode":"654321","resendAfterSeconds":90}}',
                    202,
                  )
                : http.Response(
                    '{"error":{"code":"SERVICE_UNAVAILABLE"}}',
                    503,
                  );
          }),
        );
        await tester.pumpWidget(
          app(
            Verification.accountDeletion(
              email: 'owner@example.com',
              apiClient: api,
              resendCooldownSeconds: 2,
              onDeleteAccount: api.deleteAccount,
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), '12');
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1초 후 다시 받기'), findsOneWidget);
        expect(requests, isEmpty);
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('인증번호 다시 받기'));
        await tester.pumpAndSettle();

        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/v1/auth/email/start');
        expect(requests.single.headers['authorization'], 'Bearer access');
        expect(jsonDecode(requests.single.body), {'purpose': 'delete-account'});
        final field = tester.widget<VerificationCodeField>(
          find.byType(VerificationCodeField),
        );
        expect(field.controller.text, successful ? '' : '12');
        expect(field.arrivalSequence, successful ? 1 : 0);
        if (successful) {
          expect(find.text('90초 후 다시 받기'), findsOneWidget);
          expect(find.text('개발 환경 인증번호: 654321'), findsOneWidget);
        }
        expect(sessions.isLoggedIn, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'compact deletion verification scrolls above keyboard with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.8),
            ),
            child: child!,
          ),
          home: Verification.accountDeletion(
            email: 'long.email.address@example.com',
            onDeleteAccount: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 360);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, '계정 삭제');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(280));
      expect(confirm.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
