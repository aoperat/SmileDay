# 미소 습관 중심 제품 전환 Implementation Plan

> **중단:** 이 계획은 `SmileDay/docs/superpowers/plans/2026-07-28-notification-smile-mvp.md`로 대체되었다. 남은 Task를 실행하지 않는다. 이미 완료된 변경이 있다면 새 계획 Task 0에서 현 상태와 충돌 여부를 먼저 확인한다.

> **For agentic workers:** 각 Task를 순서대로 수행하고 체크박스로 진행 상태를 기록한다. 구현 전 대응 설계 `SmileDay/docs/superpowers/specs/2026-07-27-smile-habit-reframe-design.md`를 전체 읽는다.

**Goal:** 점수 개선 중심의 현재 경험을 질문→미소→선택적 좋은 순간 기록→습관 회고 흐름으로 전환한다. AR 측정 데이터와 기존 저장 기록은 보존하되 일반 사용자 화면과 추천 로직에서 얼굴 평가를 제거한다.

**Architecture:** `CoachingKit`에 optional SwiftData 필드, 회고 값 타입, 저장소 갱신 API, 행동 기반 격려 엔진과 ViewModel 집계를 둔다. 앱 타깃은 점수를 노출하지 않는 SwiftUI 흐름과 “쉬어가기” 콘텐츠를 제공한다. 기존 모델·필드는 삭제하거나 이름을 바꾸지 않고 전방 호환 방식으로 확장한다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, ARKit, UserNotifications, Observation, XCTest, Swift Charts.

---

## 선행 조건과 변경 보호

- [x] 루트 `AGENTS.md`와 대상 하위 `AGENTS.md`를 다시 확인한다.
- [x] `SmileDay/docs/reports/2026-07-27-project-review.md`의 P0 안정성 항목을 확인한다.
- [x] 가능하면 `2026-07-27-project-hardening.md`를 먼저 완료한다. 완료하지 못했다면 iOS 타깃, SwiftData/Metal 강제 종료 위험을 이 작업의 미해결 선행 위험으로 기록한다.
- [x] 기존 작업 트리를 확인하고 사용자 변경을 덮어쓰지 않는다.

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git status --short
git diff --check
```

- [x] 기준 테스트 결과를 기록한다.

```bash
cd CoachingKit
swift test
cd ..
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

샌드박스가 사용자 캐시나 CoreSimulatorService 접근을 막으면 임시 캐시와 `swift test --disable-sandbox`를 사용하고, 앱 빌드는 환경 제한으로 분리 기록한다.

---

### Task 1: 회고 데이터 모델과 저장 API

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/CheckInSession.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SessionRepository.swift`
- Create: `CoachingKit/Sources/CoachingKit/SmileReflection.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileReflectionTests.swift`

- [x] `CheckInSession`에 아래 optional 필드를 추가한다.

```swift
public var promptText: String? = nil
public var smileMomentNote: String? = nil
```

- [x] initializer 끝에 기본값 `nil`인 인자를 추가해 기존 호출부와 과거 데이터 호환을 유지한다.
- [x] `SmileReflection` 값 타입을 추가한다.
- [x] 메모 정규화 규칙을 순수 로직으로 구현한다.
  - 앞뒤 공백과 줄바꿈 제거
  - 비어 있으면 nil
  - 최대 200자
  - 200자를 넘는 입력은 UI에서 막고 저장소에서도 200자로 제한
- [x] `SessionRepository.saveCheckIn(...)`에 optional `promptText` 인자를 추가하고 세션 저장 시 함께 기록한다.
- [x] `updateReflectionOnLatestCheckIn(_:)`를 추가해 mood와 note를 한 번의 `modelContext.save()`로 갱신한다.
- [x] 체크인이 없을 때는 기존 `updateMoodOnLatestCheckIn`처럼 안전하게 아무 것도 하지 않는다.
- [x] 기존 `updateMoodOnLatestCheckIn`는 호출부 전환 후 제거하거나 새 API를 호출하는 호환 래퍼로 남긴다.

Tests:

- [x] 기존 필드가 nil인 레코드를 정상 생성·조회
- [x] prompt 저장 round-trip
- [x] mood + note 동시 저장
- [x] 공백 메모가 nil로 저장
- [x] 200자 경계와 초과 입력 제한
- [x] 체크인이 없을 때 no-op
- [x] 기존 요약/payload 저장 테스트 회귀

```bash
cd CoachingKit
swift test --filter SmileReflectionTests
swift test --filter SessionRepositoryTests
```

---

### Task 2: 질문 카탈로그를 비평가적 문구로 개편

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/ReminderPrompt.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift`

