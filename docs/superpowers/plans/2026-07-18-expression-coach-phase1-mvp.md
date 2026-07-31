# Expression Coach Phase 1 (MVP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Phase 1 MVP described in `docs/superpowers/specs/2026-07-18-expression-coach-design.md`: baseline onboarding capture, ARKit-driven coaching check-in with a live gauge, SwiftData session persistence, and a minimal home screen — TrueDepth devices only.

**Architecture:** Pure business logic (measurement types, score math, SwiftData models, repository, view models) lives in a new local Swift package `CoachingKit` so it can be unit-tested with `swift test` without Xcode or a device. The app target (`SmileDay`) depends on `CoachingKit` and adds only what genuinely requires iOS/ARKit/SwiftUI: the ARKit session wrapper, the camera preview, and the views. This keeps ARKit — which cannot run in the Simulator or be meaningfully unit tested — isolated to the thinnest possible layer, verified by manual on-device checks instead of automated tests.

**Tech Stack:** Swift 6.3 (language mode 5, see Task 1), SwiftUI, SwiftData, ARKit (`ARFaceTrackingConfiguration` + `ARSCNView`), Swift Package Manager (local package), XCTest.

**Key decisions locked in during planning (not otherwise specified in the spec):**
- Coaching session ends on a manual "완료" (Complete) button tap, not a timer.
- `scoreDelta` = simple signed average of the three per-metric differences: `((current.mouthCornerLeft − baseline.mouthCornerLeft) + (current.mouthCornerRight − baseline.mouthCornerRight) + (current.browTension − baseline.browTension)) / 3`.
- `browTension` is computed from ARKit blend shapes as the average of `browDownLeft`, `browDownRight`, and `browInnerUp`.
- `lightingQuality` and `deviceAngleOK` are persisted with fixed neutral defaults (`1.0` / `true`) in Phase 1 — real detection is Phase 3 scope per the spec's milestone list. This keeps the `CheckInSession` schema stable across phases instead of adding the fields later.
- Development and all manual verification targets a physical TrueDepth (Face ID) iPhone. The Simulator is used only to verify the code *compiles* (`ARKit` links in the Simulator SDK even though `ARFaceTrackingConfiguration` cannot run there).
- Phase 1's Home screen presents Coaching as a modal (`fullScreenCover`), not as a persistent tab. The spec's final 4-tab structure (Home/Coaching/History/Settings) is realized incrementally as History and Settings are built in Phase 2/3 — tracked here as a known, intentional deviation from the end-state IA, not an oversight.

---

## File Structure

```
SmileDay/                                    (repo root, sibling of SmileDay.xcodeproj)
├── CoachingKit/                              (new local SPM package — pure logic, unit tested)
│   ├── Package.swift
│   ├── Sources/CoachingKit/
│   │   ├── FaceMeasurement.swift
│   │   ├── ScoreCalculator.swift
│   │   ├── Baseline.swift                    (SwiftData @Model)
│   │   ├── CheckInSession.swift              (SwiftData @Model)
│   │   ├── SessionRepository.swift
│   │   ├── FaceTrackingSession.swift          (protocol only, no ARKit import)
│   │   ├── BaselineCaptureViewModel.swift
│   │   ├── CoachingViewModel.swift
│   │   └── HomeViewModel.swift
│   └── Tests/CoachingKitTests/
│       ├── ScoreCalculatorTests.swift
│       ├── SessionRepositoryTests.swift
│       ├── BaselineCaptureViewModelTests.swift
│       ├── CoachingViewModelTests.swift
│       └── HomeViewModelTests.swift
└── SmileDay/                                 (existing Xcode app target — file-system-synchronized group, no pbxproj edits needed for new files placed here)
    ├── SmileDayApp.swift                     (modify)
    ├── ContentView.swift                     (delete — replaced by RootView.swift)
    ├── Services/
    │   ├── ARKitFaceTrackingSession.swift
    │   └── ARFacePreviewRepresentable.swift
    └── Views/
        ├── RootView.swift
        ├── Onboarding/BaselineCaptureView.swift
        ├── Home/HomeView.swift
        └── Coaching/
            ├── CoachingSessionView.swift
            └── SessionSummarySheet.swift
```

---

### Task 1: CoachingKit package scaffold — `FaceMeasurement` + `ScoreCalculator`

**Files:**
- Create: `CoachingKit/Package.swift`
- Create: `CoachingKit/Sources/CoachingKit/FaceMeasurement.swift`
- Create: `CoachingKit/Sources/CoachingKit/ScoreCalculator.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/ScoreCalculatorTests.swift`

