import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/screen/pages/menu.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('offline logout clears the session and leaves the busy screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Controller.init();
    final sessions = SessionStore.inMemory();
    await sessions.save(
      const UserSession(
        userId: 'qa-owner',
        email: 'qa@example.com',
        accessToken: 'access',
        refreshToken: 'refresh',
        accessTokenExpiresIn: 900,
        refreshTokenExpiresIn: 2592000,
      ),
    );
    final client = ApiClient(
      baseUrl: 'https://api.pillnote.test',
      sessionStore: sessions,
      client: MockClient((request) async {
        expect(request.url.path, '/v1/auth/logout');
        throw http.ClientException('offline');
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Menu(apiClient: client, sessionStore: sessions),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('로그아웃'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(sessions.isLoggedIn, false);
    expect(find.text('로그인 없이 시작하기'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
