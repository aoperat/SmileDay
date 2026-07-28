# 알림 중심 미소 습관 MVP Implementation Plan

> **For agentic workers:** 이 계획은 `2026-07-27-smile-habit-reframe.md`를 대체한다. 구현 전 `SmileDay/docs/superpowers/specs/2026-07-28-notification-smile-mvp-design.md`를 전체 읽고 Task를 순서대로 수행한다.

**Goal:** 카메라·점수·감정 기록 없이, 사용자가 여러 알림과 3개 미소 가이드를 설정하고 5초 실행을 완료한 뒤 오늘 횟수와 최근 7일을 볼 수 있는 최소 제품을 만든다.

**Architecture:** `CoachingKit`에 고정 가이드 카탈로그, `SmileMoment` SwiftData 모델, 저장소, 홈/가이드 ViewModel, 가이드가 연결된 리마인더 로직을 둔다. 앱 타깃은 로컬 알림, 딥링크 라우팅, 홈·가이드·설정 화면만 제공한다. 기존 얼굴 측정 모델은 저장 호환을 위해 스키마에 유지하지만 새 흐름에서 사용하지 않는다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, UserNotifications, Observation, XCTest, iOS 17+.

---

### Task 0: 현재 변경과 배포 상태 확인

**Files:** none

- [x] 작업 트리와 기존 사용자 변경을 확인한다.

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git status --short
git diff --check
```

- [x] `2026-07-27-smile-habit-reframe.md`에서 이미 구현된 Task가 있는지 코드로 확인한다. 체크박스만 신뢰하지 않는다.
- [x] 앱이 App Store/TestFlight/외부 사용자에게 배포된 적이 있는지 릴리스 기록으로 확인한다.
  - 배포 이력이 있거나 불명확: 기존 SwiftData 모델과 필드를 삭제하지 않는다.
  - 확실한 미배포: 이번 계획에서도 우선 보존하고, MVP 완성 후 별도 cleanup에서 삭제 여부를 결정한다.
- [x] `2026-07-27-project-hardening.md`의 iOS 17, SwiftData 시작 실패, Metal 강제 종료 항목의 실제 코드 상태를 확인한다.
- [x] 기준 테스트와 앱 빌드를 기록한다.

```bash
cd CoachingKit && swift test
cd ..
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

환경 권한 때문에 실패하면 코드 실패와 구분해 기록한다.

---

### Task 1: 고정 미소 가이드 카탈로그

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileGuide.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileGuideTests.swift`

- [x] `SmileGuide` 값 타입과 `SmileGuideCatalog`를 추가한다.
- [x] 카탈로그는 설계의 `soft-smile`, `greeting-smile`, `bright-smile` 3개만 제공한다.
- [x] 모든 가이드의 duration은 5초로 고정한다.
- [x] `guide(id:)`는 알 수 없는 ID와 nil을 `soft-smile`로 대체한다.
- [x] title, instruction, notificationText가 비어 있지 않은지 테스트한다.
- [x] 가이드 문구에 점수·개선·교정·행복 보장 표현이 없는지 테스트한다.

```bash
cd CoachingKit
swift test --filter SmileGuideTests
```

---

### Task 2: SmileMoment 저장 모델과 저장소

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileMoment.swift`
- Create: `CoachingKit/Sources/CoachingKit/SmileMomentRepository.swift`
- Modify: `CoachingKit/Sources/CoachingKit/PersistenceSchema.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileMomentTests.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileMomentRepositoryTests.swift`

- [x] `SmileMomentSource`를 `manual`/`notification` raw String enum으로 추가한다.
- [x] `SmileMoment`에 `date`, `guideID`, `sourceRawValue`를 저장한다.
- [x] 알 수 없는 source는 값 타입 변환 시 `.manual`로 처리한다.
- [x] `PersistenceSchema.models`에 `SmileMoment.self`를 추가하고 기존 4개 모델은 유지한다.
- [x] `SmileMomentRepository`에 다음 API를 추가한다.
  - `save(guideID:source:date:)`
  - `fetch(from:to:)`
  - `count(onDayOf:)`
  - `recentSevenDays(endingOn:)`
  - `weekActiveDayCount(endingOn:)`