- [ ] **Step 1: Create the package manifest**

```bash
mkdir -p /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit/Sources/CoachingKit
mkdir -p /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit/Tests/CoachingKitTests
```

`CoachingKit/Package.swift`:

```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CoachingKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "CoachingKit", targets: ["CoachingKit"])
    ],
    targets: [
        .target(name: "CoachingKit"),
        .testTarget(name: "CoachingKitTests", dependencies: ["CoachingKit"])
    ]
)
```

(`swift-tools-version: 5.10` pins Swift 5 language mode so we don't have to solve Swift 6 strict-concurrency checking for `@Observable` view models in this MVP.)

- [ ] **Step 2: Write the failing test**

`CoachingKit/Tests/CoachingKitTests/ScoreCalculatorTests.swift`:

```swift
import XCTest
@testable import CoachingKit

final class ScoreCalculatorTests: XCTestCase {
    func test_delta_isZero_whenCurrentMatchesBaseline() {
        let baseline = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.2)
        let current = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.2)

        XCTAssertEqual(ScoreCalculator.delta(current: current, baseline: baseline), 0.0, accuracy: 0.0001)
    }

    func test_delta_isPositive_whenCurrentValuesExceedBaseline() {
        let baseline = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1)
        let current = FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4)

        XCTAssertEqual(ScoreCalculator.delta(current: current, baseline: baseline), 0.3, accuracy: 0.0001)
    }

    func test_delta_averagesMixedDirections() {
        let baseline = FaceMeasurement(mouthCornerLeft: 0.2, mouthCornerRight: 0.2, browTension: 0.2)
        let current = FaceMeasurement(mouthCornerLeft: 0.5, mouthCornerRight: 0.1, browTension: 0.2)

        // (0.3 + -0.1 + 0.0) / 3
        XCTAssertEqual(ScoreCalculator.delta(current: current, baseline: baseline), 0.2 / 3, accuracy: 0.0001)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: FAIL to build — `FaceMeasurement` and `ScoreCalculator` are not defined.

- [ ] **Step 4: Write minimal implementation**

`CoachingKit/Sources/CoachingKit/FaceMeasurement.swift`:

```swift
import Foundation

public struct FaceMeasurement: Equatable, Sendable {
    public let mouthCornerLeft: Double
    public let mouthCornerRight: Double
    public let browTension: Double

    public init(mouthCornerLeft: Double, mouthCornerRight: Double, browTension: Double) {
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
    }
}
```

`CoachingKit/Sources/CoachingKit/ScoreCalculator.swift`:

```swift
import Foundation

public enum ScoreCalculator {
    public static func delta(current: FaceMeasurement, baseline: FaceMeasurement) -> Double {
        let mouthLeftDelta = current.mouthCornerLeft - baseline.mouthCornerLeft
        let mouthRightDelta = current.mouthCornerRight - baseline.mouthCornerRight
        let browDelta = current.browTension - baseline.browTension
        return (mouthLeftDelta + mouthRightDelta + browDelta) / 3
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: `Test Suite 'All tests' passed` with 3 tests passing.

- [ ] **Step 6: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Package.swift CoachingKit/Sources/CoachingKit/FaceMeasurement.swift CoachingKit/Sources/CoachingKit/ScoreCalculator.swift CoachingKit/Tests/CoachingKitTests/ScoreCalculatorTests.swift
git commit -m "feat: add CoachingKit package with FaceMeasurement and ScoreCalculator"
```

---

### Task 2: SwiftData models — `Baseline` + `CheckInSession`

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/Baseline.swift`
- Create: `CoachingKit/Sources/CoachingKit/CheckInSession.swift`

- [ ] **Step 1: Write the models**

`CoachingKit/Sources/CoachingKit/Baseline.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class Baseline {
    public var capturedAt: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double

    public init(capturedAt: Date, mouthCornerLeft: Double, mouthCornerRight: Double, browTension: Double) {
        self.capturedAt = capturedAt
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
    }

    public var measurement: FaceMeasurement {
        FaceMeasurement(mouthCornerLeft: mouthCornerLeft, mouthCornerRight: mouthCornerRight, browTension: browTension)
    }
}
```

`CoachingKit/Sources/CoachingKit/CheckInSession.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class CheckInSession {
    public var date: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double
    public var lightingQuality: Double
    public var deviceAngleOK: Bool
    public var scoreDelta: Double

    public init(
        date: Date,
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double
    ) {
        self.date = date
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.lightingQuality = lightingQuality
        self.deviceAngleOK = deviceAngleOK
        self.scoreDelta = scoreDelta
    }
}
```

There's no test here — `@Model` classes are exercised through `SessionRepository` in Task 3, which is where behavior worth testing first appears.

- [ ] **Step 2: Verify the package still builds**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift build`
Expected: builds with no errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/Baseline.swift CoachingKit/Sources/CoachingKit/CheckInSession.swift
git commit -m "feat: add Baseline and CheckInSession SwiftData models"
```

---

### Task 3: `SessionRepository` (SwiftData CRUD)

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/SessionRepository.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`

- [ ] **Step 1: Write the failing tests**

`CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CoachingKit

final class SessionRepositoryTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Baseline.self, CheckInSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_saveBaseline_thenFetchLatestBaseline_returnsSavedValues() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let measurement = FaceMeasurement(mouthCornerLeft: 0.12, mouthCornerRight: 0.14, browTension: 0.2)

        try repository.saveBaseline(measurement, capturedAt: Date(timeIntervalSince1970: 1_000))

        let fetched = try repository.fetchLatestBaseline()
        XCTAssertEqual(fetched?.mouthCornerLeft, 0.12)
        XCTAssertEqual(fetched?.mouthCornerRight, 0.14)
        XCTAssertEqual(fetched?.browTension, 0.2)
    }

    func test_fetchLatestBaseline_returnsNil_whenNoneSaved() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())

        XCTAssertNil(try repository.fetchLatestBaseline())
    }

    func test_saveCheckIn_thenFetchLatestCheckIn_returnsMostRecentByDate() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let older = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1)
        let newer = FaceMeasurement(mouthCornerLeft: 0.2, mouthCornerRight: 0.2, browTension: 0.2)

        try repository.saveCheckIn(measurement: older, date: Date(timeIntervalSince1970: 1_000), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)
        try repository.saveCheckIn(measurement: newer, date: Date(timeIntervalSince1970: 2_000), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.1)

        let latest = try repository.fetchLatestCheckIn()
        XCTAssertEqual(latest?.mouthCornerLeft, 0.2)
    }

    func test_hasCheckInToday_isFalse_whenLatestCheckInIsYesterday() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        try repository.saveCheckIn(measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1), date: yesterday, lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)

        XCTAssertFalse(try repository.hasCheckInToday(calendar: calendar, now: Date()))
    }

    func test_hasCheckInToday_isTrue_whenLatestCheckInIsToday() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try repository.saveCheckIn(measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1), date: Date(), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)

        XCTAssertTrue(try repository.hasCheckInToday())
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: FAIL to build — `SessionRepository` is not defined.

