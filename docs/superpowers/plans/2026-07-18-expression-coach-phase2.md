# Expression Coach Phase 2 Implementation Plan (와이어프레임 기반)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자 제공 와이어프레임(4탭: 홈/코칭/기록/설정)대로 앱을 확장한다 — 탭 내비게이션, 홈 스트릭 표시, 코칭 화면 개편(조명 경고 배너·얼굴 가이드·세로 게이지·측정 종료), 어제 대비 저장 확인 화면, 기록 탭(Swift Charts 주간 그래프 + 월간 히트맵), 설정 탭(리마인더·기준선 재설정·데이터 저장 위치·계정 자리).

**Architecture:** Phase 1과 동일 — 테스트 가능한 로직은 전부 `CoachingKit` 패키지(swift test), 앱 타겟은 SwiftUI/ARKit/UserNotifications 등 프레임워크 의존 레이어만. Phase 1의 확립된 패턴(phase 머신, `[weak self]` 클로저 배선, `.onAppear`/`.onDisappear` 세션 수명주기, `do/catch`+`errorMessage`, phase-aware `.disabled`)을 그대로 따른다.

**Tech Stack:** Phase 1 스택 + Swift Charts(주간 그래프), UserNotifications(로컬 리마인더).

**이번 계획에서 확정된 설계 결정 (사용자 승인):**
- **점수 표기**: 내부 delta 계수(대략 -1...1)를 `×10 반올림`한 정수에 `°`를 붙여 표시 (예: 0.31 → `+3°`). 실측 각도가 아닌 표시용 점수임 — 코드 주석/문서에 명시.
- **계정 항목**: 로컬 전용 앱이므로 기능 없는 자리(row)만 만들고 "준비 중" 표시.
- **기록 화면 포함**: 와이어프레임에는 탭 아이콘만 있지만 주간 그래프 + 월간 체크인 히트맵까지 이번에 구현.
- **조명 경고**: 원래 Phase 3였으나 와이어프레임에 배너가 명시되어 ARKit `lightEstimate.ambientIntensity` 기반의 단순 감지를 이번에 넣는다. `deviceAngleOK`는 계속 `true` 고정(Phase 3 유지).
- **ReminderSetting 모델**: 원 스펙의 `DateComponents` 대신 `hour`/`minute` Int 저장 (SwiftData 호환성·단순성). 스키마에 엔티티 추가는 additive라 자동 경량 마이그레이션으로 충분.
- **탭 전환 시 코칭 세션**: 코칭 탭 진입 시 세션 시작, 이탈 시 정지 (기존 `.onAppear`/`.onDisappear` 패턴 재사용). 코칭 탭 재진입 시 매번 새 세션(뷰모델 재생성)으로 시작.

---

## File Structure

```
CoachingKit/Sources/CoachingKit/
├── ScoreCalculator.swift            (수정: displayScore 추가)
├── PersistenceSchema.swift          (수정: ReminderSetting 추가)
├── ReminderSetting.swift            (신규: @Model)
├── ReminderRepository.swift         (신규: 리마인더 CRUD)
├── ReminderScheduling.swift         (신규: 알림 스케줄러 프로토콜)
├── LightingEvaluator.swift          (신규: 조명 판정 순수 로직)
├── FaceTrackingSession.swift        (수정: onLightingUpdate 추가)
├── SessionRepository.swift          (수정: 기간 조회·스트릭·최근 N일 추가)
├── CoachingViewModel.swift          (수정: 조명 상태·yesterdayDelta·실제 lightingQuality 저장)
├── HomeViewModel.swift              (수정: 스트릭·최근 5일 추가)
├── HistoryViewModel.swift           (신규)
└── SettingsViewModel.swift          (신규)
CoachingKit/Tests/CoachingKitTests/  (각 항목별 테스트 추가/수정)

SmileDay/
├── Services/
│   ├── ARKitFaceTrackingSession.swift        (수정: ambientIntensity 방출)
│   └── UserNotificationReminderScheduler.swift (신규)
└── Views/
    ├── RootView.swift               (수정: HomeView → MainTabView)
    ├── MainTabView.swift            (신규: 4탭)
    ├── Home/HomeView.swift          (개편: 카드+스트릭 도트, fullScreenCover 제거)
    ├── Home/StreakDotsView.swift    (신규)
    ├── Coaching/CoachingTabView.swift      (신규: 세션↔저장확인 상태 전환)
    ├── Coaching/CoachingSessionView.swift  (개편: 배너·가이드·세로 게이지·측정 종료·콜백)
    ├── Coaching/SaveConfirmView.swift      (신규: SessionSummarySheet 대체)
    ├── History/HistoryView.swift    (신규: Swift Charts + 히트맵)
    └── Settings/
        ├── SettingsView.swift       (신규)
        ├── ReminderListView.swift   (신규)
        └── DataLocationView.swift   (신규)

삭제: SmileDay/Views/Coaching/SessionSummarySheet.swift (SaveConfirmView로 대체)
```

