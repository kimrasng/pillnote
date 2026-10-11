import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pillnote/app/app_services.dart';
import 'package:pillnote/controller/controller.dart';
import 'package:pillnote/data/local_medication_store.dart';
import 'package:pillnote/models/medication.dart';
import 'package:pillnote/screen/features/pillinfo.dart';
import 'package:pillnote/screen/features/pillsearch.dart';
import 'package:pillnote/screen/management/medication_form.dart';
import 'package:pillnote/services/api_client.dart';
import 'package:pillnote/services/api/public_api_cache.dart';
import 'package:pillnote/services/dose_reminder_service.dart';
import 'package:pillnote/services/session_store.dart';
import 'package:pillnote/widgets/medication_reminder_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'helpers/fake_dose_reminder_gateway.dart';

void main() {
  tz_data.initializeTimeZones();
  late LocalMedicationStore store;
  late FakeDoseReminderGateway gateway;
  late DoseReminderService reminders;

  Future<void> prepare() async {
    SharedPreferences.setMockInitialValues({});
    gateway = FakeDoseReminderGateway(tz.getLocation('Asia/Seoul'));
    var tick = 0;
    await AppServices.initialize(
      reminderGateway: gateway,
      now: () =>
          DateTime.utc(2026, 10, 8, 8).add(Duration(microseconds: tick++)),
    );
    store = LocalMedicationStore(await SharedPreferences.getInstance());
    reminders = AppServices.instance.reminders;
    await reminders.refresh();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        220,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('a blank schedule cannot silently become an 08:00 dose', (
    tester,
  ) async {
    await prepare();
    await tester.pumpWidget(const MaterialApp(home: MedicationForm()));
    await tester.enterText(find.widgetWithText(TextFormField, '약 이름'), '테스트약');
    await tap(tester, '등록하기');
    expect(Controller.getPills(), isEmpty);
    expect(find.text('복용 시간을 선택하거나 나중에 시간 설정을 선택해주세요.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, '한 번에 복용할 수량'),
      '0',
    );
    await tap(tester, '나중에 시간 설정');
    await tap(tester, '등록하기');
    expect(Controller.getPills().single['times'], isEmpty);
    expect(Controller.getPills().single['dosage'], 1);
    expect(find.text('등록 완료'), findsOneWidget);
    expect(find.text('복용 시간은 나중에 설정하기로 했어요.'), findsOneWidget);
    expect(find.byType(MedicationReminderStatus), findsNothing);

    await tap(tester, '복용 시간 설정');
    expect(find.text('시간 추가'), findsOneWidget);
    await tap(tester, '시간 추가');
    await tap(tester, 'OK');
    await tap(tester, '변경 사항 저장');
    expect(Controller.getPills(), hasLength(1));
    expect(Controller.getPills().single['times'], ['08:00']);
    expect(find.text('등록 완료'), findsOneWidget);
    expect(find.text('매일 08:00\n한 번에 1정'), findsOneWidget);
  });

  testWidgets(
    'directly registered catalog medicines can still fetch their guidance',
    (tester) async {
      await prepare();
      await Controller.addPill({
        'ITEM_SEQ': '123',
        'ITEM_NAME': '내가 정한 이름',
        'times': [],
      }, null);
      final id = '${Controller.getPills().single['id']}';
      final api = ApiClient(
        baseUrl: 'https://api.pillnote.test',
        sessionStore: SessionStore.inMemory(),
        cache: PublicApiCache.inMemory(),
        client: MockClient((request) async {
          expect(request.url.path, '/v1/drugs/123');
          return http.Response(
            jsonEncode({
              'data': {
                'itemSeq': '123',
                'name': '검색 이름',
                'consumerInfo': {'efficacy': '제공된 효능 안내'},
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Pillinfo(pillSEQ: id, isLocal: true, apiClient: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('제공된 효능 안내'), findsOneWidget);
      expect(find.text('내가 정한 이름'), findsOneWidget);
      expect(find.text('이 약 선택 · 일정 설정'), findsNothing);
    },
  );

  testWidgets(
    'large text keeps the schedule and completion usable on a small screen',
    (tester) async {
      await prepare();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: MedicationForm(
            pill: const {
              'ITEM_SEQ': '123',
              'ITEM_NAME': '이름이 아주 긴 약물 500mg 캡슐',
              'times': ['18:00'],
              'startDate': '2026-10-08',
            },
            reminderService: reminders,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, '등록하기');
      await tap(tester, '이 약의 알림이 예약됐어요');
      expect(find.text('완료').hitTestable(), findsOneWidget);
      expect(find.text('다른 약 추가').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a guidance failure retains the saved medicine and offers retry',
    (tester) async {
      await prepare();
      await Controller.addPill({'ITEM_SEQ': '123', 'ITEM_NAME': '저장한 약'}, null);
      final api = ApiClient(
        baseUrl: 'https://api.pillnote.test',
        sessionStore: SessionStore.inMemory(),
        cache: PublicApiCache.inMemory(),
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Pillinfo(
            pillSEQ: '${Controller.getPills().single['id']}',
            isLocal: true,
            apiClient: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('저장한 약'), findsOneWidget);
      expect(find.text('안내 다시 불러오기'), findsOneWidget);
      expect(find.text('약 정보를 찾지 못했어요.'), findsNothing);
      expect(Controller.getPills(), hasLength(1));
    },
  );

  testWidgets(
    'search selects a medicine directly and repeat registration clears search',
    (tester) async {
      await prepare();
      var detailRequests = 0;
      final api = ApiClient(
        baseUrl: 'https://api.pillnote.test',
        sessionStore: SessionStore.inMemory(),
        cache: PublicApiCache.inMemory(),
        client: MockClient((request) async {
          if (request.url.path != '/v1/drugs/search') detailRequests++;
          return http.Response(
            jsonEncode({
              'data': [
                {'itemSeq': '123', 'name': '검색 테스트약', 'manufacturer': '테스트 제약'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(MaterialApp(home: Pillsearch(apiClient: api)));
      await tester.enterText(find.byType(TextField), '테스트');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(find.text('약 정보 보기'), findsOneWidget);
      await tap(tester, '검색 테스트약');
      expect(find.byType(MedicationForm), findsOneWidget);
      expect(find.byType(Pillinfo), findsNothing);
      expect(detailRequests, 0);
      expect(find.widgetWithText(TextFormField, '약 이름'), findsNothing);
      await tap(tester, '나중에 시간 설정');
      await tap(tester, '등록하기');
      expect(Controller.getPills().single['ITEM_SEQ'], '123');
      await tap(tester, '다른 약 추가');
      expect(find.byType(MedicationForm), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      await tap(tester, '검색 없이 직접 입력');
      await tester.enterText(
        find.widgetWithText(TextFormField, '약 이름'),
        '두 번째 약',
      );
      await tap(tester, '나중에 시간 설정');
      await tap(tester, '등록하기');
      expect(Controller.getPills(), hasLength(2));
      await tap(tester, '완료');
      expect(find.byType(MedicationForm), findsNothing);
      expect(Controller.getPills(), hasLength(2));
    },
  );

  testWidgets(
    'copying times keeps this medicine dosage and period independent',
    (tester) async {
      await prepare();
      await Controller.addPill({
        'ITEM_NAME': '기존 약',
        'times': ['09:00', '20:00'],
        'dosage': 2.5,
        'unit': 'mL',
        'startDate': '2020-01-01',
      }, null);
      await tester.pumpWidget(const MaterialApp(home: MedicationForm()));
      await tester.enterText(find.widgetWithText(TextFormField, '약 이름'), '새 약');
      await tap(tester, '기존 약과 같은 시간 사용');
      await tap(tester, '기존 약');
      await tap(tester, '등록하기');
      final pill = Controller.getPills().last;
      expect(pill['times'], ['09:00', '20:00']);
      expect(pill['dosage'], 1);
      expect(pill['unit'], '정');
      expect(pill['startDate'], Medication.dateKey(DateTime.now()));
      expect(Controller.getPills().first['dosage'], 2.5);
    },
  );

  testWidgets(
    'collapsed optional fields preserve stock and still validate invalid stock',
    (tester) async {
      await prepare();
      await tester.pumpWidget(const MaterialApp(home: MedicationForm()));
      await tester.enterText(
        find.widgetWithText(TextFormField, '약 이름'),
        '수량 관리 약',
      );
      await tap(tester, '나중에 시간 설정');
      expect(find.text('현재 보유 수량'), findsNothing);
      await tap(tester, '추가 설정');
      await tap(tester, '남은 약 수량 관리');
      await tap(tester, '추가 설정');
      await tap(tester, '등록하기');
      expect(Controller.getPills(), isEmpty);
      expect(find.text('0 이상의 수량을 입력하세요.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, '현재 보유 수량'),
        '12',
      );
      await tap(tester, '추가 설정');
      await tap(tester, '등록하기');
      expect(Controller.getPills().single['stock'], 12);
    },
  );

  for (final scenario in ['ready', 'disabled', 'denied', 'failed']) {
    testWidgets(
      'registration completes with honest $scenario reminder status',
      (tester) async {
        await prepare();
        if (scenario == 'disabled') await store.setDoseRemindersEnabled(false);
        if (scenario == 'denied') gateway.granted = false;
        if (scenario == 'failed') gateway.dropSchedules = true;
        await Controller.addPill({
          'ITEM_NAME': '다른 약',
          'times': ['17:30'],
        }, null);
        await tester.pumpWidget(
          MaterialApp(
            home: MedicationForm(
              pill: const {
                'ITEM_NAME': '등록할 약',
                'times': ['18:00'],
                'startDate': '2026-10-08',
              },
              reminderService: reminders,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(gateway.permissionRequests, 0);
        await tap(tester, '등록하기');
        expect(Controller.getPills(), hasLength(2));
        expect(find.text('등록 완료'), findsOneWidget);
        final id = '${Controller.getPills().last['id']}';
        if (scenario == 'ready') {
          expect(reminders.nextScheduledAt!.minute, 30);
          expect(reminders.nextScheduledForPill(id)!.hour, 18);
          expect(find.text('이 약의 알림이 예약됐어요'), findsOneWidget);
          expect(find.text('다음 알림 · 10월 8일 18:00'), findsOneWidget);
        } else {
          expect(reminders.nextScheduledForPill(id), isNull);
          expect(find.text('이 약의 알림이 예약됐어요'), findsNothing);
          if (scenario == 'disabled') {
            expect(find.text('복용 알림이 꺼져 있어요'), findsOneWidget);
            await tap(tester, '복용 알림 켜기');
            expect(find.text('이 약의 알림이 예약됐어요'), findsOneWidget);
            expect(gateway.permissionRequests, 1);
          } else if (scenario == 'denied') {
            expect(find.text('알림 권한이 필요해요'), findsOneWidget);
            await tap(tester, '알림 허용하기');
            expect(gateway.permissionRequests, 1);
            await tap(tester, '기기 알림 설정');
            expect(gateway.settingsOpened, 1);
            expect(Controller.getPills(), hasLength(2));
          } else {
            expect(find.text('알림 예약을 확인해주세요'), findsOneWidget);
            gateway.dropSchedules = false;
            await tap(tester, '알림 다시 확인');
            expect(find.text('이 약의 알림이 예약됐어요'), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
