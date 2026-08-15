# 빈도 중심 전환 후 죽은 코드 정리 Implementation Plan

> 구현 전 대응 설계 `docs/superpowers/specs/2026-07-29-dead-code-cleanup-design.md`와 상위 제품 설계 `docs/superpowers/specs/2026-07-29-smile-frequency-window-reminders-design.md`를 전체 읽는다.
>
> 2026-07-29 추가 결정: 레거시 측정 파이프라인은 이 계획대로 삭제하되, 선택형 실시간 미소 확인 모드는 `2026-07-29-live-smile-monitor.md`에서 프리뷰·기준선 저장·점수 저장 없이 새로 구현한다. 삭제 파일을 통째로 복원하지 않는다.

**Goal:** 새 Root 흐름에서 사용하지 않는 카메라·점수·기록·케어·상황 카드·개별 알림 코드를 제거하면서 기존 SwiftData 저장소와 pending notification 호환을 유지한다.

**Architecture:** 활성 제품 코드는 `SmileMoment`, 단일 `SmileReminderSchedule`, `SmileCue`, 5초 가이드와 빈도 집계에 한정한다. 기존 `@Model` 타입은 스키마 호환 껍데기로 유지하고, 모델 밖의 과거 Repository·ViewModel·계산 로직과 전용 테스트를 단계적으로 삭제한다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, UserNotifications, Observation, XCTest, iOS 17+.

---

### Task 0: 작업 범위와 기준 결과 고정

**Files:**

- Read: `AGENTS.md`
- Read: `docs/reports/2026-07-27-project-review.md`
- Read: `docs/superpowers/specs/2026-07-29-dead-code-cleanup-design.md`
- Read: `docs/superpowers/specs/2026-07-29-smile-frequency-window-reminders-design.md`

- [ ] 기존 작업 트리의 수정·삭제·미추적 파일을 기록하고 사용자 변경을 되돌리지 않는다.
- [ ] 현재 앱이 폴더 동기화 그룹을 사용하는지 확인해 Swift 파일 삭제 시 별도 pbxproj 편집이 필요한지 판정한다.
- [ ] 정리 전 전체 테스트 수와 결과를 기록한다.
- [ ] 권한이 허용되는 환경에서는 앱 빌드 기준 결과도 기록한다.

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git status --short
git diff --stat

cd CoachingKit
swift test

cd ..
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected:

- `Test Suite 'All tests' passed`
- 앱 빌드를 실행할 수 있는 환경에서는 `** BUILD SUCCEEDED **`

샌드박스의 SwiftPM 캐시 또는 CoreSimulatorService 제한은 소스 실패와 구분해 기록한다.

---

### Task 1: 영속성 호환 테스트를 삭제 작업의 안전망으로 고정

**Files:**

- Modify: `CoachingKit/Tests/CoachingKitTests/PersistenceSchemaMigrationTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileMomentRepositoryTests.swift`
- Modify or replace: `CoachingKit/Tests/CoachingKitTests/CustomSmileCardTests.swift`

- [ ] 현재 스키마에 아래 일곱 모델이 모두 등록되는지 한 테스트에서 고정한다.
  - `Baseline`
  - `CheckInSession`
  - `ReminderSetting`
  - `CareSession`
  - `SmileMoment`
  - `CustomSmileCard`
  - `SmileReminderSchedule`
- [ ] 구 스키마 파일 저장소에 다섯 레거시 모델의 레코드를 각각 저장한다.
- [ ] 현재 스키마로 다시 열었을 때 레코드 수뿐 아니라 주요 저장 프로퍼티도 유지되는지 확인한다.
- [ ] 호환 테스트가 제거 예정 Repository나 편의 프로퍼티를 통하지 않고 `ModelContext`와 저장 프로퍼티를 직접 검증하도록 바꾼다.
- [ ] `CustomSmileCard` 테스트는 카드 변환 로직 대신 저장 프로퍼티와 재열기 호환만 검증한다.
- [ ] 테스트 파일이 임시 store, `-shm`, `-wal`을 모두 정리하는지 유지한다.