---

### Task 1: `ScoreCalculator.displayScore`

**Files:** Modify `CoachingKit/Sources/CoachingKit/ScoreCalculator.swift` / Test `ScoreCalculatorTests.swift`

- [ ] **Step 1: 실패하는 테스트 추가** — `ScoreCalculatorTests.swift`에 추가:

```swift
func test_displayScore_roundsDeltaTimesTen() {
    XCTAssertEqual(ScoreCalculator.displayScore(0.31), 3)
    XCTAssertEqual(ScoreCalculator.displayScore(0.35), 4)
    XCTAssertEqual(ScoreCalculator.displayScore(-0.12), -1)
    XCTAssertEqual(ScoreCalculator.displayScore(0.0), 0)
}
```

- [ ] **Step 2: `swift test` 로 실패 확인** (displayScore 미정의 빌드 실패)
- [ ] **Step 3: 구현** — `ScoreCalculator`에 추가:

```swift
/// 내부 delta 계수를 표시용 점수(°)로 변환. 실측 각도가 아닌 표시용 스케일이다.
public static func displayScore(_ delta: Double) -> Int {
    Int((delta * 10).rounded())
}
```

- [ ] **Step 4: `swift test` 통과 확인 (17개)**
- [ ] **Step 5: Commit** — `feat: add ScoreCalculator.displayScore for degree-style display`

---

### Task 2: `ReminderSetting` 모델 + 스키마 등록

**Files:** Create `ReminderSetting.swift`, Modify `PersistenceSchema.swift`

- [ ] **Step 1: 모델 작성**

```swift
import Foundation
import SwiftData

@Model
public final class ReminderSetting {
    public var hour: Int
    public var minute: Int
    public var isEnabled: Bool
    public var createdAt: Date
    public var notificationID: String

    public init(hour: Int, minute: Int, isEnabled: Bool = true, createdAt: Date = Date(), notificationID: String = UUID().uuidString) {
        self.hour = hour
        self.minute = minute
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.notificationID = notificationID
    }
}
```

- [ ] **Step 2: `PersistenceSchema.models`에 `ReminderSetting.self` 추가** (`[Baseline.self, CheckInSession.self, ReminderSetting.self]`)
- [ ] **Step 3: `swift build` + `swift test` 통과 확인** (기존 테스트는 PersistenceSchema를 쓰므로 스키마 확장 자동 반영)
- [ ] **Step 4: Commit** — `feat: add ReminderSetting model to persistence schema`

---

### Task 3: `SessionRepository` 조회 확장 (기간·일자·스트릭·최근 N일)

**Files:** Modify `SessionRepository.swift` / Test `SessionRepositoryTests.swift`

- [ ] **Step 1: 실패하는 테스트 추가** — `SessionRepositoryTests.swift`에 추가 (기존 `makeInMemoryContext()` 재사용, `saveCheckIn`으로 날짜별 데이터 심기):

```swift
func test_fetchCheckIns_returnsOnlyThoseInRange_sortedAscending() throws { /* 3건 저장(전전날/어제/오늘), 어제~내일 범위 조회 → 2건, 날짜 오름차순 검증 */ }
func test_fetchLatestCheckIn_onDayOf_returnsThatDaysLatest() throws { /* 어제 2건 저장 → 어제 조회 시 더 늦은 것 반환, 오늘 조회 시 nil */ }
func test_checkInStreak_countsConsecutiveDaysEndingToday() throws { /* 오늘+어제+그제 저장 → 3. 그제만 빠지면 → 2 */ }
func test_checkInStreak_allowsYesterdayAnchor_whenTodayMissing() throws { /* 어제+그제만 저장 → 2 (오늘 아직 안 했어도 스트릭 유지) */ }
func test_recentCheckInDays_returnsOldestToNewest() throws { /* 오늘·그제 저장, count 3 → [true, false, true] */ }
```

(각 테스트는 `calendar.date(byAdding:)`으로 날짜를 만들고 정확한 값 검증 — 구현 시 스텁이 아니라 실제 assert 코드로 작성할 것)

- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현** — `SessionRepository`에 추가:

```swift
public func fetchCheckIns(from start: Date, to end: Date) throws -> [CheckInSession] {
    let descriptor = FetchDescriptor<CheckInSession>(
        predicate: #Predicate { $0.date >= start && $0.date < end },
        sortBy: [SortDescriptor(\.date)]
    )
    return try modelContext.fetch(descriptor)
}

public func fetchLatestCheckIn(onDayOf date: Date, calendar: Calendar = .current) throws -> CheckInSession? {
    let start = calendar.startOfDay(for: date)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
    return try fetchCheckIns(from: start, to: end).last
}

public func hasCheckIn(onDayOf date: Date, calendar: Calendar = .current) throws -> Bool {
    try fetchLatestCheckIn(onDayOf: date, calendar: calendar) != nil
}

public func checkInStreak(endingOn now: Date = Date(), calendar: Calendar = .current) throws -> Int {
    var day = calendar.startOfDay(for: now)
    if try !hasCheckIn(onDayOf: day, calendar: calendar) {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
        day = yesterday
    }
    var streak = 0
    while try hasCheckIn(onDayOf: day, calendar: calendar) {
        streak += 1
        guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
        day = previous
    }
    return streak
}

public func recentCheckInDays(count: Int, endingOn now: Date = Date(), calendar: Calendar = .current) throws -> [Bool] {
    let today = calendar.startOfDay(for: now)
    return try (0..<count).reversed().map { offset in
        guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
        return try hasCheckIn(onDayOf: day, calendar: calendar)
    }
}
```

- [ ] **Step 4: 전체 테스트 통과 확인**
- [ ] **Step 5: Commit** — `feat: add range/day/streak queries to SessionRepository`

---

### Task 4: `ReminderRepository`

**Files:** Create `ReminderRepository.swift` / Test `ReminderRepositoryTests.swift` (신규 파일, in-memory 컨텍스트 헬퍼는 기존 테스트와 동일 패턴)

- [ ] **Step 1: 실패하는 테스트** — add/fetchAll(시각순 정렬)/delete/setEnabled 4개 테스트
- [ ] **Step 2: 실패 확인**
- [ ] **Step 3: 구현**

```swift
import Foundation
import SwiftData

public final class ReminderRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func add(hour: Int, minute: Int) throws -> ReminderSetting {
        let reminder = ReminderSetting(hour: hour, minute: minute)
        modelContext.insert(reminder)
        try modelContext.save()
        return reminder
    }

    public func fetchAll() throws -> [ReminderSetting] {
        let descriptor = FetchDescriptor<ReminderSetting>(
            sortBy: [SortDescriptor(\.hour), SortDescriptor(\.minute)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func delete(_ reminder: ReminderSetting) throws {
        modelContext.delete(reminder)
        try modelContext.save()
    }

    public func setEnabled(_ reminder: ReminderSetting, _ enabled: Bool) throws {
        reminder.isEnabled = enabled
        try modelContext.save()
    }
}
```

- [ ] **Step 4: 통과 확인** / **Step 5: Commit** — `feat: add ReminderRepository`

---

### Task 5: `LightingEvaluator`

**Files:** Create `LightingEvaluator.swift` / Test `LightingEvaluatorTests.swift`

- [ ] **Step 1: 실패하는 테스트**

```swift
func test_quality_normalizesAmbientIntensity() {
    XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 1000), 1.0, accuracy: 0.001)
    XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 500), 0.5, accuracy: 0.001)
    XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 2000), 1.0, accuracy: 0.001) // clamp
    XCTAssertEqual(LightingEvaluator.quality(ambientIntensity: 0), 0.0, accuracy: 0.001)
}
func test_isTooDark_belowThreshold() {
    XCTAssertTrue(LightingEvaluator.isTooDark(ambientIntensity: 299))
    XCTAssertFalse(LightingEvaluator.isTooDark(ambientIntensity: 300))
}
```

- [ ] **Step 2: 실패 확인** / **Step 3: 구현**

```swift
import Foundation

/// ARKit lightEstimate.ambientIntensity(약 1000 = 밝은 실내) 기반 조명 판정.
public enum LightingEvaluator {
    public static let referenceIntensity: Double = 1000
    public static let darkThreshold: Double = 300

    public static func quality(ambientIntensity: Double) -> Double {
        min(max(ambientIntensity / referenceIntensity, 0), 1)
    }

    public static func isTooDark(ambientIntensity: Double) -> Bool {
        ambientIntensity < darkThreshold
    }
}
```

- [ ] **Step 4: 통과 확인** / **Step 5: Commit** — `feat: add LightingEvaluator`

---

### Task 6: `FaceTrackingSession.onLightingUpdate` + `CoachingViewModel` 조명·어제점수 확장

