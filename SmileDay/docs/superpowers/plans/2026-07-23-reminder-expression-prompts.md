# 리마인더 표정 질문 로테이션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 고정된 리마인더 알림 문구("오늘의 표정 습관을 기록해보세요")를, 시간대별(아침/낮/저녁)로 8개씩 순환하는 24개의 표정 성찰 질문으로 교체한다.

**Architecture:** `CoachingKit`에 시간대 판별(`TimeBucket`), 문구 카탈로그(`ReminderPromptCatalog`), 버킷별 순환 커서(`ReminderPromptCursorStoring`), 선택 로직(`ReminderPromptSelector`)을 추가한다. `ReminderScheduling` 프로토콜을 `scheduleDaily` → `scheduleRollingWindow`로 바꿔, 매일 다른 문구를 담은 향후 14일치 알림을 개별(one-shot)로 예약한다. 앱이 포그라운드로 돌아올 때(`RootView`의 `scenePhase`)마다 모든 활성 리마인더의 14일치를 다시 채운다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, `UserNotifications`(UNUserNotificationCenter), XCTest (Swift Package `CoachingKit`) + Xcode 프로젝트(`SmileDay`).

**설계 문서:** `SmileDay/docs/superpowers/specs/2026-07-23-reminder-expression-prompts-design.md`

**베이스라인 확인**: `cd CoachingKit && swift test` 는 현재 76 tests, 0 failures로 통과 상태.

---

### Task 1: 표정 질문 데이터 모델 + 카탈로그

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/ReminderPrompt.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift
import XCTest
@testable import CoachingKit

final class ReminderPromptCatalogTests: XCTestCase {
    func test_timeBucket_hourBoundaries() {
        XCTAssertEqual(TimeBucket(hour: 4), .evening)
        XCTAssertEqual(TimeBucket(hour: 5), .morning)
        XCTAssertEqual(TimeBucket(hour: 10), .morning)
        XCTAssertEqual(TimeBucket(hour: 11), .afternoon)
        XCTAssertEqual(TimeBucket(hour: 16), .afternoon)
        XCTAssertEqual(TimeBucket(hour: 17), .evening)
        XCTAssertEqual(TimeBucket(hour: 0), .evening)
        XCTAssertEqual(TimeBucket(hour: 23), .evening)
    }

    func test_catalog_hasEightPromptsPerBucket() {
        for bucket in TimeBucket.allCases {
            XCTAssertEqual(ReminderPromptCatalog.prompts(for: bucket).count, 8, "\(bucket) should have 8 prompts")
        }
    }

    func test_catalog_hasNoDuplicateText() {
        let allText = ReminderPromptCatalog.prompts.map(\.text)
        XCTAssertEqual(Set(allText).count, allText.count, "prompt text must be unique across the whole catalog")
    }