```bash
cd CoachingKit
swift test --filter PersistenceSchemaMigrationTests
swift test --filter SmileMomentRepositoryTests
swift test --filter CustomSmileCardTests
```

**Gate:** 이 Task가 통과하기 전에는 레거시 기능 소스를 삭제하지 않는다.

---

### Task 2: 호환 모델을 최소 스키마 타입으로 축소

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/Baseline.swift`
- Modify: `CoachingKit/Sources/CoachingKit/CustomSmileCard.swift`
- Delete: `CoachingKit/Tests/CoachingKitTests/BaselineTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/CustomSmileCardTests.swift`

- [ ] `Baseline`의 저장 프로퍼티와 스키마에 필요한 initializer는 유지한다.
- [ ] 앱 참조가 없는 `measurement`, `recommendResetThresholdWeeks`, `ageWeeks`, `isOverdueForReset`을 제거한다.
- [ ] `CustomSmileCard`의 저장 프로퍼티를 그대로 유지한다.
- [ ] `DaySlot`을 요구하는 initializer와 `slot`, `guide` 편의 프로퍼티를 제거하고, 테스트용 생성이 필요하면 `slotRawValue`을 직접 받는 최소 initializer로 바꾼다.
- [ ] `CheckInSession`, `ReminderSetting`, `CareSession`의 저장 프로퍼티 이름·타입·기본값을 바꾸지 않는다.
- [ ] 호환 모델에 새 제품 로직을 추가하지 않는다.

```bash
cd CoachingKit
swift test --filter PersistenceSchemaMigrationTests
swift test --filter CustomSmileCardTests
```

---

### Task 3: 카메라·얼굴 측정·점수 체크인 클러스터 제거

**Source files — Delete:**

- `CoachingKit/Sources/CoachingKit/AngleEvaluator.swift`
- `CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift`
- `CoachingKit/Sources/CoachingKit/CheckInPayload.swift`
- `CoachingKit/Sources/CoachingKit/CoachingViewModel.swift`
- `CoachingKit/Sources/CoachingKit/FaceMeasurement.swift`
- `CoachingKit/Sources/CoachingKit/FaceTrackingSession.swift`
- `CoachingKit/Sources/CoachingKit/LightingEvaluator.swift`
- `CoachingKit/Sources/CoachingKit/ScoreCalculator.swift`
- `CoachingKit/Sources/CoachingKit/SessionMetricsAccumulator.swift`

**Test files — Delete:**

- `CoachingKit/Tests/CoachingKitTests/AngleEvaluatorTests.swift`
- `CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`
- `CoachingKit/Tests/CoachingKitTests/CheckInPayloadTests.swift`
- `CoachingKit/Tests/CoachingKitTests/CoachingViewModelTests.swift`
- `CoachingKit/Tests/CoachingKitTests/LightingEvaluatorTests.swift`
- `CoachingKit/Tests/CoachingKitTests/ScoreCalculatorTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SessionMetricsAccumulatorTests.swift`

- [ ] 삭제 전 각 타입의 프로덕션 참조가 0인지 다시 확인한다.
- [ ] 문자열과 주석의 과거 명칭은 코드 참조로 오판하지 않는다.
- [ ] `Baseline`과 `CheckInSession` 모델 자체는 삭제하지 않는다.
- [ ] `CheckInSession.payload`와 `payloadVersion` 저장 프로퍼티는 기존 저장소 호환을 위해 유지한다.
- [ ] 삭제 후 패키지 전체를 컴파일한다.

```bash
rg -n '\b(AngleEvaluator|BaselineCaptureViewModel|CheckInPayload|CoachingViewModel|FaceMeasurement|FaceTrackingSession|LightingEvaluator|ScoreCalculator|SessionMetricsAccumulator)\b' \
  SmileDay CoachingKit/Sources --glob '*.swift'

