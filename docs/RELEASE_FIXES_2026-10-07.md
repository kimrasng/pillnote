# 모바일·백엔드 수정과 운영 반영 안내

## 이번에 수정한 문제

| 문제 | 수정된 동작 |
| --- | --- |
| 새 기기의 첫 동기화가 기존 클라우드 백업을 덮어쓸 수 있음 | 서버의 약·묶음·복용 기록·설정을 먼저 병합한 뒤 업로드 |
| 동시 동기화가 실제 업로드 완료 전 성공으로 반환됨 | 동기화·복원·백업 삭제를 순서대로 실행하고 실제 완료까지 대기 |
| 업로드 중 백업 삭제, 다운로드 중 로컬 삭제가 경합 | 업로드 완료 후 최신 revision 삭제, 로컬 삭제 전 이전 작업 무효화·종료 대기 |
| 계정 변경 후 이전 요청/refresh 응답이 적용됨 | 로그인 상태의 세대를 확인해 오래된 응답 폐기, 로그아웃 세션의 복원 차단 |
| 늦게 도착한 401이 이미 갱신한 토큰을 다시 회전 | 현재 갱신 토큰으로 재시도, 같은 로그인 세션의 refresh를 공유 |
| 모든 기기 로그아웃 실패 시 로컬 로그인까지 없어짐 | 서버 실패 시 로그인 상태와 기기 등록을 유지해 재시도 가능 |
| 모든 기기 로그아웃 뒤 푸시 기기 등록이 남음 | 백엔드가 모든 세션과 푸시 기기 등록을 같은 트랜잭션으로 삭제 |
| 계정 삭제 뒤 소유자 동기화 메타데이터가 남음 | 삭제 전 소유자 ID로 revision·마지막 백업 시각 정리 |
| 새 기기 기본 알림 설정이 복원한 설정을 덮음 | 실제 설정 변경 시각으로 병합하고 미수정 기본값 구분 |
| 오프라인 시작 시 네트워크를 기다리며 첫 화면 지연 | 로컬 화면을 먼저 시작하고 API·Firebase 준비를 별도로 실행 |
| 복원한 데이터가 열린 홈/약 상자에 바로 반영되지 않음 | 서버 병합 완료 이벤트로 화면 갱신, 앱 재개 시 동기화 재시도 |
| 같은 미복용 건을 매 분 반복 요청 | 당일 전송 성공 건 기억, 동시 검사 공유, 전송 직전 최신 복용 기록 재확인 |
| 푸시 권한 거부/해제 뒤 토큰 갱신으로 재등록 가능 | 현재 권한·세션 확인, 등록/해제 순서 보장, 로그아웃 시 등록 상태 초기화 |
| FCM 서버 오류가 모두 Firebase 오류로 표시됨 | 서버 오류 메시지 표시, 이미 없는 기기 해제도 정상 처리 |
| 인증번호 재전송 앱 30초/서버 60초 불일치 | 서버가 대기시간 반환, 앱이 이를 사용하며 기존 서버는 60초로 처리 |
| `/ready`가 미적용 DB에서도 정상 표시될 수 있음 | 인증·알림·암호화에 필요한 최신 스키마까지 검사 |
| 일부 잘못된 JWT가 500을 반환 | 잘못된 JSON 타입의 토큰을 401로 거부 |
| 백업 삭제 revision 생략·중복·불명확한 숫자 허용 | 명시한 정수 revision 하나만 허용, 안전 정수 상한 검증 |
| JSON과 비슷한 Content-Type 허용 | 정확한 application/json 미디어 타입 검사 |
| Wrangler 개발 의존성의 npm audit 고위험 4건 | sharp 0.35.5·undici 7.29.1 보안 패치 고정, audit 0건 확인 |

이전 QA의 키보드 가림, 응답 본문 타임아웃, 오프라인 로그아웃 화면 전환, iOS 앱 아이콘 수정도 포함됩니다.
iOS에 `remote-notification` background mode를 추가했습니다. 앱·백엔드 CI와 운영 조회 검사 명령도 준비했습니다.

## 검증 결과