- [x] 같은 날 여러 완료는 횟수로 모두 저장하고 active day는 하루로 계산한다.
- [x] 날짜 정렬, 일 경계, 주 경계, 빈 저장소를 테스트한다.
- [x] in-memory ModelContainer 테스트 스키마에도 `SmileMoment`를 포함한다.

```bash
cd CoachingKit
swift test --filter SmileMomentTests
swift test --filter SmileMomentRepositoryTests
```

---

### Task 3: 리마인더에 가이드 연결

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/ReminderSetting.swift`
- Modify: `CoachingKit/Sources/CoachingKit/ReminderRepository.swift`
- Modify: `CoachingKit/Sources/CoachingKit/ReminderScheduling.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderRepositoryTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`

- [x] `ReminderSetting.guideID: String? = nil`을 추가한다.
- [x] initializer 끝에 기본값 nil 인자를 추가해 기존 호출부를 유지한다.
- [x] `ReminderRepository.add`가 guideID를 받고, 기존 nil 레코드는 기본 가이드로 해석한다.
- [x] `updateGuide(_:guideID:)`를 추가한다.
- [x] `ReminderScheduling.scheduleRollingWindow`에 `guideID`를 전달한다.
- [x] `SettingsViewModel`의 추가·시간 수정·전체 재예약이 저장된 guideID를 보존한다.
- [x] 다중 알림 개수를 제한하는 Pro 게이팅이 구현되어 있다면 MVP 경로에서 제거한다.
- [x] 과거 nil guideID, 새 가이드 저장, 가이드 변경 후 재예약을 테스트한다.

```bash
cd CoachingKit
swift test --filter ReminderRepositoryTests
swift test --filter SettingsViewModelTests
```

---

### Task 4: 알림 payload와 스케줄러 전환

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/ReminderNotificationPayload.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderNotificationPayloadTests.swift`
- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift`

- [x] 새 payload가 `reminderID`와 `guideID`를 round-trip 한다.
- [x] 알 수 없는 guideID는 파싱 실패가 아니라 기본 가이드로 연결할 수 있게 원문 ID를 유지한다.
- [x] 과거 `bucket`/`promptText` payload는 다음 중 하나로 명시적으로 처리한다.
  - 필드가 있으면 기본 가이드 payload로 변환
  - 변환 불가능하면 nil로 홈 유지
- [x] 스케줄러는 `SmileGuide.notificationText`를 body로 사용한다.
- [x] `ReminderPromptSelector`와 24개 질문은 새 스케줄링 경로에서 제거한다.
- [x] 알림 identifier는 기존 `id-dayOffset` 형식을 유지해 취소와 재예약이 동작하게 한다.
- [x] 알림 권한 거부는 throw하지 않고 UI가 상태를 안내할 수 있게 반환값을 유지한다.

```bash
cd CoachingKit
swift test --filter ReminderNotificationPayloadTests
swift test --filter ReminderPromptSelectorTests
```

두 번째 테스트는 기존 타입을 아직 유지한다면 회귀 확인용이다. MVP 호출부가 0이 된 뒤 질문 관련 타입 삭제는 별도 cleanup으로 미룬다.

---

### Task 5: MVP 홈 ViewModel

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileHomeViewModel.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileHomeViewModelTests.swift`

- [x] 상태를 다음으로 제한한다.
  - `todayCompletionCount`
  - `weekActiveDayCount`
  - `recentSevenDays`
  - `nextReminder`
- [x] `SmileMomentRepository`, `ReminderRepository`, 주입된 `Calendar`와 `now`를 사용한다.
- [x] 다음 알림은 활성 알림 중 현재 이후 가장 가까운 시각을 고르고, 오늘 남은 알림이 없으면 다음 날 첫 알림을 반환한다.
- [x] 자정, 동일 시각, 비활성 알림, 알림 없음, 같은 날 여러 완료를 테스트한다.
- [x] 점수, mood, note, streak 손실 개념을 추가하지 않는다.

```bash
cd CoachingKit
swift test --filter SmileHomeViewModelTests
```

---