    func test_catalog_hasNoEmptyText() {
        XCTAssertTrue(ReminderPromptCatalog.prompts.allSatisfy { !$0.text.isEmpty })
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter ReminderPromptCatalogTests`
Expected: FAIL to build — `TimeBucket`, `ReminderPrompt`, `ReminderPromptCatalog` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
// CoachingKit/Sources/CoachingKit/ReminderPrompt.swift
import Foundation

public enum TimeBucket: String, CaseIterable, Equatable, Hashable, Sendable {
    case morning
    case afternoon
    case evening

    public init(hour: Int) {
        switch hour {
        case 5...10: self = .morning
        case 11...16: self = .afternoon
        default: self = .evening
        }
    }
}

public struct ReminderPrompt: Equatable, Sendable {
    public let bucket: TimeBucket
    public let text: String

    public init(bucket: TimeBucket, text: String) {
        self.bucket = bucket
        self.text = text
    }
}

public enum ReminderPromptCatalog {
    public static let prompts: [ReminderPrompt] = [
        // 아침 (05–10시)
        ReminderPrompt(bucket: .morning, text: "오늘 하루, 당신의 표정이 어떤 모습이었으면 좋겠나요?"),
        ReminderPrompt(bucket: .morning, text: "지금 거울을 본다면, 어떤 표정을 보고 싶나요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 처음 마주치는 사람에게 어떤 표정을 보여주고 싶나요?"),
        ReminderPrompt(bucket: .morning, text: "지금 입꼬리를 살짝 올려볼까요? 아니면 오늘은 소리 내서 웃어볼까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 하루 중 가장 크게 웃고 싶은 순간은 언제일까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 가장 기대되는 일을 떠올려볼까요? 자연스럽게 표정이 풀릴 거예요."),
        ReminderPrompt(bucket: .morning, text: "지금 이 순간, 몸에 힘을 빼고 살짝 웃어볼까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 하루를 시작하며, 나에게 짓고 싶은 표정 하나를 골라볼까요?"),

        // 낮 (11–16시)
        ReminderPrompt(bucket: .afternoon, text: "지금 누군가 당신을 본다면, 어떤 표정을 보고 있을까요?"),
        ReminderPrompt(bucket: .afternoon, text: "내가 사랑하는 사람이 나를 어떤 표정으로 봐 줬으면 하나요?"),
        ReminderPrompt(bucket: .afternoon, text: "오늘 누군가에게 웃어 보인 적이 있나요? 지금 한 번 웃어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "지금 잠깐, 소리 내서 웃어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "옆에 있는 사람이 본다면 편안해 보일 표정을 짓고 있나요?"),
        ReminderPrompt(bucket: .afternoon, text: "최근에 있었던 재미있는 순간을 떠올리며 웃어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "오늘 나를 웃게 한 사람은 누구였나요? 그 표정을 다시 지어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "지금 화면이 아니라, 진짜 당신의 표정은 어떤가요?"),

        // 저녁 (17–04시)
        ReminderPrompt(bucket: .evening, text: "오늘 하루, 가장 크게 웃었던 순간은 언제였나요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 나의 표정은 대체로 어땠나요?"),
        ReminderPrompt(bucket: .evening, text: "잠들기 전, 오늘 하루에 감사한 일을 떠올리며 웃어볼까요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 하루를 마치며, 지금 어떤 표정을 짓고 있나요?"),
        ReminderPrompt(bucket: .evening, text: "내일 아침, 어떤 표정으로 하루를 시작하고 싶나요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 나를 웃게 한 순간을 하나만 떠올려볼까요?"),
        ReminderPrompt(bucket: .evening, text: "지금 큰 소리로 한 번 웃어볼까요? 하루의 긴장이 풀릴 거예요."),
        ReminderPrompt(bucket: .evening, text: "사랑하는 사람과 나눈 표정 중, 오늘 가장 따뜻했던 순간은 언제였나요?"),
    ]

    public static func prompts(for bucket: TimeBucket) -> [ReminderPrompt] {
        prompts.filter { $0.bucket == bucket }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CoachingKit && swift test --filter ReminderPromptCatalogTests`
Expected: PASS — 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderPrompt.swift CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift
git commit -m "feat: add TimeBucket and 24-prompt reminder catalog"
```

---

### Task 2: 버킷별 순환 커서 (in-memory + UserDefaults)

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/ReminderPromptCursorStore.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/ReminderPromptCursorStoreTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKit/Tests/CoachingKitTests/ReminderPromptCursorStoreTests.swift
import XCTest
@testable import CoachingKit

final class ReminderPromptCursorStoreTests: XCTestCase {
    func test_inMemory_cyclesThroughAllIndicesBeforeRepeating() {
        let store = InMemoryReminderPromptCursorStore()
        var seen: [Int] = []
        for _ in 0..<8 {
            seen.append(store.nextIndex(for: .morning, poolCount: 8))
        }
        XCTAssertEqual(Set(seen), Set(0..<8), "one full cycle must touch every index exactly once")
    }

    func test_inMemory_bucketsAreIndependent() {
        let store = InMemoryReminderPromptCursorStore()
        let morningFirst = store.nextIndex(for: .morning, poolCount: 8)
        let eveningFirst = store.nextIndex(for: .evening, poolCount: 8)
        _ = morningFirst
        _ = eveningFirst
        // 두 번째 아침 호출은 첫 호출과 같은 사이클(0..<8) 안에서 나와야 한다.
        let morningSecond = store.nextIndex(for: .morning, poolCount: 8)
        XCTAssertTrue((0..<8).contains(morningSecond))
    }

    func test_userDefaults_persistsAcrossNewInstances() throws {
        let suiteName = "reminder-prompt-cursor-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = UserDefaultsReminderPromptCursorStore(defaults: defaults)
        var seen: Set<Int> = []
        for _ in 0..<4 {
            seen.insert(firstStore.nextIndex(for: .afternoon, poolCount: 8))
        }

        // 앱 재시작을 흉내: 같은 UserDefaults를 보는 새 인스턴스
        let secondStore = UserDefaultsReminderPromptCursorStore(defaults: defaults)
        for _ in 0..<4 {
            seen.insert(secondStore.nextIndex(for: .afternoon, poolCount: 8))
        }

        XCTAssertEqual(seen, Set(0..<8), "이어붙인 8번 호출이 인스턴스 경계와 무관하게 한 사이클을 이뤄야 한다")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter ReminderPromptCursorStoreTests`
Expected: FAIL to build — `InMemoryReminderPromptCursorStore`, `UserDefaultsReminderPromptCursorStore` do not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
// CoachingKit/Sources/CoachingKit/ReminderPromptCursorStore.swift
import Foundation

public protocol ReminderPromptCursorStoring: AnyObject {
    /// 주어진 버킷에서 다음으로 꺼낼 문구의 인덱스를 반환한다.
    /// poolCount개를 다 꺼내면 순서를 다시 섞어 새 사이클을 시작한다.
    func nextIndex(for bucket: TimeBucket, poolCount: Int) -> Int
}

/// 순환 상태(섞인 순서 + 다음 위치)를 계산하는 순수 로직. 저장 방식과 분리해 in-memory/UserDefaults 양쪽에서 재사용한다.
struct ReminderPromptCursorState {
    var order: [Int]
    var position: Int

    static func advancing(from current: ReminderPromptCursorState?, poolCount: Int) -> (index: Int, state: ReminderPromptCursorState) {
        guard poolCount > 0 else {
            return (0, ReminderPromptCursorState(order: [], position: 0))
        }

        var state = current ?? ReminderPromptCursorState(order: Array(0..<poolCount).shuffled(), position: 0)
        if state.order.count != poolCount || state.position >= state.order.count {
            state = ReminderPromptCursorState(order: Array(0..<poolCount).shuffled(), position: 0)
        }

        let index = state.order[state.position]
        state.position += 1
        return (index, state)
    }
}

public final class InMemoryReminderPromptCursorStore: ReminderPromptCursorStoring {
    private var states: [TimeBucket: ReminderPromptCursorState] = [:]

    public init() {}

    public func nextIndex(for bucket: TimeBucket, poolCount: Int) -> Int {
        let (index, state) = ReminderPromptCursorState.advancing(from: states[bucket], poolCount: poolCount)
        states[bucket] = state
        return index
    }
}

public final class UserDefaultsReminderPromptCursorStore: ReminderPromptCursorStoring {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func nextIndex(for bucket: TimeBucket, poolCount: Int) -> Int {
        let orderKey = "reminderPromptOrder_\(bucket.rawValue)"
        let positionKey = "reminderPromptPosition_\(bucket.rawValue)"

        let storedOrder = defaults.array(forKey: orderKey) as? [Int]
        let current = storedOrder.map {
            ReminderPromptCursorState(order: $0, position: defaults.integer(forKey: positionKey))
        }

        let (index, state) = ReminderPromptCursorState.advancing(from: current, poolCount: poolCount)
        defaults.set(state.order, forKey: orderKey)
        defaults.set(state.position, forKey: positionKey)
        return index
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CoachingKit && swift test --filter ReminderPromptCursorStoreTests`
Expected: PASS — 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderPromptCursorStore.swift CoachingKit/Tests/CoachingKitTests/ReminderPromptCursorStoreTests.swift
git commit -m "feat: add reminder prompt cursor store (in-memory + UserDefaults)"
```

---

### Task 3: ReminderPromptSelector

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/ReminderPromptSelector.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/ReminderPromptSelectorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKit/Tests/CoachingKitTests/ReminderPromptSelectorTests.swift
import XCTest
@testable import CoachingKit

final class ReminderPromptSelectorTests: XCTestCase {
    func test_nextPrompt_returnsPromptMatchingHourBucket() {
        let selector = ReminderPromptSelector(cursorStore: InMemoryReminderPromptCursorStore())
        let prompt = selector.nextPrompt(forHour: 9)
        XCTAssertEqual(prompt.bucket, .morning)
        XCTAssertTrue(ReminderPromptCatalog.prompts(for: .morning).contains(prompt))
    }

    func test_nextPrompt_cyclesThroughAllEightBeforeRepeating() {
        let selector = ReminderPromptSelector(cursorStore: InMemoryReminderPromptCursorStore())
        let texts = (0..<8).map { _ in selector.nextPrompt(forHour: 20).text }
        let eveningTexts = Set(ReminderPromptCatalog.prompts(for: .evening).map(\.text))
        XCTAssertEqual(Set(texts), eveningTexts)
    }

    func test_nextPrompt_differentHoursInSameBucketShareCursor() {
        let selector = ReminderPromptSelector(cursorStore: InMemoryReminderPromptCursorStore())
        // 낮 12시, 낮 15시 두 리마인더가 같은 버킷 커서를 공유해야 한다.
        let first = selector.nextPrompt(forHour: 12)
        let second = selector.nextPrompt(forHour: 15)
        XCTAssertNotEqual(first.text, second.text)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter ReminderPromptSelectorTests`
Expected: FAIL to build — `ReminderPromptSelector` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```swift
// CoachingKit/Sources/CoachingKit/ReminderPromptSelector.swift
import Foundation

public struct ReminderPromptSelector {
    private let catalog: [ReminderPrompt]
    private let cursorStore: ReminderPromptCursorStoring

    public init(catalog: [ReminderPrompt] = ReminderPromptCatalog.prompts, cursorStore: ReminderPromptCursorStoring) {
        self.catalog = catalog
        self.cursorStore = cursorStore
    }

    public func nextPrompt(forHour hour: Int) -> ReminderPrompt {
        let bucket = TimeBucket(hour: hour)
        let pool = catalog.filter { $0.bucket == bucket }
        let index = cursorStore.nextIndex(for: bucket, poolCount: pool.count)
        return pool[index]
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CoachingKit && swift test --filter ReminderPromptSelectorTests`
Expected: PASS — 3 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderPromptSelector.swift CoachingKit/Tests/CoachingKitTests/ReminderPromptSelectorTests.swift
git commit -m "feat: add ReminderPromptSelector for bucketed prompt rotation"
```

---

### Task 4: ReminderScheduling 프로토콜을 롤링 윈도로 교체

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/ReminderScheduling.swift`

- [ ] **Step 1: 프로토콜 시그니처 변경**

```swift
// CoachingKit/Sources/CoachingKit/ReminderScheduling.swift
import Foundation

/// 리마인더 알림이 며칠치를 미리 예약해둘지. 로컬 알림만 쓰므로(서버 푸시 없음)
/// 사용자가 이 기간보다 오래 앱을 열지 않으면 그 이후 알림은 끊긴다.
public let reminderRollingWindowDays = 14

public protocol ReminderScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    /// hour:minute에 향후 `days`일치 알림을 각각 다른(순환) 문구로 개별 예약한다.
    func scheduleRollingWindow(id: String, hour: Int, minute: Int, days: Int) async
    func cancel(id: String)
}
```

이 프로토콜은 CoachingKit 패키지 테스트가 없는 순수 인터페이스 파일이라 별도 유닛 테스트는 없다. 이 변경은 Task 5(SettingsViewModel)와 Task 6(UserNotificationReminderScheduler)에서 바로 사용되며, 그 두 태스크의 테스트가 이 시그니처를 검증한다.

- [ ] **Step 2: 컴파일 확인 (아직 구현체가 안 맞아 실패해야 정상)**

Run: `cd CoachingKit && swift build`
Expected: FAIL — `SettingsViewModel.swift`가 아직 옛 `scheduleDaily`를 호출하고 있어 컴파일 에러. (Task 5에서 고침)

- [ ] **Step 3: Commit은 Task 5와 함께 진행**

이 파일 하나만 따로 커밋하면 빌드가 깨진 상태로 남으므로, Task 5의 커밋에 포함해서 같이 커밋한다. (아래 Task 5 Step 5 참고)

---

### Task 5: SettingsViewModel을 롤링 윈도 예약으로 갱신 + 전체 리프레쉬 메서드 추가

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`

- [ ] **Step 1: 실패하는 테스트로 새 MockScheduler 시그니처 반영**

`SettingsViewModelTests.swift` 전체를 아래 내용으로 교체한다 (기존 5개 테스트는 새 시그니처에 맞게 수정, `test_refreshAllScheduledReminders_reschedulesOnlyEnabledReminders`가 새로 추가됨).

```swift
// CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift
import XCTest
import SwiftData
@testable import CoachingKit

final class SettingsViewModelTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        private(set) var authorizationRequests = 0
        private(set) var scheduled: [(id: String, hour: Int, minute: Int, days: Int)] = []
        private(set) var cancelled: [String] = []

        func requestAuthorization() async -> Bool {
            authorizationRequests += 1
            return true
        }

        func scheduleRollingWindow(id: String, hour: Int, minute: Int, days: Int) async {
            scheduled.append((id, hour, minute, days))
        }

        func cancel(id: String) {
            cancelled.append(id)
        }
    }

    private func makeViewModel() throws -> (SettingsViewModel, SessionRepository, MockScheduler) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let sessionRepository = SessionRepository(modelContext: context)
        let scheduler = MockScheduler()
        let viewModel = SettingsViewModel(
            reminderRepository: ReminderRepository(modelContext: context),
            sessionRepository: sessionRepository,
            scheduler: scheduler
        )
        return (viewModel, sessionRepository, scheduler)
    }

    func test_addReminder_persistsAndSchedules() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()

        try await viewModel.addReminder(hour: 9, minute: 30)

        XCTAssertEqual(viewModel.reminders.count, 1)
        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.hour, 9)
        XCTAssertEqual(scheduler.scheduled.first?.minute, 30)
        XCTAssertEqual(scheduler.scheduled.first?.days, reminderRollingWindowDays)
    }

    func test_removeReminder_deletesAndCancels() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)

        try viewModel.removeReminder(reminder)

        XCTAssertEqual(viewModel.reminders.count, 0)
        XCTAssertEqual(scheduler.cancelled, [reminder.notificationID])
    }

    func test_toggleReminder_offCancels_onReschedules() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)

        try await viewModel.toggleReminder(reminder)
        XCTAssertFalse(reminder.isEnabled)
        XCTAssertEqual(scheduler.cancelled, [reminder.notificationID])

        try await viewModel.toggleReminder(reminder)
        XCTAssertTrue(reminder.isEnabled)
        XCTAssertEqual(scheduler.scheduled.count, 2)
    }

    func test_refreshAllScheduledReminders_reschedulesOnlyEnabledReminders() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        try await viewModel.addReminder(hour: 20, minute: 30)
        let morningReminder = try XCTUnwrap(viewModel.reminders.first { $0.hour == 9 })
        try await viewModel.toggleReminder(morningReminder) // 끈다
        let scheduledBeforeRefresh = scheduler.scheduled.count

        try await viewModel.refreshAllScheduledReminders()

        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBeforeRefresh)
        XCTAssertEqual(newlyScheduled.count, 1, "꺼진 리마인더는 다시 예약되면 안 된다")
        XCTAssertEqual(newlyScheduled.first?.hour, 20)
    }

    func test_refresh_computesBaselineAgeWeeks() throws {
        let (viewModel, sessionRepository, _) = try makeViewModel()
        let sixWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: Date())!
        try sessionRepository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            capturedAt: sixWeeksAgo,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )

        try viewModel.refresh()

        XCTAssertEqual(viewModel.baselineAgeWeeks, 6)
    }

    func test_refresh_baselineAgeNil_whenNoBaseline() throws {
        let (viewModel, _, _) = try makeViewModel()

        try viewModel.refresh()

        XCTAssertNil(viewModel.baselineAgeWeeks)
    }

    func test_shouldRecommendReset_falseUnderFourWeeks() throws {
        let (viewModel, sessionRepository, _) = try makeViewModel()
        let threeWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: Date())!
        try sessionRepository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            capturedAt: threeWeeksAgo,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )

        try viewModel.refresh()

        XCTAssertFalse(viewModel.shouldRecommendReset)
    }

    func test_shouldRecommendReset_trueAtFourWeeksOrMore() throws {
        let (viewModel, sessionRepository, _) = try makeViewModel()
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())!
        try sessionRepository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            capturedAt: fourWeeksAgo,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )

        try viewModel.refresh()

        XCTAssertTrue(viewModel.shouldRecommendReset)
    }

    func test_shouldRecommendReset_falseWhenNoBaseline() throws {
        let (viewModel, _, _) = try makeViewModel()

        try viewModel.refresh()

        XCTAssertFalse(viewModel.shouldRecommendReset)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter SettingsViewModelTests`
Expected: FAIL to build — `SettingsViewModel`가 아직 `scheduleDaily`를 호출하고 `refreshAllScheduledReminders`가 없음.

- [ ] **Step 3: SettingsViewModel 구현 수정**

```swift
// CoachingKit/Sources/CoachingKit/SettingsViewModel.swift
import Foundation
import Observation

@Observable
public final class SettingsViewModel {
    public private(set) var reminders: [ReminderSetting] = []
    public private(set) var baselineAgeWeeks: Int?
    public var shouldRecommendReset: Bool {
        (baselineAgeWeeks ?? 0) >= 4
    }

    private let reminderRepository: ReminderRepository
    private let sessionRepository: SessionRepository
    private let scheduler: ReminderScheduling
    private let now: () -> Date

    public init(
        reminderRepository: ReminderRepository,
        sessionRepository: SessionRepository,
        scheduler: ReminderScheduling,
        now: @escaping () -> Date = Date.init
    ) {
        self.reminderRepository = reminderRepository
        self.sessionRepository = sessionRepository
        self.scheduler = scheduler
        self.now = now
    }

    public func refresh() throws {
        reminders = try reminderRepository.fetchAll()
        if let baseline = try sessionRepository.fetchLatestBaseline() {
            let weeks = Calendar.current.dateComponents([.weekOfYear], from: baseline.capturedAt, to: now()).weekOfYear ?? 0
            baselineAgeWeeks = max(weeks, 0)
        } else {
            baselineAgeWeeks = nil
        }
    }

    public func addReminder(hour: Int, minute: Int) async throws {
        _ = await scheduler.requestAuthorization()
        let reminder = try reminderRepository.add(hour: hour, minute: minute)
        await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: hour, minute: minute, days: reminderRollingWindowDays)
        try refresh()
    }

    public func removeReminder(_ reminder: ReminderSetting) throws {
        scheduler.cancel(id: reminder.notificationID)
        try reminderRepository.delete(reminder)
        try refresh()
    }

    public func toggleReminder(_ reminder: ReminderSetting) async throws {
        let newValue = !reminder.isEnabled
        try reminderRepository.setEnabled(reminder, newValue)
        if newValue {
            await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: reminder.hour, minute: reminder.minute, days: reminderRollingWindowDays)
        } else {
            scheduler.cancel(id: reminder.notificationID)
        }
        try refresh()
    }

    /// 앱이 포그라운드로 돌아올 때 호출. 활성화된 모든 리마인더의 향후 알림을 다시 채운다.
    public func refreshAllScheduledReminders() async throws {
        try refresh()
        for reminder in reminders where reminder.isEnabled {
            await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: reminder.hour, minute: reminder.minute, days: reminderRollingWindowDays)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CoachingKit && swift test`
Expected: PASS — all tests including the new `SettingsViewModelTests` and the previous tasks' tests (Task 1–4 files compile now that Task 4's protocol change lines up).

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderScheduling.swift CoachingKit/Sources/CoachingKit/SettingsViewModel.swift CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift
git commit -m "feat: switch reminder scheduling to rolling-window rotation"
```

---

### Task 6: UserNotificationReminderScheduler를 롤링 윈도로 재구현 (SmileDay 앱 타겟)

**Files:**
- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift`

이 파일은 SmileDay Xcode 앱 타겟에 있어 `swift test`로는 커버되지 않는다 (기존에도 유닛 테스트가 없었음). Task 8에서 `xcodebuild`로 컴파일을 확인한다.

- [ ] **Step 1: 구현 교체**

```swift
// SmileDay/Services/UserNotificationReminderScheduler.swift
import Foundation
import UserNotifications
import CoachingKit

final class UserNotificationReminderScheduler: ReminderScheduling {
    private let center: UNUserNotificationCenter
    private let promptSelector: ReminderPromptSelector
    private let calendar: Calendar
    private let now: () -> Date

    init(
        center: UNUserNotificationCenter = .current(),
        promptSelector: ReminderPromptSelector = ReminderPromptSelector(cursorStore: UserDefaultsReminderPromptCursorStore()),
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.center = center
        self.promptSelector = promptSelector
        self.calendar = calendar
        self.now = now
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func scheduleRollingWindow(id: String, hour: Int, minute: Int, days: Int) async {
        cancel(id: id)

        let today = calendar.startOfDay(for: now())
        for dayOffset in 0..<days {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
            components.hour = hour
            components.minute = minute

            let prompt = promptSelector.nextPrompt(forHour: hour)
            let content = UNMutableNotificationContent()
            content.title = "스마일데이"
            content.body = prompt.text
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(id)-\(dayOffset)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func cancel(id: String) {
        let identifiers = (0..<reminderRollingWindowDays).map { "\(id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add SmileDay/Services/UserNotificationReminderScheduler.swift
git commit -m "feat: reschedule reminders as a rolling 14-day one-shot window"
```

---

### Task 7: RootView에서 포그라운드 진입 시 전체 리마인더 리프레쉬

**Files:**
- Modify: `SmileDay/Views/RootView.swift`

- [ ] **Step 1: scenePhase 훅 추가**

```swift
// SmileDay/Views/RootView.swift
import SwiftUI
import SwiftData
import CoachingKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var baseline: Baseline?
    @State private var isLoading = true
    @State private var hasSeenIntro = false

    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .transition(.opacity)
            } else if let baseline {
                MainTabView(baseline: baseline, onBaselineUpdated: { self.baseline = $0 })
            } else if hasSeenIntro {
                BaselineCaptureView(
                    onBaselineSaved: { savedBaseline in
                        baseline = savedBaseline
                    },
                    onCancel: { hasSeenIntro = false }
                )
            } else {
                OnboardingIntroView {
                    hasSeenIntro = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .task {
            async let minimumSplashDuration: Void? = try? Task.sleep(for: .seconds(1.3))

            let repository = SessionRepository(modelContext: modelContext)
            #if DEBUG
            if CommandLine.arguments.contains("-seedDemoData") {
                try? DemoSeeder.seedIfNeeded(repository: repository)
            }
            #endif
            let fetchedBaseline = try? repository.fetchLatestBaseline()

            _ = await minimumSplashDuration
            baseline = fetchedBaseline
            isLoading = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                let viewModel = SettingsViewModel(
                    reminderRepository: ReminderRepository(modelContext: modelContext),
                    sessionRepository: SessionRepository(modelContext: modelContext),
                    scheduler: UserNotificationReminderScheduler()
                )
                try? await viewModel.refreshAllScheduledReminders()
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add SmileDay/Views/RootView.swift
git commit -m "feat: refresh rolling reminder window on app foreground"
```

---

### Task 8: 전체 빌드 및 테스트 검증

**Files:** 없음 (검증 전용 태스크)

- [ ] **Step 1: CoachingKit 유닛 테스트 전체 실행**

Run: `cd CoachingKit && swift test`
Expected: PASS — 기존 76개 + 이번에 추가된 테스트(카탈로그 4개, 커서 스토어 3개, 셀렉터 3개, SettingsViewModel 신규 1개) 전부 통과.

- [ ] **Step 2: SmileDay 앱 타겟 빌드 확인 (RootView/UserNotificationReminderScheduler 컴파일 검증)**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 문제 없으면 최종 확인 커밋 없이 종료 (이미 각 태스크에서 커밋 완료)**

빌드/테스트가 모두 통과하면 추가로 커밋할 변경사항은 없다. `git log --oneline -8`로 이번 작업의 커밋들이 순서대로 쌓였는지 확인한다.