- [x] 시간대별 8개, 총 24개 구조와 `TimeBucket` API를 유지한다.
- [x] 타인의 시선, 표정 평가, 감정 강요를 포함한 질문을 교체한다.
- [x] 각 시간대에 다음 의도를 고르게 배치한다.
  - 아침: 기대, 자신에게 건네는 여유, 가벼운 미소 초대
  - 낮: 숨 고르기, 최근 즐거운 순간, 잠깐의 휴식
  - 저녁: 감사한 일, 웃게 한 순간, 내일을 위한 부드러운 마무리
- [x] “떠오르지 않아도 괜찮다”는 허용적 질문을 최소 시간대별 1개 포함한다.
- [x] 아래 금지 패턴이 카탈로그에 없는지 테스트한다.
  - `누군가 당신을 본다면`
  - `어떤 표정을 보고`
  - `편안해 보일`
  - `더 크게`
  - `교정`
- [x] 기존 비반복 순환과 알림 payload 테스트가 계속 통과하는지 확인한다.

```bash
cd CoachingKit
swift test --filter ReminderPromptCatalogTests
swift test --filter ReminderPromptSelectorTests
swift test --filter ReminderNotificationPayloadTests
```

---

### Task 3: 행동 기반 격려 엔진 추가

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/HabitEncouragementEngine.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/HabitEncouragementEngineTests.swift`
- Modify: `CoachingKit/Sources/CoachingKit/InsightEngine.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift`

- [x] `HabitContext`와 `HabitEncouragement` 값을 정의한다.

```swift
public struct HabitContext: Equatable, Sendable {
    public let todayCheckInCount: Int
    public let streakDays: Int
    public let recentSevenDayCount: Int
    public let daysSincePreviousCheckIn: Int?
    public let hasMomentNote: Bool
}
```

- [x] 설계의 고정 우선순위로 메시지를 만드는 순수 `HabitEncouragementEngine.evaluate(_:)`를 구현한다.
- [x] 첫 기록, 같은 날 반복, 3일 이상 연속, 공백 후 복귀, 메모 있음, 기본 상태를 각각 테스트한다.
- [x] `0일`, `실패`, `깨짐`, `복구`, `점수`, `개선` 같은 압박·평가 표현이 결과 문구에 없는지 테스트한다.
- [x] `InsightEngine`은 저장 호환 및 향후 내부 연구를 위해 당장 삭제하지 않되 `CareViewModel`과 완료 UI에서 호출하지 않도록 공개 사용처를 제거한다.
- [x] `InsightEngine` 주석에 “기본 사용자 메시지 생성에 사용하지 않음”을 명시한다.

```bash
cd CoachingKit
swift test --filter HabitEncouragementEngineTests
swift test --filter InsightEngineTests
```

---

### Task 4: SessionRepository 습관 집계 API

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/SessionRepository.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`

- [x] ViewModel이 SwiftData를 직접 다루지 않도록 다음 조회를 저장소에 추가한다.
  - 특정 날짜의 체크인 횟수
  - 날짜 범위의 고유 체크인 일수
  - 날짜 범위의 한 줄 기록 수
  - 최신 한 줄 기록이 있는 체크인
  - 직전 체크인 날짜
- [x] 기존 `fetchCheckIns(from:to:)`를 조합하되 화면별 N+1 조회가 생기지 않도록 범위 조회 결과를 ViewModel에서 한 번에 집계하는 방식을 우선한다.
- [x] 경계 시각, 같은 날 여러 체크인, note nil/공백, 월 경계 테스트를 추가한다.

```bash
cd CoachingKit
swift test --filter SessionRepositoryTests
```

