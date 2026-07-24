# 리마인더 딥링크 + 버킷별 체크인 기록 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리마인더 알림 탭 시 바로 측정 화면으로 딥링크하고(질문 문구 연속성 포함), 체크인을 아침/낮/저녁 버킷 단위로 집계해 기록 탭에서 날짜별로 보여준다.

**Architecture:** 알림 userInfo의 인코딩/디코딩은 CoachingKit의 `ReminderNotificationPayload`로 순수 로직화해 단위 테스트하고, SmileDay 타겟에는 얇은 `NotificationRouter`(@Observable) + `AppDelegate`(UNUserNotificationCenterDelegate)만 둔다. 버킷 집계는 스키마 변경 없이 `CheckInSession.date`의 시각을 기존 `TimeBucket(hour:)`로 유도하며, `HistoryViewModel.bucketScores(onDayOf:)`로 노출한다. 홈/스트릭/주간 통계는 일절 건드리지 않는다.

**Tech Stack:** SwiftUI, SwiftData, UserNotifications, XCTest (CoachingKit 패키지), Observation

**설계 스펙:** `SmileDay/docs/superpowers/specs/2026-07-24-reminder-deeplink-bucket-records-design.md`

**스펙 대비 구체화 노트:**
- 스펙의 "기록 탭 날짜별 상세"는 현재 존재하지 않는 화면이므로, **월 히트맵 날짜 셀 탭 → 히트맵 아래 시간대별 카드** 방식으로 구현한다 (기본 선택: 오늘).
- 스펙의 "스케줄러 userInfo 테스트"는 `UNUserNotificationCenter`를 목킹할 수 없으므로 `ReminderNotificationPayload` 라운드트립 테스트로 대체한다. 스케줄러는 payload의 `userInfo`를 그대로 싣는 한 줄이라 빌드 검증으로 충분하다.

**검증 명령:**
- 패키지 테스트: `cd CoachingKit && swift test --filter <TestClass>`
- 앱 빌드: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`

---

### Task 1: ReminderNotificationPayload (CoachingKit)

알림 userInfo에 싣는 버킷+질문 문구의 인코딩/디코딩. 스케줄러(쓰기)와 라우터(읽기)가 공유한다.

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/ReminderNotificationPayload.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/ReminderNotificationPayloadTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
import XCTest
@testable import CoachingKit

final class ReminderNotificationPayloadTests: XCTestCase {
    func test_userInfo_roundTrip() {
        let payload = ReminderNotificationPayload(bucket: .evening, promptText: "지금 한 번 웃어볼까요?")

        let decoded = ReminderNotificationPayload(userInfo: payload.userInfo)

        XCTAssertEqual(decoded, payload)
    }

    func test_init_returnsNil_whenBucketMissing() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["promptText": "text"]))
    }

    func test_init_returnsNil_whenPromptTextMissing() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["bucket": "morning"]))
    }

    func test_init_returnsNil_whenBucketRawValueUnknown() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: ["bucket": "midnight", "promptText": "text"]))
    }

    func test_init_returnsNil_whenUserInfoEmpty() {
        XCTAssertNil(ReminderNotificationPayload(userInfo: [:]))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd CoachingKit && swift test --filter ReminderNotificationPayloadTests`
Expected: 컴파일 실패 — "cannot find 'ReminderNotificationPayload' in scope"

- [ ] **Step 3: 최소 구현**

```swift
import Foundation

/// 리마인더 알림 userInfo에 싣는 딥링크 정보. 스케줄러가 쓰고 라우터가 읽는다.
public struct ReminderNotificationPayload: Equatable, Sendable {
    public let bucket: TimeBucket
    public let promptText: String

    private enum Key {
        static let bucket = "bucket"
        static let promptText = "promptText"
    }

    public init(bucket: TimeBucket, promptText: String) {
        self.bucket = bucket
        self.promptText = promptText
    }

    public var userInfo: [String: Any] {
        [Key.bucket: bucket.rawValue, Key.promptText: promptText]
    }

    /// 필드 누락·미지의 rawValue면 nil — 구버전 알림은 조용히 무시된다.
    public init?(userInfo: [AnyHashable: Any]) {
        guard let rawBucket = userInfo[Key.bucket] as? String,
              let bucket = TimeBucket(rawValue: rawBucket),
              let promptText = userInfo[Key.promptText] as? String else { return nil }
        self.bucket = bucket
        self.promptText = promptText
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd CoachingKit && swift test --filter ReminderNotificationPayloadTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderNotificationPayload.swift CoachingKit/Tests/CoachingKitTests/ReminderNotificationPayloadTests.swift
git commit -m "feat: add reminder notification payload for deep link"
```

---

### Task 2: HistoryViewModel.bucketScores (CoachingKit)