### Task 6: 가이드 실행 ViewModel

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileGuideViewModel.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileGuideViewModelTests.swift`

- [x] 상태 머신을 정의한다.

```swift
public enum Phase: Equatable {
    case ready
    case running(remainingSeconds: Int)
    case completed
}
```

- [x] 타이머 boundary는 protocol 또는 주입 가능한 async clock으로 분리해 테스트에서 실제 5초를 기다리지 않는다.
- [x] `start()`는 ready에서 한 번만 시작한다.
- [x] 0초가 되면 repository에 정확히 한 번 저장하고 completed로 전환한다.
- [x] 화면 닫기/cancel은 저장하지 않는다.
- [x] start 연타, 완료 콜백 중복, 취소 후 tick을 테스트한다.
- [x] guideID와 source가 저장소에 정확히 전달되는지 테스트한다.

```bash
cd CoachingKit
swift test --filter SmileGuideViewModelTests
```

---

### Task 7: 새 온보딩과 완료 상태 저장

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileOnboardingState.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileOnboardingStateTests.swift`
- Create: `SmileDay/Views/Onboarding/SmileMVPOnboardingView.swift`
- Modify: `SmileDay.xcodeproj/project.pbxproj` if required

- [x] `SmileOnboardingStoring` protocol, UserDefaults 구현, InMemory 구현을 추가한다.
- [x] 온보딩 완료 flag만 저장하고 알림 권한 상태를 UserDefaults로 추정하지 않는다.
- [x] 온보딩 화면에서 목적을 한 문장으로 설명한다.
  - “원하는 시간에 알림을 받고, 잠깐 미소 짓는 습관을 만들어보세요.”
- [x] 3개의 권장 시간과 가이드를 사용자가 수정·확정할 수 있게 한다.
- [x] 알림 권한은 설명 화면 다음 사용자 액션에서 요청한다.
- [x] 권한을 거부해도 수동 미소 기능으로 앱에 진입할 수 있다.
- [x] 알림과 설정 저장이 모두 끝난 뒤에만 onboarding 완료 flag를 기록한다.
- [x] 저장 실패 시 완료 처리하지 않고 한국어 오류를 표시한다.

권장 기본값:

- 09:00 → 편안한 미소
- 13:00 → 인사 미소
- 18:00 → 활짝 미소

---

### Task 8: 홈·가이드·설정 UI 구현

**Files:**

- Create: `SmileDay/Views/Home/SmileMVPHomeView.swift`
- Create: `SmileDay/Views/Coaching/SmileGuideView.swift`
- Create: `SmileDay/Views/Settings/SmileMVPSettingsView.swift`
- Modify: `SmileDay/Views/Theme.swift` only if reusable tokens are needed
- Modify: `SmileDay/Views/SharedStrings.swift`
- Modify: `SmileDay.xcodeproj/project.pbxproj` if required

- [x] `SmileMVPHomeView`:
  - “지금 미소 짓기”
  - 가이드 3개 선택
  - 오늘 완료 횟수
  - 이번 주 완료 일수
  - 최근 7일 횟수/도트
  - 다음 알림
  - 설정 버튼
- [x] `SmileGuideView`:
  - 가이드 title/instruction
  - 코드 기반 단순 얼굴 그래픽
  - 시작 버튼
  - 5→0 숫자 카운트다운
  - 완료 햅틱과 완료 문구
  - 닫기
- [x] `SmileMVPSettingsView`:
  - 기존 알림 목록 CRUD 재사용
  - 각 알림 행에 가이드 표시·수정
  - 권한 거부 시 시스템 설정 이동 안내
  - 데이터가 기기에만 저장된다는 설명
- [x] 가이드 화면에는 카메라 권한을 요청하지 않는다.
- [x] Dynamic Type, VoiceOver, Reduce Motion을 확인한다.
- [x] 사용자가 빠르게 완료 화면을 닫아도 저장 후 홈이 refresh 되는지 확인한다.

---

### Task 9: Root와 알림 딥링크를 MVP로 전환

**Files:**

- Modify: `SmileDay/Views/RootView.swift`
- Modify: `SmileDay/Services/NotificationRouter.swift`
- Modify: `SmileDay/Services/AppDelegate.swift`
- Modify: `SmileDay/SmileDayApp.swift`
- Modify: `SmileDay/Views/MainTabView.swift` or disconnect it from Root

