# Pro 1회성 구매(잠금 해제) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **⛔ BLOCKED (2026-07-27):** Do not start this plan yet. See "선행 조건" below.

**Goal:** Add a StoreKit2 non-consumable "Pro" purchase at an initial validation price of ₩5,900, gate features that extend the smile-habit loop (multiple reminders, full moment archive, weekly recap), and define a measurable profitability gate before any paid acquisition.

**Architecture:** A pure, testable `ProEntitlement`/`ProEntitlementStoring` pair lives in CoachingKit and is injected into `SettingsViewModel` (and later `HistoryViewModel`) as a constructor dependency (default value keeps existing tests/call-sites compiling). A `StoreKitProPurchaser` in the SmileDay app target (StoreKit2 cannot be imported from the cross-platform CoachingKit package) owns the actual purchase/restore calls and writes results into the shared `ProEntitlement` instance. SwiftUI views read `entitlement.isPro` to decide whether to render a lock state that opens a new `ProPaywallView`.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, StoreKit2 (`Product`, `Transaction`, `AppStore`), XCTest.

---

## 선행 조건 (2026-07-27 추가)

**`2026-07-27-smile-habit-reframe.md`의 제품 전환 구현과 사용자 검증이 끝나기 전에는 이 계획의 StoreKit 작업을 시작하지 않는다.**

이전 유료 경계(케어 루틴 전체, 시간대별 점수 상세)는 얼굴 평가 중심 가치에 기대고 있었고, 그 가치는 제품 정의에서 제거되었다. `CareRoutine`/`CareViewModel` 타입 자체가 사라졌으므로 아래 Task 2는 더 이상 적용되지 않는다.

착수 조건:

- [ ] 미소 습관 전환 구현 완료
- [ ] `2026-07-27-smile-habit-reframe.md` Task 14의 제품 수용 기준 통과
- [ ] 아래 Pro 후보 중 **최소 3개가 실제로 완성됨** — 구현되지 않은 혜택은 페이월에 표시하지 않는다

### 무료 핵심 (절대 잠그지 않는다)

- 매일 미소 시간 (횟수 제한 없음)
- 기본 시간대 질문
- 기분과 한 줄 좋은 순간 기록
- 최근 7일 활동과 이번 달 캘린더
- 기본 쉬어가기 콘텐츠 (`SmilePractice.catalog` 전체)
- 리마인더 1개

### Pro 후보

| 혜택 | 상태 |
|---|---|
| 아침·낮·저녁 다중 리마인더 | 구현 가능 (Task 3) |
| 전체 좋은 순간 보관함 | 미구현 — 현재 `HistoryViewModel.recentMomentLimit`로 제한 |
| 주간 돌아보기 | 미구현 |
| 추가 질문·쉬어가기 콘텐츠 팩 | 미구현 |
| 사용자 지정 질문 | 미구현 |
| 기록 내보내기 | 미구현 |

---

## Spec reference

Full design: `SmileDay/docs/superpowers/specs/2026-07-24-pro-unlock-design.md`. Re-read section 2 (게이팅 규칙) and section 7 (가격과 수익성 검증) before starting. The implementation is not considered launch-ready until purchase restoration and the no-paid-advertising profitability gate are verified.

## Business constraints

- Pro is a one-time non-consumable purchase, not a subscription.
- Initial validation price: `₩5,900`; the App Store Connect product is the source of truth.
- Never hardcode a user-facing price. Render `Product.displayPrice`.
- State “한 번 구매로 계속 이용” on the paywall.
- Do not claim a discount unless a real price history and end condition exist.
- Do not start paid acquisition from an assumed conversion rate. Use observed App Store Connect downloads, purchases, proceeds, and retention.
- If current benefits do not convert, stop and create a separate paired spec/plan for stronger Pro value instead of hiding more of the free core loop.
- Describe Pro as "미소 습관을 오래 이어가고 좋은 순간을 다시 보기" — never as face analysis, scores, or appearance improvement.
- Do not sell until at least three Pro candidates are actually shipped. Never list an unimplemented benefit on the paywall.

