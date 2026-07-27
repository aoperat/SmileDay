# 기준선 신뢰성 & 관리 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기준선(Baseline) 촬영에 조명/각도 신뢰도 판정과 1초 안정화 요구를 추가하고, 재설정 안내·권장 시점·오래된 기준선 자동 정리를 구현한다.

**Architecture:** `CoachingKit` 패키지의 `Baseline` 모델과 `SessionRepository`에 신뢰도 필드/정리 메서드를 추가하고, `BaselineCaptureViewModel`이 기존 `CoachingViewModel`과 동일한 조명/각도 판정 패턴을 재사용하도록 확장한다. `SettingsViewModel`에 재설정 권장 계산 프로퍼티를 추가한다. UI 변경은 `SmileDay` 앱 타겟의 `BaselineCaptureView`/`SettingsView`에 국한한다.

**Tech Stack:** Swift, SwiftUI, SwiftData, XCTest, Swift Observation(`@Observable`)

**참고 스펙**: `SmileDay/docs/superpowers/specs/2026-07-23-baseline-reliability-design.md`

---

## 사전 확인

이 플랜의 모든 `swift test` 명령은 저장소 루트에서 실행한다:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
```

앱 타겟(SmileDay) 빌드 확인이 필요한 태스크에서는 저장소 루트에서 실행한다:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' build
```

---

### Task 1: Baseline 모델에 신뢰도 필드 추가 + 촬영 시 조명/각도 신호 연결

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/Baseline.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SessionRepository.swift:11-22`
- Modify: `CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift`
- Modify: `SmileDay/Services/DemoSeeder.swift:13-16`
- Test: `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift:13-23`
- Test: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift:77-88`
- Test: `CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`

- [ ] **Step 1: `Baseline` 모델에 `lightingQuality`/`deviceAngleOK` 필드 추가**

`CoachingKit/Sources/CoachingKit/Baseline.swift` 전체를 다음으로 교체:

```swift
import Foundation
import SwiftData

@Model
public final class Baseline {
    public var capturedAt: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double
    public var lightingQuality: Double
    public var deviceAngleOK: Bool

    public init(
        capturedAt: Date,
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        lightingQuality: Double,
        deviceAngleOK: Bool
    ) {
        self.capturedAt = capturedAt
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.lightingQuality = lightingQuality
        self.deviceAngleOK = deviceAngleOK
    }

    public var measurement: FaceMeasurement {
        FaceMeasurement(mouthCornerLeft: mouthCornerLeft, mouthCornerRight: mouthCornerRight, browTension: browTension)
    }
}
```

- [ ] **Step 2: `SessionRepository.saveBaseline` 시그니처 확장**

`CoachingKit/Sources/CoachingKit/SessionRepository.swift`의 `saveBaseline` 메서드(11~22번 줄, `@discardableResult` 포함)를 다음으로 교체:

```swift
    @discardableResult
    public func saveBaseline(
        _ measurement: FaceMeasurement,
        capturedAt: Date,
        lightingQuality: Double,
        deviceAngleOK: Bool
    ) throws -> Baseline {
        let baseline = Baseline(
            capturedAt: capturedAt,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension,
            lightingQuality: lightingQuality,
            deviceAngleOK: deviceAngleOK
        )
        modelContext.insert(baseline)
        try modelContext.save()
        return baseline
    }
```

- [ ] **Step 3: 기존 `saveBaseline` 테스트 호출부 갱신**

`CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`의 `test_saveBaseline_thenFetchLatestBaseline_returnsSavedValues`(13~23번 줄)를 다음으로 교체:

```swift
    func test_saveBaseline_thenFetchLatestBaseline_returnsSavedValues() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let measurement = FaceMeasurement(mouthCornerLeft: 0.12, mouthCornerRight: 0.14, browTension: 0.2)

        try repository.saveBaseline(measurement, capturedAt: Date(timeIntervalSince1970: 1_000), lightingQuality: 1.0, deviceAngleOK: true)

        let fetched = try repository.fetchLatestBaseline()
        XCTAssertEqual(fetched?.mouthCornerLeft, 0.12)
        XCTAssertEqual(fetched?.mouthCornerRight, 0.14)
        XCTAssertEqual(fetched?.browTension, 0.2)
    }
```

`CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`의 `test_refresh_computesBaselineAgeWeeks`(77~88번 줄)를 다음으로 교체:

```swift
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
```

- [ ] **Step 4: `DemoSeeder`의 `saveBaseline` 호출부 갱신**

`SmileDay/Services/DemoSeeder.swift`의 13~16번 줄을 다음으로 교체:

```swift
        try repository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.3, mouthCornerRight: 0.3, browTension: 0.2),
            capturedAt: calendar.date(byAdding: .weekOfYear, value: -3, to: now) ?? now,
            lightingQuality: 1.0,
            deviceAngleOK: true
        )
```

- [ ] **Step 5: `BaselineCaptureViewModel`에 조명/각도 신호 연결**

`CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift` 전체를 다음으로 교체:

```swift
import Foundation
import Observation

@Observable
public final class BaselineCaptureViewModel {
    public enum Phase: Equatable {
        case tracking
        case saved(Baseline)
    }

    public private(set) var phase: Phase = .tracking
    public private(set) var latestMeasurement: FaceMeasurement?
    @ObservationIgnored public private(set) var latestAmbientIntensity: Double?
    public private(set) var isLightingPoor: Bool = false
    public private(set) var isAngleOK: Bool = true

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
        self.session.onLightingUpdate = { [weak self] intensity in
            guard let self else { return }
            self.latestAmbientIntensity = intensity
            let poor = LightingEvaluator.isTooDark(ambientIntensity: intensity)
            if poor != self.isLightingPoor {
                self.isLightingPoor = poor
            }
        }
        self.session.onTrackingQualityUpdate = { [weak self] ok in
            self?.isAngleOK = ok
        }
    }

    public func start() {
        session.start()
    }

    public func captureBaseline() throws {
        guard phase == .tracking, let measurement = latestMeasurement else { return }
        let baseline = try repository.saveBaseline(
            measurement,
            capturedAt: now(),
            lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0,
            deviceAngleOK: isAngleOK
        )
        session.stop()
        phase = .saved(baseline)
    }
}
```

- [ ] **Step 6: `BaselineCaptureViewModelTests`에 조명/각도 테스트 추가**

`CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`의 `MockFaceTrackingSession`(6~24번 줄)에 `emitTrackingQuality` 헬퍼 추가 — 다음으로 교체:

```swift
    private final class MockFaceTrackingSession: FaceTrackingSession {
        var onUpdate: ((FaceMeasurement) -> Void)?
        var onError: ((Error) -> Void)?
        var onLightingUpdate: ((Double) -> Void)?
        var onTrackingQualityUpdate: ((Bool) -> Void)?
        private(set) var startCallCount = 0
        private(set) var stopCallCount = 0

        func start() { startCallCount += 1 }
        func stop() { stopCallCount += 1 }

        func emit(_ measurement: FaceMeasurement) {
            onUpdate?(measurement)
        }

        func emitLighting(_ intensity: Double) {
            onLightingUpdate?(intensity)
        }

        func emitTrackingQuality(_ ok: Bool) {
            onTrackingQualityUpdate?(ok)
        }
    }
```

파일 맨 끝(마지막 `}` 앞)에 다음 테스트 3개를 추가:

```swift
    func test_isLightingPoor_true_whenAmbientBelowThreshold() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository)

        XCTAssertFalse(viewModel.isLightingPoor)
        mockSession.emitLighting(200)
        XCTAssertTrue(viewModel.isLightingPoor)
        mockSession.emitLighting(800)
        XCTAssertFalse(viewModel.isLightingPoor)
    }

    func test_isAngleOK_defaultsTrue_andFollowsTrackingQualityUpdates() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository)

        XCTAssertTrue(viewModel.isAngleOK)
        mockSession.emitTrackingQuality(false)
        XCTAssertFalse(viewModel.isAngleOK)
        mockSession.emitTrackingQuality(true)
        XCTAssertTrue(viewModel.isAngleOK)
    }

    func test_captureBaseline_persistsMeasuredLightingAndAngle() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { Date(timeIntervalSince1970: 5_000) })

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05))
        mockSession.emitLighting(500)
        mockSession.emitTrackingQuality(false)
        try viewModel.captureBaseline()

        let saved = try XCTUnwrap(try repository.fetchLatestBaseline())
        XCTAssertEqual(saved.lightingQuality, 0.5, accuracy: 0.001)
        XCTAssertFalse(saved.deviceAngleOK)
    }
```