- 앱 `flutter analyze`: 오류 없음.
- 앱 `flutter test`: 88개 통과. 실제 임시 Node 백엔드와 로그인·토큰 갱신·동기화·보호자·계정 삭제 연동 포함.
- 백엔드 `npm test`: 57개 통과.
- Worker/D1: 전체 마이그레이션 적용 후 기능 14개 + 보안 8개 검사 통과.
- Worker `wrangler deploy --dry-run`: 패키징 통과, 운영 배포 없음.
- 백엔드 `npm ci` 후 `npm audit`: 취약점 0건.
- Android 에뮬레이터: 네이티브 QA 3개 통과.
- iOS 시뮬레이터: 네이티브 QA 3개 통과.
- 일반 실행용 Android debug APK와 iOS simulator 앱 빌드 통과.

테스트에서 메일/푸시 전송은 모의 제공자이며, 네이티브 운영 조회는 읽기 전용입니다.
실제 메일 수신 및 Android/iOS APNs·FCM 푸시 수신, 서명된 스토어 빌드는 아래 절차에서 확인해야 합니다.
CI 파일은 준비했으며 GitHub에서 실행한 결과는 아직 확인하지 않았습니다. Flutter CI 버전은 로컬 검증 SDK 3.47.2에 맞췄습니다.

