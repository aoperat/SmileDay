# SmileDay 프로젝트 전체점검 보고서

- 작성일: 2026-07-31
- 기준 브랜치/커밋: `feature/live-smile-monitor` / `43fd76d` + 현재 작업 트리의 P1 수정
- 기준 작업 트리: 이 보고서와 P1 수정 파일이 미커밋 상태
- 목적: 현재 존재하는 기능, 데이터 흐름, 개인정보 가드레일, 테스트·빌드 근거, 출시 전 위험 전수 점검
- 이전 전체점검: `2026-07-30-project-review.md`

## 1. 결론

현재 제품은 핵심 흐름인 “반복 알림 → 비평가적 문구 → 카메라 없는 5초 미소 → 완료 저장 → 오늘·최근 7일 횟수”를 유지하고 있다. 선택형 “실시간 미소 확인”은 핵심 흐름과 분리되어 있고, 명시적 시작 전에는 카메라를 켜지 않으며, 사진·영상·측정값을 저장하거나 전송하는 코드 경로가 없다.

이번 점검에서 P0는 발견하지 않았다. P1 수정 후 패키지 테스트 224개가 모두 통과했고, 현재 앱 Swift 소스 파싱, 개인정보 매니페스트, 아이콘 규격, 금지 문구·강제 종료 패턴 정적 검사를 통과했다. 기준 커밋 메시지에는 수정 직전 같은 커밋에서 앱 빌드 성공과 부팅된 시뮬레이터 확인 기록도 있다.

코드와 문서로 해결할 수 있는 P1 두 건은 현재 작업 트리에서 수정했다.

1. 알림 액션 백필을 새 그룹 완전 등록 → SwiftData 그룹 교체 → 기존 그룹 취소 순서로 바꿨다.
2. 철회된 얼굴 스냅샷을 구현하라고 적힌 하위 `AGENTS.md` 세 파일을 현재 절대 가드레일에 맞췄다.

남은 P1은 반복 알림·잠금화면 액션·TrueDepth 흐름의 최신 실기기 E2E 검증이다.

## 2. 현재 기능 전체 목록

### 2-1. 앱 시작과 온보딩

- SwiftData 컨테이너 성공 시 앱을 열고, 실패 시 데이터 삭제나 강제 종료 대신 복구 안내를 표시한다.
- 스플래시 뒤 온보딩 완료 여부와 반복 스케줄 존재 여부를 함께 확인한다.
- 첫 온보딩은 제품 목적 → 알림 이유 → 시간창 설정 순서다.
- 기본 설정은 09:00~21:00, 3시간 간격이다.
- 알림 권한을 거부하거나 알림을 건너뛰어도 앱 사용은 막히지 않는다.
- 카메라 권한·기준선 촬영·표정 점수는 온보딩에 없다.

### 2-2. 반복 알림

- 시작·종료 시각과 60/120/180/240분 간격으로 매일 반복 알림을 만든다.
- 새 그룹을 먼저 전부 등록하고 SwiftData 저장 후 이전 그룹을 취소한다.
- 새 그룹 등록 실패 시 새로 추가한 요청을 정리하고 기존 스케줄·알림을 유지한다.
- 이전 버전의 14일 rolling identifier와 개별 `ReminderSetting.notificationID` 취소 호환성을 유지한다.
- 알림 payload는 현재 형식과 과거 `bucket`/`promptText` 형식을 모두 읽는다.
- 앱 사용 중 도착한 알림도 배너와 소리로 표시한다.

### 2-3. 알림 문구 관리

- 기본 비평가적 한국어 문구 8개를 제공한다.
- 설정에서 추가·수정·삭제·순서 변경을 지원한다.
- 빈 값, 100자 초과, 같은 문구 중복, 마지막 한 개 삭제를 막는다.
- 문구 목록은 UserDefaults에만 저장한다.
- 알림 시각 순서대로 문구를 배정하고, 문구 수를 넘으면 처음부터 반복한다.
- 문구를 바꾼 뒤 알림 설정을 다시 저장해야 기존 예약에 반영된다고 안내한다.

### 2-4. 잠금화면 알림 액션

- “웃었어요”: 앱을 foreground로 열지 않고 `SmileMoment`를 `.notificationAction` 출처로 저장한다.
- “가이드 열기”와 일반 알림 탭: 앱을 열어 동일한 5초 미소 가이드로 이동한다.
- 알림 해제와 모르는 action identifier는 무시한다.
- 앱이 이미 떠 있을 때 “웃었어요”를 누르면 홈 새로고침 신호를 보낸다.
- 기능 추가 전에 예약한 반복 알림에는 새 group을 완전히 등록한 뒤 기존 group을 교체해 action category를 붙인다.