- [ ] **Step 7: 테스트 실행**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test
```
Expected: 모든 테스트 통과 (신규 3개 포함).

- [ ] **Step 8: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/Baseline.swift CoachingKit/Sources/CoachingKit/SessionRepository.swift CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift SmileDay/Services/DemoSeeder.swift CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift
git commit -m "feat: capture lighting/angle reliability signal with baseline"
```

---

### Task 2: 오래된 기준선 자동 정리

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/SessionRepository.swift`
- Modify: `CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`

- [ ] **Step 1: `pruneOldBaselines` 실패하는 테스트 작성**

`CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift` 파일 맨 끝(마지막 `}` 앞)에 추가:

```swift
    func test_pruneOldBaselines_keepsOnlyMostRecentN() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        for offset in 0..<8 {
            try repository.saveBaseline(
                FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
                capturedAt: day(-offset),
                lightingQuality: 1.0,
                deviceAngleOK: true
            )
        }

        try repository.pruneOldBaselines(keeping: 5)

        let remaining = try context.fetch(FetchDescriptor<Baseline>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]))
        XCTAssertEqual(remaining.count, 5)
        XCTAssertEqual(remaining.first?.capturedAt, day(0))
        XCTAssertEqual(remaining.last?.capturedAt, day(-4))
    }

    func test_pruneOldBaselines_doesNothing_whenCountAtOrBelowLimit() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        for offset in 0..<3 {
            try repository.saveBaseline(
                FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
                capturedAt: day(-offset),
                lightingQuality: 1.0,
                deviceAngleOK: true
            )
        }

        try repository.pruneOldBaselines(keeping: 5)

        let remaining = try context.fetch(FetchDescriptor<Baseline>())
        XCTAssertEqual(remaining.count, 3)
    }
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test 2>&1 | grep -A2 "pruneOldBaselines"
```
Expected: FAIL — `value of type 'SessionRepository' has no member 'pruneOldBaselines'` (컴파일 에러)

- [ ] **Step 3: `pruneOldBaselines` 구현**

`CoachingKit/Sources/CoachingKit/SessionRepository.swift`의 `recentCheckInDays` 메서드(현재 파일 맨 끝 메서드) 바로 다음, 클래스 닫는 `}` 직전에 추가:

```swift

    public func pruneOldBaselines(keeping: Int = 5) throws {
        let descriptor = FetchDescriptor<Baseline>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        let all = try modelContext.fetch(descriptor)
        guard all.count > keeping else { return }
        for baseline in all.dropFirst(keeping) {
            modelContext.delete(baseline)
        }
        try modelContext.save()
    }
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test 2>&1 | grep -A2 "pruneOldBaselines"
```
Expected: PASS (2개 테스트 모두)

- [ ] **Step 5: `captureBaseline()`에서 자동 호출하도록 연결 — 실패하는 테스트 작성**

`CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift` 파일 맨 끝(마지막 `}` 앞)에 추가:

```swift
    func test_captureBaseline_prunesOldBaselines_keepingMostRecentFive() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        for offset in 1...6 {
            try repository.saveBaseline(
                FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
                capturedAt: Date(timeIntervalSince1970: Double(offset) * 1_000),
                lightingQuality: 1.0,
                deviceAngleOK: true
            )
        }
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { Date(timeIntervalSince1970: 10_000) })

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.5, mouthCornerRight: 0.5, browTension: 0.5))
        try viewModel.captureBaseline()

        let remaining = try context.fetch(FetchDescriptor<Baseline>())
        XCTAssertEqual(remaining.count, 5)
    }
```

- [ ] **Step 6: 테스트 실행해서 실패 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test 2>&1 | grep -A5 "test_captureBaseline_prunesOldBaselines"
```
Expected: FAIL — `remaining.count`가 7 (정리 안 됨)

- [ ] **Step 7: `captureBaseline()`에 `pruneOldBaselines` 호출 추가**

`CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift`의 `captureBaseline()` 메서드를 다음으로 교체:

```swift
    public func captureBaseline() throws {
        guard phase == .tracking, let measurement = latestMeasurement else { return }
        let baseline = try repository.saveBaseline(
            measurement,
            capturedAt: now(),
            lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0,
            deviceAngleOK: isAngleOK
        )
        try repository.pruneOldBaselines()
        session.stop()
        phase = .saved(baseline)
    }
```

- [ ] **Step 8: 테스트 실행해서 통과 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test
```
Expected: 모든 테스트 통과

- [ ] **Step 9: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/SessionRepository.swift CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift
git commit -m "feat: auto-prune old baselines, keeping the most recent five"
```

---

### Task 3: 촬영 전 1초 안정화 요구

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`

이 태스크는 `latestMeasurement`가 잡히는 즉시 저장 가능했던 기존 동작을 바꾸므로, Task 1~2에서 작성한 기존 테스트들도 함께 갱신한다.

- [ ] **Step 1: 시간 제어용 `MutableClock` 테스트 헬퍼 추가**

`CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`의 `MockFaceTrackingSession` 클래스 정의 바로 다음(현재 26번 줄 `makeInMemoryContext` 앞)에 추가:

```swift

    private final class MutableClock {
        var current: Date
        init(_ current: Date) { self.current = current }
        func advance(by seconds: TimeInterval) { current.addTimeInterval(seconds) }
    }
```

- [ ] **Step 2: 안정화 요구 사항에 대한 실패하는 테스트 작성**

같은 파일 맨 끝(마지막 `}` 앞)에 추가:

```swift
    func test_isStable_requiresOneSecondWithinTolerance() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let mockSession = MockFaceTrackingSession()
        let clock = MutableClock(Date(timeIntervalSince1970: 0))
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { clock.current })
        let measurement = FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05)

        mockSession.emit(measurement)
        XCTAssertFalse(viewModel.isStable)

        clock.advance(by: 0.5)
        mockSession.emit(measurement)
        XCTAssertFalse(viewModel.isStable, "0.5초 경과는 아직 1초 미만")

        clock.advance(by: 0.6)
        mockSession.emit(measurement)
        XCTAssertTrue(viewModel.isStable, "1.1초 경과 후엔 안정화됨")
    }

    func test_isStable_resetsWhenMeasurementDrifts() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let mockSession = MockFaceTrackingSession()
        let clock = MutableClock(Date(timeIntervalSince1970: 0))
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { clock.current })

        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05))
        clock.advance(by: 1.1)
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05))
        XCTAssertTrue(viewModel.isStable)

        // 허용 오차(0.02)를 넘는 변화 — 안정화 타이머가 리셋되어야 한다.
        clock.advance(by: 0.1)
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.5, mouthCornerRight: 0.13, browTension: 0.05))
        XCTAssertFalse(viewModel.isStable)
    }

    func test_captureBaseline_doesNothing_whenNotStable() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let clock = MutableClock(Date(timeIntervalSince1970: 0))
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { clock.current })

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05))
        try viewModel.captureBaseline()

        XCTAssertEqual(viewModel.phase, .tracking)
        XCTAssertNil(try repository.fetchLatestBaseline())
    }
```

- [ ] **Step 3: 테스트 실행해서 실패 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test 2>&1 | grep -E "test_isStable|test_captureBaseline_doesNothing_whenNotStable"
```
Expected: FAIL — `viewModel`에 `isStable` 멤버가 없음(컴파일 에러)

- [ ] **Step 4: 안정화 추적 로직 구현**

`CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift` 전체를 다음으로 교체:

```swift
import Foundation
import Observation

@Observable
public final class BaselineCaptureViewModel {
    public enum Phase: Equatable {
        case tracking
        case saved(Baseline)
    }

    public private(set) var phase: Phase = .tracking
    public private(set) var latestMeasurement: FaceMeasurement?
    @ObservationIgnored public private(set) var latestAmbientIntensity: Double?
    public private(set) var isLightingPoor: Bool = false
    public private(set) var isAngleOK: Bool = true
    public private(set) var isStable: Bool = false

    private let session: FaceTrackingSession
    private let repository: SessionRepository
    private let now: () -> Date
    private let stabilityDuration: TimeInterval = 1.0
    private let stabilityTolerance: Double = 0.02
    @ObservationIgnored private var stabilityReference: FaceMeasurement?
    @ObservationIgnored private var stabilityWindowStart: Date?

    public init(session: FaceTrackingSession, repository: SessionRepository, now: @escaping () -> Date = Date.init) {
        self.session = session
        self.repository = repository
        self.now = now
        self.session.onUpdate = { [weak self] measurement in
            guard let self else { return }
            self.latestMeasurement = measurement
            self.updateStability(with: measurement)
        }
        self.session.onLightingUpdate = { [weak self] intensity in
            guard let self else { return }
            self.latestAmbientIntensity = intensity
            let poor = LightingEvaluator.isTooDark(ambientIntensity: intensity)
            if poor != self.isLightingPoor {
                self.isLightingPoor = poor
            }
        }
        self.session.onTrackingQualityUpdate = { [weak self] ok in
            self?.isAngleOK = ok
        }
    }

    public func start() {
        session.start()
    }

    public func captureBaseline() throws {
        guard phase == .tracking, let measurement = latestMeasurement, isStable else { return }
        let baseline = try repository.saveBaseline(
            measurement,
            capturedAt: now(),
            lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0,
            deviceAngleOK: isAngleOK
        )
        try repository.pruneOldBaselines()
        session.stop()
        phase = .saved(baseline)
    }

    private func updateStability(with measurement: FaceMeasurement) {
        if let reference = stabilityReference, isWithinTolerance(measurement, reference) {
            if let windowStart = stabilityWindowStart, now().timeIntervalSince(windowStart) >= stabilityDuration {
                isStable = true
            }
        } else {
            stabilityReference = measurement
            stabilityWindowStart = now()
            isStable = false
        }
    }

    private func isWithinTolerance(_ a: FaceMeasurement, _ b: FaceMeasurement) -> Bool {
        abs(a.mouthCornerLeft - b.mouthCornerLeft) <= stabilityTolerance
            && abs(a.mouthCornerRight - b.mouthCornerRight) <= stabilityTolerance
            && abs(a.browTension - b.browTension) <= stabilityTolerance
    }
}
```

- [ ] **Step 5: 테스트 실행 — 새 테스트는 통과하지만 기존 3개는 실패하는지 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test 2>&1 | tail -40
```
Expected: `test_isStable_*`, `test_captureBaseline_doesNothing_whenNotStable`는 PASS. `test_captureBaseline_savesMeasurement_andTransitionsToSaved`, `test_captureBaseline_secondCallAfterSaved_doesNotPersistDuplicate`, `test_captureBaseline_persistsMeasuredLightingAndAngle`, `test_captureBaseline_prunesOldBaselines_keepingMostRecentFive`는 FAIL (한 프레임만 emit하고 바로 저장 시도해서 `isStable`이 false인 채로 저장이 무시됨).

- [ ] **Step 6: 기존 테스트들이 안정화를 먼저 만족시키도록 갱신**

`CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift`의 `test_captureBaseline_savesMeasurement_andTransitionsToSaved`를 다음으로 교체:

```swift
    func test_captureBaseline_savesMeasurement_andTransitionsToSaved() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let clock = MutableClock(Date(timeIntervalSince1970: 5_000))
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { clock.current })
        let measurement = FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05)

        viewModel.start()
        mockSession.emit(measurement)
        clock.advance(by: 1.1)
        mockSession.emit(measurement)
        try viewModel.captureBaseline()

        XCTAssertEqual(mockSession.startCallCount, 1)
        XCTAssertEqual(mockSession.stopCallCount, 1)
        guard case let .saved(baseline) = viewModel.phase else {
            return XCTFail("Expected .saved phase, got \(viewModel.phase)")
        }
        XCTAssertEqual(baseline.mouthCornerLeft, 0.11)
        let saved = try repository.fetchLatestBaseline()
        XCTAssertEqual(saved?.mouthCornerLeft, 0.11)
    }