**Files:** Modify `FaceTrackingSession.swift`, `CoachingViewModel.swift` / Test: 기존 3개 테스트 파일의 Mock 수정 + `CoachingViewModelTests.swift` 확장

- [ ] **Step 1: 프로토콜 확장** — `FaceTrackingSession`에 `var onLightingUpdate: ((Double) -> Void)? { get set }` 추가. 3개 테스트 파일의 `MockFaceTrackingSession`에 프로퍼티 추가(+`emitLighting(_:)` 헬퍼).
- [ ] **Step 2: 실패하는 테스트 추가** — `CoachingViewModelTests.swift`:

```swift
func test_isLightingPoor_true_whenAmbientBelowThreshold() { /* emitLighting(200) → true, emitLighting(800) → false */ }
func test_complete_persistsMeasuredLightingQuality() { /* emitLighting(500) 후 complete → 저장된 CheckInSession.lightingQuality == 0.5 */ }
func test_complete_persistsNeutralLighting_whenNoLightingReceived() { /* emitLighting 없이 complete → 1.0 */ }
func test_yesterdayDelta_returnsYesterdaysLatestScoreDelta() { /* repo에 어제 체크인(scoreDelta 0.2) 저장 → vm.yesterdayDelta() == 0.2, 없으면 nil */ }
```

- [ ] **Step 3: 실패 확인** / **Step 4: 구현** — `CoachingViewModel`에:

```swift
public private(set) var latestAmbientIntensity: Double?

public var isLightingPoor: Bool {
    latestAmbientIntensity.map(LightingEvaluator.isTooDark) ?? false
}
// init에서: self.session.onLightingUpdate = { [weak self] intensity in self?.latestAmbientIntensity = intensity }
// complete()에서: lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0

public func yesterdayDelta(now: Date = Date(), calendar: Calendar = .current) throws -> Double? {
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return nil }
    return try repository.fetchLatestCheckIn(onDayOf: yesterday, calendar: calendar)?.scoreDelta
}
```

- [ ] **Step 5: 전체 테스트 통과 확인** / **Step 6: Commit** — `feat: add lighting awareness and yesterdayDelta to CoachingViewModel`

---

### Task 7: `HomeViewModel` 스트릭·최근 5일

**Files:** Modify `HomeViewModel.swift` / Test `HomeViewModelTests.swift`

- [ ] **Step 1: 실패하는 테스트** — `refresh()` 후 `streakDays`(연속일)와 `recentDays`([Bool] 5개, 과거→오늘 순) 검증 2개 추가
- [ ] **Step 2: 실패 확인** / **Step 3: 구현**

```swift
public private(set) var streakDays: Int = 0
public private(set) var recentDays: [Bool] = []
// refresh()에 추가:
streakDays = try repository.checkInStreak()
recentDays = try repository.recentCheckInDays(count: 5)
```

- [ ] **Step 4: 통과 확인** / **Step 5: Commit** — `feat: add streak and recent-days to HomeViewModel`

---

### Task 8: `HistoryViewModel`

**Files:** Create `HistoryViewModel.swift` / Test `HistoryViewModelTests.swift`

- [ ] **Step 1: 실패하는 테스트** — 지난 7일 중 3일치 체크인 심고 `refresh()` → `weeklyScores`가 해당 3일의 (날짜, displayScore) 목록인지, `monthCheckInDays`가 이번 달 체크인 일자 Set인지 검증
- [ ] **Step 2: 실패 확인** / **Step 3: 구현**

```swift
import Foundation
import Observation

public struct DailyScore: Equatable, Identifiable {
    public let date: Date
    public let displayScore: Int
    public var id: Date { date }

    public init(date: Date, displayScore: Int) {
        self.date = date
        self.displayScore = displayScore
    }
}

@Observable
public final class HistoryViewModel {
    public private(set) var weeklyScores: [DailyScore] = []
    public private(set) var monthCheckInDays: Set<Int> = []

    private let repository: SessionRepository
    private let now: () -> Date
    private let calendar: Calendar

    public init(repository: SessionRepository, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
    }

    public func refresh() throws {
        let today = calendar.startOfDay(for: now())
        var scores: [DailyScore] = []
        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if let session = try repository.fetchLatestCheckIn(onDayOf: day, calendar: calendar) {
                scores.append(DailyScore(date: day, displayScore: ScoreCalculator.displayScore(session.scoreDelta)))
            }
        }
        weeklyScores = scores

        guard let monthRange = calendar.dateInterval(of: .month, for: now()) else { return }
        let sessions = try repository.fetchCheckIns(from: monthRange.start, to: monthRange.end)
        monthCheckInDays = Set(sessions.map { calendar.component(.day, from: $0.date) })
    }
}
```

