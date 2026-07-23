# 버킷 단위 리마인더 유도 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리마인더 유도를 "0개일 때만"에서 "빈 시간대(아침/낮/저녁 버킷)를 채우도록"으로 확장한다.

**Architecture:** `TimeBucket`에 `displayName`을 추가하고, `ReminderNudge`와 상태 저장소를 버킷 집합 기반으로 교체한다. `ReminderRepository`에 등록된 버킷 집합 조회를 추가하고, 앱 타겟의 `CoachingTabView`/`HomeView` 연결부를 새 API에 맞춘다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, XCTest.

**설계 문서:** `SmileDay/docs/superpowers/specs/2026-07-23-bucket-reminder-nudge-design.md`

---

### Task 1: TimeBucket.displayName + ReminderRepository.registeredBuckets()

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/ReminderPrompt.swift`
- Modify: `CoachingKit/Sources/CoachingKit/ReminderRepository.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderRepositoryTests.swift`

- [ ] **Step 1: 실패하는 테스트 추가**

`ReminderPromptCatalogTests.swift`에 추가:

```swift
    func test_timeBucket_displayName() {
        XCTAssertEqual(TimeBucket.morning.displayName, "아침")
        XCTAssertEqual(TimeBucket.afternoon.displayName, "낮")
        XCTAssertEqual(TimeBucket.evening.displayName, "저녁")
    }
```

`ReminderRepositoryTests.swift`에 추가:

```swift
    func test_registeredBuckets_mapsHoursToBuckets() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())
        _ = try repository.add(hour: 8, minute: 0)   // morning
        _ = try repository.add(hour: 20, minute: 0)  // evening
        _ = try repository.add(hour: 21, minute: 30) // evening (중복 버킷)

        XCTAssertEqual(try repository.registeredBuckets(), [.morning, .evening])
    }
```

- [ ] **Step 2: 실패 확인**

Run: `cd CoachingKit && swift test --filter "test_timeBucket_displayName|test_registeredBuckets_mapsHoursToBuckets"`
Expected: FAIL to build — `displayName`, `registeredBuckets()` 없음.

- [ ] **Step 3: 구현**

`ReminderPrompt.swift`의 `TimeBucket`에 추가:

```swift
    public var displayName: String {
        switch self {
        case .morning: "아침"
        case .afternoon: "낮"
        case .evening: "저녁"
        }
    }
```

`ReminderRepository.swift`에 추가:

```swift
    /// 등록된 리마인더들이 커버하는 시간대 집합.
    public func registeredBuckets() throws -> Set<TimeBucket> {
        Set(try fetchAll().map { TimeBucket(hour: $0.hour) })
    }
```

- [ ] **Step 4: 통과 확인**

Run: `cd CoachingKit && swift test --filter "ReminderPromptCatalogTests|ReminderRepositoryTests"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderPrompt.swift CoachingKit/Sources/CoachingKit/ReminderRepository.swift CoachingKit/Tests/CoachingKitTests/ReminderPromptCatalogTests.swift CoachingKit/Tests/CoachingKitTests/ReminderRepositoryTests.swift
git commit -m "feat: add TimeBucket display names and registered-bucket lookup"
```

---

### Task 2: ReminderNudge를 버킷 기반으로 교체

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/ReminderNudge.swift` (전체 교체)
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderNudgeTests.swift` (전체 교체)

- [ ] **Step 1: 테스트 전체 교체 (실패 확인용)**

```swift
// CoachingKit/Tests/CoachingKitTests/ReminderNudgeTests.swift
import XCTest
@testable import CoachingKit

