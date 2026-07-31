# 정직한 피드백 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈/기록 화면의 점수 문구를 정직하게 바꾸고, 이미 존재하는 베이스라인 재설정 기능을 홈 화면에 능동적으로 노출하며, 케어 루틴에 근거 없는 효과 약속 대신 정직한 목적 설명을 추가한다.

**Architecture:** `CoachingKit`(순수 로직/모델 패키지)에 `Baseline` 확장과 `BaselineResetNudge`(스누즈 상태 저장소 포함, 기존 `ReminderNudge`와 동일 패턴)를 추가하고, 앱 타깃(`SmileDay/Views/**`)에서는 기존 `ReminderNudgeCard`를 아이콘 파라미터만 추가해 재사용해 새 카드 뷰를 만들지 않는다. `CareRoutine`에는 `purpose` 필드를 추가해 카탈로그 데이터로 채운다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, Swift Package Manager(`CoachingKit`), XCTest.

---

## 사전 확인 (실행 전 필수)

이 저장소는 다른 세션에서도 동시에 작업 중일 수 있다(예: 리마인더 넛지 관련 커밋들이 계획 수립 중에도 추가로 들어왔다). 각 태스크를 시작하기 전에 아래를 실행해서 이 계획이 여전히 유효한지 확인한다:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git status --short
git log --oneline -5
```

특히 Task 3에서 건드리는 `SmileDay/Views/Home/HomeView.swift`, `SmileDay/Views/MainTabView.swift`가 계획 작성 시점과 달라졌다면, 해당 파일을 다시 읽고 아래 코드 블록의 삽입 위치를 현재 내용에 맞게 조정한다.

---

### Task 1: `Baseline` 나이 계산 + 재설정 임계값 헬퍼

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/Baseline.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift:29-37` (refresh()), `SettingsViewModel.swift:8-10` (shouldRecommendReset)
- Create: `CoachingKit/Tests/CoachingKitTests/BaselineTests.swift`

**배경**: `SettingsViewModel`이 베이스라인 나이(주 단위)와 "재설정 권장"(4주 이상) 여부를 인라인 계산으로 갖고 있다. Task 3에서 홈 화면도 같은 "4주" 기준이 필요한데, 매직 넘버 `4`를 두 곳에 따로 두면 나중에 하나만 바뀌는 사고가 난다. `Baseline`에 순수 함수로 뽑아서 양쪽이 같은 상수를 참조하게 한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`CoachingKit/Tests/CoachingKitTests/BaselineTests.swift` 새로 생성:

```swift
import XCTest
@testable import CoachingKit

final class BaselineTests: XCTestCase {
    private func makeBaseline(capturedAt: Date) -> Baseline {
        Baseline(
            capturedAt: capturedAt,
            mouthCornerLeft: 0,
            mouthCornerRight: 0,
            browTension: 0,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )
    }

    func test_ageWeeks_computesWholeWeeksSinceCapture() {
        let now = Date()
        let sixWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -6, to: now)!
        let baseline = makeBaseline(capturedAt: sixWeeksAgo)

        XCTAssertEqual(baseline.ageWeeks(now: now), 6)
    }

    func test_ageWeeks_neverNegative() {
        let now = Date()
        let baseline = makeBaseline(capturedAt: now)

        XCTAssertEqual(baseline.ageWeeks(now: now), 0)
    }

    func test_isOverdueForReset_falseUnderThreshold() {
        let now = Date()
        let threeWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -3, to: now)!
        let baseline = makeBaseline(capturedAt: threeWeeksAgo)

        XCTAssertFalse(baseline.isOverdueForReset(now: now))
    }

    func test_isOverdueForReset_trueAtThresholdWeeksOrMore() {
        let now = Date()
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: now)!
        let baseline = makeBaseline(capturedAt: fourWeeksAgo)

        XCTAssertTrue(baseline.isOverdueForReset(now: now))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test --filter BaselineTests
```

Expected: FAIL — `value of type 'Baseline' has no member 'ageWeeks'` (컴파일 에러)

- [ ] **Step 3: `Baseline` 확장 추가**

`CoachingKit/Sources/CoachingKit/Baseline.swift` 맨 끝에 추가:

```swift
public extension Baseline {
    /// 이 이상 경과하면 재설정을 권장한다.
    static let recommendResetThresholdWeeks = 4

    /// 촬영 후 경과한 완전한 주 수.
    func ageWeeks(now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(calendar.dateComponents([.weekOfYear], from: capturedAt, to: now).weekOfYear ?? 0, 0)
    }

    /// 재설정을 권장할 시점이 됐는지.
    func isOverdueForReset(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        ageWeeks(now: now, calendar: calendar) >= Self.recommendResetThresholdWeeks
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
swift test --filter BaselineTests
```

Expected: PASS (4 tests)

- [ ] **Step 5: `SettingsViewModel`이 새 헬퍼를 쓰도록 정리**

`CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`에서 아래 두 곳을 바꾼다.

기존 (8-10번 줄):
```swift
    public var shouldRecommendReset: Bool {
        (baselineAgeWeeks ?? 0) >= 4
    }
```
변경 후:
```swift
    public var shouldRecommendReset: Bool {
        (baselineAgeWeeks ?? 0) >= Baseline.recommendResetThresholdWeeks
    }
```

기존 (29-37번 줄, `refresh()` 안):
```swift
    public func refresh() throws {
        reminders = try reminderRepository.fetchAll()
        if let baseline = try sessionRepository.fetchLatestBaseline() {
            let weeks = Calendar.current.dateComponents([.weekOfYear], from: baseline.capturedAt, to: now()).weekOfYear ?? 0
            baselineAgeWeeks = max(weeks, 0)
        } else {
            baselineAgeWeeks = nil
        }
    }
```
변경 후:
```swift
    public func refresh() throws {
        reminders = try reminderRepository.fetchAll()
        if let baseline = try sessionRepository.fetchLatestBaseline() {
            baselineAgeWeeks = baseline.ageWeeks(now: now())
        } else {
            baselineAgeWeeks = nil
        }
    }
```

- [ ] **Step 6: 기존 테스트가 그대로 통과하는지 확인 (동작 변경 없음)**

```bash
swift test --filter SettingsViewModelTests
```

Expected: PASS (모든 기존 테스트, 특히 `test_refresh_computesBaselineAgeWeeks`, `test_shouldRecommendReset_falseUnderFourWeeks`, `test_shouldRecommendReset_trueAtFourWeeksOrMore`)

- [ ] **Step 7: 커밋**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/Baseline.swift CoachingKit/Sources/CoachingKit/SettingsViewModel.swift CoachingKit/Tests/CoachingKitTests/BaselineTests.swift
git commit -m "refactor: extract Baseline.ageWeeks/isOverdueForReset helpers"
```

---

### Task 2: `BaselineResetNudge` (스누즈 상태 저장소)

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/BaselineResetNudge.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/BaselineResetNudgeTests.swift`

**배경**: 기존 `ReminderNudge`(같은 파일 위치, `CoachingKit/Sources/CoachingKit/ReminderNudge.swift`)와 동일한 프로토콜 기반 상태 저장소 패턴을 쓰되, 리마인더 넛지는 "한 번 닫으면 영구 dismiss"인 반면 베이스라인 재촬영은 4주마다 반복되는 권유라 "스누즈 후 재노출" 방식을 쓴다.

- [ ] **Step 1: 실패하는 테스트 작성**

`CoachingKit/Tests/CoachingKitTests/BaselineResetNudgeTests.swift` 새로 생성:

```swift
import XCTest
@testable import CoachingKit

final class BaselineResetNudgeTests: XCTestCase {
    func test_shouldShowHomeCard_trueWhenRecommendedAndNotSnoozed() {
        let nudge = BaselineResetNudge(store: InMemoryBaselineResetNudgeState())
        XCTAssertTrue(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: Date()))
    }

    func test_shouldShowHomeCard_falseWhenNotRecommended() {
        let nudge = BaselineResetNudge(store: InMemoryBaselineResetNudgeState())
        XCTAssertFalse(nudge.shouldShowHomeCard(shouldRecommendReset: false, now: Date()))
    }

    func test_snooze_hidesCardUntilSnoozeExpires() {
        let store = InMemoryBaselineResetNudgeState()
        let nudge = BaselineResetNudge(store: store)
        let now = Date()

        nudge.snooze(now: now, days: 7)

        XCTAssertFalse(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: now))
        let eightDaysLater = Calendar.current.date(byAdding: .day, value: 8, to: now)!
        XCTAssertTrue(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: eightDaysLater))
    }

    func test_clearSnooze_showsCardImmediately() {
        let store = InMemoryBaselineResetNudgeState()
        let nudge = BaselineResetNudge(store: store)
        let now = Date()
        nudge.snooze(now: now, days: 7)

        nudge.clearSnooze()

        XCTAssertTrue(nudge.shouldShowHomeCard(shouldRecommendReset: true, now: now))
    }

    func test_userDefaultsStore_persistsAcrossInstances() throws {
        let suiteName = "baseline-reset-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let now = Date()
        let first = UserDefaultsBaselineResetNudgeState(defaults: defaults)
        first.snoozedUntil = now

        let second = UserDefaultsBaselineResetNudgeState(defaults: defaults)
        XCTAssertEqual(second.snoozedUntil?.timeIntervalSince1970 ?? 0, now.timeIntervalSince1970, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test --filter BaselineResetNudgeTests
```

Expected: FAIL — `cannot find 'BaselineResetNudge' in scope`

- [ ] **Step 3: 구현**

`CoachingKit/Sources/CoachingKit/BaselineResetNudge.swift` 새로 생성:

```swift
import Foundation

/// 베이스라인 재촬영 유도(넛지)의 스누즈 상태 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol BaselineResetNudgeStateStoring: AnyObject {
    var snoozedUntil: Date? { get set }
}

public final class UserDefaultsBaselineResetNudgeState: BaselineResetNudgeStateStoring {
    private static let snoozedUntilKey = "baselineResetNudgeSnoozedUntil"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var snoozedUntil: Date? {
        get { defaults.object(forKey: Self.snoozedUntilKey) as? Date }
        set { defaults.set(newValue, forKey: Self.snoozedUntilKey) }
    }
}

public final class InMemoryBaselineResetNudgeState: BaselineResetNudgeStateStoring {
    public var snoozedUntil: Date?
    public init() {}
}

/// 기준선(베이스라인) 재촬영을 홈 화면에서 언제 권할지 판단한다.
/// 리마인더 넛지(ReminderNudge)와 달리 4주마다 반복되는 권유라 영구 dismiss 대신 스누즈를 쓴다.
public struct BaselineResetNudge {
    private let store: BaselineResetNudgeStateStoring

    public init(store: BaselineResetNudgeStateStoring) {
        self.store = store
    }

    /// shouldRecommendReset이 true이고 스누즈 기간이 지났으면 카드를 보여준다.
    public func shouldShowHomeCard(shouldRecommendReset: Bool, now: Date) -> Bool {
        guard shouldRecommendReset else { return false }
        guard let snoozedUntil = store.snoozedUntil else { return true }
        return now >= snoozedUntil
    }

    /// "나중에" 탭 시 호출. 기본 7일 스누즈.
    public func snooze(now: Date, days: Int = 7) {
        store.snoozedUntil = Calendar.current.date(byAdding: .day, value: days, to: now)
    }

    /// 재촬영을 실제로 완료했을 때 호출.
    public func clearSnooze() {
        store.snoozedUntil = nil
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
swift test --filter BaselineResetNudgeTests
```

Expected: PASS (5 tests)