- [ ] **Step 4: 통과 확인** / **Step 5: Commit** — `feat: add HistoryViewModel`

---

### Task 9: `ReminderScheduling` 프로토콜 + `SettingsViewModel`

**Files:** Create `ReminderScheduling.swift`, `SettingsViewModel.swift` / Test `SettingsViewModelTests.swift` (Mock scheduler로 스케줄/취소 호출 검증)

- [ ] **Step 1: 프로토콜**

```swift
import Foundation

public protocol ReminderScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleDaily(id: String, hour: Int, minute: Int) async
    func cancel(id: String)
}
```

- [ ] **Step 2: 실패하는 테스트** — Mock scheduler(호출 기록)로: `addReminder` → repo 저장 + `scheduleDaily` 호출 / `removeReminder` → 삭제 + `cancel` 호출 / `toggleReminder` off → `cancel`, on → `scheduleDaily` / `refresh` → `reminders` 목록·`baselineAgeWeeks`(기준선 capturedAt과 now의 주차 차) 검증
- [ ] **Step 3: 실패 확인** / **Step 4: 구현**

```swift
import Foundation
import Observation

@Observable
public final class SettingsViewModel {
    public private(set) var reminders: [ReminderSetting] = []
    public private(set) var baselineAgeWeeks: Int?

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
        await scheduler.scheduleDaily(id: reminder.notificationID, hour: hour, minute: minute)
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
            await scheduler.scheduleDaily(id: reminder.notificationID, hour: reminder.hour, minute: reminder.minute)
        } else {
            scheduler.cancel(id: reminder.notificationID)
        }
        try refresh()
    }
}
```

- [ ] **Step 5: 통과 확인** / **Step 6: Commit** — `feat: add SettingsViewModel with reminder scheduling`

**CoachingKit는 여기까지로 Phase 2 로직 완료. 이후는 앱 타겟.**

---

### Task 10: `ARKitFaceTrackingSession` 조명 방출 + `UserNotificationReminderScheduler`

**Files:** Modify `ARKitFaceTrackingSession.swift`, Create `UserNotificationReminderScheduler.swift`

- [ ] **Step 1: 조명 방출** — `ARSessionDelegate` extension에 추가:

```swift
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard let intensity = frame.lightEstimate?.ambientIntensity else { return }
    DispatchQueue.main.async { [weak self] in
        self?.onLightingUpdate?(Double(intensity))
    }
}
```

클래스 본체에 `var onLightingUpdate: ((Double) -> Void)?` 추가 (프로토콜 준수).

- [ ] **Step 2: 스케줄러 구현**

```swift
import Foundation
import UserNotifications
import CoachingKit

final class UserNotificationReminderScheduler: ReminderScheduling {
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func scheduleDaily(id: String, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "스마일데이"
        content.body = "오늘의 표정 습관을 기록해보세요"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
```

- [ ] **Step 3: 시뮬레이터 빌드 성공 확인** / **Step 4: Commit** — `feat: emit ambient lighting and add local notification scheduler`

---

### Task 11: `MainTabView` + `RootView` 재배선 + `HomeView` 개편 + `StreakDotsView`

**Files:** Create `MainTabView.swift`, `Home/StreakDotsView.swift` / Modify `RootView.swift`, `Home/HomeView.swift`

- [ ] **Step 1: MainTabView**

```swift
import SwiftUI
import CoachingKit

enum AppTab: Hashable {
    case home, coaching, history, settings
}

struct MainTabView: View {
    let baseline: Baseline
    let onBaselineUpdated: (Baseline) -> Void
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(baseline: baseline, onStartCoaching: { selection = .coaching })
                .tabItem { Label("홈", systemImage: "house") }
                .tag(AppTab.home)

            CoachingTabView(baseline: baseline, onFinished: { selection = .home })
                .tabItem { Label("코칭", systemImage: "video") }
                .tag(AppTab.coaching)

            HistoryView()
                .tabItem { Label("기록", systemImage: "chart.bar") }
                .tag(AppTab.history)

            SettingsView(onBaselineUpdated: onBaselineUpdated)
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
```

- [ ] **Step 2: RootView** — `HomeView(baseline: baseline)` 자리를 `MainTabView(baseline: baseline, onBaselineUpdated: { baseline = $0 })`로 교체.
- [ ] **Step 3: HomeView 개편** — fullScreenCover 제거, 와이어프레임의 카드 구성:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?

    let baseline: Baseline
    let onStartCoaching: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "camera")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                if viewModel?.hasCheckedInToday == true {
                    Label("오늘 체크인을 완료했습니다", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("오늘의 표정 습관을 기록해보세요")
                        .font(.headline)
                    Button("오늘 시작하기") {
                        onStartCoaching()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))

            if let viewModel {
                StreakDotsView(days: viewModel.recentDays, streak: viewModel.streakDays)
            }
        }
        .padding()
        .onAppear {
            let vm = viewModel ?? HomeViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
        }
    }
}
```

- [ ] **Step 4: StreakDotsView**

```swift
import SwiftUI

