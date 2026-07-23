# 리마인더 설정 유도(넛지) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 첫 체크인 저장 직후 "내일도 이 시간에 알려드릴까요?" 제안과 홈 보조 카드를 통해 사용자가 리마인더를 설정하도록 유도한다.

**Architecture:** CoachingKit에 넛지 상태 저장소(`ReminderNudgeStateStoring` + UserDefaults/인메모리 구현)와 노출 판단 로직(`ReminderNudge`)을 추가한다. 앱 타겟에서는 `SaveConfirmView`에 제안 카드를, `HomeView`에 유도 카드를 붙인다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, XCTest.

**설계 문서:** `SmileDay/docs/superpowers/specs/2026-07-23-reminder-nudge-design.md`

---

### Task 1: ReminderNudge 로직 + 상태 저장소 (CoachingKit)

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/ReminderNudge.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/ReminderNudgeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKit/Tests/CoachingKitTests/ReminderNudgeTests.swift
import XCTest
@testable import CoachingKit

final class ReminderNudgeTests: XCTestCase {
    func test_shouldOfferAfterCheckIn_trueOnlyWhenNoRemindersAndNotDeclined() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldOfferAfterCheckIn(reminderCount: 0))
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(reminderCount: 1))
    }

    func test_declineCheckInPrompt_suppressesFutureOffers() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.declineCheckInPrompt()
        XCTAssertFalse(nudge.shouldOfferAfterCheckIn(reminderCount: 0))
    }

    func test_shouldShowHomeCard_requiresCheckInHistoryAndNoReminders() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        XCTAssertTrue(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: true))
        XCTAssertFalse(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: false))
        XCTAssertFalse(nudge.shouldShowHomeCard(reminderCount: 2, hasAnyCheckIn: true))
    }

    func test_dismissHomeCard_suppressesCard() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.dismissHomeCard()
        XCTAssertFalse(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: true))
    }

    func test_declineAndDismiss_areIndependentFlags() {
        let nudge = ReminderNudge(store: InMemoryReminderNudgeState())
        nudge.declineCheckInPrompt()
        XCTAssertTrue(nudge.shouldShowHomeCard(reminderCount: 0, hasAnyCheckIn: true),
                      "체크인 제안 거절이 홈 카드까지 숨기면 안 된다")
    }

    func test_userDefaultsStore_persistsAcrossInstances() throws {
        let suiteName = "reminder-nudge-test-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = UserDefaultsReminderNudgeState(defaults: defaults)
        first.hasDeclinedCheckInPrompt = true
        first.hasDismissedHomeCard = true

        let second = UserDefaultsReminderNudgeState(defaults: defaults)
        XCTAssertTrue(second.hasDeclinedCheckInPrompt)
        XCTAssertTrue(second.hasDismissedHomeCard)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter ReminderNudgeTests`
Expected: FAIL to build — 타입들이 아직 없음.

- [ ] **Step 3: Write minimal implementation**

```swift
// CoachingKit/Sources/CoachingKit/ReminderNudge.swift
import Foundation

/// 리마인더 설정 유도(넛지)의 노출 상태 저장소. 앱에서는 UserDefaults, 테스트에서는 메모리 구현을 쓴다.
public protocol ReminderNudgeStateStoring: AnyObject {
    var hasDeclinedCheckInPrompt: Bool { get set }
    var hasDismissedHomeCard: Bool { get set }
}

public final class UserDefaultsReminderNudgeState: ReminderNudgeStateStoring {
    private static let declinedKey = "reminderNudgeDeclinedCheckInPrompt"
    private static let dismissedKey = "reminderNudgeDismissedHomeCard"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasDeclinedCheckInPrompt: Bool {
        get { defaults.bool(forKey: Self.declinedKey) }
        set { defaults.set(newValue, forKey: Self.declinedKey) }
    }

    public var hasDismissedHomeCard: Bool {
        get { defaults.bool(forKey: Self.dismissedKey) }
        set { defaults.set(newValue, forKey: Self.dismissedKey) }
    }
}

public final class InMemoryReminderNudgeState: ReminderNudgeStateStoring {
    public var hasDeclinedCheckInPrompt: Bool = false
    public var hasDismissedHomeCard: Bool = false
    public init() {}
}

/// 리마인더 유도를 언제 보여줄지 판단한다.
public struct ReminderNudge {
    private let store: ReminderNudgeStateStoring

    public init(store: ReminderNudgeStateStoring) {
        self.store = store
    }

    /// 체크인 저장 화면에서 리마인더 제안을 보여줄지.
    public func shouldOfferAfterCheckIn(reminderCount: Int) -> Bool {
        reminderCount == 0 && !store.hasDeclinedCheckInPrompt
    }

    /// 홈에 리마인더 유도 카드를 보여줄지.
    public func shouldShowHomeCard(reminderCount: Int, hasAnyCheckIn: Bool) -> Bool {
        reminderCount == 0 && hasAnyCheckIn && !store.hasDismissedHomeCard
    }

    public func declineCheckInPrompt() {
        store.hasDeclinedCheckInPrompt = true
    }

    public func dismissHomeCard() {
        store.hasDismissedHomeCard = true
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CoachingKit && swift test --filter ReminderNudgeTests`
Expected: PASS — 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderNudge.swift CoachingKit/Tests/CoachingKitTests/ReminderNudgeTests.swift
git commit -m "feat: add ReminderNudge decision logic and state store"
```

---

### Task 2: SaveConfirmView 제안 카드 + CoachingTabView 연결

**Files:**
- Modify: `SmileDay/Views/Coaching/SaveConfirmView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingTabView.swift`

앱 타겟이라 유닛 테스트 없음 — Task 4의 xcodebuild로 검증한다.

- [ ] **Step 1: SaveConfirmView에 제안 섹션 추가**

`SaveConfirmView`에 옵셔널 제안 상태를 추가한다. `reminderOffer`가 nil이면 기존과 완전히 동일하게 렌더링된다.

```swift
// SmileDay/Views/Coaching/SaveConfirmView.swift 의 SaveConfirmView 교체
struct SaveConfirmView: View {
    /// 리마인더 제안 정보. nil이면 제안 섹션을 그리지 않는다.
    struct ReminderOffer {
        let hour: Int
        let minute: Int
        let onAccept: () async -> Void
        let onDecline: () -> Void
    }

    let todayScore: Double
    let yesterdayScore: Double?
    var reminderOffer: ReminderOffer? = nil
    let onConfirm: () -> Void

    private enum OfferState { case showing, accepted, hidden }
    @State private var offerState: OfferState = .showing

    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            ConfettiDots()

            VStack(spacing: 18) {
                Spacer()

                SunFaceView()

                Text("오늘의 기록이 저장되었어요")
                    .font(.headline.bold())
                    .foregroundStyle(SDColor.ink)

                HStack(spacing: 10) {
                    if let yesterdayScore {
                        Text("어제 \(SDFormat.signedDegrees(yesterdayScore))")
                            .foregroundStyle(SDColor.muted)
                        Image(systemName: "arrow.right")
                            .font(.footnote)
                            .foregroundStyle(SDColor.muted)
                    }
                    Text("오늘 \(SDFormat.signedDegrees(todayScore))")
                        .font(.title3.bold())
                        .foregroundStyle(SDColor.coralDeep)
                }
                .font(.body)
                .monospacedDigit()

                if let yesterdayScore, todayScore > yesterdayScore {
                    Text("어제보다 \(SDFormat.signedDegrees(todayScore - yesterdayScore)) 올라갔어요")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SDColor.mint, in: Capsule())
                }

                if let reminderOffer, offerState != .hidden {
                    ReminderOfferCard(offer: reminderOffer, state: $offerState)
                }

                Button("확인") {
                    onConfirm()
                }
                .buttonStyle(SDPrimaryButtonStyle())
                .frame(width: 240)
                .padding(.top, 8)

                Spacer()
            }
            .padding()
        }
    }
}

/// 체크인 직후 리마인더 설정 제안 카드.
private struct ReminderOfferCard: View {
    let offer: SaveConfirmView.ReminderOffer
    @Binding var state: SaveConfirmView.OfferState

    var body: some View {
        Group {
            if state == .accepted {
                Label("리마인더가 설정되었어요", systemImage: "bell.badge.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.mint)
            } else {
                VStack(spacing: 10) {
                    Text("내일도 이 시간(\(String(format: "%02d:%02d", offer.hour, offer.minute)))에 알려드릴까요?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.ink)

                    HStack(spacing: 10) {
                        Button("나중에") {
                            offer.onDecline()
                            withAnimation { state = .hidden }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SDColor.muted)

                        Button("알림 받기") {
                            Task {
                                await offer.onAccept()
                                withAnimation { state = .accepted }
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(SDColor.coral, in: Capsule())
                    }
                }
                .padding(14)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
```

`OfferState`는 `ReminderOfferCard`에서 바인딩으로 쓰므로 `private enum`을 `fileprivate` 접근이 되도록 유지한다 (같은 파일 안이라 `private` 중첩 타입이어도 fileprivate 취급되어 접근 가능하지만, 컴파일 에러가 나면 `enum OfferState`로 접근 수준을 올린다).

- [ ] **Step 2: CoachingTabView에서 제안 조건과 콜백 연결**

```swift
// SmileDay/Views/Coaching/CoachingTabView.swift 전체 교체
import SwiftUI
import SwiftData
import CoachingKit

struct CoachingTabView: View {
    @Environment(\.modelContext) private var modelContext
    let baseline: Baseline
    let onFinished: () -> Void
    let onExit: () -> Void
    @State private var result: SessionResult?

    struct SessionResult {
        let todayScore: Double
        let yesterdayScore: Double?
        let completedHour: Int
        let completedMinute: Int
        let offerReminder: Bool
    }

    var body: some View {
        if let result {
            SaveConfirmView(
                todayScore: result.todayScore,
                yesterdayScore: result.yesterdayScore,
                reminderOffer: result.offerReminder ? SaveConfirmView.ReminderOffer(
                    hour: result.completedHour,
                    minute: result.completedMinute,
                    onAccept: {
                        let viewModel = SettingsViewModel(
                            reminderRepository: ReminderRepository(modelContext: modelContext),
                            sessionRepository: SessionRepository(modelContext: modelContext),
                            scheduler: UserNotificationReminderScheduler()
                        )
                        try? await viewModel.addReminder(hour: result.completedHour, minute: result.completedMinute)
                    },
                    onDecline: {
                        ReminderNudge(store: UserDefaultsReminderNudgeState()).declineCheckInPrompt()
                    }
                ) : nil
            ) {
                self.result = nil
                onFinished()
            }
        } else {
            CoachingSessionView(
                baseline: baseline,
                onCompleted: { today, yesterday in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: .now)
                    let reminderCount = (try? ReminderRepository(modelContext: modelContext).fetchAll().count) ?? 0
                    let nudge = ReminderNudge(store: UserDefaultsReminderNudgeState())
                    result = SessionResult(
                        todayScore: today,
                        yesterdayScore: yesterday,
                        completedHour: components.hour ?? 9,
                        completedMinute: components.minute ?? 0,
                        offerReminder: nudge.shouldOfferAfterCheckIn(reminderCount: reminderCount)
                    )
                },
                onExit: onExit
            )
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Views/Coaching/SaveConfirmView.swift SmileDay/Views/Coaching/CoachingTabView.swift
git commit -m "feat: offer reminder setup right after check-in save"
```

---

### Task 3: 홈 유도 카드 + 리마인더 설정 시트

**Files:**
- Modify: `SmileDay/Views/Home/HomeView.swift`

- [ ] **Step 1: HomeView에 유도 카드와 시트 추가**

`HomeView` struct에 상태와 카드를 추가한다. 기존 body의 `StatCard` HStack 아래에 카드를 넣는다.

```swift
// HomeView에 추가할 @State (viewModel 선언 아래)
@State private var showReminderNudgeCard = false
@State private var isReminderSheetPresented = false

// body의 VStack 안, StatCard HStack 아래에 추가
if showReminderNudgeCard {
    ReminderNudgeCard(
        onTap: { isReminderSheetPresented = true },
        onDismiss: {
            ReminderNudge(store: UserDefaultsReminderNudgeState()).dismissHomeCard()
            withAnimation { showReminderNudgeCard = false }
        }
    )
}

// ScrollView 모디파이어 체인의 .onAppear 안 (vm refresh 다음)에 추가
refreshReminderNudge()

// .onAppear 아래에 시트 추가
.sheet(isPresented: $isReminderSheetPresented, onDismiss: { refreshReminderNudge() }) {
    NavigationStack {
        ReminderListView(viewModel: SettingsViewModel(
            reminderRepository: ReminderRepository(modelContext: modelContext),
            sessionRepository: SessionRepository(modelContext: modelContext),
            scheduler: UserNotificationReminderScheduler()
        ))
    }
    .tint(SDColor.coral)
}

// HomeView에 추가할 메서드
private func refreshReminderNudge() {
    let reminderCount = (try? ReminderRepository(modelContext: modelContext).fetchAll().count) ?? 0
    let hasAnyCheckIn = viewModel?.recentWeek.contains(where: \.checkedIn) ?? false
    let nudge = ReminderNudge(store: UserDefaultsReminderNudgeState())
    showReminderNudgeCard = nudge.shouldShowHomeCard(reminderCount: reminderCount, hasAnyCheckIn: hasAnyCheckIn)
}
```

주의: `ReminderListView`의 `SettingsViewModel`은 `refresh()`가 호출되어야 목록이 뜬다. 시트 안에서 `.onAppear { try? viewModel.refresh() }`가 필요하다 — `ReminderListView` 자체는 수정하지 않고, 시트 쪽에서 뷰모델을 만들고 `refresh()`를 호출한 뒤 넘기거나 `.task`로 호출한다. 구현 시 아래처럼 wrapper를 쓴다:

```swift
// HomeView 파일 하단에 추가
/// 홈에서 시트로 띄우는 리마인더 설정 화면. 뷰모델 생성과 refresh를 책임진다.
private struct ReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel {
                ReminderListView(viewModel: viewModel)
            }
        }
        .tint(SDColor.coral)
        .onAppear {
            let vm = viewModel ?? SettingsViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                sessionRepository: SessionRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler()
            )
            viewModel = vm
            try? vm.refresh()
        }
    }
}

// 시트 호출부는 위 wrapper로 단순화
.sheet(isPresented: $isReminderSheetPresented, onDismiss: { refreshReminderNudge() }) {
    ReminderSheet()
}
```

`ReminderNudgeCard`는 파일 하단에 추가:

```swift
/// 리마인더 미설정 사용자를 설정으로 유도하는 카드.
struct ReminderNudgeCard: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(SDColor.apricot, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("매일 잊지 않게 알려드릴까요?")
                    .font(.subheadline.bold())
                    .foregroundStyle(SDColor.ink)
                Text("원하는 시간에 표정 질문을 보내드려요")
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(SDColor.muted)
                    .padding(6)
            }
        }
        .sdCard()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
```

X 버튼이 카드 탭 제스처에 먹히지 않도록 `Button`이 `onTapGesture`보다 우선하는 SwiftUI 기본 동작을 이용한다.

- [ ] **Step 2: Commit**

```bash
git add SmileDay/Views/Home/HomeView.swift
git commit -m "feat: add home nudge card linking to reminder setup"
```

---

### Task 4: 전체 빌드 및 테스트 검증

**Files:** 없음 (검증 전용)

- [ ] **Step 1: CoachingKit 테스트 전체 실행**

Run: `cd CoachingKit && swift test`
Expected: PASS — 기존 87개 + ReminderNudgeTests 6개 = 93개 전부 통과.

- [ ] **Step 2: 앱 타겟 빌드**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋 로그 확인**

Run: `git log --oneline -5`
Expected: Task 1~3 커밋이 순서대로 쌓여 있음.