- [x] `RootView`에서 baseline 존재 여부에 따른 진입 gate를 제거한다.
- [x] splash 후 onboarding 완료 여부로만 분기한다.
- [x] 완료 사용자는 `SmileMVPHomeView`로 진입한다.
- [x] `NotificationRouter.pendingCoaching`을 `pendingSmileGuide` 의미로 전환한다.
- [x] cold launch와 foreground 모두 payload의 guideID를 열도록 한다.
- [x] 알림 진입 source는 `.notification`, 홈 진입은 `.manual`로 전달한다.
- [x] 앱 활성화 시 rolling reminder 재예약은 유지하되 새 guideID를 포함한다.
- [x] `MainTabView`, 기존 Home/Coaching/Care/History는 새 Root에서 호출하지 않는다.
- [x] 기존 파일은 이 Task에서 삭제하지 않는다.
- [x] `SmileDayApp`은 기존 SwiftData schema와 `ko_KR` locale을 유지한다.

Verification:

```bash
rg -n 'BaselineCaptureView|MainTabView|pendingCoaching' SmileDay/Views/RootView.swift SmileDay/Services
```

새 Root 흐름에서 기존 진입 의존성이 없어야 한다.

---

### Task 10: 사용자 노출 범위 정리

**Files:**

- Modify as needed: `SmileDay/Views/**/*.swift`
- Modify: `SmileDay/Views/MainTabView.swift` if still compiled
- Do not delete persistence models in this Task

- [x] 새 MVP 화면에서 아래가 노출되지 않는지 확인한다.
  - 점수, degree
  - 미소 크기
  - 기준선
  - 얼굴 분석
  - 기분·좋은 순간 입력
  - 케어·마사지
  - Pro/paywall
- [x] 기존 화면이 빌드에는 포함되어도 Root와 알림에서 접근 불가능해야 한다.
- [x] 앱 이름·설명·온보딩은 “알림으로 미소를 의식하게 하는 앱”으로 통일한다.
- [x] 기존 ARKit/Metal/카메라 권한 설명이 Info.plist에 남는 것은 이번 Task에서 삭제하지 않는다. 실제 기능 정리 단계에서 프로젝트 설정과 함께 제거한다.
- [x] 금지 문구 검색:

```bash
rg -n '개선|교정|치료|리프팅|진짜 미소|억지 미소|어제보다|점수가|미소 크기' \
  SmileDay CoachingKit --glob '*.swift'
```

기존 비노출 파일과 새 MVP 사용자 경로를 구분해 결과를 기록한다.

---

### Task 11: 전체 테스트와 빌드