struct StreakDotsView: View {
    let days: [Bool]
    let streak: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, done in
                    Circle()
                        .fill(done ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            if streak > 0 {
                Text("연속 \(streak)일 기록 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 5: 빌드** — 이 시점엔 `CoachingTabView`/`HistoryView`/`SettingsView` 미존재로 실패가 정상. 이 세 타입만 에러로 나오는지 확인.
- [ ] **Step 6: Commit** — `feat: add MainTabView, redesign HomeView with streak dots`

---

### Task 12: 코칭 화면 개편 (`CoachingTabView` + `CoachingSessionView` + `SaveConfirmView`)

**Files:** Create `Coaching/CoachingTabView.swift`, `Coaching/SaveConfirmView.swift` / Rewrite `Coaching/CoachingSessionView.swift` / Delete `Coaching/SessionSummarySheet.swift`

- [ ] **Step 1: CoachingTabView** — 세션↔저장확인 상태 전환:

```swift
import SwiftUI
import CoachingKit

struct CoachingTabView: View {
    let baseline: Baseline
    let onFinished: () -> Void
    @State private var result: SessionResult?

    struct SessionResult {
        let todayScore: Int
        let yesterdayScore: Int?
    }

    var body: some View {
        if let result {
            SaveConfirmView(todayScore: result.todayScore, yesterdayScore: result.yesterdayScore) {
                self.result = nil
                onFinished()
            }
        } else {
            CoachingSessionView(baseline: baseline) { today, yesterday in
                result = SessionResult(todayScore: today, yesterdayScore: yesterday)
            }
        }
    }
}
```

- [ ] **Step 2: CoachingSessionView 재작성** — 와이어프레임대로: 상단 조명 경고 배너(노랑, `isLightingPoor`일 때만), 점선 얼굴 가이드(기준선 화면의 `FaceGuideOverlay`와 동일 스타일 — 해당 private 뷰를 별도 파일 `Views/FaceGuideOverlay.swift`로 승격해 공유), 우측 세로 게이지, 하단 "측정 종료" 버튼:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct CoachingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: CoachingViewModel?
    @State private var errorMessage: String?

    let baseline: Baseline
    let onCompleted: (Int, Int?) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            FaceGuideOverlay()

            HStack {
                Spacer()
                if let measurement = viewModel?.latestMeasurement {
                    let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
                    VerticalGaugeView(value: min(max((delta + 1) / 2, 0), 1))
                        .frame(width: 8, height: 220)
                        .padding(.trailing, 20)
                }
            }

            VStack {
                if viewModel?.isLightingPoor == true {
                    Label("주변이 어둡습니다. 밝은 곳에서 측정해주세요", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.yellow.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                }
                Spacer()
            }

            VStack(spacing: 16) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    complete()
                } label: {
                    Label("측정 종료", systemImage: "stop")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel?.latestMeasurement == nil || viewModel?.phase != .tracking)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .onAppear {
            let vm = CoachingViewModel(
                session: trackingSession,
                repository: SessionRepository(modelContext: modelContext),
                baseline: baseline
            )
            viewModel = vm
            vm.start()
        }
        .onDisappear {
            trackingSession.stop()
        }
    }

    private func complete() {
        guard let viewModel else { return }
        let yesterday = (try? viewModel.yesterdayDelta())?.map(ScoreCalculator.displayScore) ?? nil
        do {
            try viewModel.complete()
        } catch {
            errorMessage = SharedStrings.saveFailed
            return
        }
        if case let .completed(delta) = viewModel.phase {
            onCompleted(ScoreCalculator.displayScore(delta), yesterday)
        }
    }
}

struct VerticalGaugeView: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.3))
                Capsule().fill(Color.accentColor)
                    .frame(height: geometry.size.height * min(max(value, 0), 1))
            }
        }
    }
}
```

(주의: `yesterdayDelta`는 `complete()` **이전에** 조회 — complete 후에 조회하면 방금 저장한 오늘 기록과 무관하지만, 어제 조회라 순서 무관. 다만 명확성을 위해 위 순서 유지.)

- [ ] **Step 3: SaveConfirmView** — 와이어프레임의 저장 확인 화면:

```swift
import SwiftUI