- [ ] **Step 5: 커밋**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/BaselineResetNudge.swift CoachingKit/Tests/CoachingKitTests/BaselineResetNudgeTests.swift
git commit -m "feat: add BaselineResetNudge snooze state and decision logic"
```

---

### Task 3: 홈 화면에 베이스라인 재촬영 카드 노출

**Files:**
- Modify: `SmileDay/Views/Home/HomeView.swift`
- Modify: `SmileDay/Views/MainTabView.swift`

**주의**: 이 태스크를 시작하기 전에 "사전 확인" 섹션의 `git log`/`git status`를 다시 실행해서 `HomeView.swift`가 계획 작성 시점(Task 3 작성 시)과 같은지 확인한다. 다르면 아래 코드 블록의 삽입 위치(정확한 줄 번호가 아니라 "어떤 함수/구조체 안인지")를 기준으로 맞춰 넣는다.

- [ ] **Step 1: `ReminderNudgeCard`에 아이콘 파라미터 추가 (기존 호출부는 그대로 동작)**

`SmileDay/Views/Home/HomeView.swift`에서 `ReminderNudgeCard` 구조체 정의를 찾는다:

```swift
struct ReminderNudgeCard: View {
    let title: String
    let subtitle: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(SDColor.apricot, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
```

아래처럼 `icon`/`iconColor`를 기본값 있는 파라미터로 추가하고 하드코딩된 값을 참조로 바꾼다:

```swift
struct ReminderNudgeCard: View {
    let title: String
    let subtitle: String
    var icon: String = "bell.badge.fill"
    var iconColor: Color = SDColor.apricot
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
```

(`body`의 나머지 부분은 그대로 둔다.) 기본값 덕분에 기존 리마인더 카드 호출부는 수정할 필요가 없다.

- [ ] **Step 2: `HomeView`에 상태/파라미터 추가**

`HomeView` 구조체 상단 프로퍼티들을 찾는다:

```swift
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var showReminderNudgeCard = false
    @State private var reminderNudgeTitle = ""
    @State private var reminderNudgeSubtitle = ""
    @State private var isReminderSheetPresented = false

    let baseline: Baseline
    let onStartCoaching: () -> Void
```

아래로 바꾼다:

```swift
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var showReminderNudgeCard = false
    @State private var reminderNudgeTitle = ""
    @State private var reminderNudgeSubtitle = ""
    @State private var isReminderSheetPresented = false
    @State private var showBaselineResetNudgeCard = false
    @State private var isRecapturingBaseline = false

    let baseline: Baseline
    let onStartCoaching: () -> Void
    let onBaselineUpdated: (Baseline) -> Void
```

- [ ] **Step 3: 카드 노출 + 재촬영 화면 연결**

리마인더 넛지 카드를 렌더링하는 블록을 찾는다:

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

바로 아래에 추가한다:

```swift
                if showBaselineResetNudgeCard {
                    ReminderNudgeCard(
                        title: "기준 얼굴을 다시 찍을 때가 됐어요",
                        subtitle: "지난 촬영 후 4주가 지났어요. 다시 찍으면 오늘의 미소 크기가 더 정확해져요.",
                        icon: "arrow.clockwise",
                        iconColor: SDColor.coral,
                        onTap: { isRecapturingBaseline = true },
                        onDismiss: {
                            BaselineResetNudge(store: UserDefaultsBaselineResetNudgeState()).snooze(now: Date())
                            withAnimation { showBaselineResetNudgeCard = false }
                        }
                    )
                }
```

- [ ] **Step 4: `onAppear`에서 새 카드 상태도 갱신, 재촬영 fullScreenCover 추가**

`.onAppear`와 `.sheet` 다음을 찾는다:

```swift
        .onAppear {
            let vm = viewModel ?? HomeViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
            refreshReminderNudge()
        }
        .sheet(isPresented: $isReminderSheetPresented, onDismiss: { refreshReminderNudge() }) {
            ReminderSheet()
        }
    }
```

아래로 바꾼다 (새 줄과 `fullScreenCover` 추가):

```swift
        .onAppear {
            let vm = viewModel ?? HomeViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
            refreshReminderNudge()
            refreshBaselineResetNudge()
        }
        .sheet(isPresented: $isReminderSheetPresented, onDismiss: { refreshReminderNudge() }) {
            ReminderSheet()
        }
        .fullScreenCover(isPresented: $isRecapturingBaseline) {
            BaselineCaptureView(
                onBaselineSaved: { newBaseline in
                    onBaselineUpdated(newBaseline)
                    BaselineResetNudge(store: UserDefaultsBaselineResetNudgeState()).clearSnooze()
                    isRecapturingBaseline = false
                    showBaselineResetNudgeCard = false
                },
                onCancel: { isRecapturingBaseline = false }
            )
        }
    }
```

- [ ] **Step 5: 갱신 함수 추가**

`refreshReminderNudge()` 함수 바로 아래에 추가:

```swift
    private func refreshBaselineResetNudge() {
        showBaselineResetNudgeCard = BaselineResetNudge(store: UserDefaultsBaselineResetNudgeState())
            .shouldShowHomeCard(shouldRecommendReset: baseline.isOverdueForReset(), now: Date())
    }
```

- [ ] **Step 6: `MainTabView`에서 콜백 연결**

`SmileDay/Views/MainTabView.swift`에서 아래 줄을 찾는다:

```swift
            HomeView(baseline: baseline, onStartCoaching: { selection = .coaching })
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.home)
```

아래로 바꾼다:

```swift
            HomeView(
                baseline: baseline,
                onStartCoaching: { selection = .coaching },
                onBaselineUpdated: onBaselineUpdated
            )
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.home)
```

- [ ] **Step 7: 앱 타깃 빌드 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 커밋**

```bash
git add SmileDay/Views/Home/HomeView.swift SmileDay/Views/MainTabView.swift
git commit -m "feat: surface baseline recapture nudge on home screen"
```

---

### Task 4: "오늘의 미소 크기" 문구 변경

**Files:**
- Modify: `SmileDay/Views/Home/HomeView.swift`
- Modify: `SmileDay/Views/History/HistoryView.swift`

계산 로직은 건드리지 않고 사용자에게 보이는 라벨 문자열만 바꾼다.

- [ ] **Step 1: 홈 화면 라벨 변경**

`SmileDay/Views/Home/HomeView.swift`의 `heroCard`에서:

```swift
    private var heroCard: some View {
        VStack(spacing: 0) {
            if viewModel?.hasCheckedInToday == true {
                ArcGaugeView(score: viewModel?.todayScore, label: "오늘의 입꼬리 각도")
                Label("오늘 체크인을 완료했어요", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.mint)
                    .padding(.top, 12)
            } else {
                ArcGaugeView(score: viewModel?.yesterdayScore, label: "어제의 입꼬리 각도")
```

`"오늘의 입꼬리 각도"` → `"오늘의 미소 크기"`, `"어제의 입꼬리 각도"` → `"어제의 미소 크기"`로 바꾼다.

- [ ] **Step 2: 기록 화면 차트 데이터 라벨 변경**

`SmileDay/Views/History/HistoryView.swift`에서:

```swift
                Chart(viewModel.weeklyScores) { score in
                    BarMark(
                        x: .value("날짜", score.date, unit: .day),
                        y: .value("점수", score.displayScore),
                        width: .fixed(12)
                    )
```

`.value("점수", ...)` → `.value("미소 크기", ...)`로 바꾼다.

- [ ] **Step 3: 빌드 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add SmileDay/Views/Home/HomeView.swift SmileDay/Views/History/HistoryView.swift
git commit -m "copy: rename smile score label from mouth-corner angle to smile size"
```

---

### Task 5: 케어 루틴 정직한 목적 설명

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CareRoutine.swift`
- Modify: `SmileDay/Views/Care/CarePlayerView.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift`

- [ ] **Step 1: 실패하는 테스트 추가**

`CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift`의 기존 테스트 아래에 추가:

```swift
    func test_catalog_everyRoutineHasNonEmptyPurpose() {
        for routine in CareRoutine.catalog {
            XCTAssertFalse(
                routine.purpose.isEmpty,
                "\(routine.id) is missing a purpose description"
            )
        }
    }
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test --filter CareRoutineTests
```

Expected: FAIL — `value of type 'CareRoutine' has no member 'purpose'`

- [ ] **Step 3: `CareRoutine`에 `purpose` 필드 추가**

`CoachingKit/Sources/CoachingKit/CareRoutine.swift`에서 구조체 정의를 찾는다:

```swift
public struct CareRoutine: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: CareCategory
    public let difficulty: CareDifficulty
    public let steps: [CareStep]
    /// 번들 내 영상 파일 이름(확장자 제외). 파일이 없으면 플레이어가 아이콘 히어로를 보여준다.
    public let videoFileName: String

    public init(
        id: String,
        title: String,
        category: CareCategory,
        difficulty: CareDifficulty,
        steps: [CareStep],
        videoFileName: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.difficulty = difficulty
        self.steps = steps
        self.videoFileName = videoFileName
    }
```

아래로 바꾼다 (근거·효과 약속 없이 무엇을 하는지만 서술하는 필드):

```swift
public struct CareRoutine: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: CareCategory
    public let difficulty: CareDifficulty
    public let steps: [CareStep]
    /// 이 루틴이 실제로 무엇을 하는지에 대한 담백한 설명. 효과를 약속하지 않는다.
    public let purpose: String
    /// 번들 내 영상 파일 이름(확장자 제외). 파일이 없으면 플레이어가 아이콘 히어로를 보여준다.
    public let videoFileName: String

    public init(
        id: String,
        title: String,
        category: CareCategory,
        difficulty: CareDifficulty,
        steps: [CareStep],
        purpose: String,
        videoFileName: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.difficulty = difficulty
        self.steps = steps
        self.purpose = purpose
        self.videoFileName = videoFileName
    }
```

- [ ] **Step 4: 카탈로그 5개 루틴에 `purpose` 채우기**

같은 파일의 `catalog` 안, 각 `CareRoutine(...)` 호출에 `purpose:` 인자를 `videoFileName:` 바로 앞에 추가한다:

| id | purpose 인자로 넣을 값 |
|---|---|
| `lift-smile` | `"입꼬리 주변 근육을 움직이고 마사지하는 스트레칭이에요."` |
| `lift-cheek` | `"광대 주변을 눌러 풀고 쓸어 올리는 마사지예요."` |
| `relax-brow` | `"미간과 눈가 주변 근육의 긴장을 풀어주는 간단한 스트레칭이에요."` |
| `depuff-morning` | `"목과 얼굴의 림프 흐름을 도와주는 마사지예요."` |
| `morning-1min` | `"아침에 표정 근육을 가볍게 깨우는 1분 스트레칭이에요."` |

예시 (`lift-smile`):
```swift
        CareRoutine(
            id: "lift-smile",
            title: "입꼬리 리프팅 루틴",
            category: .lift,
            difficulty: .beginner,
            steps: [
                CareStep(title: "손바닥 비벼 데우기", seconds: 30, systemImage: "hands.and.sparkles.fill"),
                CareStep(title: "입꼬리 올려 10초 유지", seconds: 10, reps: 3, systemImage: "mouth.fill"),
                CareStep(title: "광대 쓸어올리기", seconds: 30, systemImage: "hand.draw.fill"),
                CareStep(title: "입꼬리 옆 지그시 원 그리기", seconds: 60, systemImage: "arrow.triangle.2.circlepath"),
            ],
            purpose: "입꼬리 주변 근육을 움직이고 마사지하는 스트레칭이에요.",
            videoFileName: "care_lift_smile"
        ),
```

나머지 4개도 같은 방식으로 `purpose:` 인자를 추가한다 (steps 배열은 변경하지 않는다).

- [ ] **Step 5: 테스트 통과 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test --filter CareRoutineTests
```

Expected: PASS (2 tests — 기존 `systemImage` 테스트 + 새 `purpose` 테스트)

- [ ] **Step 6: `CarePlayerView`에 목적 설명 표시**

`SmileDay/Views/Care/CarePlayerView.swift`에서 상단 타이틀 영역을 찾는다:

```swift
            HStack(spacing: 10) {
                SDCloseButton { onClose(false) }
                Text(routine.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Spacer()
            }

            videoArea
```

아래로 바꾼다 (제목 아래, 영상/히어로 영역 위에 목적 설명 한 줄 추가):

```swift
            HStack(spacing: 10) {
                SDCloseButton { onClose(false) }
                Text(routine.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Spacer()
            }

            Text(routine.purpose)
                .font(.caption)
                .foregroundStyle(SDColor.muted)

            videoArea
```

- [ ] **Step 7: 앱 타깃 빌드 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 전체 CoachingKit 테스트 스위트 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test 2>&1 | tail -20
```

Expected: 모든 테스트 PASS, 0 failures

- [ ] **Step 9: 커밋**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/CareRoutine.swift CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift SmileDay/Views/Care/CarePlayerView.swift
git commit -m "feat: add honest purpose descriptions to care routines"
```

---

## 완료 후 전체 확인

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test 2>&1 | tail -10
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' -configuration Debug build 2>&1 | tail -10
```

두 명령 모두 성공해야 계획이 완료된 것이다.