final class ReminderNudgeTests: XCTestCase {
    func test_shouldOfferAfterCheckIn_onlyWhenCurrentBucketMissing() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(registeredBuckets: [], checkInHour: 9))
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(registeredBuckets: [.morning], checkInHour: 9))
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(registeredBuckets: [.morning], checkInHour: 20))
    }

    func test_declineCheckInPrompt_isPerBucket() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.declineCheckInPrompt(forHour: 9) // 아침 거절
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(registeredBuckets: [], checkInHour: 10))
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(registeredBuckets: [], checkInHour: 20),
                      "아침 거절이 저녁 제안을 막으면 안 된다")
    }

    func test_missingBuckets_keepsAllCasesOrder() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertEqual(nudge.missingBuckets(registeredBuckets: [.afternoon]), [.morning, .evening])
        XCTAssertEqual(nudge.missingBuckets(registeredBuckets: []), [.morning, .afternoon, .evening])
        XCTAssertEqual(nudge.missingBuckets(registeredBuckets: [.morning, .afternoon, .evening]), [])
    }

    func test_shouldShowHomeCard_whenAnyBucketMissing() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldShowHomeCard(registeredBuckets: [.morning], hasAnyCheckIn: true))
        XCTAssertFalse(nudge.shouldShowHomeCard(registeredBuckets: [.morning, .afternoon, .evening], hasAnyCheckIn: true))
        XCTAssertFalse(nudge.shouldShowHomeCard(registeredBuckets: [], hasAnyCheckIn: false))
    }

    func test_dismissHomeCard_hidesUntilMissingSetChanges() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.dismissHomeCard(registeredBuckets: [.morning]) // 빈 버킷: 낮·저녁
        XCTAssertFalse(nudge.shouldShowHomeCard(registeredBuckets: [.morning], hasAnyCheckIn: true))
        // 낮 리마인더 추가 → 빈 버킷 조합이 [저녁]으로 달라짐 → 재노출
        XCTAssertTrue(nudge.shouldShowHomeCard(registeredBuckets: [.morning, .afternoon], hasAnyCheckIn: true))
    }

    func test_userDefaultsStore_persistsAcrossInstances() throws {
        let suiteName = "reminder-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = UserDefaultsReminderNudgeState(defaults: defaults)
        first.declinedBuckets = [.morning, .evening]
        first.dismissedHomeCardMissingBuckets = [.afternoon]

        let second = UserDefaultsReminderNudgeState(defaults: defaults)
        XCTAssertEqual(second.declinedBuckets, [.morning, .evening])
        XCTAssertEqual(second.dismissedHomeCardMissingBuckets, [.afternoon])
    }

    func test_userDefaultsStore_snapshotNilMeansNeverDismissed() throws {
        let suiteName = "reminder-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsReminderNudgeState(defaults: defaults)
        XCTAssertNil(store.dismissedHomeCardMissingBuckets)
    }
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd CoachingKit && swift test --filter ReminderNudgeTests`
Expected: FAIL to build — 새 API 없음.

- [ ] **Step 3: 구현 전체 교체**

```swift
// CoachingKit/Sources/CoachingKit/ReminderNudge.swift
import Foundation

/// 리마인더 설정 유도(넛지)의 노출 상태 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol ReminderNudgeStateStoring: AnyObject {
    /// 체크인 제안을 거절한 버킷들.
    var declinedBuckets: Set<TimeBucket> { get set }
    /// 홈 카드를 닫은 시점의 "빈 버킷" 조합. nil이면 닫은 적 없음.
    var dismissedHomeCardMissingBuckets: Set<TimeBucket>? { get set }
}

public final class UserDefaultsReminderNudgeState: ReminderNudgeStateStoring {
    private static let declinedKey = "reminderNudgeDeclinedBuckets"
    private static let dismissedKey = "reminderNudgeDismissedMissingBuckets"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var declinedBuckets: Set<TimeBucket> {
        get { Set((defaults.stringArray(forKey: Self.declinedKey) ?? []).compactMap(TimeBucket.init(rawValue:))) }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: Self.declinedKey) }
    }

    public var dismissedHomeCardMissingBuckets: Set<TimeBucket>? {
        get {
            guard let raw = defaults.stringArray(forKey: Self.dismissedKey) else { return nil }
            return Set(raw.compactMap(TimeBucket.init(rawValue:)))
        }
        set {
            if let newValue {
                defaults.set(newValue.map(\.rawValue).sorted(), forKey: Self.dismissedKey)
            } else {
                defaults.removeObject(forKey: Self.dismissedKey)
            }
        }
    }
}

public final class InMemoryReminderNudgeState: ReminderNudgeStateStoring {
    public var declinedBuckets: Set<TimeBucket> = []
    public var dismissedHomeCardMissingBuckets: Set<TimeBucket>?
    public init() {}
}

/// 빈 시간대(버킷)를 채우도록 리마인더 유도를 언제 보여줄지 판단한다.
public struct ReminderNudge {
    private let store: ReminderNudgeStateStoring

    public init(store: ReminderNudgeStateStoring) {
        self.store = store
    }

    /// 체크인 저장 화면에서 리마인더 제안을 보여줄지. 체크인 시각의 버킷이 비어 있고 거절한 적 없을 때만.
    public func shouldOfferAfterCheckIn(registeredBuckets: Set<TimeBucket>, checkInHour: Int) -> Bool {
        let bucket = TimeBucket(hour: checkInHour)
        return !registeredBuckets.contains(bucket) && !store.declinedBuckets.contains(bucket)
    }

    public func declineCheckInPrompt(forHour hour: Int) {
        store.declinedBuckets.insert(TimeBucket(hour: hour))
    }

    /// 비어 있는 버킷을 allCases 순서대로. 홈 카드 문구에 쓴다.
    public func missingBuckets(registeredBuckets: Set<TimeBucket>) -> [TimeBucket] {
        TimeBucket.allCases.filter { !registeredBuckets.contains($0) }
    }