struct SaveConfirmView: View {
    let todayScore: Int
    let yesterdayScore: Int?
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("오늘의 기록이 저장되었습니다")
                .font(.headline)

            HStack(spacing: 12) {
                if let yesterdayScore {
                    Text("어제 \(signed(yesterdayScore))°")
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                }
                Text("오늘 \(signed(todayScore))°")
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
            .font(.title3)

            Button("확인") {
                onConfirm()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

#Preview {
    SaveConfirmView(todayScore: 3, yesterdayScore: 1, onConfirm: {})
}
```

- [ ] **Step 4:** `SessionSummarySheet.swift` 삭제(`git rm`), `BaselineCaptureView`의 private `FaceGuideOverlay`를 `Views/FaceGuideOverlay.swift`(internal)로 이동하고 양쪽에서 공유.
- [ ] **Step 5: 빌드** — 남은 미구현은 `HistoryView`/`SettingsView`만 에러인지 확인.
- [ ] **Step 6: Commit** — `feat: rebuild coaching flow with tab lifecycle, lighting banner, vertical gauge, save confirm`

---

### Task 13: `HistoryView` (Swift Charts + 월간 히트맵)

**Files:** Create `History/HistoryView.swift`

- [ ] **Step 1: 구현**

```swift
import SwiftUI
import SwiftData
import Charts
import CoachingKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("주간 추이")
                    .font(.headline)

                if let viewModel, !viewModel.weeklyScores.isEmpty {
                    Chart(viewModel.weeklyScores) { score in
                        BarMark(
                            x: .value("날짜", score.date, unit: .day),
                            y: .value("점수", score.displayScore)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 180)
                } else {
                    Text("아직 기록이 없습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }

                Text("이번 달 체크인")
                    .font(.headline)

                MonthHeatmapView(checkInDays: viewModel?.monthCheckInDays ?? [])
            }
            .padding()
        }
        .onAppear {
            let vm = viewModel ?? HistoryViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
        }
    }
}

struct MonthHeatmapView: View {
    let checkInDays: Set<Int>
    private let calendar = Calendar.current

    var body: some View {
        let dayCount = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(1...dayCount, id: \.self) { day in
                RoundedRectangle(cornerRadius: 4)
                    .fill(checkInDays.contains(day) ? Color.accentColor : Color.secondary.opacity(0.15))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Text("\(day)")
                            .font(.system(size: 9))
                            .foregroundStyle(checkInDays.contains(day) ? .white : .secondary)
                    }
            }
        }
    }
}
```

- [ ] **Step 2: 빌드** (`SettingsView`만 남은 에러인지 확인) / **Step 3: Commit** — `feat: add HistoryView with weekly chart and month heatmap`

---

### Task 14: 설정 탭 (`SettingsView` + `ReminderListView` + `DataLocationView` + 기준선 재설정)

**Files:** Create `Settings/SettingsView.swift`, `Settings/ReminderListView.swift`, `Settings/DataLocationView.swift`

- [ ] **Step 1: SettingsView**

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var isResettingBaseline = false

    let onBaselineUpdated: (Baseline) -> Void

    var body: some View {
        NavigationStack {
            List {
                if let viewModel {
                    NavigationLink {
                        ReminderListView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Label("리마인더", systemImage: "bell")
                            Spacer()
                            Text("\(viewModel.reminders.count)개")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        isResettingBaseline = true
                    } label: {
                        HStack {
                            Label("기준선 재설정", systemImage: "arrow.clockwise")
                            Spacer()
                            if let weeks = viewModel.baselineAgeWeeks {
                                Text("\(weeks)주 전")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    NavigationLink {
                        DataLocationView()
                    } label: {
                        Label("데이터 저장 위치", systemImage: "lock")
                    }

                    HStack {
                        Label("계정", systemImage: "person")
                        Spacer()
                        Text("준비 중")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("설정")
        }
        .onAppear {
            let vm = viewModel ?? SettingsViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                sessionRepository: SessionRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler()
            )
            viewModel = vm
            try? vm.refresh()
        }
        .fullScreenCover(isPresented: $isResettingBaseline) {
            BaselineCaptureView { newBaseline in
                onBaselineUpdated(newBaseline)
                isResettingBaseline = false
            }
        }
    }
}
```

- [ ] **Step 2: ReminderListView** — 목록(시각·토글·스와이프 삭제) + 시간 추가 UI:

```swift
import SwiftUI
import CoachingKit

struct ReminderListView: View {
    let viewModel: SettingsViewModel
    @State private var newTime = Date()

    var body: some View {
        List {
            Section {
                ForEach(viewModel.reminders, id: \.notificationID) { reminder in
                    HStack {
                        Text(String(format: "%02d:%02d", reminder.hour, reminder.minute))
                            .font(.title3.monospacedDigit())
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { reminder.isEnabled },
                            set: { _ in Task { try? await viewModel.toggleReminder(reminder) } }
                        ))
                        .labelsHidden()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        try? viewModel.removeReminder(viewModel.reminders[index])
                    }
                }
            }

            Section("리마인더 추가") {
                DatePicker("시간", selection: $newTime, displayedComponents: .hourAndMinute)
                Button("추가") {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                    Task {
                        try? await viewModel.addReminder(hour: components.hour ?? 9, minute: components.minute ?? 0)
                    }
                }
            }
        }
        .navigationTitle("리마인더")
    }
}
```

- [ ] **Step 3: DataLocationView** — 정적 안내:

```swift
import SwiftUI

struct DataLocationView: View {
    var body: some View {
        List {
            Section {
                Label("모든 데이터는 이 기기에만 저장됩니다", systemImage: "iphone")
                Label("얼굴 측정값·기록은 외부 서버로 전송되지 않습니다", systemImage: "lock.shield")
                Label("앱을 삭제하면 모든 데이터가 함께 삭제됩니다", systemImage: "trash")
            } footer: {
                Text("이 앱은 카메라로 측정한 얼굴 표정 데이터를 기기 내부 저장공간(SwiftData)에만 보관합니다.")
            }
        }
        .navigationTitle("데이터 저장 위치")
    }
}
```

- [ ] **Step 4: 전체 빌드 성공 확인** (`** BUILD SUCCEEDED **` — Phase 2 통합 완료 지점) / **Step 5: `swift test` 전체 통과 확인** / **Step 6: Commit** — `feat: add settings tab with reminders, baseline reset, data location`

---

### Task 15: 실기기 수동 검증 (Phase 2)

코드 변경 없음. Face ID 기기에서:

- [ ] 4개 탭 전환이 자연스럽고, 코칭 탭 이탈 시 카메라가 꺼지는지 (다른 탭에서 카메라 인디케이터 꺼짐 확인)
- [ ] 홈: 스트릭 도트·연속일 표시, "오늘 시작하기" → 코칭 탭 전환
- [ ] 코칭: 얼굴 가이드·세로 게이지 동작, 어두운 곳에서 조명 경고 배너 표시, "측정 종료" → 저장 확인 화면(어제 기록이 있으면 `어제 +N° → 오늘 +M°`) → 확인 → 홈 복귀·상태 갱신
- [ ] 기록: 주간 그래프에 오늘 막대 표시, 히트맵에 오늘 칸 칠해짐
- [ ] 설정: 리마인더 추가 시 권한 요청 → 지정 시각에 로컬 알림 도착, 토글 오프 시 미도착 / 기준선 재설정 → 재촬영 → 새 기준선으로 코칭 점수 변화 / 데이터 저장 위치·계정(준비 중) 표시
- [ ] 앱 재실행: 스키마 마이그레이션(ReminderSetting 추가) 후에도 기존 기준선·체크인 기록 유지

---

## Plan Self-Review

**와이어프레임 커버리지:** 홈(카드+오늘 시작하기+스트릭 도트) Task 11 / 코칭(경고 배너+얼굴 가이드+세로 게이지+측정 종료) Task 12 / 저장 확인(체크+어제→오늘+확인) Task 12 / 설정(리마인더 N개+기준선 재설정 N주 전+데이터 저장 위치+계정) Task 14 / 4탭 바 Task 11 — 전부 매핑됨. 기록 화면은 와이어프레임엔 없지만 사용자 결정으로 포함(Task 13).

**타입 일관성:** `displayScore(Int)`·`DailyScore`·`ReminderSetting.notificationID`·`FaceTrackingSession.onLightingUpdate`·`SettingsViewModel` 시그니처가 정의 태스크와 사용 태스크에서 동일한지 확인함. `CoachingViewModel.Phase`는 변경하지 않고 `yesterdayDelta()` 별도 메서드로 확장 — 기존 테스트 호환 유지.

**알려진 한계(의도적):** `deviceAngleOK` 고정 유지, Vision 폴백 없음(Phase 3), 리마인더 문구 고정, 히트맵은 요일 정렬 없이 1일부터 채움(단순 그리드), 접근성 검토는 Phase 3.

---

## Execution Handoff

Plan complete. 실행 방식 선택:

1. **Subagent-Driven (권장)** — Phase 1과 동일하게 태스크별 서브에이전트 + 2단계 리뷰
2. **Inline Execution** — 이 세션에서 직접 배치 실행