- [ ] **Step 3: Write the implementation**

`CoachingKit/Sources/CoachingKit/SessionRepository.swift`:

```swift
import Foundation
import SwiftData

public final class SessionRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func saveBaseline(_ measurement: FaceMeasurement, capturedAt: Date) throws {
        let baseline = Baseline(
            capturedAt: capturedAt,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension
        )
        modelContext.insert(baseline)
        try modelContext.save()
    }

    public func fetchLatestBaseline() throws -> Baseline? {
        var descriptor = FetchDescriptor<Baseline>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func saveCheckIn(
        measurement: FaceMeasurement,
        date: Date,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double
    ) throws {
        let session = CheckInSession(
            date: date,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension,
            lightingQuality: lightingQuality,
            deviceAngleOK: deviceAngleOK,
            scoreDelta: scoreDelta
        )
        modelContext.insert(session)
        try modelContext.save()
    }

    public func fetchLatestCheckIn() throws -> CheckInSession? {
        var descriptor = FetchDescriptor<CheckInSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func hasCheckInToday(calendar: Calendar = .current, now: Date = Date()) throws -> Bool {
        guard let latest = try fetchLatestCheckIn() else { return false }
        return calendar.isDate(latest.date, inSameDayAs: now)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: all `SessionRepositoryTests` pass (5 tests), plus the 3 from Task 1.

- [ ] **Step 5: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/SessionRepository.swift CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift
git commit -m "feat: add SessionRepository for baseline and check-in persistence"
```

---

### Task 4: `FaceTrackingSession` protocol + `BaselineCaptureViewModel`

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/FaceTrackingSession.swift`
- Create: `CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`

- [ ] **Step 1: Write the protocol**

`CoachingKit/Sources/CoachingKit/FaceTrackingSession.swift`:

```swift
import Foundation

public protocol FaceTrackingSession: AnyObject {
    var onUpdate: ((FaceMeasurement) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
    func start()
    func stop()
}
```

- [ ] **Step 2: Write the failing tests**

`CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CoachingKit

final class BaselineCaptureViewModelTests: XCTestCase {
    private final class MockFaceTrackingSession: FaceTrackingSession {
        var onUpdate: ((FaceMeasurement) -> Void)?
        var onError: ((Error) -> Void)?
        private(set) var startCallCount = 0
        private(set) var stopCallCount = 0