---

### Task 5: CoachingViewModel에서 사용자 점수 결과 제거

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/CoachingViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/CoachingViewModelTests.swift`

- [x] `Phase.completed(scoreDelta:)`를 `Phase.completed`로 변경한다.
- [x] `complete(promptText:)`가 내부적으로 기존 점수와 payload를 계속 저장하되 UI 결과로 점수를 반환하지 않게 한다.
- [x] 전달된 질문을 `SessionRepository.saveCheckIn(..., promptText:)`에 저장한다.
- [x] `displayedMeasurement`는 저장 버튼 활성화와 트래킹 준비 상태에만 사용한다.
- [x] `yesterdayDelta()`를 제거하고 호출부·테스트를 습관 집계로 대체한다.
- [x] 아래를 테스트한다.
  - promptText가 저장됨
  - 일반 진입 nil prompt 저장
  - 측정이 없으면 완료되지 않음
  - 두 번 완료해도 중복 저장하지 않음
  - scoreDelta/payload 기존 저장 회귀

```bash
cd CoachingKit
swift test --filter CoachingViewModelTests
```

---

### Task 6: 촬영 화면을 “미소 시간”으로 전환

**Files:**

- Modify: `SmileDay/Views/Coaching/CoachingSessionView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingTabView.swift`
- Modify: `SmileDay/Views/SharedStrings.swift`

- [x] `CoachingSessionView`에서 아래 UI를 제거한다.
  - `liveDelta`
  - 숫자 점수 capsule
  - `VerticalGaugeView`
  - “지금 미소 크기”
- [x] 화면 하단을 다음 상태 중심으로 변경한다.
  - 측정 전: “얼굴을 가이드 안에 맞춰주세요”
  - 측정 가능: “편하게 숨을 쉬고 살짝 미소 지어보세요”
  - 버튼: “오늘의 미소 남기기”
- [x] 조명, 각도, 카메라 오류 안내와 완료 버튼 안전 조건은 유지한다.
- [x] `onCompleted` 콜백에서 점수 인자를 제거하고 완료 시각·질문만 다음 화면에 전달한다.
- [x] 알림 딥링크 질문은 상단에 유지하고 저장할 `promptText`와 동일한 값인지 확인한다.
- [x] VoiceOver에서 카메라 가이드→질문→상태→완료 버튼 순서로 읽히는지 확인한다.

Verification:

```bash
rg -n '미소 크기|liveDelta|VerticalGaugeView|signedDegrees' \
  SmileDay/Views/Coaching
```

검색 결과가 0이거나 호환용 비사용 코드만 남아야 한다.

---

### Task 7: 완료 화면에 선택적 좋은 순간 기록 추가

**Files:**

- Modify: `SmileDay/Views/Coaching/SaveConfirmView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingTabView.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`

- [x] `SaveConfirmView`에서 오늘/어제 점수, 상승 배지, 얼굴 지표 인사이트를 제거한다.
- [x] 메인 문구를 “오늘도 잠시 웃어봤어요”로 변경한다.
- [x] `TextField` 또는 짧은 `TextEditor`로 좋은 순간 입력을 추가한다.
- [x] 입력은 최대 200자이며 현재 글자 수를 접근 가능하게 안내한다.
- [x] 기분 선택과 메모는 모두 optional이다.
- [x] 확인 버튼에서 `SmileReflection(mood:momentNote:)`를 한 번 전달한다.
- [x] `CoachingTabView`가 `SessionRepository.updateReflectionOnLatestCheckIn`을 호출한 뒤 홈으로 이동한다.
- [x] 저장 실패 시 완료 화면을 닫지 않고 `SharedStrings.saveFailed`를 표시한다.
- [x] `InsightEngine.evaluateLatest` 호출을 제거하고 `HabitEncouragementEngine` 결과를 표시한다.
- [x] 리마인더 제안은 유지하되 회고 저장과 별개로 실패해도 체크인 완료를 잃지 않게 한다.

Verification:

```bash
rg -n '어제보다|오늘 .*°|InsightEngine|scoreDelta|todayScore|yesterdayScore' \
  SmileDay/Views/Coaching