## File Structure

- Create: `CoachingKit/Sources/CoachingKit/ProEntitlement.swift` — protocol + concrete `@Observable` entitlement holder (pure, cross-platform)
- Create: `CoachingKit/Tests/CoachingKitTests/ProEntitlementTests.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift` — add `entitlement` dependency + `canAddReminder` + early-return in `addReminder`
- Modify: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift` — add gating tests
- Create: `SmileDay/Configuration.storekit` — local StoreKit product config for simulator testing
- Create: `SmileDay/Services/StoreKitProPurchaser.swift` — StoreKit2 purchase/restore/refresh service (app target only, no unit tests — same convention as `ARKitFaceTrackingSession`)
- Create: `SmileDay/Views/Store/ProPaywallView.swift` — sheet shown when a locked feature is tapped
- Modify: `SmileDay/Views/RootView.swift` — own `ProEntitlement` + `StoreKitProPurchaser`, inject via `.environment`, refresh on launch
- Modify: `SmileDay/Views/History/HistoryView.swift` — "Pro에서 전체 보기" row past the free moment-archive limit (no blur over already-visible entries)
- Modify: `SmileDay/Views/Settings/SettingsView.swift` — pass entitlement into `SettingsViewModel`, add Pro row
- **Not modified:** `SmileDay/Views/Care/CareView.swift` — 쉬어가기 기본 콘텐츠는 전부 무료다
- Modify: `SmileDay/Views/Settings/ReminderListView.swift` — lock "추가" affordance when `canAddReminder == false`

---

### Task 1: ProEntitlement core type

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/ProEntitlement.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/ProEntitlementTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CoachingKit

final class ProEntitlementTests: XCTestCase {
    func test_init_defaultsToFalse() {
        let entitlement = ProEntitlement()
        XCTAssertFalse(entitlement.isPro)
    }

    func test_init_acceptsExplicitValue() {
        let entitlement = ProEntitlement(isPro: true)
        XCTAssertTrue(entitlement.isPro)
    }

    func test_setPro_updatesValue() {
        let entitlement = ProEntitlement()
        entitlement.setPro(true)
        XCTAssertTrue(entitlement.isPro)
        entitlement.setPro(false)
        XCTAssertFalse(entitlement.isPro)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter ProEntitlementTests`
Expected: FAIL to compile — "cannot find type 'ProEntitlement' in scope"

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Observation

public protocol ProEntitlementStoring: AnyObject {
    var isPro: Bool { get }
}

@Observable
public final class ProEntitlement: ProEntitlementStoring {
    public private(set) var isPro: Bool

    public init(isPro: Bool = false) {
        self.isPro = isPro
    }

    public func setPro(_ value: Bool) {
        isPro = value
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CoachingKit && swift test --filter ProEntitlementTests`
Expected: PASS, 3 tests

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ProEntitlement.swift CoachingKit/Tests/CoachingKitTests/ProEntitlementTests.swift
git commit -m "feat: add ProEntitlement for Pro purchase state"
```

---

### Task 2: ~~CareViewModel routine locking~~ → 전체 좋은 순간 보관함 잠금

> **삭제됨 (2026-07-27).** `CareRoutine`/`CareViewModel`은 미소 습관 전환에서 제거되었고,
> 쉬어가기 기본 콘텐츠는 전부 무료다. 얼굴 부위 기반 루틴을 유료로 나누는 규칙은 더 이상 존재하지 않는다.

대체 후보 — **구현 전에는 페이월에 표시하지 않는다:**

`HistoryViewModel`에 `entitlement: ProEntitlementStoring`을 주입하고, 무료 사용자에게는
`recentMoments`를 `recentMomentLimit`까지만 노출한다. Pro는 전체 기간을 본다.

- 저장은 무료·Pro 동일하다. **기록 자체를 막지 않는다** — 다시 보는 범위만 다르다.
- `HistoryView`는 한도를 넘는 자리에 "Pro에서 전체 보기" 행을 둔다. 이미 보이는 항목을 블러 처리하지 않는다.
- 테스트: 무료 한도 절단, Pro 전체 노출, 한도 미만일 때 잠금 행 없음.

이 Task는 선행 조건(미소 습관 전환 완료 + 수용 기준 통과)을 만족한 뒤에 구체화한다.

---

### Task 3: SettingsViewModel reminder count gating

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`, inside `final class SettingsViewModelTests`:

```swift
    func test_canAddReminder_freeUser_falseAfterFirstReminder() async throws {
        let (viewModel, _, _) = try makeViewModel()
        XCTAssertTrue(viewModel.canAddReminder)

        try await viewModel.addReminder(hour: 9, minute: 0)

        XCTAssertFalse(viewModel.canAddReminder)
    }

    func test_addReminder_freeUser_ignoresSecondReminder() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let scheduledAfterFirst = scheduler.scheduled.count

        try await viewModel.addReminder(hour: 20, minute: 0)

        XCTAssertEqual(viewModel.reminders.count, 1)
        XCTAssertEqual(scheduler.scheduled.count, scheduledAfterFirst)
    }