cd CoachingKit && swift test
```

Expected: 검색 결과가 호환 설명 주석 외에는 없고 전체 테스트가 통과한다.

---

### Task 4: 과거 점수형 홈·기록·인사이트 클러스터 제거

**Source files — Delete:**

- `CoachingKit/Sources/CoachingKit/BaselineResetNudge.swift`
- `CoachingKit/Sources/CoachingKit/HabitEncouragementEngine.swift`
- `CoachingKit/Sources/CoachingKit/HistoryViewModel.swift`
- `CoachingKit/Sources/CoachingKit/HomeViewModel.swift`
- `CoachingKit/Sources/CoachingKit/InsightEngine.swift`
- `CoachingKit/Sources/CoachingKit/SessionRepository.swift`
- `CoachingKit/Sources/CoachingKit/SmileReflection.swift`

**Test files — Delete:**

- `CoachingKit/Tests/CoachingKitTests/BaselineResetNudgeTests.swift`
- `CoachingKit/Tests/CoachingKitTests/HabitEncouragementEngineTests.swift`
- `CoachingKit/Tests/CoachingKitTests/HistoryViewModelTests.swift`
- `CoachingKit/Tests/CoachingKitTests/HomeViewModelTests.swift`
- `CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SmileReflectionTests.swift`

- [ ] 활성 `SmileHomeViewModel`과 과거 `HomeViewModel`을 구분해 전자만 유지한다.
- [ ] `SmileMomentRepository`, `SmileDayCount`, 오늘·최근 7일 집계는 유지한다.
- [ ] `Baseline`, `CheckInSession` 저장 모델을 유지한다.
- [ ] 삭제 후 이름 충돌이나 오래된 문서 주석을 정리한다.

```bash
rg -n '\b(BaselineResetNudge|HabitEncouragementEngine|HistoryViewModel|HomeViewModel|InsightEngine|SessionRepository|SmileReflection)\b' \
  SmileDay CoachingKit/Sources --glob '*.swift'

cd CoachingKit
swift test --filter SmileHomeViewModelTests
swift test --filter SmileMomentRepositoryTests
swift test
```

---

### Task 5: 케어·미소 연습·상황 카드 관리 클러스터 제거

**Source files — Delete:**

- `CoachingKit/Sources/CoachingKit/CareRepository.swift`
- `CoachingKit/Sources/CoachingKit/HiddenSmileGuideStore.swift`
- `CoachingKit/Sources/CoachingKit/SmileGuideLibrary.swift`
- `CoachingKit/Sources/CoachingKit/SmileLibraryViewModel.swift`
- `CoachingKit/Sources/CoachingKit/SmilePractice.swift`
- `CoachingKit/Sources/CoachingKit/SmilePracticeViewModel.swift`

**Test files — Delete:**

- `CoachingKit/Tests/CoachingKitTests/CareRepositoryTests.swift`
- `CoachingKit/Tests/CoachingKitTests/HiddenSmileGuideStoreTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SmileGuideLibraryTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SmileLibraryViewModelTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SmilePracticeTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SmilePracticeViewModelTests.swift`

- [ ] `CareSession`과 `CustomSmileCard` 모델은 `PersistenceSchema`에 유지한다.
- [ ] `hiddenSmileGuideIDs` UserDefaults 키를 자동 삭제하지 않는다.
- [ ] 과거 즐겨찾기 UserDefaults 키도 자동 삭제하지 않는다.
- [ ] 활성 `SmileCue`, `SmileCueSelector`, `SmileGuideViewModel`은 유지한다.
- [ ] 삭제 후 상황 카드 관리 타입의 소스 참조가 0인지 확인한다.

```bash
rg -n '\b(CareRepository|HiddenSmileGuideStoring|SmileGuideLibrary|SmileLibraryViewModel|SmilePractice|SmilePracticeViewModel)\b' \
  SmileDay CoachingKit/Sources --glob '*.swift'