```

---

### Task 8: 홈 ViewModel과 화면을 습관 중심으로 변경

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/HomeViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/HomeViewModelTests.swift`
- Modify: `SmileDay/Views/Home/HomeView.swift`

- [x] `HomeViewModel`에서 사용자 표시용 `todayScore`, `yesterdayScore`, `weeklyAverageScore`를 제거한다.
- [x] 아래 상태를 추가한다.
  - `todayCheckInCount`
  - `weekCheckInDayCount`
  - `weekMomentNoteCount`
  - `latestMomentNote`
  - 기존 `recentWeek`, `streakDays`, `hasCheckedInToday`
- [x] 같은 날 여러 체크인은 오늘 횟수에는 모두 반영하고 주간 일수에는 하루로 계산한다.
- [x] `HomeView`에서 `ArcGaugeView`와 7일 평균 카드를 제거한다.
- [x] hero를 오늘의 질문/완료 상태/CTA 중심 카드로 교체한다.
- [x] 통계는 “이번 주 웃어본 날”, “남긴 좋은 순간”으로 표시한다.
- [x] 최근 메모가 있으면 따옴표 없이 최대 두 줄로 표시하고 없으면 빈 상태를 만들지 않는다.
- [x] 기준선 4주 재촬영 홈 넛지를 제거한다. 설정의 수동 재촬영 경로는 유지한다.
- [x] 빠진 날 도트는 회색으로만 표시하고 실패 아이콘이나 경고색을 쓰지 않는다.

```bash
cd CoachingKit
swift test --filter HomeViewModelTests
```

---

### Task 9: 기록 ViewModel과 화면을 활동·회고 중심으로 변경

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/HistoryViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/HistoryViewModelTests.swift`
- Modify: `SmileDay/Views/History/HistoryView.swift`

- [x] `DailyScore`를 `SmileDayActivity`로 대체한다.

```swift
public struct SmileDayActivity: Equatable, Identifiable {
    public let date: Date
    public let checkInCount: Int
    public let hasMomentNote: Bool
}
```

- [x] 최근 회고 표시용 `SmileMomentEntry(date:mood:note:promptText:)` 값을 추가한다.
- [x] `HistoryViewModel`이 아래를 제공한다.
  - 최근 7일 활동
  - 이번 달 웃어본 고유 일수
  - 현재 연속 일수
  - 시간대별 체크인 횟수
  - 최근 좋은 순간 목록
- [x] `weeklyAverageScore`, `weeklyScores`, `bucketScores`를 사용자 경로에서 제거한다.
- [x] 기록 화면을 다음 순서로 재구성한다.
  1. 연속 일수 / 이번 달 웃어본 날 / 남긴 좋은 순간
  2. 최근 7일 활동 차트
  3. 월간 웃어본 날 캘린더
  4. 아침·낮·저녁 미소 시간 횟수
  5. 좋은 순간 목록
- [x] 점수 y축, degree 단위, 점수 색상 비교를 제거한다.
- [x] 과거 레코드에 mood/note가 없어도 캘린더와 활동 수는 정상 표시한다.

```bash
cd CoachingKit
swift test --filter HistoryViewModelTests
```

---

### Task 10: “케어”를 “쉬어가기”로 교체

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmilePractice.swift`
- Create: `CoachingKit/Sources/CoachingKit/SmilePracticeViewModel.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmilePracticeTests.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmilePracticeViewModelTests.swift`
- Modify: `CoachingKit/Sources/CoachingKit/CareRepository.swift`
- Modify: `SmileDay/Views/Care/CareView.swift`
- Modify: `SmileDay/Views/Care/CarePlayerView.swift`
- Modify: `SmileDay/Views/MainTabView.swift`
- Remove after migration: `CoachingKit/Sources/CoachingKit/CareRoutine.swift`
- Remove after migration: `CoachingKit/Sources/CoachingKit/CareViewModel.swift`
- Remove after migration: matching obsolete tests