        func start() { startCallCount += 1 }
        func stop() { stopCallCount += 1 }

        func emit(_ measurement: FaceMeasurement) {
            onUpdate?(measurement)
        }
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Baseline.self, CheckInSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_captureBaseline_savesMeasurement_andTransitionsToSaved() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { Date(timeIntervalSince1970: 5_000) })

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05))
        try viewModel.captureBaseline()

        XCTAssertEqual(mockSession.startCallCount, 1)
        XCTAssertEqual(mockSession.stopCallCount, 1)
        XCTAssertEqual(viewModel.phase, .saved)
        let saved = try repository.fetchLatestBaseline()
        XCTAssertEqual(saved?.mouthCornerLeft, 0.11)
    }

    func test_captureBaseline_doesNothing_whenNoMeasurementReceivedYet() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository)

        try viewModel.captureBaseline()

        XCTAssertEqual(viewModel.phase, .tracking)
        XCTAssertNil(try repository.fetchLatestBaseline())
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: FAIL to build — `BaselineCaptureViewModel` is not defined.

- [ ] **Step 4: Write the implementation**

`CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
public final class BaselineCaptureViewModel {
    public enum Phase: Equatable {
        case tracking
        case saved
    }

    public private(set) var phase: Phase = .tracking
    public private(set) var latestMeasurement: FaceMeasurement?

    private let session: FaceTrackingSession
    private let repository: SessionRepository
    private let now: () -> Date

    public init(session: FaceTrackingSession, repository: SessionRepository, now: @escaping () -> Date = Date.init) {
        self.session = session
        self.repository = repository
        self.now = now
        self.session.onUpdate = { [weak self] measurement in
            self?.latestMeasurement = measurement
        }
    }

    public func start() {
        session.start()
    }

    public func captureBaseline() throws {
        guard let measurement = latestMeasurement else { return }
        try repository.saveBaseline(measurement, capturedAt: now())
        session.stop()
        phase = .saved
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: all tests pass (10 total).

- [ ] **Step 6: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/FaceTrackingSession.swift CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift
git commit -m "feat: add FaceTrackingSession protocol and BaselineCaptureViewModel"
```

---

### Task 5: `CoachingViewModel`

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/CoachingViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/CoachingViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

`CoachingKit/Tests/CoachingKitTests/CoachingViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CoachingKit

final class CoachingViewModelTests: XCTestCase {
    private final class MockFaceTrackingSession: FaceTrackingSession {
        var onUpdate: ((FaceMeasurement) -> Void)?
        var onError: ((Error) -> Void)?
        private(set) var startCallCount = 0
        private(set) var stopCallCount = 0

        func start() { startCallCount += 1 }
        func stop() { stopCallCount += 1 }

        func emit(_ measurement: FaceMeasurement) {
            onUpdate?(measurement)
        }
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Baseline.self, CheckInSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_complete_savesCheckIn_andTransitionsToCompletedPhase() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline, now: { Date(timeIntervalSince1970: 5_000) })

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        try viewModel.complete()

        XCTAssertEqual(mockSession.startCallCount, 1)
        XCTAssertEqual(mockSession.stopCallCount, 1)

        guard case let .completed(scoreDelta) = viewModel.phase else {
            return XCTFail("Expected .completed phase, got \(viewModel.phase)")
        }
        XCTAssertEqual(scoreDelta, 0.3, accuracy: 0.0001)

        let saved = try repository.fetchLatestCheckIn()
        XCTAssertEqual(saved?.scoreDelta ?? -1, 0.3, accuracy: 0.0001)
    }

    func test_complete_doesNothing_whenNoMeasurementReceivedYet() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        try viewModel.complete()

        XCTAssertEqual(viewModel.phase, .tracking)
        XCTAssertNil(try repository.fetchLatestCheckIn())
    }
}
```

Note: `Phase` is `Equatable` (so `.tracking` comparisons above work directly), but the completed-case assertion pattern-matches instead of comparing the whole enum, to avoid asserting exact floating-point equality on `scoreDelta` through `XCTAssertEqual(_:_:)`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: FAIL to build — `CoachingViewModel` is not defined.

- [ ] **Step 3: Write the implementation**