cd CoachingKit
swift test --filter SmileCueTests
swift test --filter SmileGuideViewModelTests
swift test
```

---

### Task 6: 과거 개별 알림·시간대 질문 클러스터 제거

**Source files — Delete:**

- `CoachingKit/Sources/CoachingKit/ReminderNudge.swift`
- `CoachingKit/Sources/CoachingKit/ReminderPrompt.swift`
- `CoachingKit/Sources/CoachingKit/ReminderPromptCursorStore.swift`
- `CoachingKit/Sources/CoachingKit/ReminderPromptSelector.swift`
- `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`

**Test files — Delete:**

- `CoachingKit/Tests/CoachingKitTests/ReminderNudgeTests.swift`
- `CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift`
- `CoachingKit/Tests/CoachingKitTests/ReminderPromptCursorStoreTests.swift`
- `CoachingKit/Tests/CoachingKitTests/ReminderPromptSelectorTests.swift`
- `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`

**Files — Modify:**

- `CoachingKit/Sources/CoachingKit/ReminderRepository.swift`
- `CoachingKit/Tests/CoachingKitTests/ReminderRepositoryTests.swift`
- `CoachingKit/Sources/CoachingKit/SmileReminderScheduleViewModel.swift`
- `CoachingKit/Tests/CoachingKitTests/SmileReminderScheduleViewModelTests.swift`

- [ ] `ReminderRepository`에서 현재 사용하는 레거시 notification ID 조회만 남긴다.
- [ ] `add`, `registeredBuckets`, `delete`, `setEnabled`, `updateTime`, `updateGuide`, `reminders(usingGuideID:)`를 제거한다.
- [ ] 가능하면 타입을 `LegacyReminderRepository`로 이름 바꿔 새 알림 저장소로 오해하지 않게 한다.
- [ ] `SmileReminderScheduleViewModel`은 새 스케줄 저장 성공 뒤 레거시 ID를 취소하는 순서를 유지한다.
- [ ] 저장 전에 레거시 취소가 호출되지 않고, 저장 성공 뒤 모든 기존 `notificationID`에 `cancel(id:)`가 호출되는지 테스트로 고정한다.
- [ ] `TimeBucket`, 과거 질문 24개와 cursor 저장소를 제거한다.

```bash
rg -n '\b(TimeBucket|ReminderPrompt|ReminderNudge|SettingsViewModel)\b' \
  SmileDay CoachingKit/Sources --glob '*.swift'

cd CoachingKit
swift test --filter ReminderRepositoryTests
swift test --filter SmileReminderScheduleViewModelTests
swift test
```

---

### Task 7: rolling-window 예약 API 제거

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/ReminderScheduling.swift`
- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift`
- Modify: reminder scheduler fakes in active test files

- [ ] 프로덕션 호출이 없는 `scheduleRollingWindow(id:hour:minute:guide:days:)`를 프로토콜과 앱 구현에서 제거한다.
- [ ] 기존 pending request 취소에 필요한 `cancel(id:)`와 동일 identifier 규칙은 유지한다.
- [ ] `reminderRollingWindowDays`는 `cancel(id:)`가 기존 14개 identifier를 지우는 동안 유지한다.
- [ ] `scheduleDailyPattern`과 `cancelGroup`의 프로토콜 기본 no-op 구현을 제거하고 모든 활성 fake가 명시적으로 구현하게 한다.
- [ ] fake가 호출을 조용히 버리지 않도록 예약 시각과 취소 group을 기록하는지 확인한다.

```bash
rg -n 'scheduleRollingWindow|scheduleDailyPattern|cancelGroup|reminderRollingWindowDays' \
  SmileDay CoachingKit --glob '*.swift'