- [x] 새 값 타입 이름은 `SmilePractice`, `SmilePracticeStep`, `SmilePracticeCategory`를 사용한다.
- [x] 카테고리를 얼굴 부위가 아니라 경험 의도로 정의한다.
  - `.pause`: 잠깐 멈춤
  - `.recall`: 좋은 순간
  - `.breathe`: 숨 고르기
  - `.connect`: 따뜻한 연결
- [x] 최소 5개의 기본 콘텐츠를 설계 문서 방향으로 작성한다.
- [x] 근육, 림프, 붓기, 좌우 균형, 점수 상승을 약속하는 제목·설명을 제거한다.
- [x] 재생 완료·중도 이탈은 기존 `CareRepository`와 `CareSession.routineID`에 계속 저장해 데이터 모델 변경을 피한다.
- [x] 새 practice ID는 기존 ID와 충돌하지 않게 `smile-` 접두사를 사용한다.
- [x] 기존 즐겨찾기 ID가 새 카탈로그에 없으면 조용히 무시하고 UserDefaults를 강제로 삭제하지 않는다.
- [x] 추천은 얼굴 지표가 아니라 시간대와 최근 완료 여부로 결정한다.
  - 아침: 하루 시작 practice
  - 낮: 숨 고르기 practice
  - 저녁: 좋은 순간 회고 practice
- [x] `AppTab.care`의 내부 case는 유지해도 되지만 표시명은 “쉬어가기”, 아이콘은 평가·미용보다 휴식을 나타내는 심볼로 변경한다.
- [x] 앱 뷰 파일 이름 변경은 Xcode 프로젝트 참조까지 안전하게 갱신할 수 있을 때만 한다. 그렇지 않으면 파일명 `CareView.swift`는 유지하고 타입부터 단계적으로 전환한다.
- [x] 새 타입 전환 후 `CareRoutine`/`CareViewModel` 참조가 0인지 확인한 뒤에만 제거한다.

```bash
rg -n 'CareRoutine|CareViewModel|InsightEngine|scoreDelta|붓기|림프|균형' \
  SmileDay/Views/Care CoachingKit/Sources/CoachingKit --glob '*.swift'
cd CoachingKit
swift test --filter SmilePracticeTests
swift test --filter SmilePracticeViewModelTests
swift test --filter CareRepositoryTests
```

---

### Task 11: 앱 전반 용어와 접근성 정리

**Files:**

- Modify: `SmileDay/Views/MainTabView.swift`
- Modify: `SmileDay/Views/Onboarding/OnboardingIntroView.swift`
- Modify: `SmileDay/Views/Onboarding/BaselineCaptureView.swift`
- Modify: `SmileDay/Views/Settings/SettingsView.swift`
- Modify: `SmileDay/Views/Settings/DataLocationView.swift`
- Modify: `SmileDay/Views/SharedStrings.swift`
- Modify as found: all user-facing Swift files

- [x] 온보딩에서 “정확한 점수”, “개선”보다 미소 습관과 사진 미저장 원칙을 먼저 설명한다.
- [x] 기준선은 “잘 웃는 기준”이 아니라 카메라가 사용자의 평소 표정을 참고하기 위한 초기 설정으로 설명한다.
- [x] 탭과 제목을 “코칭”→“미소”, “케어”→“쉬어가기”로 변경한다.
- [x] 설정의 기준선 재촬영 문구에서 점수 향상 기대를 제거한다.
- [x] 빈 상태는 행동을 초대하되 죄책감을 주지 않게 작성한다.
- [x] Dynamic Type, Reduce Motion, VoiceOver 레이블을 확인한다.
- [x] 사용자 노출 문구 정적 검색:

```bash
rg -n '점수|미소 크기|어제보다|올라갔|내려갔|약한 쪽|진짜 미소|억지 미소|교정|개선|리프팅|치료' \
  SmileDay CoachingKit --glob '*.swift'
```

측정 내부 변수·테스트 이름과 사용자 노출 문자열을 구분해 판정한다. 남는 사용자 문구는 각각 설계 목적을 설명할 수 있어야 한다.

---

### Task 12: Pro 계획을 새 가치에 맞게 갱신

**Files:**

