# 2026-10-11 약 API 화면 지연 측정 자료

보고서는 ../../API_LATENCY_REPORT_2026-10-11.md 에 있다. latency-samples.json이 최종 성공 실행의 원본 표본과 집계다. benchmark.log는 해당 실행의 PN_BENCH 로그만 추출한 파일이다. 이전 프레임 판별 실험에서 타임아웃이 발생한 실행은 집계에 포함하지 않았다.

cache_latency_benchmark.dart는 별도 임시 Flutter 프로젝트에서 실제 실행한 진입점이다. screen-instrumentation.patch는 Pillsearch/Pillinfo에 선택적 ApiClient 및 측정 콜백을 주입한 변경이다. 운영 앱에는 적용하지 않았다.

재현 시 앱의 lib/assets/fonts/android 및 pubspec 파일을 임시 프로젝트로 복사하고 진입점 파일을 lib에 놓는다. 화면 계측 패치를 임시 복사본에 적용한다. 동일한 앱 테마를 사용한다. 원본 앱과 독립적인 Android applicationId(당시 kr.kimrasng.pillnote.pillnote.benchmark), 독립 저장소 접두사(pillnote.latency.benchmark.), 기존 MainActivity의 완전한 이름을 사용한다. 임시 복사본에서는 Firebase Google Services 플러그인 적용과 배포용 서명 태스크 가드만 제거했다. 사용자 계정 로그인을 수행하거나 실앱 데이터를 삭제하지 않는다.

당시 실행 명령은 `flutter run --profile -d emulator-5554 --target lib/cache_latency_benchmark.dart --no-resident`였다. ADB logcat의 PN_BENCH_META / PN_BENCH_SAMPLE / PN_BENCH_DONE를 수집했다. 각 조건 6회, 전체 72회와 DONE 72를 확인한다. BYPASS/HIT 및 로컬 네트워크 0회 검증은 진입점에 포함되어 있다.

로그에 기록된 resultFrameBuildStartAfterReadyMs는 측정을 완료한 프레임의 값이다. 상세에서는 안정화 완료 프레임이므로 첫 결과 프레임 값과 같다고 해석하면 안 된다. 본문 보고서는 이 진단용 필드를 사용하지 않는다.

에뮬레이터 측정은 실제 휴대폰 성능을 대표하지 않는다. 로컬 복원 조건은 이미 초기화된 SharedPreferences에서 새 캐시 객체가 복원하는 경우다. 앱 프로세스 전체 재시작이나 최초 디스크 읽기를 재현한 조건이 아니다. 재실험 시 실행 환경, 프레임 종료 정의, 연결 재사용 여부, 캐시 및 이미지 상태, 서버 버전을 기록해야 한다.
