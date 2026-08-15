# 데이터 수집 확장 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ARKit 블렌드셰이프 52개 전체·세션 통계·케어 행동 데이터·기분 이모지를 온디바이스에 수집한다 (스펙: `docs/superpowers/specs/2026-07-23-data-collection-expansion-design.md`).

**Architecture:** CoachingKit(SwiftPM, 테스트 가능)에 순수 로직(`SessionMetricsAccumulator`, `CheckInPayload`, 모델/리포지토리 확장)을 먼저 TDD로 넣고, 앱 레이어(ARKit 세션·뷰)는 마지막에 연결한다. 블렌드셰이프 키는 앱이 ARKit 타입 상수의 rawValue를 주입하므로 문자열 추측이 없다(consistent-by-construction). 새 저장 필드는 전부 optional/기본값 → SwiftData 경량 마이그레이션 자동.

**Tech Stack:** Swift 5.10, SwiftData, SwiftUI, ARKit, XCTest.

**검증 명령:**
- CoachingKit 테스트: `cd CoachingKit && swift test` (macOS에서 실행 가능)
- 앱 빌드: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build` (모든 경로는 리포 루트 `/Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay` 기준)

---

### Task 1: MetricStats + CuratedMetricKeys + SessionMetricsAccumulator

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/SessionMetricsAccumulator.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/SessionMetricsAccumulatorTests.swift`

주의: 이 태스크의 테스트는 Task 2의 `FaceMeasurement.blendShapes` 필드에 의존한다. Task 2를 먼저 읽고 함께 구현해도 된다(커밋은 태스크별로).

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKit/Tests/CoachingKitTests/SessionMetricsAccumulatorTests.swift
import XCTest
@testable import CoachingKit

final class SessionMetricsAccumulatorTests: XCTestCase {
    private let keys = CuratedMetricKeys.default

    private func measurement(smileLeft: Double, smileRight: Double, blendShapes: [String: Double] = [:]) -> FaceMeasurement {
        FaceMeasurement(
            mouthCornerLeft: smileLeft,
            mouthCornerRight: smileRight,
            browTension: 0.1,
            blendShapes: blendShapes
        )
    }

    func test_smileStats_meanMaxStd_fromKnownSequence() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let base = Date(timeIntervalSince1970: 1_000)
        // smile = (L+R)/2 → 0.2, 0.4, 0.6
        accumulator.add(measurement(smileLeft: 0.2, smileRight: 0.2), at: base)
        accumulator.add(measurement(smileLeft: 0.4, smileRight: 0.4), at: base.addingTimeInterval(0.1))
        accumulator.add(measurement(smileLeft: 0.6, smileRight: 0.6), at: base.addingTimeInterval(0.2))

        let summary = accumulator.summarize()
        XCTAssertEqual(summary.smileMean ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(summary.smileMax ?? -1, 0.6, accuracy: 0.0001)
        // 표본 표준편차: sqrt(((−0.2)²+0²+0.2²)/2) = 0.2
        XCTAssertEqual(summary.smileStability ?? -1, 0.2, accuracy: 0.0001)
    }

    func test_smileAsymmetry_isMeanOfLeftMinusRight() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let base = Date(timeIntervalSince1970: 1_000)
        accumulator.add(measurement(smileLeft: 0.5, smileRight: 0.3), at: base)
        accumulator.add(measurement(smileLeft: 0.4, smileRight: 0.4), at: base.addingTimeInterval(0.1))

