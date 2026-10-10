# 본인 복용 시간 알림 구현

2026-10-08 JST. 본인에게 보내는 로컬 알림을 추가했다.

- 설정 → 내 복용 시간 알림에서 이 기기의 알림을 켠다. 로그인 없이 사용한다.
- 약·묶음의 같은 시각 일정을 하나의 알림으로 묶고 이미 복용한 일정과 지난 시각을 제외한다.
- 일정 변경·보관·삭제·복용·취소·클라우드 병합·데이터 초기화 뒤 예약을 갱신한다.
- 앱 시작·재개·전경 검사에서 예약을 채운다. Android는 재부팅·업데이트 복원 receiver와 정확한 알람 권한을 설정했다.
- 정확한 알람 권한이 없는 Android는 일반 예약을 사용하며 지연 가능성을 설정 화면에 표시한다.
- 알림에서 약 이름은 표시하지 않는다. 예약 payload로 본인 알림을 구분해 다른 알림을 취소하지 않는다.
- 네이티브 예약을 다시 조회해 확인된 건수·다음 알림·마지막 예약 날짜를 표시한다.

앞으로 366일 이내 일정 중 iPhone은 가까운 60건, Android는 최대 400건을 예약한다.
예약이 끝나기 전에 앱을 한 번 열어야 이후 일정을 채울 수 있다. 설정 화면에서도
예약된 마지막 날짜와 이 안내를 제공한다.

## 검증

- Flutter 정적 분석: 문제 없음.
- 앱 단위·위젯 회귀 테스트: 121개 통과 (`backend-e2e` 제외).
- Android 네이티브 통합 테스트: 2개 통과. 실제 예약·수정·복용·취소·알림 해제를 확인했다.
- Android 앱을 런처 홈 화면으로 보낸 상태에서 20초 뒤 예약 알림의 OS 표시를 확인했다.
- Android debug APK와 iOS simulator 앱 빌드 성공.
- iPhone의 실제 알림 수신과 사용자 실기기 수신은 아직 확인하지 않았다.

예약 제한 및 네이티브 설정 근거:
[flutter_local_notifications 22.3.1](https://pub.dev/packages/flutter_local_notifications/versions/22.3.1).

다른 계정으로 로그인할 때 이전 복약 데이터와 알림 예약을 먼저 삭제한다.
적용 내용은 [계정 데이터 분리](ACCOUNT_DATA_REVIEW_2026-10-08.md)에 기록했다.

## 2026-10-09 iOS 초기화 오류 수정

iOS에서 `requestAlertPermission`, `requestBadgePermission`, `requestSoundPermission`을
모두 `false`로 지정하면 플러그인의 `initialize()`는 네이티브 초기화를 완료하면서도
권한 요청 결과인 `false`를 반환한다. 앱이 이 값을 Android와 같은 초기화 실패로
판단해 `StateError`를 반복하고 알림 권한 확인·예약에 도달하지 못했다.

iOS의 `false` 반환값은 초기화 완료로 처리하고, 별도 권한 확인·요청 결과로 예약 여부를
결정하도록 수정했다. Android 초기화 실패, 네이티브 예외 및 누락된 반환값은 계속 오류로
처리한다. 실패 로그에는 오류 메시지와 debug stack trace를 남긴다.

`test/native_dose_reminder_gateway_test.dart`에서 실제 플러그인의 method channel을
통해 iOS 권한 미요청·기존 권한·권한 요청·거부와 Android 초기화 실패·재시도 등을
검증한다. 별도 iOS QA 실행 파일은 `integration_test/ios_reminder_initialization_test.dart`다.

- 전체 앱 회귀 테스트: 로컬 백엔드 연동을 포함한 146개 통과.
- Flutter 정적 분석: 문제 없음.
- iOS 26.5 / iPhone 17 Pro 임시 시뮬레이터 네이티브 테스트: 1개 통과. 플러그인의
  권한 미요청 초기화가 실제로 `false`를 반환함을 확인했고, 반복 갱신이 오류 없이
  완료됐다. 권한 허용 뒤 복용 알림 1건의 네이티브 예약과 사용 해제 후 취소를 확인했다.
- 이 검증은 예약·취소 검증이며, iOS에서의 실제 배너 수신을 확인한 것은 아니다.
- QA 완료 후 임시 시뮬레이터를 삭제했고, 일반 앱의 iOS simulator debug 빌드도 성공했다.