### 2-5. 핵심 5초 미소

- 8개 비평가적 cue를 순환한다.
- 화면을 연 것만으로 기록하지 않고 사용자가 “시작”을 누른 뒤 5초를 마쳐야 저장한다.
- 중도 닫기, 중복 시작, 취소 뒤 늦게 도착한 tick은 저장하지 않는다.
- 완료는 정확히 한 번만 저장하며 출처를 수동/알림 가이드/알림 바로 기록으로 구분한다.
- 카메라·표정 측정·점수는 사용하지 않는다.

### 2-6. 홈

- 오늘 완료 횟수
- 지금 한 번 웃기
- 선택형 실시간 미소 확인 진입
- 다음 알림 시각
- 오늘로 끝나는 최근 7일의 일별 횟수와 합계
- 앱 활성 복귀, 설정 복귀, 가이드 종료, foreground 알림 액션 저장 후 새로고침
- 0회인 날을 실패·손실·스트릭 중단으로 표현하지 않는다.

### 2-7. 선택형 실시간 미소 확인

- 홈의 보조 카드에서만 진입하며 사용자가 “시작하기”를 누를 때 카메라 권한과 ARSession을 시작한다.
- TrueDepth 미지원은 이 모드만 막고 나머지 앱은 유지한다.
- 세션마다 유효 프레임으로 편한 표정을 2초 보정한다.
- 좌우 입꼬리 계수 평균, 카메라를 향한 각도, 조명만 사용한다.
- 내부 신호를 EMA로 평활하고 hysteresis를 적용해 4단계로 표시한다. 실시간 숫자 점수는 표시하지 않는다.
- 얼굴 없음, 카메라를 보지 않음, 어두움을 단계보다 먼저 안내한다.
- 카메라 프리뷰는 기본 꺼짐이며 사용자가 토글을 켠 동안에만 `ARSCNView`를 만든다.
- `ARFrame.capturedImage`를 읽지 않으며 사진·영상 생성, 캡처, 저장, 공유, 내보내기 경로가 없다.
- 웃지 않는 상태가 설정 간격만큼 이어지면 화면 cue, 선택적 진동, 즉시 로컬 알림으로 알린다. 품질이 끊긴 시간은 세지 않는다.
- 1초 단위 타임라인을 메모리에만 만들고, 종료 시 판정 가능한 시간 기준 미소 비율과 unknown 비율을 보여준다.
- 백그라운드·scene inactive·세션 실패 시 즉시 카메라를 멈추고, 이미 기록된 시간이 있으면 요약을 먼저 보여준다.
- 자동 잠금 상태를 모든 종료 경로에서 원래 값으로 복원한다.
- 요약을 닫으면 타임라인과 비율이 사라지고 `SmileMoment`에는 아무것도 추가하지 않는다.

### 2-8. 설정·데이터·호환성

- 반복 알림 활성화, 시간창, 간격, 권한 상태, 시스템 설정 이동
- 알림 문구 관리
- 실시간 모드 nudge 활성화, 30/60/90/120/180초 간격, 진동 설정
- 모든 기록이 기기에만 있고 앱 삭제 시 함께 삭제된다는 안내
- 활성 SwiftData 모델은 `SmileMoment`, `SmileReminderSchedule`
- 과거 저장소 재개방을 위해 `Baseline`, `CheckInSession`, `CareSession`, `ReminderSetting`, `CustomSmileCard`를 스키마에만 유지
- 과거 얼굴 점수·기분·케어·카드 UI와 저장 로직은 현재 제품 흐름에서 사용하지 않음

## 3. 검증 결과

### 3-1. CoachingKit

실행:

```bash
cd CoachingKit
CLANG_MODULE_CACHE_PATH=/private/tmp/smileday-20260731-clang \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/smileday-20260731-clang \
swift test --disable-sandbox
```

결과:

- `Test Suite 'All tests' passed`
- 224 tests, 0 failures
- XCTest 뒤 Swift Testing runner가 출력한 `0 tests in 0 suites passed`는 실패가 아니다.
- CoreData notification registration 경고는 있었지만 테스트 실패는 없었다.

주요 자동 검증:

- SwiftData 7개 모델 등록과 과거 스키마 재개방
- 완료 저장·날짜 집계·최근 7일
- 5초 상태 머신과 정확히 한 번 저장
- 반복 시각 계산과 스케줄 교체 순서
- 알림 문구 저장·검증·배정
- 현재/레거시 payload와 알림 action identifier 호환성
- 액션 category 백필의 일반 성공·재시도 상태
- 실시간 신호, 시선 기하, 품질 우선순위, 보정, 평활, hysteresis, nudge
- 1초 타임라인, gap, unknown, 비율·신뢰도
- 디자인 토큰 대비

