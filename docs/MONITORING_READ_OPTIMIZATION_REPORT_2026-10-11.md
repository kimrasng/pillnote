# PillNote 운영 모니터링 행 읽기 최적화 보고서

작성일: 2026-10-11, 한국·일본 시간 UTC+9. 적용 버전: **백엔드 0.1.11, 관리자 0.3.4**.

운영 모니터링 장애를 조사한 결과, 삭제할 기록이 없는데도 정기 검사 기록 전체를 매분 읽는 쿼리가 주요 원인이었다. 조사 당시 최근 24시간 통계에서 이 쿼리 하나가 **1,432회 실행되며 5,988,467행을 읽었고, 실제 삭제한 행은 0개**였다.

정리 쿼리를 기존 기본 키로 검색하도록 바꾸고, 정리 작업을 시간당 한 번으로 분리했다. 장애 감시는 필요한 전달 실패 건수만 조회하며, 장애 페이지에서는 사용하지 않는 전체 대시보드 집계를 실행하지 않는다. **복약 검사와 장애 감시는 매분 유지한다.** 수정은 운영에 배포됐다.

로컬 SQLite 비교에서 정리 쿼리의 연산량은 **30,550 → 435개, 약 98.58% 감소**했다. 현재 사용 규모를 유지하면 하루 전체 읽기량을 **약 10만~30만 행**으로 예상하지만, 이 수치는 운영 실측 결과가 아니다. 이미 소진한 한도가 초기화된 뒤 실제 읽기량과 기능 복구를 확인해야 한다.

## 1. 측정한 지표와 예상한 지표

이번 보고서의 주 지표는 **D1에서 읽은 행 수(rows_read)**다. SQL 실행 횟수, 응답으로 반환한 행 수, 삭제한 행 수와 구분한다. 결과가 0개인 쿼리도 조건에 맞는 기록을 찾기 위해 수천 행을 읽을 수 있다.

| 지표 | 의미 | 이번 자료의 성격 |
| --- | --- | --- |
| 쿼리 실행 횟수 | 같은 SQL이 실행된 횟수 | 운영 D1 insights 통계 |
| 읽은 행 수 | 쿼리가 검색·처리를 위해 읽은 행 수 | 운영 D1 insights 통계 |
| 삭제한 행 수 | 조건에 맞아 실제 삭제된 행 수 | 운영 D1 insights 통계 및 로컬 검증 |
| SQLite VM 연산 수 | 로컬 SQLite가 쿼리 처리 중 실행한 연산 수 | 동일 데이터 조건의 전후 비교 |
| 최적화 후 하루 읽기량 | 기존 통계와 새 실행 빈도를 근거로 한 예상 | 추정치; 운영 재측정 전 |

**로컬 연산량 98.58% 감소를 운영 D1 행 읽기 98.58% 감소로 해석하면 안 된다.** D1의 읽기량과 로컬 SQLite 연산량은 서로 다른 지표다.

## 2. 행 읽기가 많았던 원인

기존 정리 쿼리는 다음과 같았다.

```sql
DELETE FROM monitoring_runs WHERE completed_at < ?;
```

검사 기록의 기본 키는 `scheduled_at`인데, 정리 조건은 인덱스가 없는 `completed_at`이었다. 삭제할 기록이 있는지 확인하기 위해 전체 기록을 훑었고, 이 작업을 정기 복약 검사 후 매분 반복했다.

| 조사 당시 최근 24시간 통계 | 값 |
| --- | ---: |
| 해당 쿼리 실행 | 1,432회 |
| 실행당 평균 읽기 | 약 4,181행 |
| 누적 읽기 | 5,988,467행 |
| 누적 삭제 | 0행 |

약 4천 개 기록을 하루 약 1,440번 훑으면 수백만 행 읽기가 발생한다. 앱 사용자 요청이 많아서만 생긴 문제가 아니라, **운영 기록을 정리하는 작업 자체가 불필요한 읽기를 반복한 구조 문제**였다. 기록이 쌓일수록 비용도 증가한다.

조사 시 다른 상위 쿼리의 읽기량은 각각 1만 행 미만이었다. 이 정리 쿼리가 주요 비용 원인으로 확인됐다. 최근 24시간 이동 통계와 UTC 자정부터 집계하는 무료 일일 한도는 집계 구간이 다르므로, 위 숫자를 특정 UTC 날짜의 정확한 청구 사용량으로 해석하지 않는다.