    func test_addReminder_proUser_allowsMultiple() async throws {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let scheduler = MockScheduler()
        let viewModel = SettingsViewModel(
            reminderRepository: ReminderRepository(modelContext: context),
            sessionRepository: SessionRepository(modelContext: context),
            scheduler: scheduler,
            entitlement: ProEntitlement(isPro: true)
        )

        try await viewModel.addReminder(hour: 9, minute: 0)
        try await viewModel.addReminder(hour: 20, minute: 0)

        XCTAssertEqual(viewModel.reminders.count, 2)
        XCTAssertTrue(viewModel.canAddReminder)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd CoachingKit && swift test --filter SettingsViewModelTests`
Expected: FAIL to compile — `SettingsViewModel` has no member `canAddReminder`, no parameter `entitlement`

- [ ] **Step 3: Write minimal implementation**

In `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`, update the constructor and `addReminder`:

```swift
    private let entitlement: ProEntitlementStoring

    public init(
        reminderRepository: ReminderRepository,
        sessionRepository: SessionRepository,
        scheduler: ReminderScheduling,
        entitlement: ProEntitlementStoring = ProEntitlement(),
        now: @escaping () -> Date = Date.init
    ) {
        self.reminderRepository = reminderRepository
        self.sessionRepository = sessionRepository
        self.scheduler = scheduler
        self.entitlement = entitlement
        self.now = now
    }

    /// 무료: 리마인더 1개까지. Pro: 무제한.
    public var canAddReminder: Bool {
        entitlement.isPro || reminders.count < 1
    }
```

Update `addReminder` to early-return when the free limit is reached:

```swift
    public func addReminder(hour: Int, minute: Int) async throws {
        guard canAddReminder else { return }
        _ = await scheduler.requestAuthorization()
        let reminder = try reminderRepository.add(hour: hour, minute: minute)
        await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: hour, minute: minute, days: reminderRollingWindowDays)
        try refresh()
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd CoachingKit && swift test --filter SettingsViewModelTests`
Expected: PASS, all `SettingsViewModelTests` (existing + 3 new)

- [ ] **Step 5: Run the full CoachingKit suite**

Run: `cd CoachingKit && swift test 2>&1 | tail -10`
Expected: `Test Suite 'All tests' passed`

- [ ] **Step 6: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/SettingsViewModel.swift CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift
git commit -m "feat: gate reminder count behind Pro entitlement"
```

---

### Task 4: StoreKit configuration file

**Files:**
- Create: `SmileDay/Configuration.storekit`

- [ ] **Step 1: Create the file**

```json
{
  "identifier" : "09F07AA5-4CAE-4BA1-94D2-4CB510CF3548",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "5900",
      "familyShareable" : false,
      "internalID" : "AD66F3E5-A45F-446E-A635-35608AF4C625",
      "localizations" : [
        {
          "description" : "아침·낮·저녁 리마인더, 전체 좋은 순간 보관함, 주간 돌아보기",
          "displayName" : "SmileDay Pro",
          "locale" : "ko"
        }
      ],
      "productID" : "dvelo.SmileDay.pro.unlock",
      "referenceName" : "SmileDay Pro Unlock",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {
    "_askToBuyEnabled" : false
  },
  "subscriptionGroups" : [],
  "version" : {
    "major" : 3,
    "minor" : 0
  }
}
```

- [ ] **Step 2: Attach it to the scheme (manual, one-time, in Xcode)**

Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → select `Configuration.storekit`. This only affects local simulator runs; the real product/price is registered separately in App Store Connect before release.

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Configuration.storekit
git commit -m "feat: add StoreKit configuration for Pro unlock testing"
```

---

### Task 5: StoreKitProPurchaser service

**Files:**
- Create: `SmileDay/Services/StoreKitProPurchaser.swift`

- [ ] **Step 1: Write the implementation**

No unit test for this task — it wraps live StoreKit2 APIs that require a simulator/App Store sandbox session, consistent with how `ARKitFaceTrackingSession` (also hardware/OS-bound) has no unit test. Verification happens via manual run against `Configuration.storekit` in Task 8.

```swift
import StoreKit
import CoachingKit

@MainActor
public final class StoreKitProPurchaser {
    public static let productID = "dvelo.SmileDay.pro.unlock"

    public enum PurchaseOutcome {
        case purchased
        case pending
        case cancelled
    }

    public enum PurchaseError: Error {
        case productNotFound
        case verificationFailed
    }

    private let entitlement: ProEntitlement
    private var updatesTask: Task<Void, Never>?

    public init(entitlement: ProEntitlement) {
        self.entitlement = entitlement
    }

    deinit {
        updatesTask?.cancel()
    }

    public func startObservingTransactions() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }
    }