cd CoachingKit
swift test --filter SmileReminderScheduleViewModelTests
swift test --filter SmileOnboardingStateTests
```

Expected:

- `scheduleRollingWindow` 결과 없음
- `reminderRollingWindowDays`는 레거시 `cancel(id:)` 구현과 관련 테스트에서만 남음

---

### Task 8: `SmileGuide`를 활성 실행에 필요한 최소 타입으로 축소

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/SmileGuide.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SmileGuideViewModel.swift`
- Modify: `SmileDay/Views/Coaching/SmileGuideView.swift`
- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileGuideTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileGuideViewModelTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderNotificationPayloadTests.swift`

- [ ] `SmileGuide`에서 사용하지 않는 `title`, `instruction`, `slot`, `isBuiltIn`을 제거한다.
- [ ] 활성 경로에 필요한 안정적인 기본 ID와 `durationSeconds`만 유지한다.
- [ ] `SmileGuideCatalog.builtIn`의 과거 상황 카드 14개를 제거하고 기본 가이드를 직접 선언한다.
- [ ] `DaySlot`, `legacyIDAliases`, `builtInGuide`, `guide(id:)`, `builtIn(in:)`를 제거한다.
- [ ] 비평가적 표시 문구는 `SmileCueCatalog`가 계속 담당하게 한다.
- [ ] 기본 ID가 기존 `"anytime-soft"`를 유지해 `SmileMoment.guideID`와 예약 payload의 의미를 바꾸지 않게 한다.
- [ ] 강제 언래핑으로 기본 카드를 찾는 코드를 제거한다.

```bash
rg -n '\b(DaySlot|legacyIDAliases|builtInGuide|SmileGuideCatalog\\.builtIn)\b' \
  SmileDay CoachingKit/Sources --glob '*.swift'

cd CoachingKit
swift test --filter SmileGuideTests
swift test --filter SmileGuideViewModelTests
swift test --filter ReminderNotificationPayloadTests
swift test
```

---

### Task 9: 알림 payload의 쓰기 전용 값은 호환 경계로 격리

**Files:**

- Modify if needed: `CoachingKit/Sources/CoachingKit/ReminderNotificationPayload.swift`
- Modify if needed: `SmileDay/Services/NotificationRouter.swift`
- Modify if needed: `SmileDay/Views/Home/SmileMVPHomeView.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderNotificationPayloadTests.swift`

- [ ] 홈이 payload의 `reminderID`와 `guideID`를 사용하지 않는다는 사실을 코드와 테스트에서 명확히 한다.
- [ ] 새 `guideID`, 옛 `bucket`, 옛 `promptText` payload가 모두 미소 가이드 시작 신호로 인식되는 동작은 유지한다.
- [ ] 이미 예약된 알림과의 호환을 위해 userInfo key는 이번 Task에서 삭제하지 않는다.
- [ ] payload를 marker 타입으로 축소할 경우 기존 initializer와 userInfo 생성 경로를 한 번에 갱신한다.
- [ ] `SmileMoment.guideID` 저장 프로퍼티는 이번 작업에서 제거하지 않는다.

```bash
cd CoachingKit && swift test --filter ReminderNotificationPayloadTests
```

---

### Task 10: 앱 타깃의 소규모 죽은 코드와 오래된 설명 정리

**Files:**

- Modify: `SmileDay/Views/Theme.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SDPalette.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SDPaletteTests.swift`
- Modify: `SmileDay/Views/Coaching/SmileGuideView.swift`

- [ ] 사용하지 않는 `SDColor.coralWarm`, `mint`, `lilac`을 제거한다.
- [ ] 패키지 raw palette 값도 활성 UI나 대비 테스트에서 참조하지 않으면 함께 제거한다.
- [ ] 사용하지 않는 `SmileArc.point(t:in:depth:)`를 제거한다.
- [ ] `SDCloseButton`의 “카메라 화면” 설명을 일반 전체 화면 닫기 버튼 설명으로 바꾼다.
- [ ] `SDInkButtonStyle`의 “측정 종료” 설명을 현재 저장·닫기 용도에 맞춘다.
- [ ] 실제 사용자 문자열은 변경하지 않는다.

```bash
rg -n 'coralWarm|\\bmint\\b|\\blilac\\b|SmileArc\\.point|측정 종료|카메라 화면' \
  SmileDay CoachingKit --glob '*.swift'