### 3-2. 앱 정적 검증

- `xcrun swiftc -frontend -parse`로 `SmileDay/**/*.swift` 전체 통과
- `git diff --check` 통과
- `plutil -lint SmileDay/PrivacyInfo.xcprivacy` 통과
- 앱·패키지 Swift 소스에 `fatalError`, `try!`, 금지 사용자 문구 없음
- CoachingKit에 ARKit, SwiftUI, UIKit, AVFoundation, UserNotifications import 없음
- 앱·패키지 활성 코드에 네트워크 API나 측정값을 직접 파일로 쓰는 API 경로 없음
- AppIcon light/dark/tinted: 각각 1024×1024, alpha 없음
- Debug/Release 모두 iOS 17.0 및 카메라 사용 설명 설정

### 3-3. 앱 빌드

기준 커밋 `43fd76d`의 commit message에는 다음 검증이 기록되어 있다.

- 225 tests pass
- app build succeeds
- booted simulator에서 splash와 onboarding 확인

이번 점검 환경에서 같은 `xcodebuild`를 재실행했을 때는 앱 소스 컴파일 전에 `CoreSimulatorService` 연결 실패와 `sandbox-exec: sandbox_apply: Operation not permitted`로 중단됐다. 따라서 이번 세션이 독립적으로 빌드를 재현하지는 못했지만, 현재 커밋 자체에는 빌드 성공 기록이 있고 현재 앱 소스 파싱도 통과한다.

## 4. 발견 사항

### 해결 — 알림 액션 백필 중간 실패 안전성

기존 문제:

- `ReminderActionBackfill.runIfNeeded()`는 기존 `notificationGroupID`를 그대로 `scheduleDailyPattern`에 넘긴다.
- 같은 identifier의 `UNNotificationCenter.add`는 기존 요청을 덮어쓴다.
- `UserNotificationReminderScheduler.scheduleDailyPattern`은 중간 add 실패 시 이번 루프에서 성공한 identifier를 모두 `removePendingNotificationRequests`로 제거한다.

새 그룹을 만드는 일반 설정 저장에서는 이 롤백이 안전하다. 그러나 백필은 기존 그룹과 같은 identifier를 사용하므로, 예를 들어 다섯 시각 중 앞의 두 개를 덮어쓴 뒤 세 번째에서 실패하면 앞의 두 기존 알림까지 제거된다. 다음 앱 실행의 재시도가 성공하면 복구되지만 그 사이에는 일부 반복 알림이 빠진다.

기존 `ReminderActionBackfillTests`의 fake scheduler는 실제 scheduler의 identifier 제거 동작을 모델링하지 않아 이 조합을 잡지 못했다.

반영:

- 백필마다 새 group ID를 만든다.
- 새 그룹 예약이 전부 성공한 뒤에만 SwiftData의 group ID를 교체한다.
- 저장까지 성공한 뒤에만 기존 그룹을 취소한다.
- 예약 실패 시 기존 그룹과 저장값을 유지하고 다음 실행에서 재시도한다.
- 새 그룹 선등록·기존 그룹 후취소·저장값 교체·실패 보존 회귀 테스트를 추가했다.

### P1 — 최신 실기기 E2E 검증 공백

자동 테스트와 simulator build는 아래 경계를 대신하지 못한다.

- iOS 17+ 실기기에서 반복 알림 등록·변경·비활성화·문구 순서
- 잠금화면 “웃었어요”의 background-only SwiftData 저장
- “가이드 열기”와 일반 탭 딥링크
- category 백필 성공·중간 실패·다음 실행 재시도
- TrueDepth 권한 허용·거부, 얼굴 이탈, 조명, 방향, 프리뷰 토글
- background/scene inactive/전화 인터럽트 뒤 카메라 중지와 요약
- 종료 후 측정값·타임라인·세션 시간 비영속성
- App Privacy Report에서 네트워크 접속 없음과 카메라 접근 시간

### 해결 — 철회된 얼굴 스냅샷을 지시하던 하위 AI 지침

루트 `AGENTS.md`, `CLAUDE.md`, 서비스 지침과 현재 코드는 “still image를 만들지 않고 `capturedImage`를 읽지 않는다”고 일치한다.

그러나 아래 하위 지침은 반대로 스냅샷 구현을 요구한다.