    public func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                entitlement.setPro(true)
                return
            }
        }
        entitlement.setPro(false)
    }

    public func purchase() async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [Self.productID]).first else {
            throw PurchaseError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PurchaseError.verificationFailed
            }
            await transaction.finish()
            entitlement.setPro(true)
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    public func displayPrice() async -> String? {
        try? await Product.products(for: [Self.productID]).first?.displayPrice
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              transaction.productID == Self.productID else { return }
        await transaction.finish()
        await refreshEntitlement()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -30`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Services/StoreKitProPurchaser.swift
git commit -m "feat: add StoreKit purchase service for Pro unlock"
```

---

### Task 6: ProPaywallView

**Files:**
- Create: `SmileDay/Views/Store/ProPaywallView.swift`

- [ ] **Step 1: Write the view**

```swift
import SwiftUI
import CoachingKit

struct ProPaywallView: View {
    let purchaser: StoreKitProPurchaser
    @Environment(\.dismiss) private var dismiss
    @State private var price: String?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("SmileDay Pro")
                    .font(.title2.bold())
                    .foregroundStyle(SDColor.ink)

                VStack(alignment: .leading, spacing: 10) {
                    benefitRow("아침·낮·저녁 리마인더")
                    benefitRow("리마인더 무제한 등록")
                    benefitRow("전체 좋은 순간 보관함")
                }

                Text("한 번 구매로 계속 이용할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(SDColor.muted)

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await purchase() }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        }
                        Text(price.map { "\($0)에 잠금 해제" } ?? "잠금 해제")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SDColor.primaryGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                    .font(.headline)
                }
                .disabled(isPurchasing)

                Button("구매 복원") {
                    Task { await restore() }
                }
                .font(.footnote)
                .foregroundStyle(SDColor.muted)
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .task {
            price = await purchaser.displayPrice()
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SDColor.coral)
            Text(text)
                .foregroundStyle(SDColor.ink)
        }
    }

    private func purchase() async {
        isPurchasing = true
        errorMessage = nil
        do {
            switch try await purchaser.purchase() {
            case .purchased:
                dismiss()
            case .cancelled:
                break
            case .pending:
                errorMessage = "구매 승인을 기다리고 있어요. 승인되면 자동으로 적용돼요."
            }
        } catch {
            errorMessage = "구매를 완료하지 못했어요. 잠시 후 다시 시도해주세요."
        }
        isPurchasing = false
    }

    private func restore() async {
        do {
            try await purchaser.restore()
            if purchaser.entitlementIsPro {
                dismiss()
            }
        } catch {
            errorMessage = "복원할 구매 내역을 찾지 못했어요."
        }
    }
}
```

- [ ] **Step 2: Add the small entitlement-read helper this view needs**

`ProPaywallView.restore()` checks `purchaser.entitlementIsPro` after restoring. Add this computed property to `StoreKitProPurchaser` in `SmileDay/Services/StoreKitProPurchaser.swift` (below `init`):

```swift
    public var entitlementIsPro: Bool { entitlement.isPro }
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -30`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add SmileDay/Views/Store/ProPaywallView.swift SmileDay/Services/StoreKitProPurchaser.swift
git commit -m "feat: add Pro paywall sheet"
```

---

### Task 7: Wire entitlement + paywall into RootView, HistoryView, SettingsView, ReminderListView

**Files:**
- Modify: `SmileDay/Views/RootView.swift`
- Modify: `SmileDay/Views/History/HistoryView.swift`
- Modify: `SmileDay/Views/Settings/SettingsView.swift`
- Modify: `SmileDay/Views/Settings/ReminderListView.swift`

- [ ] **Step 1: RootView owns and injects the entitlement + purchaser**

In `SmileDay/Views/RootView.swift`, add state and environment injection:

```swift
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var baseline: Baseline?
    @State private var isLoading = true
    @State private var hasSeenIntro = false
    @State private var entitlement = ProEntitlement()
    @State private var purchaser: StoreKitProPurchaser?

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
        .environment(entitlement)
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

            let resolvedPurchaser = StoreKitProPurchaser(entitlement: entitlement)
            purchaser = resolvedPurchaser
            resolvedPurchaser.startObservingTransactions()
            await resolvedPurchaser.refreshEntitlement()

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
                    scheduler: UserNotificationReminderScheduler(),
                    entitlement: entitlement
                )
                try? await viewModel.refreshAllScheduledReminders()
            }
        }
        .environment(\.storeKitProPurchaser, purchaser)
    }
}
```

`environment(\.storeKitProPurchaser, purchaser)` needs a custom `EnvironmentKey` since `StoreKitProPurchaser` isn't an `Observable` model type. Add this to the bottom of `SmileDay/Services/StoreKitProPurchaser.swift`:

```swift
private struct StoreKitProPurchaserKey: EnvironmentKey {
    static let defaultValue: StoreKitProPurchaser? = nil
}