`CoachingKit/Sources/CoachingKit/CoachingViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
public final class CoachingViewModel {
    public enum Phase: Equatable {
        case tracking
        case completed(scoreDelta: Double)
    }

    public private(set) var phase: Phase = .tracking
    public private(set) var latestMeasurement: FaceMeasurement?

    private let session: FaceTrackingSession
    private let repository: SessionRepository
    private let baseline: Baseline
    private let now: () -> Date

    public init(
        session: FaceTrackingSession,
        repository: SessionRepository,
        baseline: Baseline,
        now: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.repository = repository
        self.baseline = baseline
        self.now = now
        self.session.onUpdate = { [weak self] measurement in
            self?.latestMeasurement = measurement
        }
    }

    public func start() {
        session.start()
    }

    public func complete() throws {
        guard let measurement = latestMeasurement else { return }
        let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
        try repository.saveCheckIn(
            measurement: measurement,
            date: now(),
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: delta
        )
        session.stop()
        phase = .completed(scoreDelta: delta)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: all tests pass (12 total).

- [ ] **Step 5: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/CoachingViewModel.swift CoachingKit/Tests/CoachingKitTests/CoachingViewModelTests.swift
git commit -m "feat: add CoachingViewModel"
```

---

### Task 6: `HomeViewModel`

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/HomeViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/HomeViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

`CoachingKit/Tests/CoachingKitTests/HomeViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CoachingKit

final class HomeViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Baseline.self, CheckInSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_refresh_setsHasCheckedInToday_true_whenCheckInExistsToday() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        try repository.saveCheckIn(measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1), date: Date(), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertTrue(viewModel.hasCheckedInToday)
    }

    func test_refresh_setsHasCheckedInToday_false_whenNoCheckInToday() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertFalse(viewModel.hasCheckedInToday)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: FAIL to build — `HomeViewModel` is not defined.

- [ ] **Step 3: Write the implementation**

`CoachingKit/Sources/CoachingKit/HomeViewModel.swift`:

```swift
import Foundation
import Observation

@Observable
public final class HomeViewModel {
    public private(set) var hasCheckedInToday: Bool = false

    private let repository: SessionRepository

    public init(repository: SessionRepository) {
        self.repository = repository
    }