- [x] CoachingKit 전체:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test
```

Expected: `Test Suite 'All tests' passed`.

- [x] 앱:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [x] 스키마 호환:
  - 기존 Baseline/CheckInSession/CareSession이 있는 저장소로 업데이트 실행
  - 새 SmileMoment 저장·재실행
  - 과거 ReminderSetting guideID nil 기본 처리
  - 기존 데이터 삭제 없음
- [x] 중복 저장:
  - 시작 연타
  - 앱 백그라운드/복귀
  - 완료 직후 닫기
  - 알림 연속 탭
- [x] 정적 검사:

```bash
git diff --check
git status --short
git diff --stat
```

---

### Task 12: 실기기 알림 QA

**Required:** iOS 17 이상 iPhone. TrueDepth는 필요하지 않다.

- [ ] 신규 설치 → 온보딩 → 알림 허용
- [ ] 알림 거부 → 수동 미소 정상 사용
- [ ] 기본 3개 알림 저장
- [ ] 시간·가이드 수정 후 pending notification 재예약
- [ ] 앱 종료 상태에서 알림 탭 → 정확한 가이드
- [ ] 앱 foreground 상태에서 배너 → 정확한 가이드
- [ ] 수동 진입 완료 source
- [ ] 알림 진입 완료 source
- [ ] 타이머 중 닫기 → 기록 없음
- [ ] 타이머 완료 → 기록 1개
- [ ] 오늘 횟수와 최근 7일 즉시 갱신
- [ ] 앱 재실행 후 기록 유지
- [ ] VoiceOver와 큰 글자
- [ ] 운전·보행 중 화면 사용을 유도하는 문구 없음

결과는 `SmileDay/docs/reports/YYYY-MM-DD-notification-smile-mvp-device-verification.md`에 기기, iOS, 빌드/커밋, PASS/FAIL만 기록한다.

---

### Task 13: MVP 검증과 다음 단계 게이트

- [ ] TestFlight 또는 직접 설치로 5~10명을 모집한다.
- [ ] 유료 광고를 집행하지 않는다.
- [ ] 최소 7일 사용 후 아래를 확인한다.
  - 알림 때문에 실제로 미소를 의식했는가?
  - 알림 탭 후 완료가 충분히 짧았는가?
  - 기본 3회 빈도가 적절했는가?
  - 자주 사용한 가이드는 무엇인가?
  - 카메라가 없어도 목적을 달성했는가?
- [ ] 반복적으로 필요한 요청만 다음 기능 후보로 올린다.
  - 상황 이름이 붙은 알림
  - 위젯
  - Apple Watch 햅틱
  - 알림 빈도 자동 조절
  - 선택적 거울 모드
- [ ] 아래 기능은 검증 없이 복구하지 않는다.
  - 얼굴 점수와 기준선
  - AR 분석
  - 감정·좋은 순간 기록
  - 케어 루틴
  - 상세 차트
- [ ] 핵심 루프가 검증된 뒤 별도의 수익화 spec↔plan을 작성한다. 기존 Pro 계획을 그대로 실행하지 않는다.

---

## 실행 기록 (2026-07-28)

브랜치: `feature/notification-smile-mvp`. Task 0~11 완료, Task 12~13은 실기기·실사용자가 필요해 미실행.

### 검증 결과

| 항목 | 결과 |
|---|---|
| `swift test` (기준) | `Executed 234 tests, with 0 failures` |
| `swift test` (완료 후) | `Executed 330 tests, with 0 failures` — `Test Suite 'All tests' passed` |
| `xcodebuild ... build` | `** BUILD SUCCEEDED **` |
| `git diff --check` | 오류 없음 |

### 계획과 달라진 점

- **`SmileDayActivity` → `SmileDayCount`**: 계획의 `recentSevenDays` 반환 타입 이름이
  `HistoryViewModel.swift`의 기존 `SmileDayActivity`와 충돌했다. 레거시를 삭제하지 않는다는
  원칙에 따라 새 타입 이름을 바꿨다.
- **Task 3의 Pro 게이팅 제거**: Swift 코드에 StoreKit·paywall·알림 개수 제한 구현이 없어
  제거할 대상이 없었다. 다중 알림에 개수 제한이 없음을 테스트로 고정했다.
- **`ReminderScheduling`에 `currentAuthorizationStatus()` 추가**: Task 8의 "알림 권한 상태 안내"를
  UserDefaults 추정 없이 구현하려면 시스템 상태를 읽어야 했다.
- **`SmileGuideViewModel.saveFailed` 추가**: 계획이 정한 3-상태 `Phase`는 그대로 두고,
  저장 실패 시 완료 문구 대신 실패를 알리도록 별도 플래그를 뒀다.
- **`PersistenceSchemaMigrationTests` 추가**: Task 11의 "스키마 호환" 항목을 실기기 없이
  확인하려고 실제 저장소 파일을 구스키마로 쓰고 신스키마로 다시 여는 테스트를 만들었다.
- **`SmileOnboardingViewModel`**: Task 7이 파일만 지정하고 타입을 지정하지 않아,
  "저장·예약이 모두 끝난 뒤에만 완료 flag"를 테스트 가능하게 만들려고 뷰모델을 함께 뒀다.

### 남은 정리 대상 (이번 계획 범위 밖, 삭제하지 않음)

`MainTabView`, `HomeView`, `CoachingTabView`, `CareView`, `HistoryView`,
`BaselineCaptureView`, `OnboardingIntroView`, `ReminderListView`, `SettingsView`,
`DataLocationView`, `ReminderPrompt*`, ARKit·카메라 서비스와 Info.plist 권한 설명.
빌드에는 포함되지만 `RootView`와 알림 딥링크에서 도달할 수 없다.