날짜별 버킷 대표 점수 집계. 같은 버킷은 마지막 기록이 남는다.

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/HistoryViewModel.swift` (refresh() 아래에 메서드 추가)
- Test: `CoachingKit/Tests/CoachingKitTests/HistoryViewModelTests.swift` (기존 파일에 테스트 추가)

- [ ] **Step 1: 실패하는 테스트 작성**

`HistoryViewModelTests.swift`의 기존 클래스 안에 추가한다. 기존 파일에 `makeInMemoryContext()` 헬퍼가 이미 있으면 재사용하고, 없으면 아래 헬퍼도 함께 추가한다 (HomeViewModelTests와 동일 패턴):

```swift
// 헬퍼가 없을 때만 추가
private func makeInMemoryContext() throws -> ModelContext {
    let schema = PersistenceSchema.schema
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

private func saveCheckIn(_ repository: SessionRepository, hour: Int, scoreDelta: Double, calendar: Calendar = .current) throws {
    let start = calendar.startOfDay(for: Date())
    let date = calendar.date(byAdding: .hour, value: hour, to: start)!
    try repository.saveCheckIn(
        measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
        date: date,
        lightingQuality: 1.0,
        deviceAngleOK: true,
        scoreDelta: scoreDelta
    )
}

func test_bucketScores_mapsSessionsToBuckets() throws {
    let context = try makeInMemoryContext()
    let repository = SessionRepository(modelContext: context)
    try saveCheckIn(repository, hour: 9, scoreDelta: 0.2)   // 아침
    try saveCheckIn(repository, hour: 20, scoreDelta: 0.1)  // 저녁
    let viewModel = HistoryViewModel(repository: repository)

    let scores = try viewModel.bucketScores(onDayOf: Date())

    XCTAssertEqual(scores[.morning], ScoreCalculator.displayValue(0.2))
    XCTAssertEqual(scores[.evening], ScoreCalculator.displayValue(0.1))
    XCTAssertNil(scores[.afternoon])
}

func test_bucketScores_lastRecordWins_inSameBucket() throws {
    let context = try makeInMemoryContext()
    let repository = SessionRepository(modelContext: context)
    try saveCheckIn(repository, hour: 8, scoreDelta: 0.1)
    try saveCheckIn(repository, hour: 10, scoreDelta: 0.3)  // 같은 아침 버킷, 더 늦은 기록
    let viewModel = HistoryViewModel(repository: repository)

    let scores = try viewModel.bucketScores(onDayOf: Date())

    XCTAssertEqual(scores[.morning], ScoreCalculator.displayValue(0.3))
}

func test_bucketScores_earlyMorningBelongsToEveningBucket() throws {
    let context = try makeInMemoryContext()
    let repository = SessionRepository(modelContext: context)
    try saveCheckIn(repository, hour: 2, scoreDelta: 0.1)   // 새벽 2시 → 저녁 버킷(달력일 기준)
    let viewModel = HistoryViewModel(repository: repository)

    let scores = try viewModel.bucketScores(onDayOf: Date())

    XCTAssertEqual(scores[.evening], ScoreCalculator.displayValue(0.1))
    XCTAssertNil(scores[.morning])
}

func test_bucketScores_emptyWhenNoCheckIns() throws {
    let context = try makeInMemoryContext()
    let repository = SessionRepository(modelContext: context)
    let viewModel = HistoryViewModel(repository: repository)

    XCTAssertTrue(try viewModel.bucketScores(onDayOf: Date()).isEmpty)
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd CoachingKit && swift test --filter HistoryViewModelTests`
Expected: 컴파일 실패 — "value of type 'HistoryViewModel' has no member 'bucketScores'"

- [ ] **Step 3: 최소 구현**

`HistoryViewModel.swift`의 `refresh()` 아래에 추가:

```swift
    /// 해당 날짜의 버킷별 대표 점수(표시 점수). 같은 버킷은 마지막 기록이 남는다.
    /// 버킷 귀속은 달력일 기준 — 새벽 기록은 그 날짜의 저녁 버킷으로 분류된다.
    public func bucketScores(onDayOf date: Date) throws -> [TimeBucket: Double] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [:] }
        var scores: [TimeBucket: Double] = [:]
        for session in try repository.fetchCheckIns(from: start, to: end) { // 날짜 오름차순
            let bucket = TimeBucket(hour: calendar.component(.hour, from: session.date))
            scores[bucket] = ScoreCalculator.displayValue(session.scoreDelta)
        }
        return scores
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd CoachingKit && swift test --filter HistoryViewModelTests`
Expected: PASS (기존 테스트 + 신규 4개)

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/HistoryViewModel.swift CoachingKit/Tests/CoachingKitTests/HistoryViewModelTests.swift
git commit -m "feat: add per-bucket score aggregation to history view model"
```

---

### Task 3: 스케줄러 userInfo (SmileDay 타겟)

**Files:**
- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift:38-42`

- [ ] **Step 1: userInfo 추가**

`scheduleRollingWindow`의 content 구성 부분(38-42행)을 다음으로 교체:

```swift
            let prompt = promptSelector.nextPrompt(forHour: hour)
            let content = UNMutableNotificationContent()
            content.title = "스마일데이"
            content.body = prompt.text
            content.sound = .default
            content.userInfo = ReminderNotificationPayload(bucket: TimeBucket(hour: hour), promptText: prompt.text).userInfo
```

- [ ] **Step 2: 빌드 검증**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Services/UserNotificationReminderScheduler.swift
git commit -m "feat: attach deep link payload to reminder notifications"
```

---

### Task 4: NotificationRouter + AppDelegate + 앱 연결 (SmileDay 타겟)

**Files:**
- Create: `SmileDay/Services/NotificationRouter.swift`
- Create: `SmileDay/Services/AppDelegate.swift`
- Modify: `SmileDay/SmileDayApp.swift`

- [ ] **Step 1: NotificationRouter 작성**

`SmileDay/Services/NotificationRouter.swift`:

```swift
import Foundation
import Observation
import CoachingKit

/// 알림 탭 신호를 뷰 계층에 전달한다. AppDelegate가 쓰고 MainTabView가 소비한다.
@Observable
final class NotificationRouter {
    var pendingCoaching: ReminderNotificationPayload?

    /// userInfo 파싱 실패(구버전 알림 등) 시 아무것도 하지 않는다 — 홈 유지.
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let payload = ReminderNotificationPayload(userInfo: userInfo) else { return }
        pendingCoaching = payload
    }
}
```

- [ ] **Step 2: AppDelegate 작성**

`SmileDay/Services/AppDelegate.swift`:

```swift
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = NotificationRouter()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        router.handleNotificationTap(userInfo: response.notification.request.content.userInfo)
    }

    // 앱 사용 중 도착한 알림도 배너로 보여준다 (기본값은 무표시).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
```

- [ ] **Step 3: SmileDayApp에 어댑터 연결**

`SmileDayApp.swift`의 struct 내부에 어댑터를 추가하고 environment로 라우터를 주입:

```swift
@main
struct SmileDayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                // 앱 카피가 전부 한국어라 날짜·차트 축 표기도 한국어로 고정한다.
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .environment(appDelegate.router)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- [ ] **Step 4: 빌드 검증**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add SmileDay/Services/NotificationRouter.swift SmileDay/Services/AppDelegate.swift SmileDay/SmileDayApp.swift
git commit -m "feat: route reminder notification taps via app delegate"
```

---

### Task 5: 탭 전환 + 측정 화면 질문 오버레이 (SmileDay 타겟)

**Files:**
- Modify: `SmileDay/Views/MainTabView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingTabView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingSessionView.swift`

- [ ] **Step 1: CoachingSessionView에 promptText 오버레이 추가**

`CoachingSessionView`에 저장 프로퍼티 추가 (`let baseline: Baseline` 위):

```swift
    /// 알림 딥링크로 진입한 경우 상단에 이어서 보여줄 표정 질문. 일반 진입은 nil.
    var promptText: String? = nil
```

body의 상단 VStack에서 닫기 버튼 HStack 바로 아래(조명 경고 라벨 위)에 추가:

```swift
                if let promptText {
                    Text(promptText)
                        .font(.caption.bold())
                        .foregroundStyle(SDColor.ink)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)
                }
```

- [ ] **Step 2: CoachingTabView에 promptText 전달 통로 추가**

프로퍼티 추가 (`let baseline: Baseline` 아래):

```swift
    var promptText: String? = nil
```

`CoachingSessionView` 생성 부분에 전달:

```swift
            CoachingSessionView(
                promptText: promptText,
                baseline: baseline,
                onCompleted: { today, yesterday in
```

(주의: `CoachingSessionView`의 프로퍼티 선언 순서에 맞춰 멤버와이즈 이니셜라이저 인자 순서를 조정한다 — promptText를 baseline 위에 선언했으므로 인자도 먼저 온다.)

- [ ] **Step 3: MainTabView에서 라우터 소비**

`MainTabView`에 environment와 상태 추가 (`@State private var selection: AppTab` 아래):

```swift
    @Environment(NotificationRouter.self) private var notificationRouter
    @State private var coachingPrompt: String? = nil
```

(커스텀 init이 있는 구조체이므로 명시적 `= nil` 초기값 필수.)

`CoachingTabView` 생성 부분을 다음으로 교체 (완료/이탈 시 프롬프트 비움):

```swift
            CoachingTabView(
                baseline: baseline,
                promptText: coachingPrompt,
                onFinished: {
                    coachingPrompt = nil
                    selection = .home
                },
                onExit: {
                    coachingPrompt = nil
                    selection = .home
                }
            )
```

(주의: `CoachingTabView`의 프로퍼티 선언 순서상 promptText는 baseline 다음, onFinished 앞이다.)

TabView의 `.tint(SDColor.coral)` 아래에 라우팅 감지 추가:

```swift
        .onChange(of: notificationRouter.pendingCoaching, initial: true) { _, payload in
            guard let payload else { return }
            coachingPrompt = payload.promptText
            selection = .coaching
            notificationRouter.pendingCoaching = nil
        }
```

`initial: true`인 이유: 콜드 스타트에서 알림 탭이 스플래시 중에 처리되면 MainTabView 생성 시점에 이미 pendingCoaching이 차 있다.

- [ ] **Step 4: 빌드 검증**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add SmileDay/Views/MainTabView.swift SmileDay/Views/Coaching/CoachingTabView.swift SmileDay/Views/Coaching/CoachingSessionView.swift
git commit -m "feat: deep link reminder tap to coaching with prompt continuity"
```

---

### Task 6: 기록 탭 — 히트맵 날짜 선택 + 시간대별 카드 (SmileDay 타겟)

**Files:**
- Modify: `SmileDay/Views/History/HistoryView.swift`

- [ ] **Step 1: MonthHeatmapView에 선택 기능 추가**

`MonthHeatmapView`에 프로퍼티 추가 (`let checkInDays: Set<Int>` 아래):

```swift
    var selectedDay: Int? = nil
    var onSelectDay: ((Int) -> Void)? = nil
```

셀의 두 번째 `.overlay`(날짜 숫자) 아래에 선택 표시와 탭 제스처 추가:

```swift
                    .overlay {
                        if day == selectedDay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(SDColor.coralDeep, lineWidth: 2)
                        }
                    }
                    .onTapGesture {
                        guard !isFuture else { return }
                        onSelectDay?(day)
                    }