- Modify: `SmileDay/docs/superpowers/specs/2026-07-24-pro-unlock-design.md`
- Modify: `SmileDay/docs/superpowers/plans/2026-07-24-pro-unlock.md`

- [x] 이 제품 전환 구현과 사용자 검증 전에는 StoreKit Pro 작업을 시작하지 않는다는 선행 조건을 추가한다.
- [x] 기존 “케어 루틴 전체/시간대별 점수 상세” 혜택을 제거한다.
- [x] 무료 핵심을 다음으로 확정한다.
  - 매일 미소 시간
  - 기본 질문
  - 기분과 한 줄 기록
  - 최근 7일
  - 기본 쉬어가기 콘텐츠
  - 리마인더 1개
- [x] Pro 후보를 다음으로 변경한다.
  - 다중 리마인더
  - 전체 좋은 순간 보관함
  - 주간 돌아보기
  - 추가 질문·쉬어가기 팩
  - 사용자 지정 질문
  - 내보내기
- [x] 아직 구현하지 않은 혜택을 페이월에 표시하지 않는다.
- [x] `₩5,900` 검증 가격은 유지하되 위 혜택 중 최소 3개가 실제 완성되기 전 판매하지 않는다.
- [x] 광고 손익 게이트와 StoreKit 거래 상태 계획은 유지한다.

---

### Task 13: 전체 회귀 검증

- [x] CoachingKit 전체 테스트:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test
```

Expected: `Test Suite 'All tests' passed`.

- [x] 앱 빌드:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] 스키마 호환 확인:
  - 기존 데이터가 있는 앱 업데이트 후 실행
  - 과거 체크인이 활동 캘린더에 표시
  - 과거 mood/note nil 안전
  - 기존 CareSession 삭제 없음
  - 새 회고 저장 후 재실행 유지

- [x] 정적 검사:

```bash
rg -n 'try!.*ModelContainer|fatalError' SmileDay --glob '*.swift'
rg -n 'InsightEngine\\.evaluateLatest|weeklyAverageScore|todayScore|yesterdayScore|bucketScores' \
  SmileDay CoachingKit --glob '*.swift'
git diff --check
git status --short
git diff --stat
```

- [ ] TrueDepth 실기기 검증:
  - 일반 진입과 알림 딥링크 진입
  - 질문 표시
  - 얼굴 감지 전후 상태 안내
  - 미소 완료
  - 기분만 저장
  - 메모만 저장
  - 모두 비워서 저장
  - 200자 경계
  - 홈 즉시 갱신
  - 기록 화면 회고 표시
  - 백그라운드 복귀
  - 앱 재실행 후 데이터 유지

결과는 `SmileDay/docs/reports/YYYY-MM-DD-smile-habit-device-verification.md`에 기기, iOS, 빌드/커밋, PASS/FAIL만 기록한다. 얼굴 이미지·영상·원시 얼굴 수치를 저장소에 추가하지 않는다.

---

### Task 14: 제품 수용 기준 확인

- [ ] 내부 QA에서 아래 질문에 모두 “예”로 답할 수 있어야 한다.
  - 점수를 보지 않고도 사용자가 오늘 할 일을 이해하는가?
  - 힘든 기분을 선택해도 앱이 사용자를 교정하거나 훈계하지 않는가?
  - 메모를 비워도 완료 경험이 온전한가?
  - 기록 화면이 얼굴 성과가 아니라 웃어본 날과 좋은 순간을 보여주는가?
  - 쉬어가기 콘텐츠가 외모 개선이 아니라 잠깐의 여유를 제공하는가?
- [ ] 5~10명의 소규모 사용성 확인에서 다음을 질문한다.
  - 이 앱이 무엇을 도와준다고 이해했는가?
  - 점수를 올려야 한다는 압박을 느꼈는가?
  - 좋은 순간 기록이 부담스러웠는가?
  - 다음 날 다시 열 이유가 있었는가?
- [ ] “얼굴 개선 앱”으로 이해하는 사용자가 반복되면 홍보가 아니라 온보딩·홈·완료 문구를 먼저 수정한다.
- [ ] 이 수용 기준을 통과한 뒤 Pro 가치 구현과 유료 홍보 단계로 이동한다.