```

---

### Task 11: 전체 정적 참조 감사

- [ ] 앱과 패키지 소스에서 삭제 타입 이름이 다시 나타나지 않는지 확인한다.
- [ ] 삭제된 테스트 파일이 Package target에 남지 않았는지 확인한다.
- [ ] 활성 앱이 아래 클러스터로 도달하지 않는지 재검증한다.
  - ARKit·카메라·얼굴 측정
  - 점수·기준선 촬영
  - 과거 기록·인사이트
  - 케어·연습
  - 상황 카드 CRUD
  - 개별 알림 CRUD와 시간대 질문
- [ ] SwiftData 호환 모델은 모두 남아 있는지 확인한다.
- [ ] 금지된 사용자 노출 표현을 검사한다.

```bash
rg -n 'import ARKit|FaceTracking|FaceMeasurement|ScoreCalculator|BaselineCapture|CoachingViewModel|HistoryViewModel|InsightEngine|CareRepository|SmilePractice|SmileGuideLibrary|TimeBucket|ReminderPrompt' \
  SmileDay CoachingKit/Sources --glob '*.swift'

rg -n '리프팅|젊어진다|교정한다|치료' SmileDay CoachingKit \
  --glob '*.swift'

rg -n 'Baseline\\.self|CheckInSession\\.self|ReminderSetting\\.self|CareSession\\.self|CustomSmileCard\\.self|SmileMoment\\.self|SmileReminderSchedule\\.self' \
  CoachingKit/Sources/CoachingKit/PersistenceSchema.swift
```

과거 호환 설명 또는 타입 이름 자체가 필요한 결과는 실제 실행 참조와 구분해 기록한다.

---

### Task 12: 전체 자동 검증

- [ ] `CoachingKit` 전체 테스트:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test
```

Expected: `Test Suite 'All tests' passed`.

- [ ] iOS 17 앱 빌드:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] diff와 삭제 범위 검증:

```bash
git diff --check
git status --short
git diff --stat
git diff --name-status
```

- [ ] 테스트 감소량을 기록하되 테스트 수 자체를 품질 목표로 삼지 않는다.
- [ ] 삭제된 코드 줄 수와 남은 호환 모델 목록을 구현 결과에 기록한다.

---

### Task 13: 기존 데이터와 알림 실기기 회귀 확인

**Required:** 이전 버전 데이터 또는 동일 스키마 fixture가 있는 iOS 17 이상 iPhone.

- [ ] 기존 앱 버전에서 기준선·체크인·케어·개별 알림·사용자 카드를 하나씩 만든다.
- [ ] 정리 빌드로 업데이트한 뒤 앱이 시작되고 새 홈이 표시되는지 확인한다.
- [ ] SwiftData 초기화 실패 화면으로 빠지지 않는지 확인한다.
- [ ] 새 반복 스케줄 저장 뒤 기존 개별 pending notification이 취소되는지 확인한다.
- [ ] 새 repeating notification이 설정 시각에 도착하는지 확인한다.
- [ ] 옛 알림을 탭해도 새 5초 미소 화면이 열리는지 확인한다.
- [ ] 수동·알림 완료가 각각 정확히 한 번 저장되는지 확인한다.
- [ ] 오늘과 최근 7일 횟수가 즉시 갱신되는지 확인한다.
- [ ] 앱 재실행 뒤 새 완료 기록과 반복 설정이 유지되는지 확인한다.

결과는 `docs/reports/YYYY-MM-DD-dead-code-cleanup-device-verification.md`에 기기, iOS, 이전 빌드, 정리 빌드, 항목별 PASS/FAIL만 기록한다. 얼굴 이미지나 개인 측정 원시값은 저장하지 않는다.

---

## 완료 체크리스트

- [ ] 대응 Design Spec의 완료 기준을 모두 충족함
- [ ] 삭제 대상 전체에 삭제 사유와 참조 0 근거가 있음
- [ ] 다섯 레거시 모델과 두 활성 모델이 스키마에 유지됨
- [ ] 기존 저장소 재열기 테스트 통과
- [ ] 활성 기능 테스트와 패키지 전체 테스트 통과
- [ ] iOS 17 앱 빌드 통과
- [ ] 기존 pending notification 취소와 신·구 payload 회귀 확인
- [ ] 사용자 기존 변경을 되돌리거나 덮어쓰지 않음
- [ ] `git diff --check` 통과