    public func refresh() throws {
        hasCheckedInToday = try repository.hasCheckInToday()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test`
Expected: all tests pass (14 total).

- [ ] **Step 5: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add CoachingKit/Sources/CoachingKit/HomeViewModel.swift CoachingKit/Tests/CoachingKitTests/HomeViewModelTests.swift
git commit -m "feat: add HomeViewModel"
```

**CoachingKit is now feature-complete for Phase 1 and fully covered by `swift test`. Remaining tasks integrate it into the Xcode app target.**

---

### Task 7: Wire CoachingKit into the SmileDay Xcode target

**Files:**
- Modify: `SmileDay.xcodeproj/project.pbxproj` (via Xcode UI, not hand-edited — see rationale below)

The project already declares an empty `packageProductDependencies = ();` on the `SmileDay` native target (confirmed by inspection), so this is a standard "add local package" operation. Hand-editing `project.pbxproj` to wire `XCLocalSwiftPackageReference` / `XCSwiftPackageProductDependency` objects is possible but risks producing a project Xcode can't parse, with no fast way to verify short of opening Xcode anyway — so do this step through Xcode itself:

- [ ] **Step 1: Open the project**

```bash
open /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/SmileDay.xcodeproj
```

- [ ] **Step 2: Add the local package dependency**

In Xcode: **File → Add Package Dependencies…** → click **Add Local…** at the bottom left → navigate to and select `/Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit` → **Add Package**. When prompted to choose the product, check **CoachingKit** for the **SmileDay** target → **Add Package**.

- [ ] **Step 3: Verify via command line**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`. If it fails with a package resolution error, re-run Step 2 — the dependency wasn't added correctly.

- [ ] **Step 4: Confirm the pbxproj changed as expected**

```bash
grep -c "CoachingKit" /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/SmileDay.xcodeproj/project.pbxproj
```

Expected: a non-zero count (package reference, product dependency, and build file entries).

- [ ] **Step 5: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add SmileDay.xcodeproj/project.pbxproj
git commit -m "chore: add CoachingKit as a local package dependency"
```

---

### Task 8: SwiftData `ModelContainer` + camera usage description

**Files:**
- Modify: `SmileDay/SmileDayApp.swift`
- Modify: `SmileDay.xcodeproj/project.pbxproj`

- [ ] **Step 1: Wire the ModelContainer in the app entry point**

Replace the full contents of `SmileDay/SmileDayApp.swift`:

```swift
//
//  SmileDayApp.swift
//  SmileDay
//
//  Created by 이종환 on 7/18/26.
//

import SwiftUI
import SwiftData
import CoachingKit

@main
struct SmileDayApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Baseline.self, CheckInSession.self])
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

(`RootView` doesn't exist yet — it's created in Task 13. The project will not compile again until then; that's expected and each intervening task is still independently git-committed.)

- [ ] **Step 2: Add the camera usage description build setting**

The project uses `GENERATE_INFOPLIST_FILE = YES`, so the usage string is a build setting, not a plist file edit. Add `INFOPLIST_KEY_NSCameraUsageDescription` right after `GENERATE_INFOPLIST_FILE = YES;` in both the Debug and Release configurations of the `SmileDay` target (this exact line appears twice, once per configuration):

Find:
```
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
```

Replace both occurrences with:
```
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_NSCameraUsageDescription = "카메라로 촬영한 얼굴 표정 데이터는 이 기기에만 저장되며 외부로 전송되지 않습니다.";
```

- [ ] **Step 3: Verify the setting was added to both configurations**

```bash
grep -c "INFOPLIST_KEY_NSCameraUsageDescription" /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/SmileDay.xcodeproj/project.pbxproj
```

Expected: `2`

- [ ] **Step 4: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add SmileDay/SmileDayApp.swift SmileDay.xcodeproj/project.pbxproj
git commit -m "feat: wire SwiftData ModelContainer and add camera usage description"
```

---

### Task 9: `ARKitFaceTrackingSession` + `ARFacePreviewRepresentable`

**Files:**
- Create: `SmileDay/Services/ARKitFaceTrackingSession.swift`
- Create: `SmileDay/Services/ARFacePreviewRepresentable.swift`

This is the one piece that cannot be unit tested — `ARFaceTrackingConfiguration` only runs on a physical TrueDepth device. It's kept as thin as possible: all it does is translate ARKit's `ARFaceAnchor.blendShapes` into a `FaceMeasurement` and hand it to the `FaceTrackingSession` protocol from `CoachingKit`. Correctness is checked manually on-device in Task 14.

- [ ] **Step 1: Write the ARKit session wrapper**

`SmileDay/Services/ARKitFaceTrackingSession.swift`:

```swift
import ARKit
import SceneKit
import CoachingKit

enum FaceTrackingError: Error {
    case unsupportedDevice
}

final class ARKitFaceTrackingSession: NSObject, FaceTrackingSession {
    var onUpdate: ((FaceMeasurement) -> Void)?
    var onError: ((Error) -> Void)?

    let previewView = ARSCNView()

    override init() {
        super.init()
        previewView.delegate = self
        previewView.session.delegate = self
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            onError?(FaceTrackingError.unsupportedDevice)
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        previewView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        previewView.session.pause()
    }
}

extension ARKitFaceTrackingSession: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        let blendShapes = faceAnchor.blendShapes

        let mouthCornerLeft = blendShapes[.mouthSmileLeft]?.doubleValue ?? 0
        let mouthCornerRight = blendShapes[.mouthSmileRight]?.doubleValue ?? 0
        let browDownLeft = blendShapes[.browDownLeft]?.doubleValue ?? 0
        let browDownRight = blendShapes[.browDownRight]?.doubleValue ?? 0
        let browInnerUp = blendShapes[.browInnerUp]?.doubleValue ?? 0
        let browTension = (browDownLeft + browDownRight + browInnerUp) / 3

        let measurement = FaceMeasurement(
            mouthCornerLeft: mouthCornerLeft,
            mouthCornerRight: mouthCornerRight,
            browTension: browTension
        )

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(measurement)
        }
    }
}

extension ARKitFaceTrackingSession: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        onError?(error)
    }
}
```

- [ ] **Step 2: Write the SwiftUI camera preview wrapper**

`SmileDay/Services/ARFacePreviewRepresentable.swift`:

```swift
import SwiftUI
import ARKit

struct ARFacePreviewRepresentable: UIViewRepresentable {
    let session: ARKitFaceTrackingSession

    func makeUIView(context: Context) -> ARSCNView {
        session.previewView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
```

- [ ] **Step 3: Verify the app target compiles**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: still fails at this point because `RootView` (used in `SmileDayApp.swift`) doesn't exist yet — confirm the *only* remaining error mentions `RootView`, not `ARKitFaceTrackingSession`/`ARFacePreviewRepresentable`/`CoachingKit`. That isolates this task's code as correct.

- [ ] **Step 4: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add SmileDay/Services/ARKitFaceTrackingSession.swift SmileDay/Services/ARFacePreviewRepresentable.swift
git commit -m "feat: add ARKit face tracking session and camera preview wrapper"
```

---

### Task 10: `BaselineCaptureView`

**Files:**
- Create: `SmileDay/Views/Onboarding/BaselineCaptureView.swift`

- [ ] **Step 1: Write the view**

`SmileDay/Views/Onboarding/BaselineCaptureView.swift`:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct BaselineCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: BaselineCaptureViewModel?

    let onBaselineSaved: (Baseline) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("무표정으로 카메라를 바라봐주세요")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("이 앱은 의학적 효과를 보장하지 않습니다. 심한 비대칭이나 안면마비가 의심되면 전문의 상담을 권장합니다.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("기준선 저장") {
                    saveBaseline()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel?.latestMeasurement == nil)
            }
            .padding()
            .background(.black.opacity(0.4))
        }
        .onAppear {
            let vm = BaselineCaptureViewModel(
                session: trackingSession,
                repository: SessionRepository(modelContext: modelContext)
            )
            viewModel = vm
            vm.start()
        }
    }

    private func saveBaseline() {
        guard let viewModel else { return }
        try? viewModel.captureBaseline()
        if let saved = try? SessionRepository(modelContext: modelContext).fetchLatestBaseline() {
            onBaselineSaved(saved)
        }
    }
}
```

The medical-disclaimer copy and the "인지·기록" framing follow the spec's Section 1 wording rules verbatim ("의학적 효과를 보장하지 않으며, 심한 비대칭이나 안면마비가 의심되면 전문의 상담을 권장한다").

- [ ] **Step 2: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add SmileDay/Views/Onboarding/BaselineCaptureView.swift
git commit -m "feat: add BaselineCaptureView onboarding screen"
```

---

### Task 11: `CoachingSessionView` + `SessionSummarySheet`

**Files:**
- Create: `SmileDay/Views/Coaching/CoachingSessionView.swift`
- Create: `SmileDay/Views/Coaching/SessionSummarySheet.swift`

- [ ] **Step 1: Write the summary sheet**

`SmileDay/Views/Coaching/SessionSummarySheet.swift`:

```swift
import SwiftUI

struct SessionSummarySheet: View {
    let scoreDelta: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("오늘의 기록이 저장되었습니다")
                .font(.headline)

            Text(String(format: "기준선 대비 변화량: %.2f", scoreDelta))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("닫기") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    SessionSummarySheet(scoreDelta: 0.12)
}
```

- [ ] **Step 2: Write the coaching session view**

`SmileDay/Views/Coaching/CoachingSessionView.swift`:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct CoachingSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: CoachingViewModel?
    @State private var isShowingSummary = false

    let baseline: Baseline

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if let measurement = viewModel?.latestMeasurement {
                    let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
                    GaugeView(value: delta)
                }

                Button("완료") {
                    try? viewModel?.complete()
                    isShowingSummary = true
                }
                .buttonStyle(.borderedProminent)
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
        .sheet(isPresented: $isShowingSummary) {
            if let viewModel, case let .completed(scoreDelta) = viewModel.phase {
                SessionSummarySheet(scoreDelta: scoreDelta)
            }
        }
    }
}

private struct GaugeView: View {
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("기준선 대비 변화")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: min(max((value + 1) / 2, 0), 1))
                .tint(.accentColor)
        }
    }
}
```

`GaugeView` maps `scoreDelta` (theoretical range roughly -1...1, since each blend shape is 0...1) onto a 0...1 `ProgressView` via `(value + 1) / 2`, clamped for safety.

- [ ] **Step 3: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add SmileDay/Views/Coaching/CoachingSessionView.swift SmileDay/Views/Coaching/SessionSummarySheet.swift
git commit -m "feat: add CoachingSessionView with live gauge and summary sheet"
```

---

### Task 12: `HomeView`

**Files:**
- Create: `SmileDay/Views/Home/HomeView.swift`

- [ ] **Step 1: Write the view**

`SmileDay/Views/Home/HomeView.swift`:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var isShowingCoaching = false

    let baseline: Baseline

    var body: some View {
        VStack(spacing: 24) {
            if viewModel?.hasCheckedInToday == true {
                Label("오늘 체크인을 완료했습니다", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("오늘의 표정 습관을 기록해보세요")
                    .font(.headline)
                Button("코칭 시작") {
                    isShowingCoaching = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            let vm = HomeViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
        }
        .fullScreenCover(isPresented: $isShowingCoaching, onDismiss: {
            try? viewModel?.refresh()
        }) {
            CoachingSessionView(baseline: baseline)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add SmileDay/Views/Home/HomeView.swift
git commit -m "feat: add HomeView"
```

---

### Task 13: `RootView` (replaces `ContentView`)

**Files:**
- Create: `SmileDay/Views/RootView.swift`
- Delete: `SmileDay/ContentView.swift`

- [ ] **Step 1: Write RootView**

`SmileDay/Views/RootView.swift`:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var baseline: Baseline?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let baseline {
                HomeView(baseline: baseline)
            } else {
                BaselineCaptureView { savedBaseline in
                    baseline = savedBaseline
                }
            }
        }
        .task {
            let repository = SessionRepository(modelContext: modelContext)
            baseline = try? repository.fetchLatestBaseline()
            isLoading = false
        }
    }
}
```

- [ ] **Step 2: Delete the template ContentView**

```bash
rm /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/SmileDay/ContentView.swift
```

(The file-system-synchronized group means Xcode picks this deletion up automatically — no pbxproj edit needed.)

- [ ] **Step 3: Build for the simulator**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `** BUILD SUCCEEDED **`. This is the first point where the whole app target compiles end-to-end.

- [ ] **Step 4: Commit**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git add SmileDay/Views/RootView.swift
git rm SmileDay/ContentView.swift
git commit -m "feat: add RootView baseline gate, remove template ContentView"
```