extension EnvironmentValues {
    public var storeKitProPurchaser: StoreKitProPurchaser? {
        get { self[StoreKitProPurchaserKey.self] }
        set { self[StoreKitProPurchaserKey.self] = newValue }
    }
}
```

- [x] ~~**Step 2: CareView reads the entitlement and locks routines**~~

> **삭제됨 (2026-07-27).** 쉬어가기 탭에는 잠금 UI를 두지 않는다. 기본 콘텐츠는 전부 무료이며
> `CareRoutine`/`CareViewModel` 타입도 더 이상 존재하지 않는다. `CareView.swift`는 이 계획에서 수정하지 않는다.

- [ ] **Step 3: HistoryView locks the bucket detail card**

In `SmileDay/Views/History/HistoryView.swift`, add environment reads and a paywall trigger:

```swift
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(\.storeKitProPurchaser) private var purchaser
    @State private var viewModel: HistoryViewModel?
    @State private var selectedDay: Int = Calendar.current.component(.day, from: .now)
    @State private var selectedBucketScores: [TimeBucket: Double] = [:]
    @State private var showPaywall = false
```

> **개정됨 (2026-07-27).** `bucketDetailCard`는 시간대별 **점수**가 아니라 미소 시간 **횟수**를 보여주며 무료다.
> 잠금 대상은 좋은 순간 보관함이다 — 무료 한도(`HistoryViewModel.recentMomentLimit`)를 넘는 자리에
> "Pro에서 전체 보기" 행을 두고, 이미 보이는 항목은 블러 처리하지 않는다.
> 구체적인 코드는 선행 조건 통과 후 `HistoryViewModel` 잠금 구현과 함께 확정한다.

- [ ] **Step 4: SettingsView passes entitlement and shows a Pro row**

In `SmileDay/Views/Settings/SettingsView.swift`, add environment reads:

```swift
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProEntitlement.self) private var entitlement
    @Environment(\.storeKitProPurchaser) private var purchaser
    @State private var viewModel: SettingsViewModel?
    @State private var isResettingBaseline = false
    @State private var showPaywall = false

    let onBaselineUpdated: (Baseline) -> Void