    /// 홈에 리마인더 유도 카드를 보여줄지. 닫은 시점과 빈 버킷 조합이 달라지면 다시 보여준다.
    public func shouldShowHomeCard(registeredBuckets: Set<TimeBucket>, hasAnyCheckIn: Bool) -> Bool {
        let missing = Set(missingBuckets(registeredBuckets: registeredBuckets))
        guard !missing.isEmpty, hasAnyCheckIn else { return false }
        return store.dismissedHomeCardMissingBuckets != missing
    }

    public func dismissHomeCard(registeredBuckets: Set<TimeBucket>) {
        store.dismissedHomeCardMissingBuckets = Set(missingBuckets(registeredBuckets: registeredBuckets))
    }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd CoachingKit && swift test`
Expected: PASS — 전체 통과 (기존 93개 중 구 ReminderNudgeTests 6개가 새 7개로 대체 → 94개).

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderNudge.swift CoachingKit/Tests/CoachingKitTests/ReminderNudgeTests.swift
git commit -m "feat: make reminder nudge bucket-aware"
```

---

### Task 3: 앱 연결부 갱신 (CoachingTabView + HomeView)

**Files:**
- Modify: `SmileDay/Views/Coaching/CoachingTabView.swift`
- Modify: `SmileDay/Views/Home/HomeView.swift`

앱 타겟이라 유닛 테스트 없음 — Task 4의 xcodebuild로 검증.

- [ ] **Step 1: CoachingTabView의 판단/거절 로직 교체**

`onCompleted`에서:

```swift
onCompleted: { today, yesterday in
    let components = Calendar.current.dateComponents([.hour, .minute], from: .now)
    let hour = components.hour ?? 9
    let registered = (try? ReminderRepository(modelContext: modelContext).registeredBuckets()) ?? []
    let nudge = ReminderNudge(store: UserDefaultsReminderNudgeState())
    result = SessionResult(
        todayScore: today,
        yesterdayScore: yesterday,
        completedHour: hour,
        completedMinute: components.minute ?? 0,
        offerReminder: nudge.shouldOfferAfterCheckIn(registeredBuckets: registered, checkInHour: hour)
    )
},
```

거절 콜백:

```swift
onDecline: {
    ReminderNudge(store: UserDefaultsReminderNudgeState()).declineCheckInPrompt(forHour: result.completedHour)
}
```

- [ ] **Step 2: HomeView의 노출 판단·문구·닫기 교체**

`ReminderNudgeCard`에 title/subtitle 파라미터 추가:

```swift
/// 리마인더 미설정 시간대를 채우도록 유도하는 카드.
struct ReminderNudgeCard: View {
    let title: String
    let subtitle: String
    let onTap: () -> Void
    let onDismiss: () -> Void
    // body는 기존과 동일하되 Text(title) / Text(subtitle) 사용
}
```

`refreshReminderNudge()`와 카드 호출부 교체:

```swift
@State private var reminderNudgeTitle = ""
@State private var reminderNudgeSubtitle = ""

private func refreshReminderNudge() {
    let registered = (try? ReminderRepository(modelContext: modelContext).registeredBuckets()) ?? []
    let hasAnyCheckIn = viewModel?.recentWeek.contains(where: \.checkedIn) ?? false
    let nudge = ReminderNudge(store: UserDefaultsReminderNudgeState())
    let missing = nudge.missingBuckets(registeredBuckets: registered)

    if missing.count == TimeBucket.allCases.count {
        reminderNudgeTitle = "매일 잊지 않게 알려드릴까요?"
        reminderNudgeSubtitle = "원하는 시간에 표정 질문을 보내드려요"
    } else {
        reminderNudgeTitle = "\(missing.map(\.displayName).joined(separator: "·")) 리마인더도 설정해볼까요?"
        reminderNudgeSubtitle = "하루 세 번이면 표정 습관이 더 잘 자리 잡아요"
    }
    showReminderNudgeCard = nudge.shouldShowHomeCard(registeredBuckets: registered, hasAnyCheckIn: hasAnyCheckIn)
}
```

카드 호출부:

```swift
if showReminderNudgeCard {
    ReminderNudgeCard(
        title: reminderNudgeTitle,
        subtitle: reminderNudgeSubtitle,
        onTap: { isReminderSheetPresented = true },
        onDismiss: {
            let registered = (try? ReminderRepository(modelContext: modelContext).registeredBuckets()) ?? []
            ReminderNudge(store: UserDefaultsReminderNudgeState()).dismissHomeCard(registeredBuckets: registered)
            withAnimation { showReminderNudgeCard = false }
        }
    )
}
```

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Views/Coaching/CoachingTabView.swift SmileDay/Views/Home/HomeView.swift
git commit -m "feat: nudge per missing reminder time bucket in app views"
```

---

### Task 4: 전체 빌드 및 테스트 검증

- [ ] **Step 1: CoachingKit 테스트 전체 실행**

Run: `cd CoachingKit && swift test`
Expected: PASS — 94개 전부 통과.

- [ ] **Step 2: 앱 타겟 빌드**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`