```

`test_captureBaseline_secondCallAfterSaved_doesNotPersistDuplicate`를 다음으로 교체:

```swift
    func test_captureBaseline_secondCallAfterSaved_doesNotPersistDuplicate() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let clock = MutableClock(Date(timeIntervalSince1970: 5_000))
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { clock.current })
        let measurement = FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05)

        viewModel.start()
        mockSession.emit(measurement)
        clock.advance(by: 1.1)
        mockSession.emit(measurement)
        try viewModel.captureBaseline()

        guard case let .saved(firstBaseline) = viewModel.phase else {
            return XCTFail("Expected .saved phase, got \(viewModel.phase)")
        }
        XCTAssertEqual(mockSession.stopCallCount, 1)

        // Simulate a double-tap: a new measurement arrives and captureBaseline is called again.
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.99, mouthCornerRight: 0.98, browTension: 0.97))
        try viewModel.captureBaseline()

        guard case let .saved(secondBaseline) = viewModel.phase else {
            return XCTFail("Expected .saved phase, got \(viewModel.phase)")
        }
        XCTAssertEqual(secondBaseline, firstBaseline)
        XCTAssertEqual(mockSession.stopCallCount, 1)

        let allBaselines = try context.fetch(FetchDescriptor<Baseline>())
        XCTAssertEqual(allBaselines.count, 1)
        XCTAssertEqual(allBaselines.first?.mouthCornerLeft, 0.11)
    }
```

`test_captureBaseline_persistsMeasuredLightingAndAngle`를 다음으로 교체:

```swift
    func test_captureBaseline_persistsMeasuredLightingAndAngle() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let clock = MutableClock(Date(timeIntervalSince1970: 5_000))
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { clock.current })
        let measurement = FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05)

        viewModel.start()
        mockSession.emit(measurement)
        clock.advance(by: 1.1)
        mockSession.emit(measurement)
        mockSession.emitLighting(500)
        mockSession.emitTrackingQuality(false)
        try viewModel.captureBaseline()

        let saved = try XCTUnwrap(try repository.fetchLatestBaseline())
        XCTAssertEqual(saved.lightingQuality, 0.5, accuracy: 0.001)
        XCTAssertFalse(saved.deviceAngleOK)
    }
```

`test_captureBaseline_prunesOldBaselines_keepingMostRecentFive`를 다음으로 교체:

```swift
    func test_captureBaseline_prunesOldBaselines_keepingMostRecentFive() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        for offset in 1...6 {
            try repository.saveBaseline(
                FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
                capturedAt: Date(timeIntervalSince1970: Double(offset) * 1_000),
                lightingQuality: 1.0,
                deviceAngleOK: true
            )
        }
        let mockSession = MockFaceTrackingSession()
        let clock = MutableClock(Date(timeIntervalSince1970: 10_000))
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { clock.current })
        let measurement = FaceMeasurement(mouthCornerLeft: 0.5, mouthCornerRight: 0.5, browTension: 0.5)

        viewModel.start()
        mockSession.emit(measurement)
        clock.advance(by: 1.1)
        mockSession.emit(measurement)
        try viewModel.captureBaseline()

        let remaining = try context.fetch(FetchDescriptor<Baseline>())
        XCTAssertEqual(remaining.count, 5)
    }
```

- [ ] **Step 7: 테스트 실행해서 전체 통과 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test
```
Expected: 모든 테스트 통과

- [ ] **Step 8: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/BaselineCaptureViewModel.swift CoachingKit/Tests/CoachingKitTests/BaselineCaptureViewModelTests.swift
git commit -m "feat: require 1s stable reading before baseline capture"
```

---

### Task 4: 4주 경과 시 재설정 권장 표시 (뷰모델)

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift` 파일 맨 끝(마지막 `}` 앞)에 추가:

```swift
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
```

- [ ] **Step 2: 테스트 실행해서 실패 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test 2>&1 | grep -A2 "shouldRecommendReset"
```
Expected: FAIL — `viewModel`에 `shouldRecommendReset` 멤버가 없음(컴파일 에러)

- [ ] **Step 3: `shouldRecommendReset` 구현**

`CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`의 `public private(set) var baselineAgeWeeks: Int?` 바로 다음 줄에 추가:

```swift
    public var shouldRecommendReset: Bool {
        (baselineAgeWeeks ?? 0) >= 4
    }
```

- [ ] **Step 4: 테스트 실행해서 통과 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test
```
Expected: 모든 테스트 통과