```

Update view-model construction:

```swift
        .onAppear {
            let vm = viewModel ?? SettingsViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                sessionRepository: SessionRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler(),
                entitlement: entitlement
            )
            viewModel = vm
            try? vm.refresh()
        }
```

Add a Pro section (insert right after the reminder/기준선 재설정 `Section`, before the "데이터 저장 위치" section):

```swift
                    Section {
                        if entitlement.isPro {
                            SettingsRow(icon: "star.fill", chipColor: SDColor.coral, title: "Pro") {
                                Text("활성화됨")
                                    .foregroundStyle(SDColor.muted)
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                SettingsRow(icon: "star.fill", chipColor: SDColor.coral, title: "Pro 잠금 해제") {
                                    Text("보기")
                                        .foregroundStyle(SDColor.muted)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .listRowBackground(Color.white)
```

Add the sheet modifier near the existing `.fullScreenCover`:

```swift
        .sheet(isPresented: $showPaywall) {
            if let purchaser {
                ProPaywallView(purchaser: purchaser)
            }
        }
```

- [ ] **Step 5: ReminderListView locks the "추가" affordance at the free limit**

In `SmileDay/Views/Settings/ReminderListView.swift`, add a paywall trigger and gate both add paths:

```swift
struct ReminderListView: View {
    let viewModel: SettingsViewModel
    @Environment(\.storeKitProPurchaser) private var purchaser
    @State private var newTime = Date()
    @State private var editingReminder: ReminderSetting?
    @State private var showPaywall = false
```

Update the "추천 시간" button action:

```swift
                            Button("추가") {
                                if viewModel.canAddReminder {
                                    Task { try? await viewModel.addReminder(hour: bucket.suggestedHour, minute: 0) }
                                } else {
                                    showPaywall = true
                                }
                            }
```

Update the "리마인더 추가" section button:

```swift
            Section("리마인더 추가") {
                DatePicker("시간", selection: $newTime, displayedComponents: .hourAndMinute)
                Button(viewModel.canAddReminder ? "추가" : "Pro에서 무제한 추가") {
                    if viewModel.canAddReminder {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                        Task {
                            try? await viewModel.addReminder(hour: components.hour ?? 9, minute: components.minute ?? 0)
                        }
                    } else {
                        showPaywall = true
                    }
                }
            }
```

Add the sheet modifier at the end of the `List`'s modifier chain (alongside the existing `.sheet(isPresented:` for `editingReminder`):

```swift
        .sheet(isPresented: $showPaywall) {
            if let purchaser {
                ProPaywallView(purchaser: purchaser)
            }
        }
```

- [ ] **Step 6: Commit**

```bash
git add SmileDay/Views/RootView.swift SmileDay/Views/History/HistoryView.swift SmileDay/Views/Settings/SettingsView.swift SmileDay/Views/Settings/ReminderListView.swift SmileDay/Services/StoreKitProPurchaser.swift
git commit -m "feat: wire Pro entitlement and paywall into Care, History, Settings"
```

---

### Task 8: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full CoachingKit suite**

Run: `cd CoachingKit && swift test 2>&1 | tail -15`
Expected: `Test Suite 'All tests' passed`, no failures. Existing `SettingsViewModelTests` still pass unchanged (defaulted `entitlement` param preserves old behavior).

- [ ] **Step 2: Build the app target**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -30`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual smoke test in simulator (StoreKit Configuration attached per Task 4 Step 2)**

- Launch app, go to 설정 → confirm "Pro 잠금 해제" row appears.
- Go to 케어 탭 → confirm `lift-cheek` shows a lock icon + "Pro" badge, tapping it opens the paywall; `lift-smile`/`relax-brow`/`depuff-morning`/`morning-1min` still play normally.
- Go to 설정 → 리마인더 → add one reminder → confirm the "리마인더 추가" button now reads "Pro에서 무제한 추가" and opens the paywall instead of adding a second one.
- Go to 기록 탭 → confirm the 시간대별 카드 is blurred with a "Pro에서 보기" button.
- In the paywall, tap 잠금 해제 → StoreKit sandbox purchase sheet appears (simulator, no real charge) → confirm purchase → confirm all three locks disappear across tabs without restarting the app.
- Force-quit and relaunch → confirm Pro state persists (entitlement restored via `refreshEntitlement()` in `RootView.task`).
- Confirm the paywall displays the StoreKit-provided localized price and “한 번 구매로 계속 이용할 수 있어요.”; no hardcoded `₩5,900` appears in Swift source.
- Simulate user cancellation and pending approval → confirm no false Pro unlock and no misleading failure message.

- [ ] **Step 4: Report results**

If manual smoke test step 3 reveals any issue, fix and re-run Steps 1-3 before considering the plan complete. No commit for this task — it's verification only.

---

### Task 9: App Store monetization readiness

**Files:** none (App Store Connect configuration and release decision)

- [ ] **Step 1: Configure the real product**

In App Store Connect:

- Accept the current Paid Apps agreement.
- Create non-consumable product `dvelo.SmileDay.pro.unlock`.
- Set Korean display name and description to match the reviewed paywall.
- Set the initial Korean storefront price closest to `₩5,900`.
- Confirm tax/banking status and whether the App Store Small Business Program reduced commission actually applies.
- Submit the IAP with the app version and confirm it reaches the required review state.

- [ ] **Step 2: Verify sandbox and TestFlight purchase lifecycle**

- New purchase succeeds and unlocks Pro.
- User cancellation leaves the app usable and free.
- Pending/Ask to Buy does not unlock early.
- Relaunch and reinstall restore current entitlement.
- “구매 복원” works without creating a duplicate charge.
- Refunded or revoked entitlement is not treated as permanently active.

- [ ] **Step 3: Launch with organic acquisition only**

Do not buy installs yet. Obtain the first users through owned social content, direct outreach, communities, and TestFlight/release feedback. Record for one fixed observation window:

- first-time downloads
- Pro purchases
- proceeds after Apple adjustments
- retention available in App Store Connect
- support/refund issues

Use at least 100 qualified first-time downloads when practical. If the sample is smaller, label the result directional and do not scale advertising from it.

- [ ] **Step 4: Calculate the paid-acquisition ceiling**

```text
installToProConversion = proPurchases / firstTimeDownloads
netRevenuePerPurchase = proceeds / proPurchases
ARPI = installToProConversion * netRevenuePerPurchase
targetCPI = ARPI * 0.5
```

Do not use gross list price or an assumed 15% commission in place of actual proceeds.

- [ ] **Step 5: Make the launch decision**

- If Pro conversion is weak or users report that the paid bundle lacks value: do not advertise. Create a separate design/plan pair for stronger Pro value based on already collected data.
- If conversion and retention are acceptable: run only a small App Store search campaign with a hard CPI cap at or below `targetCPI`.
- Stop the campaign if observed CPI exceeds `targetCPI`, organic retention falls, refunds/support issues rise, or the sample cannot support a reliable decision.
- Revisit `₩9,900` only after the `₩5,900` cohort has enough purchase and retention data; do not change price and advertising variables simultaneously.