- `SmileDay/Views/Coaching/AGENTS.md`: `snapshotJPEGData()`, `[Data]` snapshot array
- `CoachingKit/Sources/CoachingKit/AGENTS.md`: snapshot slots와 app-owned snapshot array
- `CoachingKit/Tests/CoachingKitTests/AGENTS.md`: snapshot slot tests

루트 지침이 우선하므로 현재 코드에는 사진 경로가 없었지만, 해당 디렉터리만 보고 작업하는 에이전트가 제거된 기능을 되살릴 위험이 있었다.

반영:

- 세 파일에서 snapshot slot, JPEG data, app-owned snapshot array 지침을 제거했다.
- `ARFrame.capturedImage`를 읽거나 still image·캡처·저장·공유 경로를 추가하지 말라는 현재 규칙으로 통일했다.
- 실제 사용자 문구와 다른 “영상과 점수” 표현을 “영상과 측정값”으로 바로잡았다.

관련 설계 문서도 상단에서 사진 관련 절을 무효라고 선언했지만 본문에는 예전 구현 내용이 길게 남아 있다. 역사 기록과 현재 규칙을 명확히 분리하는 편이 안전하다.

### P2 — SwiftData 저장 실패 뒤 context 변경이 남을 수 있음

`SmileMomentRepository.save`는 insert 후 save가 실패해도 삽입을 취소하지 않는다. `SmileReminderScheduleRepository.save`도 기존 모델의 여러 필드를 바꾼 뒤 save가 실패할 때 원래 값을 복원하지 않는다.

지속 저장이 실패했더라도 같은 `ModelContext`에는 pending insert·수정이 남을 수 있다. 이후 다른 저장이 성공하면 사용자가 실패했다고 안내받은 완료나 스케줄 변경이 뒤늦게 함께 저장될 가능성이 있다.

권장:

- repository 저장 실패 시 자신이 만든 insert·수정만 되돌리는 명시적 정리 정책을 둔다.
- 다른 변경까지 지우는 무조건적 context 전체 rollback은 피하고, 저장소 단위로 원본 값을 복원하거나 독립 context/transaction 경계를 검토한다.
- save failure를 주입할 수 있는 경계를 만들어 회귀 테스트를 추가한다.

### P2 — 완료 저장 실패 화면의 “다시 시도” 동작이 없음

5초 완료 저장이 실패하면 문구는 “다시 시도해주세요”라고 안내하지만 phase는 `.completed`이고 화면에는 닫기 버튼만 있다. 같은 완료 저장을 다시 시도하는 기능은 없다. 사용자는 닫고 처음부터 5초를 다시 실행해야 한다.

저장 재시도 버튼을 제공하거나, 현재 가능한 행동에 맞게 문구를 바꾸는 것이 좋다.

## 5. 양호한 점

- 핵심 행동 루프가 가장 짧고 카메라와 완전히 분리되어 있다.
- 실시간 모드는 repository가 없고 `capturedImage`·네트워크·파일 쓰기 경로도 없다.
- 알림 액션의 `.notificationAction`과 5초 가이드의 `.notification`을 구분해 행동 의미가 섞이지 않는다.
- 새 알림 그룹을 먼저 등록하는 교체 순서와 부분 등록 롤백이 일반 설정 저장 경로에서는 잘 설계되어 있다.
- 기존 7개 SwiftData 모델과 레거시 identifier/payload 호환성 안전망이 있다.
- 저장소 초기화·읽기 실패를 빈 데이터나 강제 종료로 숨기지 않는다.
- 사용자 문구는 한국어이고 외모·감정·치료·스트릭 손실 평가를 피한다.
- 노랑 주조색 전환 뒤 버튼 글자, 로딩 spinner, 최근 7일 점의 대비를 코드와 테스트로 보강했다.

## 6. 권장 우선순위

1. 반복 알림·잠금화면 액션 실기기 E2E
2. TrueDepth 실기기 QA와 비영속성 확인
3. 저장 실패 후 context 정리와 완료 재시도 UX
4. Archive 번들의 `PrivacyInfo.xcprivacy` 포함 및 App Store Connect 개인정보 응답 대조

## 7. 다음 점검 시 갱신 규칙

- 이 문서는 `43fd76d`의 스냅샷이다.
- 위 P1/P2에 영향을 주는 코드 변경 뒤 관련 테스트·빌드·실기기 결과를 다시 확인한다.
- 새로운 전체점검을 수행하면 이 문서를 갱신하거나 더 최신 날짜의 보고서로 대체하고 루트 `AGENTS.md`의 최신 보고서 링크도 함께 바꾼다.