개발 도구 보안 패치의 근거는 유지관리자의 [sharp 보안 공지](https://github.com/lovell/sharp/security/advisories/GHSA-wq5f-xc86-pv6w)와
[undici 보안 공지](https://github.com/nodejs/undici/security/advisories/GHSA-w293-vg96-wgc3)입니다.

## 사용자 배포 후 확인한 운영 상태

- 활성 Worker 배포: 2026-10-07 13:53 JST, version ID `0d878c97-2b89-4bb9-8e40-46e8b9794be2`, 트래픽 100%.
- `/health`의 버전은 수정 코드와 같은 `0.1.1`.
- 운영 `/ready`: 정상. 최신 DB 스키마와 운영 연동 설정 검사 통과.
- 원격 D1: `0004_production_readiness.sql` 적용 완료, 미적용 마이그레이션 없음.
- 필수 Secret 이름 9개는 모두 존재. 값의 유효성·메일/APNs 권한까지 확인된 것은 아님.
- 의약품 검색·상세·약국 조회와 비로그인 인증 차단은 정상.
- 사용자가 운영 DB와 Worker를 배포한 뒤 읽기 전용 재검증을 수행함. `verify:production` 6개 검사 모두 PASS.

## 사용자가 진행할 순서

### 1. 소스 저장과 앱 릴리스 준비

앱 변경을 Git에 저장하고 CI를 확인합니다. 백엔드는 현재 Git 저장소가 아니므로 먼저 전용 저장소로 관리하고
`.github/workflows/ci.yml`을 필수 검사로 설정합니다. 기본 브랜치의 리뷰/검사 보호도 설정합니다.

Android 배포에는 기존 앱의 업로드 키를 사용합니다. 현재 로컬에는 `android/app/upload-keystore.jks`가 없습니다.
기존 키를 이 경로에 준비하고 `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`를 터미널 환경변수로 설정합니다.
현재 스토어 빌드 번호보다 높은 정수를 `PILLNOTE_BUILD_NUMBER` 환경변수로 설정한 뒤 아래 명령을 실행합니다.
GitHub 릴리스 워크플로를 사용할 때는 위 값과 `KEYSTORE_BASE64`를 저장소의 `env` Environment Secret에 넣습니다.

```bash
cd /Users/kimrasng/dev/pillnote
/Users/kimrasng/flutter/bin/flutter build appbundle --release --build-number="$PILLNOTE_BUILD_NUMBER"
```

Play Console에 이미 올라간 빌드보다 높은 build number를 사용해 새 앱을 배포합니다.
새 키를 임의로 만들면 기존 배포 앱을 업데이트하지 못할 수 있으므로 기존 서명 체계를 사용합니다.

iOS는 `ios/Runner.xcworkspace`의 Runner > Signing & Capabilities에서 Apple Developer Team과
Push Notifications 권한을 확인합니다. 앱 ID는 `kr.kimrasng.pillnote.pillnote`입니다.
Firebase Console > Cloud Messaging에서 해당 Apple Team의 APNs 인증키 등록을 확인합니다.

```bash
cd /Users/kimrasng/dev/pillnote
/Users/kimrasng/flutter/bin/flutter build ipa --release --build-number="$PILLNOTE_BUILD_NUMBER"
```

현재 프로젝트에는 Apple Team ID가 지정되지 않아 실제 배포 서명은 사용자의 계정 설정이 필요합니다.
서명한 앱은 먼저 Android 내부 테스트/iOS TestFlight로 확인하고 배포합니다.
새 서버의 refresh 재사용 탐지 정책에 맞는 이 앱을 먼저 배포한 뒤 다음 서버 작업을 진행합니다.

### 2. 운영 DB와 서버 반영

아래 절차는 운영 DB·Worker를 실제로 변경합니다. 앱 배포와 `OPERATIONS.md` 출시 게이트 확인 후 실행합니다.
WAF/Rate Limiting 대상 경로와 실제 로그인·푸시 사전 검증은 `pillnotebackend/OPERATIONS.md`를 따릅니다.
기존 JWT·백업 암호화 Secret은 그대로 사용합니다.

```bash
cd /Users/kimrasng/dev/pillnotebackend
npm ci
npm audit --audit-level=high
npm run check
npm test
npm run test:worker
npx wrangler deploy --dry-run
npx wrangler d1 time-travel info pillnote --json
npm run d1:migrate:remote
npm run deploy:worker
npm run verify:production
npx wrangler d1 migrations list pillnote --remote
```

각 명령이 성공한 것을 확인하고 다음 명령으로 진행합니다. Time Travel bookmark를 별도로 기록한 뒤
`0004`를 적용합니다. 마지막 조회에 미적용 마이그레이션이 없어야 합니다.
`verify:production`은 버전 `0.1.1`, `/ready`의 DB·운영 설정, 의약품·약국 조회, 인증 차단을 확인합니다.
초기 점검에서는 버전 및 `/ready` 검사가 실패했으며, 사용자 배포 후에는 모든 검사가 PASS인 것을 확인했습니다.

### 3. 실제 Android·iPhone에서 최종 확인

서로 다른 이메일의 환자·보호자 테스트 계정으로 확인합니다.

1. 양쪽 기기에서 실제 인증 메일 수신과 로그인. 재전송 대기시간도 확인.
2. 같은 계정으로 두 기기에 로그인해 약 추가·복용·취소·설정 변경 후 동기화 확인.
3. 보호자를 초대하고 수락한 뒤 보호자 기기의 알림 켜기. Android와 iPhone에서 각각 수신 확인.
4. 보호자 앱을 배경/종료 상태로 두고 환자 앱을 활성화해 테스트 일정의 미복용 알림 수신 확인.
5. 모든 기기 로그아웃 후 세션과 푸시 등록이 종료되는지 확인. 다시 로그인한 보호자 기기는 알림을 다시 켜기.
6. 테스트 계정으로 백업 삭제·계정 삭제 확인. 백업 삭제는 로컬 데이터를 유지하고, 계정 삭제는 로컬 데이터도 정리.

## 0.1.1의 제한 (0.1.2에서 수정)

아래 내용은 0.1.1까지의 상태입니다. 이후 구현한 0.1.2 서버 검사와 추가 배포 절차는
[서버 미복용 검사 안내](SERVER_MISSED_DOSE_2026-10-07.md)를 참고합니다.

0.1.1에는 환자 앱이 완전히 종료된 동안 정해진 시각의 미복용을 검사하는 서버 스케줄러가 없습니다.
현재는 앱 활성화 중과 재개 시 판정합니다. 푸시 수신자의 백그라운드 수신과는 별개이며,
iOS background mode 추가만으로 종료된 환자 앱의 미복용 판정이 실행되지는 않습니다.
앱 종료 상태에서도 정확한 시각에 판정하려면 별도의 서버 일정 처리 기능이 필요합니다.