- [ ] **Step 5: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/SettingsViewModel.swift CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift
git commit -m "feat: compute baseline reset recommendation at 4 weeks"
```

---

### Task 5: `BaselineCaptureView` UI — 경고 배너, 촬영 가이드, 안정화 표시

**Files:**
- Modify: `SmileDay/Views/Onboarding/BaselineCaptureView.swift`

이 태스크는 UI 전용이라 `swift test`로 검증되지 않는다. `xcodebuild`로 컴파일을 확인한다.

- [ ] **Step 1: 경고 배너, 안내 문구, 안정화 진행 표시 추가**

`SmileDay/Views/Onboarding/BaselineCaptureView.swift`의 `BaselineCaptureView` 구조체(1~81번 줄)를 다음으로 교체:

```swift
import SwiftUI
import SwiftData
import CoachingKit

struct BaselineCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingSession = ARKitFaceTrackingSession()
    @State private var viewModel: BaselineCaptureViewModel?
    @State private var errorMessage: String?

    let onBaselineSaved: (Baseline) -> Void
    /// 저장하지 않고 나가기. nil이면 나가기 버튼을 숨긴다.
    var onCancel: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottom) {
            ARFacePreviewRepresentable(session: trackingSession)
                .ignoresSafeArea()

            FaceGuideOverlay()

            VStack(spacing: 8) {
                if let onCancel {
                    HStack {
                        SDCloseButton { onCancel() }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                }

                if viewModel?.isLightingPoor == true {
                    ReliabilityBanner(text: "조금 어두워요 · 밝은 곳에서 촬영해 주세요", systemImage: "exclamationmark.circle.fill")
                }
                if viewModel?.isAngleOK == false {
                    ReliabilityBanner(text: "얼굴을 정면으로 비춰주세요", systemImage: "face.dashed")
                }

                Spacer()
            }

            VStack(spacing: 16) {
                Text("무표정으로 얼굴을 타원 안에 맞춰주세요")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("밝은 곳에서 정면을 바라보고 촬영해주세요")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                MeasurementTable(measurement: viewModel?.latestMeasurement)

                if viewModel?.latestMeasurement != nil && viewModel?.isStable == false {
                    Text("안정화 중...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("기준선 저장") {
                    saveBaseline()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel?.latestMeasurement == nil || viewModel?.phase != .tracking || viewModel?.isStable != true)
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
        .onDisappear {
            trackingSession.stop()
        }
    }

    private func saveBaseline() {
        guard let viewModel else { return }
        do {
            try viewModel.captureBaseline()
        } catch {
            errorMessage = SharedStrings.saveFailed
            return
        }
        if case let .saved(baseline) = viewModel.phase {
            onBaselineSaved(baseline)
        }
    }
}

private struct ReliabilityBanner: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.bold())
            .foregroundStyle(.yellow)
            .padding(8)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
    }
}
```

(파일의 나머지 부분 — `MeasurementTable`, `MeasurementRow` — 은 그대로 둔다.)

- [ ] **Step 2: 앱 타겟 빌드 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add SmileDay/Views/Onboarding/BaselineCaptureView.swift
git commit -m "feat: show reliability banners and stabilization hint during baseline capture"
```

---

### Task 6: `SettingsView` UI — 재설정 권장 표시

**Files:**
- Modify: `SmileDay/Views/Settings/SettingsView.swift:26-36`

- [ ] **Step 1: "기준선 재설정" 행에 권장 표시 추가**

`SmileDay/Views/Settings/SettingsView.swift`의 26~36번 줄을 다음으로 교체:

```swift
                        Button {
                            isResettingBaseline = true
                        } label: {
                            SettingsRow(icon: "arrow.clockwise", chipColor: SDColor.coral, title: "기준선 재설정") {
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let weeks = viewModel.baselineAgeWeeks {
                                        Text("\(weeks)주 전")
                                            .foregroundStyle(viewModel.shouldRecommendReset ? SDColor.coral : SDColor.muted)
                                    }
                                    if viewModel.shouldRecommendReset {
                                        Text("재설정을 권장해요")
                                            .font(.caption2)
                                            .foregroundStyle(SDColor.coral)
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.primary)
```

- [ ] **Step 2: 앱 타겟 빌드 확인**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add SmileDay/Views/Settings/SettingsView.swift
git commit -m "feat: highlight baseline reset row after 4 weeks"
```

---

## 최종 검증

모든 태스크 완료 후:

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay && xcodebuild -scheme SmileDay -destination 'generic/platform=iOS Simulator' build
```

두 명령 모두 성공해야 완료로 간주한다.