```

- [ ] **Step 2: HistoryView에 선택 상태와 시간대별 카드 추가**

프로퍼티 추가 (`@State private var viewModel` 아래):

```swift
    @State private var selectedDay: Int = Calendar.current.component(.day, from: .now)
    @State private var selectedBucketScores: [TimeBucket: Double] = [:]
```

`monthHeatmapCard`의 `MonthHeatmapView` 호출을 교체:

```swift
            MonthHeatmapView(
                checkInDays: viewModel?.monthCheckInDays ?? [],
                selectedDay: selectedDay,
                onSelectDay: { day in
                    selectedDay = day
                    refreshBucketScores()
                }
            )
```

body의 `monthHeatmapCard` 아래에 카드 추가:

```swift
                bucketDetailCard
```

카드와 갱신 헬퍼를 `monthHeatmapCard` 아래에 추가:

```swift
    private var bucketDetailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("시간대별 미소 · \(selectedDay)일")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            HStack(spacing: 8) {
                ForEach(TimeBucket.allCases, id: \.self) { bucket in
                    SummaryTile(
                        value: selectedBucketScores[bucket].map { SDFormat.signedNumber($0) } ?? "—",
                        unit: selectedBucketScores[bucket] == nil ? "" : "°",
                        label: bucket.displayName
                    )
                }
            }
        }
        .sdCard()
    }

    private func refreshBucketScores() {
        guard let viewModel else { return }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: .now)
        components.day = selectedDay
        guard let date = calendar.date(from: components) else { return }
        selectedBucketScores = (try? viewModel.bucketScores(onDayOf: date)) ?? [:]
    }
```

`.onAppear`의 `try? vm.refresh()` 아래에 초기 로드 추가:

```swift
            refreshBucketScores()
```

- [ ] **Step 3: 빌드 검증**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add SmileDay/Views/History/HistoryView.swift
git commit -m "feat: show per-bucket smile scores in history day detail"
```

---

### Task 7: 최종 검증

- [ ] **Step 1: 패키지 전체 테스트**

Run: `cd CoachingKit && swift test`
Expected: 전체 PASS (기존 테스트 포함 회귀 없음)

- [ ] **Step 2: 앱 빌드**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 수동 확인 항목 (시뮬레이터)**

시뮬레이터에서 앱 실행 후:
1. 설정 → 리마인더 등록 → 몇 분 뒤 시각으로 설정
2. 앱을 백그라운드로 → 알림 도착 → 탭 → 코칭 탭 + 질문 오버레이 확인
3. 측정 완료 → 기록 탭 → 히트맵 오늘 셀 선택 → 시간대별 카드에 점수 확인
4. 홈 탭 → 히어로 카드가 기존과 동일하게 동작하는지 확인