        XCTAssertEqual(accumulator.summarize().smileAsymmetry ?? -1, 0.1, accuracy: 0.0001)
    }

    func test_duchenneScore_averagesFourSquintKeys_whenAllPresent() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let shapes = [
            keys.eyeSquintLeft: 0.2, keys.eyeSquintRight: 0.4,
            keys.cheekSquintLeft: 0.6, keys.cheekSquintRight: 0.8,
        ]
        accumulator.add(measurement(smileLeft: 0.5, smileRight: 0.5, blendShapes: shapes), at: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(accumulator.summarize().duchenneScore ?? -1, 0.5, accuracy: 0.0001)
    }

    func test_duchenneScore_isNil_whenSquintKeysMissing() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        accumulator.add(measurement(smileLeft: 0.5, smileRight: 0.5), at: Date(timeIntervalSince1970: 1_000))

        XCTAssertNil(accumulator.summarize().duchenneScore)
    }

    func test_curatedStats_trackedPerKey() {
        let accumulator = SessionMetricsAccumulator(keys: keys)
        let base = Date(timeIntervalSince1970: 1_000)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1, blendShapes: [keys.jawOpen: 0.2]), at: base)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1, blendShapes: [keys.jawOpen: 0.6]), at: base.addingTimeInterval(0.1))

        let stats = accumulator.summarize().stats[keys.jawOpen]
        XCTAssertEqual(stats?.mean ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(stats?.max ?? -1, 0.6, accuracy: 0.0001)
    }

    func test_trackingLossCount_countsFrameGapsOverThreshold() {
        let accumulator = SessionMetricsAccumulator(keys: keys, gapThreshold: 0.5)
        let base = Date(timeIntervalSince1970: 1_000)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1), at: base)
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1), at: base.addingTimeInterval(0.1))
        accumulator.add(measurement(smileLeft: 0.1, smileRight: 0.1), at: base.addingTimeInterval(1.0)) // 0.9초 갭 → 유실 1회

        let summary = accumulator.summarize()
        XCTAssertEqual(summary.trackingLossCount, 1)
        XCTAssertEqual(summary.durationSeconds, 1.0, accuracy: 0.0001)
    }

    func test_emptyAccumulator_summarizesToZeroDurationAndNilMetrics() {
        let summary = SessionMetricsAccumulator(keys: keys).summarize()
        XCTAssertEqual(summary.durationSeconds, 0)
        XCTAssertEqual(summary.trackingLossCount, 0)
        XCTAssertNil(summary.smileMean)
        XCTAssertTrue(summary.stats.isEmpty)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter SessionMetricsAccumulatorTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `CuratedMetricKeys`, `SessionMetricsAccumulator` 미정의 (Task 2 전이면 `blendShapes` 파라미터도 미정의)

- [ ] **Step 3: Write the implementation**

```swift
// CoachingKit/Sources/CoachingKit/SessionMetricsAccumulator.swift
import Foundation

/// 지표 하나의 세션 통계 (표본 표준편차).
public struct MetricStats: Codable, Equatable, Sendable {
    public var mean: Double
    public var max: Double
    public var std: Double

    public init(mean: Double, max: Double, std: Double) {
        self.mean = mean
        self.max = max
        self.std = std
    }
}

/// 선별 지표 12개의 블렌드셰이프 딕셔너리 키.
/// 앱 레이어가 ARKit BlendShapeLocation rawValue로 인스턴스를 만들어 주입하므로
/// 프로덕션에서는 문자열 추측이 없다. `default`는 테스트/프리뷰용.
public struct CuratedMetricKeys: Sendable {
    public let mouthSmileLeft: String
    public let mouthSmileRight: String
    public let browDownLeft: String
    public let browDownRight: String
    public let browInnerUp: String
    public let eyeSquintLeft: String
    public let eyeSquintRight: String
    public let cheekSquintLeft: String
    public let cheekSquintRight: String
    public let jawOpen: String
    public let mouthPressLeft: String
    public let mouthPressRight: String

    public init(
        mouthSmileLeft: String, mouthSmileRight: String,
        browDownLeft: String, browDownRight: String, browInnerUp: String,
        eyeSquintLeft: String, eyeSquintRight: String,
        cheekSquintLeft: String, cheekSquintRight: String,
        jawOpen: String,
        mouthPressLeft: String, mouthPressRight: String
    ) {
        self.mouthSmileLeft = mouthSmileLeft
        self.mouthSmileRight = mouthSmileRight
        self.browDownLeft = browDownLeft
        self.browDownRight = browDownRight
        self.browInnerUp = browInnerUp
        self.eyeSquintLeft = eyeSquintLeft
        self.eyeSquintRight = eyeSquintRight
        self.cheekSquintLeft = cheekSquintLeft
        self.cheekSquintRight = cheekSquintRight
        self.jawOpen = jawOpen
        self.mouthPressLeft = mouthPressLeft
        self.mouthPressRight = mouthPressRight
    }

    public var all: [String] {
        [mouthSmileLeft, mouthSmileRight, browDownLeft, browDownRight, browInnerUp,
         eyeSquintLeft, eyeSquintRight, cheekSquintLeft, cheekSquintRight,
         jawOpen, mouthPressLeft, mouthPressRight]
    }

    public static let `default` = CuratedMetricKeys(
        mouthSmileLeft: "mouthSmile_L", mouthSmileRight: "mouthSmile_R",
        browDownLeft: "browDown_L", browDownRight: "browDown_R", browInnerUp: "browInnerUp",
        eyeSquintLeft: "eyeSquint_L", eyeSquintRight: "eyeSquint_R",
        cheekSquintLeft: "cheekSquint_L", cheekSquintRight: "cheekSquint_R",
        jawOpen: "jawOpen",
        mouthPressLeft: "mouthPress_L", mouthPressRight: "mouthPress_R"
    )
}

/// 파생 지표의 stats 딕셔너리 키.
public enum DerivedMetric {
    public static let smile = "smile"
    public static let smileAsymmetry = "smileAsymmetry"
    public static let duchenne = "duchenne"
}

/// 트래킹 세션 동안 프레임을 받아 지표별 mean/max/std를 스트리밍 계산한다.
/// Welford 알고리즘 — 프레임 원본을 쌓지 않으므로 메모리 사용이 일정하다.
public final class SessionMetricsAccumulator {
    public struct Summary: Equatable, Sendable {
        public let stats: [String: MetricStats]
        public let durationSeconds: Double
        public let trackingLossCount: Int

        public var smileMean: Double? { stats[DerivedMetric.smile]?.mean }
        public var smileMax: Double? { stats[DerivedMetric.smile]?.max }
        public var smileStability: Double? { stats[DerivedMetric.smile]?.std }
        public var smileAsymmetry: Double? { stats[DerivedMetric.smileAsymmetry]?.mean }
        public var duchenneScore: Double? { stats[DerivedMetric.duchenne]?.mean }
    }

    private struct Welford {
        var count = 0
        var mean = 0.0
        var m2 = 0.0
        var maxValue = -Double.infinity

        mutating func add(_ value: Double) {
            count += 1
            let delta = value - mean
            mean += delta / Double(count)
            m2 += delta * (value - mean)
            maxValue = Swift.max(maxValue, value)
        }

        var stats: MetricStats {
            MetricStats(mean: mean, max: maxValue, std: count > 1 ? (m2 / Double(count - 1)).squareRoot() : 0)
        }
    }

    private let keys: CuratedMetricKeys
    private let gapThreshold: TimeInterval
    private var welfords: [String: Welford] = [:]
    private var firstFrameAt: Date?
    private var lastFrameAt: Date?
    private var trackingLossCount = 0

    public init(keys: CuratedMetricKeys = .default, gapThreshold: TimeInterval = 0.5) {
        self.keys = keys
        self.gapThreshold = gapThreshold
    }

    public func add(_ measurement: FaceMeasurement, at date: Date) {
        if firstFrameAt == nil { firstFrameAt = date }
        if let last = lastFrameAt, date.timeIntervalSince(last) > gapThreshold {
            trackingLossCount += 1
        }
        lastFrameAt = date

        for key in keys.all {
            if let value = measurement.blendShapes[key] {
                welfords[key, default: Welford()].add(value)
            }
        }

        let smile = (measurement.mouthCornerLeft + measurement.mouthCornerRight) / 2
        welfords[DerivedMetric.smile, default: Welford()].add(smile)
        welfords[DerivedMetric.smileAsymmetry, default: Welford()].add(measurement.mouthCornerLeft - measurement.mouthCornerRight)

        let squints = [keys.eyeSquintLeft, keys.eyeSquintRight, keys.cheekSquintLeft, keys.cheekSquintRight]
            .compactMap { measurement.blendShapes[$0] }
        if squints.count == 4 {
            welfords[DerivedMetric.duchenne, default: Welford()].add(squints.reduce(0, +) / 4)
        }
    }

    public func summarize() -> Summary {
        let duration: Double
        if let first = firstFrameAt, let last = lastFrameAt {
            duration = last.timeIntervalSince(first)
        } else {
            duration = 0
        }
        return Summary(
            stats: welfords.mapValues(\.stats),
            durationSeconds: duration,
            trackingLossCount: trackingLossCount
        )
    }
}
```

- [ ] **Step 4: Task 2의 FaceMeasurement 변경을 먼저 적용해야 컴파일된다** — Task 2 Step 3의 코드를 지금 적용한 뒤 진행 (커밋은 별도).

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd CoachingKit && swift test --filter SessionMetricsAccumulatorTests 2>&1 | tail -5`
Expected: `Executed 7 tests, with 0 failures`

- [ ] **Step 6: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/SessionMetricsAccumulator.swift CoachingKit/Tests/CoachingKitTests/SessionMetricsAccumulatorTests.swift
git commit -m "feat: add SessionMetricsAccumulator with Welford streaming stats"
```

---

### Task 2: FaceMeasurement 확장 (blendShapes, pitch/yaw)

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/FaceMeasurement.swift`

기존 3필드 init 호출부(테스트 다수, DemoSeeder)는 기본값 덕분에 변경 없이 컴파일된다.

- [ ] **Step 1: FaceMeasurement 교체**

```swift
// CoachingKit/Sources/CoachingKit/FaceMeasurement.swift 전체 교체
import Foundation

public struct FaceMeasurement: Equatable, Sendable {
    public let mouthCornerLeft: Double
    public let mouthCornerRight: Double
    public let browTension: Double
    /// 블렌드셰이프 전체 (키: 앱 레이어가 주입한 ARKit rawValue). 테스트/구버전 경로에서는 빈 딕셔너리.
    public let blendShapes: [String: Double]
    /// 얼굴 각도 원본 (도 단위). 트래킹 세션이 제공하지 않으면 nil.
    public let pitchDegrees: Double?
    public let yawDegrees: Double?

    public init(
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        blendShapes: [String: Double] = [:],
        pitchDegrees: Double? = nil,
        yawDegrees: Double? = nil
    ) {
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.blendShapes = blendShapes
        self.pitchDegrees = pitchDegrees
        self.yawDegrees = yawDegrees
    }
}
```

- [ ] **Step 2: 전체 테스트로 회귀 확인**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과 (기존 테스트는 기본값으로 컴파일 유지)

- [ ] **Step 3: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/FaceMeasurement.swift
git commit -m "feat: carry full blendshapes and head angles in FaceMeasurement"
```

---

### Task 3: CheckInPayload (Codable)

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/CheckInPayload.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/CheckInPayloadTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKit/Tests/CoachingKitTests/CheckInPayloadTests.swift
import XCTest
@testable import CoachingKit

final class CheckInPayloadTests: XCTestCase {
    func test_encodeDecode_roundTrip() throws {
        let payload = CheckInPayload(
            blendshapesFinal: ["mouthSmile_L": 0.42, "jawOpen": 0.1],
            sessionStats: ["smile": MetricStats(mean: 0.4, max: 0.6, std: 0.2)],
            pitchDegrees: 3.5,
            yawDegrees: -1.2,
            captureDurationSeconds: 12.5,
            trackingLossCount: 2
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CheckInPayload.self, from: data)

        XCTAssertEqual(decoded, payload)
    }

    func test_decode_missingOptionalAngles_succeeds() throws {
        let json = """
        {"blendshapesFinal":{},"sessionStats":{},"captureDurationSeconds":0,"trackingLossCount":0}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CheckInPayload.self, from: json)
        XCTAssertNil(decoded.pitchDegrees)
        XCTAssertNil(decoded.yawDegrees)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter CheckInPayloadTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `CheckInPayload` 미정의

- [ ] **Step 3: Write the implementation**

```swift
// CoachingKit/Sources/CoachingKit/CheckInPayload.swift
import Foundation

/// 체크인 1회의 확장 데이터. CheckInSession.payload에 JSON으로 저장된다.
/// 스키마 확장은 optional 필드 추가 + payloadVersion 증가로 한다.
public struct CheckInPayload: Codable, Equatable, Sendable {
    public var blendshapesFinal: [String: Double]
    public var sessionStats: [String: MetricStats]
    public var pitchDegrees: Double?
    public var yawDegrees: Double?
    public var captureDurationSeconds: Double
    public var trackingLossCount: Int

    public static let currentVersion = 1

    public init(
        blendshapesFinal: [String: Double],
        sessionStats: [String: MetricStats],
        pitchDegrees: Double?,
        yawDegrees: Double?,
        captureDurationSeconds: Double,
        trackingLossCount: Int
    ) {
        self.blendshapesFinal = blendshapesFinal
        self.sessionStats = sessionStats
        self.pitchDegrees = pitchDegrees
        self.yawDegrees = yawDegrees
        self.captureDurationSeconds = captureDurationSeconds
        self.trackingLossCount = trackingLossCount
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd CoachingKit && swift test --filter CheckInPayloadTests 2>&1 | tail -3`
Expected: `Executed 2 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/CheckInPayload.swift CoachingKit/Tests/CoachingKitTests/CheckInPayloadTests.swift
git commit -m "feat: add versioned CheckInPayload codable"
```

---

### Task 4: CheckInSession 모델 + SessionRepository 확장

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CheckInSession.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SessionRepository.swift:37-55` (saveCheckIn), 파일 끝에 updateMoodOnLatestCheckIn 추가
- Test: `CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift` (테스트 추가)

- [ ] **Step 1: Write the failing tests** — `SessionRepositoryTests.swift` 클래스 끝에 추가

```swift
    func test_saveCheckIn_persistsSummaryColumnsAndPayload() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let stats = [
            DerivedMetric.smile: MetricStats(mean: 0.4, max: 0.6, std: 0.2),
            DerivedMetric.smileAsymmetry: MetricStats(mean: 0.05, max: 0.1, std: 0.02),
            DerivedMetric.duchenne: MetricStats(mean: 0.3, max: 0.5, std: 0.1),
        ]
        let summary = SessionMetricsAccumulator.Summary(stats: stats, durationSeconds: 10, trackingLossCount: 1)
        let payload = CheckInPayload(
            blendshapesFinal: ["jawOpen": 0.2],
            sessionStats: stats,
            pitchDegrees: 2.0,
            yawDegrees: -3.0,
            captureDurationSeconds: 10,
            trackingLossCount: 1
        )

        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.1),
            date: Date(timeIntervalSince1970: 1_000),
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.2,
            summary: summary,
            payload: payload
        )

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertEqual(saved.smileMean ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(saved.smileMax ?? -1, 0.6, accuracy: 0.0001)
        XCTAssertEqual(saved.smileStability ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(saved.smileAsymmetry ?? -1, 0.05, accuracy: 0.0001)
        XCTAssertEqual(saved.duchenneScore ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(saved.payloadVersion, CheckInPayload.currentVersion)
        let decoded = try JSONDecoder().decode(CheckInPayload.self, from: XCTUnwrap(saved.payload))
        XCTAssertEqual(decoded, payload)
    }

    func test_saveCheckIn_withoutSummary_leavesNewColumnsNil() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 1_000))

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertNil(saved.smileMean)
        XCTAssertNil(saved.mood)
        XCTAssertNil(saved.payload)
    }

    func test_updateMoodOnLatestCheckIn_setsMoodOnMostRecent() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 1_000))
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 2_000))

        try repository.updateMoodOnLatestCheckIn("😊")

        let sessions = try repository.fetchCheckIns(from: .distantPast, to: .distantFuture)
        XCTAssertNil(sessions.first?.mood)
        XCTAssertEqual(sessions.last?.mood, "😊")
    }

    func test_updateMoodOnLatestCheckIn_doesNothing_whenNoCheckIns() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        XCTAssertNoThrow(try repository.updateMoodOnLatestCheckIn("😊"))
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd CoachingKit && swift test --filter SessionRepositoryTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `summary:`/`payload:` 파라미터, `smileMean`, `updateMoodOnLatestCheckIn` 미정의

- [ ] **Step 3: CheckInSession 모델 확장** — 전체 교체

```swift
// CoachingKit/Sources/CoachingKit/CheckInSession.swift 전체 교체
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

    // 세션 통계 (2026-07 데이터 수집 확장). 구버전 레코드는 nil.
    public var smileMean: Double?
    public var smileMax: Double?
    public var smileStability: Double?
    public var smileAsymmetry: Double?
    public var duchenneScore: Double?
    /// 기분 이모지. 미선택 시 nil.
    public var mood: String?
    /// CheckInPayload JSON. 스키마는 payloadVersion으로 구분한다.
    public var payload: Data?
    public var payloadVersion: Int = 1

    public init(
        date: Date,
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double,
        smileMean: Double? = nil,
        smileMax: Double? = nil,
        smileStability: Double? = nil,
        smileAsymmetry: Double? = nil,
        duchenneScore: Double? = nil,
        mood: String? = nil,
        payload: Data? = nil,
        payloadVersion: Int = 1
    ) {
        self.date = date
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.lightingQuality = lightingQuality
        self.deviceAngleOK = deviceAngleOK
        self.scoreDelta = scoreDelta
        self.smileMean = smileMean
        self.smileMax = smileMax
        self.smileStability = smileStability
        self.smileAsymmetry = smileAsymmetry
        self.duchenneScore = duchenneScore
        self.mood = mood
        self.payload = payload
        self.payloadVersion = payloadVersion
    }
}
```

- [ ] **Step 4: SessionRepository.saveCheckIn 교체 + updateMoodOnLatestCheckIn 추가**

`SessionRepository.swift`의 기존 `saveCheckIn`(37-55행)을 교체:

```swift
    @discardableResult
    public func saveCheckIn(
        measurement: FaceMeasurement,
        date: Date,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double,
        summary: SessionMetricsAccumulator.Summary? = nil,
        payload: CheckInPayload? = nil
    ) throws -> CheckInSession {
        let payloadData = try payload.map { try JSONEncoder().encode($0) }
        let session = CheckInSession(
            date: date,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension,
            lightingQuality: lightingQuality,
            deviceAngleOK: deviceAngleOK,
            scoreDelta: scoreDelta,
            smileMean: summary?.smileMean,
            smileMax: summary?.smileMax,
            smileStability: summary?.smileStability,
            smileAsymmetry: summary?.smileAsymmetry,
            duchenneScore: summary?.duchenneScore,
            payload: payloadData,
            payloadVersion: CheckInPayload.currentVersion
        )
        modelContext.insert(session)
        try modelContext.save()
        return session
    }
```

파일 끝(클래스 안, `pruneOldBaselines` 뒤)에 추가:

```swift
    /// 방금 저장된 체크인에 기분 이모지를 사후 기록한다. 체크인이 없으면 무시.
    public func updateMoodOnLatestCheckIn(_ mood: String) throws {
        guard let latest = try fetchLatestCheckIn() else { return }
        latest.mood = mood
        try modelContext.save()
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과 (기존 saveCheckIn 호출부는 기본 파라미터로 유지, 반환값은 @discardableResult)

- [ ] **Step 6: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/CheckInSession.swift CoachingKit/Sources/CoachingKit/SessionRepository.swift CoachingKit/Tests/CoachingKitTests/SessionRepositoryTests.swift
git commit -m "feat: persist session stats, payload, and mood on CheckInSession"
```

---

### Task 5: CoachingViewModel 통합

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CoachingViewModel.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/CoachingViewModelTests.swift` (테스트 추가)

- [ ] **Step 1: Write the failing test** — `CoachingViewModelTests.swift` 클래스 끝에 추가

```swift
    func test_complete_persistsSessionSummaryAndPayload() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let keys = CuratedMetricKeys.default
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline, now: { Date(timeIntervalSince1970: 5_000) }, metricKeys: keys)

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.2, mouthCornerRight: 0.2, browTension: 0.1, blendShapes: [keys.jawOpen: 0.3]))
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.6, mouthCornerRight: 0.4, browTension: 0.1, blendShapes: [keys.jawOpen: 0.5], pitchDegrees: 2.0, yawDegrees: -1.0))
        try viewModel.complete()

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertEqual(saved.smileMean ?? -1, 0.35, accuracy: 0.0001) // (0.2 + 0.5)/2
        XCTAssertEqual(saved.smileMax ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(saved.smileAsymmetry ?? -1, 0.1, accuracy: 0.0001) // (0 + 0.2)/2

        let payload = try JSONDecoder().decode(CheckInPayload.self, from: XCTUnwrap(saved.payload))
        XCTAssertEqual(payload.blendshapesFinal[keys.jawOpen] ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(payload.pitchDegrees ?? -1, 2.0, accuracy: 0.0001)
        XCTAssertEqual(payload.sessionStats[keys.jawOpen]?.mean ?? -1, 0.4, accuracy: 0.0001)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter CoachingViewModelTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `metricKeys:` 파라미터 미정의

- [ ] **Step 3: CoachingViewModel 수정**

init 시그니처와 accumulator 연결 (`CoachingViewModel.swift:27-58` 교체):

```swift
    @ObservationIgnored private let accumulator: SessionMetricsAccumulator

    public init(
        session: FaceTrackingSession,
        repository: SessionRepository,
        baseline: Baseline,
        now: @escaping () -> Date = Date.init,
        metricKeys: CuratedMetricKeys = .default
    ) {
        self.session = session
        self.repository = repository
        self.baseline = baseline
        self.now = now
        self.accumulator = SessionMetricsAccumulator(keys: metricKeys)
        self.session.onUpdate = { [weak self] measurement in
            guard let self else { return }
            self.latestMeasurement = measurement
            self.accumulator.add(measurement, at: self.now())
            let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
            let centiDelta = Int((delta * 100).rounded())
            if centiDelta != self.lastDisplayedCentiDelta {
                self.lastDisplayedCentiDelta = centiDelta
                self.displayedMeasurement = measurement
            }
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
```

`complete()`(64-76행) 교체:

```swift
    public func complete() throws {
        guard phase == .tracking, let measurement = latestMeasurement else { return }
        let delta = ScoreCalculator.delta(current: measurement, baseline: baseline.measurement)
        let summary = accumulator.summarize()
        let payload = CheckInPayload(
            blendshapesFinal: measurement.blendShapes,
            sessionStats: summary.stats,
            pitchDegrees: measurement.pitchDegrees,
            yawDegrees: measurement.yawDegrees,
            captureDurationSeconds: summary.durationSeconds,
            trackingLossCount: summary.trackingLossCount
        )
        try repository.saveCheckIn(
            measurement: measurement,
            date: now(),
            lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0,
            deviceAngleOK: isAngleOK,
            scoreDelta: delta,
            summary: summary,
            payload: payload
        )
        session.stop()
        phase = .completed(scoreDelta: delta)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/CoachingViewModel.swift CoachingKit/Tests/CoachingKitTests/CoachingViewModelTests.swift
git commit -m "feat: accumulate and persist session metrics in CoachingViewModel"
```

---

### Task 6: CareSession 모델 + CareRepository.saveSession

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CareSession.swift`
- Modify: `CoachingKit/Sources/CoachingKit/CareRepository.swift:11-14`
- Test: `CoachingKit/Tests/CoachingKitTests/CareRepositoryTests.swift` (신규 — 기존 CareRepository 테스트는 CareViewModelTests에 흩어져 있으므로 신규 파일)

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKit/Tests/CoachingKitTests/CareRepositoryTests.swift
import XCTest
import SwiftData
@testable import CoachingKit

final class CareRepositoryTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_saveSession_persistsBehavioralFields() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())
        let started = Date(timeIntervalSince1970: 1_000)
        let ended = Date(timeIntervalSince1970: 1_130)

        try repository.saveSession(
            routineID: "lift-smile",
            date: ended,
            startedAt: started,
            durationSeconds: 130,
            completedSteps: 2,
            totalSteps: 4,
            wasCompleted: false
        )

        let saved = try XCTUnwrap(repository.fetchCompletions(from: .distantPast, to: .distantFuture).first)
        XCTAssertEqual(saved.startedAt, started)
        XCTAssertEqual(saved.durationSeconds ?? -1, 130, accuracy: 0.001)
        XCTAssertEqual(saved.completedSteps, 2)
        XCTAssertEqual(saved.totalSteps, 4)
        XCTAssertFalse(saved.wasCompleted)
    }

    func test_saveCompletion_marksCompleted_withNilBehavioralFields() throws {
        let repository = CareRepository(modelContext: try makeInMemoryContext())

        try repository.saveCompletion(routineID: "lift-smile", date: Date(timeIntervalSince1970: 1_000))

        let saved = try XCTUnwrap(repository.fetchCompletions(from: .distantPast, to: .distantFuture).first)
        XCTAssertTrue(saved.wasCompleted)
        XCTAssertNil(saved.startedAt)
        XCTAssertNil(saved.durationSeconds)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter CareRepositoryTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `saveSession`, `startedAt` 등 미정의

- [ ] **Step 3: CareSession 모델 교체**

```swift
// CoachingKit/Sources/CoachingKit/CareSession.swift 전체 교체
import Foundation
import SwiftData

/// 케어 루틴 재생 기록. 완주뿐 아니라 중도 이탈도 남긴다 (wasCompleted로 구분).
@Model
public final class CareSession {
    public var date: Date
    public var routineID: String

    // 행동 데이터 (2026-07 데이터 수집 확장). 구버전 레코드는 nil.
    public var startedAt: Date?
    public var durationSeconds: Double?
    public var completedSteps: Int?
    public var totalSteps: Int?
    /// 기본값 true — 확장 전 레코드는 전부 완주 기록이었다.
    public var wasCompleted: Bool = true

    public init(
        date: Date,
        routineID: String,
        startedAt: Date? = nil,
        durationSeconds: Double? = nil,
        completedSteps: Int? = nil,
        totalSteps: Int? = nil,
        wasCompleted: Bool = true
    ) {
        self.date = date
        self.routineID = routineID
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.completedSteps = completedSteps
        self.totalSteps = totalSteps
        self.wasCompleted = wasCompleted
    }
}
```

- [ ] **Step 4: CareRepository에 saveSession 추가, saveCompletion은 위임으로 교체**

`CareRepository.swift`의 `saveCompletion`(11-14행)을 다음으로 교체:

```swift
    public func saveCompletion(routineID: String, date: Date) throws {
        try saveSession(routineID: routineID, date: date, startedAt: nil, durationSeconds: nil, completedSteps: nil, totalSteps: nil, wasCompleted: true)
    }

    public func saveSession(
        routineID: String,
        date: Date,
        startedAt: Date?,
        durationSeconds: Double?,
        completedSteps: Int?,
        totalSteps: Int?,
        wasCompleted: Bool
    ) throws {
        modelContext.insert(CareSession(
            date: date,
            routineID: routineID,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            completedSteps: completedSteps,
            totalSteps: totalSteps,
            wasCompleted: wasCompleted
        ))
        try modelContext.save()
    }
```

주의: `hasCompletion`/`fetchCompletions`는 이제 이탈 기록도 반환한다. 기존 소비처(추천 로직 등)가 "완주"만 세야 하는지 확인 — 현재 `hasCompletion`은 홈 화면 오늘 케어 표시에 쓰이므로, 완주만 세도록 `fetchCompletions` 결과에서 `wasCompleted` 필터를 `hasCompletion`에 추가한다:

```swift
    public func hasCompletion(onDayOf date: Date, calendar: Calendar = .current) throws -> Bool {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        return try fetchCompletions(from: start, to: end).contains { $0.wasCompleted }
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과

- [ ] **Step 6: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/CareSession.swift CoachingKit/Sources/CoachingKit/CareRepository.swift CoachingKit/Tests/CoachingKitTests/CareRepositoryTests.swift
git commit -m "feat: record care session behavior including abandonment"
```

---

### Task 7: CareViewModel — completeRoutine 확장 + abandonRoutine

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CareViewModel.swift:90-92`
- Test: `CoachingKit/Tests/CoachingKitTests/CareViewModelTests.swift` (테스트 추가)

- [ ] **Step 1: Write the failing tests** — `CareViewModelTests.swift`에 추가. 기존 테스트의 뷰모델 생성 헬퍼 패턴을 그대로 따르되, `now`를 고정 주입한다. (기존 파일의 헬퍼가 다르면 그 패턴에 맞춰 조정 — 검증 대상은 아래 동작이다.)

```swift
    func test_completeRoutine_savesFullCompletionWithDuration() throws {
        let context = try makeInMemoryContext()
        let careRepository = CareRepository(modelContext: context)
        let viewModel = CareViewModel(
            sessionRepository: SessionRepository(modelContext: context),
            careRepository: careRepository,
            favorites: InMemoryCareFavorites(),
            now: { Date(timeIntervalSince1970: 2_000) }
        )
        let routine = CareRoutine.catalog[0]

        try viewModel.completeRoutine(routine, startedAt: Date(timeIntervalSince1970: 1_870))

        let saved = try XCTUnwrap(careRepository.fetchCompletions(from: .distantPast, to: .distantFuture).first)
        XCTAssertTrue(saved.wasCompleted)
        XCTAssertEqual(saved.durationSeconds ?? -1, 130, accuracy: 0.001)
        XCTAssertEqual(saved.completedSteps, routine.steps.count)
        XCTAssertEqual(saved.totalSteps, routine.steps.count)
    }

    func test_abandonRoutine_savesPartialProgress() throws {
        let context = try makeInMemoryContext()
        let careRepository = CareRepository(modelContext: context)
        let viewModel = CareViewModel(
            sessionRepository: SessionRepository(modelContext: context),
            careRepository: careRepository,
            favorites: InMemoryCareFavorites(),
            now: { Date(timeIntervalSince1970: 2_000) }
        )
        let routine = CareRoutine.catalog[0]

        try viewModel.abandonRoutine(routine, startedAt: Date(timeIntervalSince1970: 1_940), completedSteps: 2)

        let saved = try XCTUnwrap(careRepository.fetchCompletions(from: .distantPast, to: .distantFuture).first)
        XCTAssertFalse(saved.wasCompleted)
        XCTAssertEqual(saved.completedSteps, 2)
        XCTAssertEqual(saved.totalSteps, routine.steps.count)
    }

    func test_abandonRoutine_ignoresZeroStepAbandons() throws {
        let context = try makeInMemoryContext()
        let careRepository = CareRepository(modelContext: context)
        let viewModel = CareViewModel(
            sessionRepository: SessionRepository(modelContext: context),
            careRepository: careRepository,
            favorites: InMemoryCareFavorites(),
            now: { Date(timeIntervalSince1970: 2_000) }
        )

        try viewModel.abandonRoutine(CareRoutine.catalog[0], startedAt: Date(timeIntervalSince1970: 1_990), completedSteps: 0)

        XCTAssertTrue(try careRepository.fetchCompletions(from: .distantPast, to: .distantFuture).isEmpty)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd CoachingKit && swift test --filter CareViewModelTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `completeRoutine(_:startedAt:)`, `abandonRoutine` 미정의

- [ ] **Step 3: CareViewModel 수정** — `completeRoutine`(90-92행)을 교체

```swift
    public func completeRoutine(_ routine: CareRoutine, startedAt: Date? = nil) throws {
        let endedAt = now()
        try careRepository.saveSession(
            routineID: routine.id,
            date: endedAt,
            startedAt: startedAt,
            durationSeconds: startedAt.map { endedAt.timeIntervalSince($0) },
            completedSteps: routine.steps.count,
            totalSteps: routine.steps.count,
            wasCompleted: true
        )
    }

    /// 중도 이탈 기록. 스텝을 하나도 못 마친 이탈(열자마자 닫기)은 노이즈라 저장하지 않는다.
    public func abandonRoutine(_ routine: CareRoutine, startedAt: Date?, completedSteps: Int) throws {
        guard completedSteps > 0 else { return }
        let endedAt = now()
        try careRepository.saveSession(
            routineID: routine.id,
            date: endedAt,
            startedAt: startedAt,
            durationSeconds: startedAt.map { endedAt.timeIntervalSince($0) },
            completedSteps: completedSteps,
            totalSteps: routine.steps.count,
            wasCompleted: false
        )
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과 (기존 `completeRoutine(routine)` 호출부는 기본 파라미터로 유지)

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/CareViewModel.swift CoachingKit/Tests/CoachingKitTests/CareViewModelTests.swift
git commit -m "feat: track care routine duration and abandonment in CareViewModel"
```

---

### Task 8: ARKitFaceTrackingSession — 블렌드셰이프 전체 + 각도 원본 전달

**Files:**
- Modify: `SmileDay/Services/ARKitFaceTrackingSession.swift:41-88`
- Modify: `SmileDay/Views/Coaching/CoachingSessionView.swift:111-119` (metricKeys 주입)

- [ ] **Step 1: renderer(didUpdate:)와 각도 계산 교체**

`ARKitFaceTrackingSession.swift`의 `extension ARKitFaceTrackingSession: ARSCNViewDelegate` 블록(41-88행)을 교체:

```swift
extension ARKitFaceTrackingSession: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        // 트래킹이 유실된 프레임(손으로 가림/프레임 이탈)은 마지막 정상값을 덮어쓰지 않도록 무시한다.
        guard faceAnchor.isTracked else { return }
        let blendShapes = faceAnchor.blendShapes

        let mouthCornerLeft = blendShapes[.mouthSmileLeft]?.doubleValue ?? 0
        let mouthCornerRight = blendShapes[.mouthSmileRight]?.doubleValue ?? 0
        let browDownLeft = blendShapes[.browDownLeft]?.doubleValue ?? 0
        let browDownRight = blendShapes[.browDownRight]?.doubleValue ?? 0
        let browInnerUp = blendShapes[.browInnerUp]?.doubleValue ?? 0
        let browTension = (browDownLeft + browDownRight + browInnerUp) / 3

        let allShapes = Dictionary(uniqueKeysWithValues: blendShapes.map { ($0.key.rawValue, $0.value.doubleValue) })
        let angles = Self.faceAngles(transform: faceAnchor.transform)

        let measurement = FaceMeasurement(
            mouthCornerLeft: mouthCornerLeft,
            mouthCornerRight: mouthCornerRight,
            browTension: browTension,
            blendShapes: allShapes,
            pitchDegrees: angles.pitch,
            yawDegrees: angles.yaw
        )

        let angleOK = AngleEvaluator.isWithinTolerance(pitchDegrees: angles.pitch, yawDegrees: angles.yaw)

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(measurement)
            self?.onTrackingQualityUpdate?(angleOK)
        }
    }

    /// 얼굴 world-space transform에서 pitch(x축)/yaw(y축) 각도를 도 단위로 구한다.
    /// 쿼터니언 성분 순서는 simd_quatf.vector == (x, y, z, w).
    private static func faceAngles(transform: simd_float4x4) -> (pitch: Double, yaw: Double) {
        let q = simd_quatf(transform)
        let x = Double(q.vector.x)
        let y = Double(q.vector.y)
        let z = Double(q.vector.z)
        let w = Double(q.vector.w)

        // pitch: x축 회전 (atan2), yaw: y축 회전 (asin). 정면 응시 시 항등 쿼터니언 → 0도.
        let pitchRadians = atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y))
        let sinYaw = max(-1, min(1, 2 * (w * y - z * x)))
        let yawRadians = asin(sinYaw)

        return (pitchRadians * 180 / .pi, yawRadians * 180 / .pi)
    }
}
```

파일 끝에 ARKit rawValue 기반 키 주입용 확장 추가 (`import CoachingKit`은 이미 파일 상단에 있다):

```swift
extension CuratedMetricKeys {
    /// ARKit 타입 상수의 rawValue로 만든 키셋. 프로덕션 트래킹 경로는 항상 이걸 쓴다.
    static let arKit = CuratedMetricKeys(
        mouthSmileLeft: ARFaceAnchor.BlendShapeLocation.mouthSmileLeft.rawValue,
        mouthSmileRight: ARFaceAnchor.BlendShapeLocation.mouthSmileRight.rawValue,
        browDownLeft: ARFaceAnchor.BlendShapeLocation.browDownLeft.rawValue,
        browDownRight: ARFaceAnchor.BlendShapeLocation.browDownRight.rawValue,
        browInnerUp: ARFaceAnchor.BlendShapeLocation.browInnerUp.rawValue,
        eyeSquintLeft: ARFaceAnchor.BlendShapeLocation.eyeSquintLeft.rawValue,
        eyeSquintRight: ARFaceAnchor.BlendShapeLocation.eyeSquintRight.rawValue,
        cheekSquintLeft: ARFaceAnchor.BlendShapeLocation.cheekSquintLeft.rawValue,
        cheekSquintRight: ARFaceAnchor.BlendShapeLocation.cheekSquintRight.rawValue,
        jawOpen: ARFaceAnchor.BlendShapeLocation.jawOpen.rawValue,
        mouthPressLeft: ARFaceAnchor.BlendShapeLocation.mouthPressLeft.rawValue,
        mouthPressRight: ARFaceAnchor.BlendShapeLocation.mouthPressRight.rawValue
    )
}
```

- [ ] **Step 2: CoachingSessionView에서 키 주입**

`CoachingSessionView.swift`의 `.onAppear`(111-119행) 안 뷰모델 생성을 교체:

```swift
            let vm = CoachingViewModel(
                session: trackingSession,
                repository: SessionRepository(modelContext: modelContext),
                baseline: baseline,
                metricKeys: .arKit
            )
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add SmileDay/Services/ARKitFaceTrackingSession.swift SmileDay/Views/Coaching/CoachingSessionView.swift
git commit -m "feat: stream full blendshapes and head angles from ARKit session"
```

---

### Task 9: 기분 이모지 UI (SaveConfirmView + CoachingTabView)

**Files:**
- Modify: `SmileDay/Views/Coaching/SaveConfirmView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingTabView.swift:20-43`

- [ ] **Step 1: SaveConfirmView에 무드 피커 추가**

`SaveConfirmView` 구조체에 프로퍼티 추가 (`reminderOffer` 선언 아래):

```swift
    /// 기분 이모지 선택 콜백. nil이면 무드 섹션을 그리지 않는다.
    var onMoodSelected: ((String) -> Void)? = nil
```

`@State private var offerState` 아래에 추가:

```swift
    @State private var selectedMood: String?
    private static let moods = ["😊", "🙂", "😐", "😞", "😫"]
```

body의 `if let reminderOffer` 블록 **위**에 무드 섹션 추가:

```swift
                if onMoodSelected != nil {
                    VStack(spacing: 8) {
                        Text("지금 기분은 어때요?")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SDColor.muted)
                        HStack(spacing: 12) {
                            ForEach(Self.moods, id: \.self) { mood in
                                Button {
                                    selectedMood = mood
                                    onMoodSelected?(mood)
                                } label: {
                                    Text(mood)
                                        .font(.system(size: 28))
                                        .opacity(selectedMood == nil || selectedMood == mood ? 1 : 0.35)
                                        .scaleEffect(selectedMood == mood ? 1.15 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .animation(.spring(duration: 0.25), value: selectedMood)
                    }
                    .padding(.top, 4)
                }
```

건너뛰기는 별도 버튼 없이 "선택하지 않고 확인을 누르면" 그대로 nil 유지 — 스펙의 마찰 최소 원칙.

- [ ] **Step 2: CoachingTabView에서 연결**

`SaveConfirmView(...)` 호출(22행 시작)에 인자 추가 — `reminderOffer:` 인자 **뒤**, 트레일링 클로저 앞에:

```swift
                onMoodSelected: { mood in
                    try? SessionRepository(modelContext: modelContext).updateMoodOnLatestCheckIn(mood)
                }
```

(이모지를 다시 탭하면 updateMoodOnLatestCheckIn이 다시 불려 마지막 선택이 저장된다 — 의도된 동작.)

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add SmileDay/Views/Coaching/SaveConfirmView.swift SmileDay/Views/Coaching/CoachingTabView.swift
git commit -m "feat: add one-tap mood emoji on check-in confirmation"
```

---

### Task 10: CarePlayerView 결과 전달 + CareView 연결

**Files:**
- Modify: `SmileDay/Views/Care/CarePlayerView.swift:6-31,125-132`
- Modify: `SmileDay/Views/Care/CareView.swift:65-76`

- [ ] **Step 1: CarePlayerView 시그니처 변경**

`CarePlayerView.swift` 상단(6-21행)을 교체:

```swift
/// 플레이어 종료 시 CareView로 전달되는 재생 결과.
struct CarePlayResult {
    let completed: Bool
    let completedSteps: Int
    let startedAt: Date
}

struct CarePlayerView: View {
    let routine: CareRoutine
    let onClose: (CarePlayResult) -> Void

    @State private var currentStepIndex = 0
    @State private var remainingSeconds = 0
    @State private var player: AVPlayer?
    @State private var startedAt = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isLastStep: Bool { currentStepIndex >= routine.steps.count - 1 }

    private var currentStep: CareStep? {
        routine.steps.indices.contains(currentStepIndex) ? routine.steps[currentStepIndex] : nil
    }
```

닫기 버튼(26행)을 교체:

```swift
                SDCloseButton {
                    onClose(CarePlayResult(completed: false, completedSteps: currentStepIndex, startedAt: startedAt))
                }
```

`advance()`(125-132행)를 교체:

```swift
    private func advance() {
        if isLastStep {
            onClose(CarePlayResult(completed: true, completedSteps: routine.steps.count, startedAt: startedAt))
        } else {
            currentStepIndex += 1
            resetTimer()
        }
    }
```

`.onAppear`에 `startedAt = Date()` 리셋 추가 (`resetTimer()` 호출 앞):

```swift
        .onAppear {
            startedAt = Date()
            resetTimer()
            if let url = Bundle.main.url(forResource: routine.videoFileName, withExtension: "mp4") {
                let player = AVPlayer(url: url)
                self.player = player
                player.play()
            }
        }
```

- [ ] **Step 2: CareView 연결부 교체**

`CareView.swift`의 `.fullScreenCover`(65-76행)를 교체:

```swift
        .fullScreenCover(item: $playingRoutine) { routine in
            CarePlayerView(routine: routine) { result in
                if let viewModel {
                    do {
                        if result.completed {
                            try viewModel.completeRoutine(routine, startedAt: result.startedAt)
                        } else {
                            try viewModel.abandonRoutine(routine, startedAt: result.startedAt, completedSteps: result.completedSteps)
                        }
                    } catch {
                        showSaveError = true
                    }
                }
                playingRoutine = nil
            }
        }
```

(이탈 저장 실패도 showSaveError를 띄우는 게 과할 수 있으나, 저장 실패는 어떤 경로든 사용자에게 알리는 기존 정책을 따른다.)

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add SmileDay/Views/Care/CarePlayerView.swift SmileDay/Views/Care/CareView.swift
git commit -m "feat: report care play result for duration and abandonment tracking"
```

---

### Task 11: 최종 검증

- [ ] **Step 1: 전체 테스트**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과, 0 failures

- [ ] **Step 2: 앱 빌드**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 마이그레이션 수동 QA (시뮬레이터)**

새 필드가 전부 optional/기본값이라 SwiftData 경량 마이그레이션이 자동 적용된다. 확인 절차:
1. 이 브랜치 이전 커밋으로 앱을 시뮬레이터에 설치하고 `-seedDemoData` 런치 인자로 데모 데이터 생성
2. 이 브랜치 빌드로 덮어 설치 후 실행
3. 히스토리 화면에서 기존 체크인 기록이 그대로 보이면 통과 (크래시/빈 화면이면 실패)

- [ ] **Step 4: 실기기 스모크 (블렌드셰이프 키 검증)**

시뮬레이터에는 얼굴 트래킹이 없으므로, 실기기에서 체크인 1회 후 확인:
- 체크인 완료가 정상 동작하고, (Xcode 디버거나 임시 로그로) 저장된 세션의 `smileMean`·`payload`가 nil이 아닌지 확인
- `payload`를 디코드해 `blendshapesFinal`에 50개 이상의 키가 있는지 확인 (ARKit rawValue 키가 그대로 들어온다)

---

## 스펙 대비 커버리지

| 스펙 항목 | 태스크 |
|---|---|
| 하이브리드 스키마 (타입 컬럼 + payload) | Task 3, 4 |
| 세션 통계 (Welford) | Task 1, 5 |
| 블렌드셰이프 52개 + pitch/yaw 전달 | Task 2, 8 |
| CareSession 행동 데이터 + 중도 이탈 | Task 6, 7, 10 |
| 기분 이모지 | Task 4 (저장), 9 (UI) |
| 경량 마이그레이션 | Task 4, 6 (optional 필드), 11 (수동 QA) |
| 테스트 5종 (스펙 §6) | Task 1 (통계), 3 (라운드트립), 6·7 (이탈), 4 (무드), 11 (마이그레이션 QA) |
