import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/main.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/push_notification_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Run on both platforms with:
/// `flutter test integration_test/mobile_qa_test.dart -d <device-id>`
/// Public API checks are read-only; local QA data uses a separate preferences prefix.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('pillnote.qa.');

  testWidgets('guest medication lifecycle persists through native storage', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await AppServices.initialize();
    addTearDown(() async {
      AppServices.instance.dispose();
      await prefs.clear();
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await _tap(tester, find.text('시작하기'));
    await _tap(tester, find.text('로그인 없이 시작하기'));
    await _tab(tester, '내 약 상자');
    await _tap(tester, find.text('약 추가'));
    await _tap(tester, find.text('검색 없이 직접 입력'));
    await tester.enterText(
      find.widgetWithText(TextFormField, '약 이름'),
      'QA 테스트약',
    );
    await _tap(tester, find.text('내 약 상자에 등록'));
    final pill = AppServices.instance.medications.getPills().single;
    final id = pill['id'].toString();
    expect(pill['stock'], isNull);
    expect(pill['times'], ['08:00']);
    expect(find.text('QA 테스트약'), findsOneWidget);

    await _tap(tester, find.text('QA 테스트약'));
    await _tap(tester, find.widgetWithText(TextButton, '설정'));
    await _tap(tester, find.widgetWithText(SwitchListTile, '수량 관리'));
    await tester.enterText(
      find.widgetWithText(TextFormField, '현재 보유 수량'),
      '10',
    );
    await _tap(tester, find.text('저장'));
    expect(AppServices.instance.medications.getPills().single['stock'], 10);
    await _tap(tester, find.byTooltip('뒤로'));
    await _tab(tester, '홈');
    await _tap(tester, find.byKey(ValueKey('dose-$id|08:00')));
    expect(AppServices.instance.medications.getPills().single['stock'], 9);
    await _tap(tester, find.text('실행 취소'));
    expect(AppServices.instance.medications.getPills().single['stock'], 10);
    expect(
      AppServices.instance.intakes.getHistoryByDate(
        Medication.dateKey(DateTime.now()),
      ),
      isEmpty,
    );

    await _tab(tester, '내 약 상자');
    await _tap(tester, find.text('약 묶음 관리'));
    await _tap(tester, find.text('약 묶음 만들기').last);
    await tester.enterText(
      find.widgetWithText(TextFormField, '묶음 이름'),
      'QA 아침 묶음',
    );
    await _tap(tester, find.widgetWithText(CheckboxListTile, 'QA 테스트약'));
    await _tap(tester, find.text('약 묶음 저장'));
    expect(AppServices.instance.medications.getGroups(), hasLength(1));
    expect(AppServices.instance.scheduledDoses(DateTime.now()), hasLength(1));
    await _tap(tester, find.text('QA 아침 묶음'));
    await _tap(tester, find.byTooltip('묶음 삭제'));
    await _tap(tester, find.widgetWithText(FilledButton, '삭제'));
    expect(AppServices.instance.medications.getGroups(), isEmpty);
    await _tap(tester, find.byTooltip('뒤로'));

    await _tap(tester, find.text('QA 테스트약'));
    await _tap(tester, find.text('이 약 보관하기'));
    await _tap(tester, find.widgetWithText(FilledButton, '보관'));
    expect(AppServices.instance.scheduledDoses(DateTime.now()), isEmpty);
    await _tap(tester, find.text('다시 관리하기'));
    expect(AppServices.instance.scheduledDoses(DateTime.now()), hasLength(1));
    await _tap(tester, find.byTooltip('뒤로'));

    await _tab(tester, '설정');
    await _tap(tester, find.text('놓친 복용 알림'));
    await _tap(tester, find.widgetWithText(ChoiceChip, '60분'));
    await _tap(tester, find.widgetWithText(SwitchListTile, '보호자에게 알림 보내기'));
    await _tap(tester, find.text('알림 설정 저장'));
    expect(AppServices.instance.getSettings()['reminderMinutes'], 60);
    expect(AppServices.instance.getSettings()['guardianAlertsEnabled'], false);

    await prefs.reload();
    await AppServices.initialize();
    expect(AppServices.instance.medications.getPills().single['stock'], 10);
    expect(AppServices.instance.getSettings()['reminderMinutes'], 60);
    expect(AppServices.instance.shouldShowOnboarding, false);
    expect(AppServices.instance.medications.getGroups(), isEmpty);
    await _tap(tester, find.text('이메일로 로그인'));
    await tester.tap(find.text('인증번호 받기'));
    // Live devices can still be showing the preceding settings-save SnackBar.
    // Wait for the validation message to enter the shared messenger's queue.
    for (
      var attempt = 0;
      attempt < 60 && find.text('올바른 이메일을 입력해주세요.').evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('올바른 이메일을 입력해주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('native HTTPS client matches production public API responses', (
    tester,
  ) async {
    final client = ApiClient(sessionStore: SessionStore.inMemory());
    expect((await client.health())['status'], 'ok');
    final drugs = await client.searchDrugs('타이레놀', limit: 2);
    expect(drugs, isNotEmpty);
    expect(drugs.first['ITEM_NAME'], isNotEmpty);
    final detail = await client.drugDetail(drugs.first['ITEM_SEQ'].toString());
    expect(detail['ITEM_NAME'], isNotEmpty);
    final pharmacies = await client.searchPharmacies(
      latitude: 37.5665,
      longitude: 126.9780,
      radius: 1000,
      limit: 2,
    );
    expect(pharmacies, isNotEmpty);
    expect(pharmacies.first['latitude'], isA<num>());
    expect(pharmacies.first['longitude'], isA<num>());
    await expectLater(
      client.searchDrugs(''),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
  });

  testWidgets('native secure storage and Firebase initialization work', (
    tester,
  ) async {
    const storage = FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.unlocked_this_device,
        synchronizable: false,
      ),
      aOptions: AndroidOptions(migrateWithBackup: true),
    );
    const key = 'pillnote_qa_native_token';
    addTearDown(() => storage.delete(key: key));
    await storage.write(key: key, value: 'qa-token');
    expect(await storage.read(key: key), 'qa-token');
    await storage.delete(key: key);
    expect(await storage.read(key: key), isNull);
    final zone = await FlutterTimezone.getLocalTimezone();
    expect(zone.identifier, isNotEmpty);
    await PushNotificationService.instance.initialize();
    expect(
      PushNotificationService.instance.isInitialized,
      true,
      reason: PushNotificationService.instance.lastError,
    );
  });
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) => _tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);