---

### Task 14: Manual on-device verification

**No files change in this task.** ARKit face tracking cannot run in the Simulator (`ARFaceTrackingConfiguration.isSupported` is `false` there), so this is the only way to confirm the coaching flow actually works.

- [ ] **Step 1: Run on a TrueDepth device**

Connect a Face ID iPhone, then:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'generic/platform=iOS' build
```

Expected: `** BUILD SUCCEEDED **`. Then run from Xcode (▶) with the device selected as the destination, since `xcodebuild` alone won't install/launch on a device without additional provisioning arguments.

- [ ] **Step 2: Walk the onboarding flow**

- [ ] Camera permission prompt appears with the Korean usage description from Task 8, Step 2.
- [ ] After granting permission, the live camera preview renders in `BaselineCaptureView`.
- [ ] "기준선 저장" is disabled until a face is detected, then becomes enabled.
- [ ] Tapping it transitions to `HomeView`.

- [ ] **Step 3: Walk the coaching flow**

- [ ] From `HomeView`, tap "코칭 시작" — `CoachingSessionView` presents full-screen with a live camera preview.
- [ ] Making an exaggerated smile visibly moves the gauge bar.
- [ ] Tapping "완료" presents `SessionSummarySheet` with a non-zero `scoreDelta` when the face differs from the baseline.
- [ ] Dismissing the sheet returns to `HomeView`, which now shows "오늘 체크인을 완료했습니다" instead of the start button.

- [ ] **Step 4: Restart the app and confirm persistence**

- [ ] Force-quit and relaunch the app.
- [ ] `RootView` skips `BaselineCaptureView` (baseline persisted) and goes straight to `HomeView`.
- [ ] `HomeView` still shows "오늘 체크인을 완료했습니다" (check-in persisted).

- [ ] **Step 5: Record the result**

If all checks pass, Phase 1 (MVP) is complete per the spec. If any step fails, file it as a follow-up — do not silently patch scope back into the spec without updating `docs/superpowers/specs/2026-07-18-expression-coach-design.md` first.

---

## Plan Self-Review

**Spec coverage:** Onboarding baseline capture (Task 10), coaching screen with ARKit blend shapes + gauge overlay (Tasks 9, 11), session save via SwiftData (Tasks 2–3, 5), simple home screen (Task 12) — all four Phase 1 milestone items from the spec's Section 7 are covered. The positioning/wording guardrails from Section 1 are embedded directly in `BaselineCaptureView`'s copy (Task 10). The `lightingQuality`/`deviceAngleOK` schema fields from Section 4 are present with documented Phase 1 defaults (Task 2) so Phase 3 doesn't require a migration.

**Not in this plan (by design, deferred to later phases per the spec's own milestones):** Vision fallback for non-TrueDepth devices, real lighting/angle detection, baseline reset flow, History tab, Settings tab, reminders, routines. These are Phase 2/3/4 in the spec and are out of scope for a Phase 1 plan.

**Placeholder scan:** No TBD/TODO markers; every step has complete, runnable code or an exact command with an expected result.

**Type consistency:** `FaceMeasurement`, `ScoreCalculator.delta`, `SessionRepository`'s method signatures, and `FaceTrackingSession`'s `onUpdate`/`onError`/`start`/`stop` are defined once in Tasks 1–4 and used identically (same names, same parameter labels) in every later task.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-18-expression-coach-phase1-mvp.md`. Two execution options:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