Cloudflare D1 무료 요금제의 일일 읽기 한도는 500만 행이며, 한도를 초과하면 쿼리 오류가 발생할 수 있다. 무료 한도는 UTC 자정, 한국·일본 시간 오전 9시에 초기화된다. [Cloudflare D1 공식 요금·한도 안내](https://developers.cloudflare.com/d1/platform/pricing/)

## 3. 기존 방식과 현재 방식

기존 경로:

`매분 복약 검사 → 검사 결과 저장 → 전체 검사 기록 검색 → 지표·메일·이벤트·기기 정리 반복`

현재 경로:

`매분 복약 검사 → 검사 결과 저장 → 정리 실행 권한 확인 → 시간당 한 번만 정리 → 기본 키 범위로 삭제 대상 검색`

| 작업 | 기존 방식 | 현재 방식 |
| --- | --- | --- |
| 검사 기록 정리 | 완료 시각 조건으로 전체 기록 검색 | 기존 정수 기본 키로 검색 범위를 제한 |
| 보관 기간이 지난 데이터 정리 | 복약 검사 후 매분 반복 | 정상 정리 실행 기준 시간당 한 번 |
| 중복 실행·Worker 재시작 | 정리 호출이 반복될 수 있음 | DB에 저장한 원자적 실행 권한으로 간격 유지 |
| 감시용 이메일 조회 | 전체 상태 요약과 이메일 목록 20개 조회 | 최근 1시간 전달 실패 건수만 조회 |
| 감시용 웹훅 조회 | 누적 이벤트 전체 집계 | 감시에 사용하지 않는 누적 집계 제외 |
| 장애 페이지 | 독립 감시와 전체 대시보드 집계를 함께 조회 | 독립 감시 상태 조회만 수행 |
| 정리 실패 | 복약 검사 결과까지 실패로 처리될 수 있음 | 수집 실패로 기록하고 정리 재시도 |
| 복약 검사·장애 감시 | 매분 실행 | 매분 실행 유지 |

지표는 30일, 검사 기록·이메일·웹훅 이벤트 등은 기존 7일 보관 정책을 유지한다. 정리를 시간당 실행하므로 만료 데이터의 물리 삭제는 정상 동작 기준 다음 정리 시점까지 약 1시간 늦어질 수 있다. 정리 실패 시에는 더 늦어질 수 있다.

## 4. 정리 쿼리의 전후 검증

동일한 로컬 SQLite 데이터에 보관 대상 **10,080개**와 삭제 대상 **60개**를 넣고 비교했다. 보관 10,080개는 매분 생성되는 검사 기록 약 7일 분량이다.

| 비교 항목 | 기존 쿼리 | 수정 쿼리 |
| --- | ---: | ---: |
| 실행 계획 | 전체 검색 `SCAN` | 기본 키 범위 검색 `SEARCH` |
| SQLite VM 연산 | 30,550개 | 435개 |
| 실제 삭제 | 60개 | 60개 |
| 보관 기록 | 10,080개 | 10,080개 |

연산량 감소율은 `(30,550 - 435) / 30,550 × 100 = 98.58%`다. 삭제 결과를 유지하면서 보관할 기록 전체를 반복 검색하는 비용을 줄였다.

정상 정리 호출 빈도도 **하루 약 1,440회 → 약 24회**, 약 60분의 1로 줄였다. 두 효과는 별개이며, 두 비율을 곱해서 운영 전체 읽기량 감소율로 발표하지 않는다. 실행 권한 확인과 복약 검사 결과 저장은 여전히 매분 진행된다. 정리 실패 후 재시도는 정상 실행 빈도와 별개다.

이 실험은 SQL 처리량 비교다. 운영 D1의 쿼리 지연, 앱 화면 지연, 하루 전체 읽기량을 직접 측정한 실험은 아니다.

## 5. 최적화 후 예상 하루 읽기량

**현재 계정 수·앱 요청량이 유지되고 관리자 화면을 간헐적으로 보는 조건에서, 하루 약 10만~30만 행을 초기 예상 범위로 잡는다.** 무료 일일 한도 500만 행의 약 2~6%다.

| 사용 조건 | 예상 읽기량 | 전제 |
| --- | ---: | --- |
| 자동 검사·장애 감시와 현재 수준의 앱 사용 | 하루 약 10만~30만 행 | 현재 규모 유지, 관리자 화면 간헐적 사용 |
| 일반 대시보드 30초 자동 갱신 | 시간당 약 1만~3만 행 추가 | 탭 한 개, 현재 데이터 규모, 통상적인 조회 기간 |
| 긴 기간의 검사 이력 조회 | 별도 측정 필요 | 아직 완료 시각 조회·정렬 최적화가 남아 있음 |

이 범위는 기존 운영 통계에 새 실행 빈도와 조회 범위를 반영한 추정이다. 대표 자료에서 전체 지표 조회는 실행당 약 39행, 일부 계정·기기 집계는 실행당 약 15~21행을 읽었다. 지표 조회 통계에는 서로 다른 기간 및 감시 요청이 섞여 있어 모든 화면의 고정 비용으로 사용할 수 없다. 조회 실패가 포함된 조사 구간이므로 정상 운영 비용을 정확히 외삽하는 데에도 한계가 있다.

30초 갱신은 시간당 약 120회다. 일반 대시보드 추가 예상 1만~3만 행은 조회 한 번당 전체 쿼리가 약 83~250행을 읽는 경우에 해당한다. 계정·이메일·실패 기록·조회 기간이 커지면 이 범위를 넘을 수 있고, 여러 탭이나 운영자가 동시에 조회하면 추가 비용도 늘어난다.

**10만~30만 행은 실측값이나 상한 보장이 아니다.** 관리자 화면을 하루 종일 열어두거나 사용자 수가 크게 늘어난 조건까지 포함한 숫자는 아니다. 한도 초기화 후 수정본이 정상 동작한 24시간 사용량을 측정해야 이 예상 범위를 확인할 수 있다.

## 6. 아직 개선되지 않은 구간

| 구간 | 현재 처리 | 남은 개선·검증 |
| --- | --- | --- |
| 검사 이력 목록 | `completed_at` 조건으로 총 건수 및 목록 조회·정렬 | 완료 시각 조회에 맞는 인덱스와 집계 방식 보완 |
| 긴 조회 기간의 전체 지표 | 선택한 기간의 집계 행을 읽어 그래프·합계 계산 | 기간별 읽기량 측정, 데이터 증가 시 조회 재사용·사전 집계 검토 |
| 이메일 전달 상태 | 메시지별 이벤트 우선순위를 계산 | 이메일·이벤트 증가 시 실제 조회 비용 재측정 |
| 관리자 장시간 자동 갱신 | 일반 화면은 30초마다 조회 | 화면·기간별 비용 측정과 갱신 정책 보완 |
| 최적화 후 일일 사용량 | 기존 통계 기반 추정 | 한도 초기화 후 정상 24시간 운영 통계 확인 |

검사 기록 **정리** 쿼리는 바꿨지만, 검사 이력 **목록 조회** 쿼리까지 모두 최적화한 것은 아니다. 목록의 `COUNT(*)`와 완료 시각 정렬은 별도 비용을 발생시킨다. 화면에 20개만 표시한다고 DB도 20행만 읽는 것은 아니다. 긴 기간을 30초마다 계속 새로고침하는 경우에는 앞의 일반 대시보드 예상 범위를 적용하지 않는다.

## 7. 운영에서 얻는 효과와 장애 상태

주요 효과는 사용자 요청이 없어도 발생하던 반복 읽기를 줄여, 복약 검사와 앱 기능이 사용할 DB 한도를 확보하는 것이다. 감시가 필요로 하지 않는 이메일 상세 조회를 없애면서 실패 감지에 필요한 건수는 유지한다. 장애 페이지는 전체 대시보드 조회가 실패해도 독립 감시 상태를 표시할 수 있는 구조다.

이번 수정은 모니터링 비용 개선이다. 로그인·동기화·약 검색 화면의 응답 시간을 새로 측정하거나 단축률을 확인한 변경은 아니다. 약 API 캐시의 지연 개선은 별도 보고서에서 다룬다.

배포 당시에는 D1 한도가 이미 소진되어 운영 조회와 정기 복약 검사에서 같은 한도 오류가 확인됐다. 수정 배포가 사용량을 초기화하지는 않는다. 이 보고서에는 **장애 복구 또는 최적화 후 정상 운영 읽기량이 확인됐다고 기록하지 않았다.** 한도 초기화 예정은 2026-10-11 오전 9시 UTC+9였다. 실제 복구 확인은 별도로 필요하다.

감시 Worker는 한도 초과 원인을 저장하고 Telegram에 원인을 포함한 지속 통지를 보낸 상태를 확인했다. 복구 통지는 정상 공개 응답과 정상 모니터링 조회가 돌아오고 연속 정상 검사 조건을 충족해야 발송된다. 유료 요금제 변경은 진행하지 않았다.

## 8. 테스트와 운영 배포

| 검증 | 결과 |
| --- | --- |
| 백엔드 테스트 | 134개 통과 |
| 관리자 테스트 | 31개 통과 |
| 실제 로컬 Worker 통합 검사 | 34개 통과 |
| 정리 쿼리 전후 비교 | 삭제·보관 결과 동일, 연산량 98.58% 감소 |
| 로컬 관리자 장애 화면 | 독립 감시 표시 및 갱신 동작 확인 |
| 운영 백엔드 버전 | `/health`에서 0.1.11 확인 |
| 운영 관리자 비로그인 접근 | Cloudflare Access 로그인으로 이동 확인 |
| 최적화 후 운영 24시간 읽기량 | 아직 미확인 |

테스트에는 시간당 실행 권한, 중복 실행 방지, 정리 실패 시 재시도, 성공한 복약 검사 결과 보존, 이메일 전달 이벤트 우선순위와 시간 범위, 감시가 이메일 상세 목록을 읽지 않는 조건을 포함했다.

배포 버전:

- 백엔드 0.1.11: `0db2e0eb-724d-4c65-9918-b4044fe8d9e4`.
- 관리자 0.3.4: `3779b03a-266f-451d-97d8-ea8a9a35ecfa`.
- 앞선 한도 오류 보완 감시 Worker: `f302db9c-7e10-447f-8fd0-d914bbbbf007`.

기존 테이블과 기본 키를 사용해 이번 최적화에 새로운 마이그레이션은 필요하지 않았다.

## 9. 원본 및 재현 자료

- [장애 조사 당시 D1 쿼리 통계](/Users/kimrasng/dev/pillnotebackend/releases/0.1.10/d1-insights.json)
- [후속 읽기량 추정에 사용한 D1 통계](</Users/kimrasng/dev/pillnote/docs/benchmarks/2026-10-11/monitoring-read/d1-insights-estimate.json>)
- [정리 쿼리 비교 결과 JSON](/Users/kimrasng/dev/pillnotebackend/releases/0.1.11/verification/retention-benchmark.json)
- [로컬 비교 실행 스크립트](/Users/kimrasng/dev/pillnotebackend/scripts/benchmark-monitoring-retention.py)
- [백엔드 배포·검증 기록](/Users/kimrasng/dev/pillnotebackend/releases/0.1.11/manifest.json)
- [관리자 배포·검증 기록](/Users/kimrasng/dev/pillnoteadmin/releases/0.3.4/manifest.json)
- [한도 장애 조사 기록](/Users/kimrasng/dev/pillnoteadmin/docs/D1_READ_QUOTA_INCIDENT_2026-10-11.md)
- [약 API 캐시와 사용자 화면 지연 보고서](/Users/kimrasng/Desktop/API_LATENCY_REPORT_2026-10-11.md)

로컬 비교 재현:

```sh
python3 /Users/kimrasng/dev/pillnotebackend/scripts/benchmark-monitoring-retention.py
```

스크립트는 메모리 SQLite DB에 비교 데이터를 생성하므로 운영 DB를 변경하지 않는다. 기존 결과와 수정 결과가 같은지 확인하고 연산량 감소 조건을 검증한다. D1 통계는 수집 시점에 따라 최근 24시간 범위가 이동하므로, 서로 다른 시점의 파일에서 누적 값이 달라질 수 있다.

## 10. 실제 수정한 핵심 코드

비용과 실행 동작을 바꾸는 핵심 다섯 가지를 발췌했다. 아래 코드는 설명에 필요한 부분이며, 전체 함수와 오류 처리는 연결된 원본에서 확인할 수 있다.

**① 정리 쿼리를 기본 키 범위로 제한** — [operations-store.js](/Users/kimrasng/dev/pillnotebackend/src/operations-store.js:120)

```javascript
await run(
  'DELETE FROM monitoring_runs WHERE scheduled_at<? AND completed_at<?',
  [before, before],
);
```

`scheduled_at`은 정수 기본 키여서 보관할 전체 기록을 훑는 대신 이전 기록 범위를 찾는다. `completed_at` 조건도 함께 유지해 오래전에 시작했지만 최근 완료한 실행은 삭제하지 않는다.

**② 정리를 시간당 한 번만 실행하고 중복 호출을 막음** — [monitoring-maintenance.js](/Users/kimrasng/dev/pillnotebackend/src/monitoring-maintenance.js:3), [monitoring.js](/Users/kimrasng/dev/pillnotebackend/src/monitoring.js:67)

```javascript
export const MAINTENANCE_INTERVAL_MS = 3600000;

return Boolean(await first(`
  INSERT INTO monitoring_state (name,payload,updated_at)
  VALUES ('maintenance','{}',?)
  ON CONFLICT(name) DO UPDATE SET updated_at=excluded.updated_at
  WHERE monitoring_state.updated_at<=?
  RETURNING name
`, [at, at - MAINTENANCE_INTERVAL_MS]));
```

조건부 INSERT/UPDATE 하나로 정리 실행 권한을 얻는다. 최근 한 시간 안에 다른 호출이 권한을 얻었으면 결과가 없어 정리를 건너뛴다. 메모리 타이머가 아니라 DB 상태를 사용하므로 Worker가 재시작되어도 간격을 유지한다.

```javascript
if (await repository.claimMonitoringMaintenance(maintenanceAt)) {
  await repository.pruneMonitoring(maintenanceAt - 30 * 86400000);
  await repository.pruneMonitoringOperations(maintenanceAt - 7 * 86400000);
  await repository.pruneMonitoringEmails(maintenanceAt - 7 * 86400000);
  await repository.pruneEmailEvents(maintenanceAt - 7 * 86400000);
  await repository.pruneAppDevices(maintenanceAt);
}
```

이 실행 조건은 데이터 정리에만 적용한다. 매분 복약 검사와 결과 저장을 생략하지 않는다.

**③ 감시에는 이메일 전달 실패 건수만 조회** — [email-monitoring-store.js](/Users/kimrasng/dev/pillnotebackend/src/email-monitoring-store.js:15), [monitoring.js](/Users/kimrasng/dev/pillnotebackend/src/monitoring.js:95)

```javascript
return first(`
  SELECT COUNT(*) AS undelivered
  FROM monitoring_email_delivery
  WHERE created_at>=? AND created_at<=?
    AND delivery_status IN ('bounced','failed','suppressed')
`, [at - 3600000, at]);
```

기존 감시는 이메일 목록과 모든 상태별 요약까지 가져왔다. 현재는 감시 규칙에 필요한 최근 한 시간의 전달 실패 건수만 읽는다. 기존 전달 상태 뷰를 사용하므로 이벤트 우선순위를 유지한다. 한 행짜리 결과를 반환해도 집계 대상 행은 읽을 수 있으며, DB 읽기량이 무조건 한 행이 된다는 뜻은 아니다.

**④ 장애 페이지에서 전체 대시보드 조회를 중단** — [App.jsx](/Users/kimrasng/dev/pillnoteadmin/src/ui/App.jsx:159), [useMonitoring.js](/Users/kimrasng/dev/pillnoteadmin/src/ui/useMonitoring.js:14)

```javascript
useMonitoring(range, page !== 'incidents');
```

```javascript
if (authenticationLost.current || !enabled) return;
```

장애 페이지에서는 전체 집계 조회를 비활성화한다. 주기적 갱신도 `enabled`일 때만 수행한다. 페이지 전환 시 진행 중인 전체 집계 요청을 취소하며, 독립 감시 상태 조회와 그 화면의 새로고침은 별도로 유지한다.

**⑤ 정리 실패는 재시도하고 복약 검사 성공 결과를 보존** — [monitoring.js](/Users/kimrasng/dev/pillnotebackend/src/monitoring.js:77)

```javascript
await repository.releaseMonitoringMaintenance(maintenanceAt).catch(() => {});
```

```javascript
console.error(JSON.stringify({event: 'monitoring-maintenance-failed'}));
await Promise.resolve()
  .then(() => repository.recordCollectionFailure(maintenanceAt))
  .catch(() => {});
```

정리에 실패하면 해당 실행의 권한을 반환해 다음 검사에서 다시 시도할 수 있게 한다. 수집 상태에 실패를 기록하되, 이미 완료한 복약 검사 결과를 실패로 덮어쓰지 않는다. 실패 기록 저장 자체도 한도 때문에 실패할 수 있으므로 로그를 함께 남긴다.
