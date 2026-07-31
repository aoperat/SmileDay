# 룰 기반 코칭 4종 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 비대칭·진짜미소·긴장도·측정신뢰도 지표를 개인 히스토리 상대 비교로 판정해, 체크인 직후 인사이트 1줄과 케어 추천에 반영한다 (스펙: `docs/superpowers/specs/2026-07-24-rule-based-coaching-design.md`).

**Architecture:** 판정 로직은 CoachingKit의 순수 컴포넌트 `InsightEngine`(값 타입 입력, SwiftData 무관)으로 만들어 TDD. SwiftData 연결은 `CheckInRecord(session:)` 매퍼와 `InsightEngine.evaluateLatest(in:)` 편의 함수로 한 곳에 모은다. 앱 레이어(SaveConfirmView/CoachingTabView)와 CareViewModel은 이 한 함수만 호출한다.

**Tech Stack:** Swift 5.10, SwiftData, SwiftUI, XCTest.

**검증 명령** (리포 루트 `/Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay` 기준):
- CoachingKit 테스트: `cd CoachingKit && swift test`
- 앱 빌드: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build`

---

### Task 1: InsightEngine 코어 (CheckInRecord, CheckInInsight, evaluate)

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/InsightEngine.swift`
- Test: `CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift
import XCTest
@testable import CoachingKit

final class InsightEngineTests: XCTestCase {
    private func record(
        daysAgo: Int = 0,
        browTension: Double = 0.2,
        smileAsymmetry: Double? = 0.02,
        duchenneScore: Double? = 0.4,
        deviceAngleOK: Bool = true,
        lightingQuality: Double = 1.0,
        trackingLossCount: Int? = 0
    ) -> CheckInRecord {
        CheckInRecord(
            date: Date(timeIntervalSince1970: 1_000_000 - Double(daysAgo) * 86_400),
            browTension: browTension,
            smileAsymmetry: smileAsymmetry,
            duchenneScore: duchenneScore,
            deviceAngleOK: deviceAngleOK,
            lightingQuality: lightingQuality,
            trackingLossCount: trackingLossCount
        )
    }

    /// 긴장도 0.2 고정(std 0) 신뢰 히스토리 3개. 임계 = 0.2 + max(0, 0.05) = 0.25.
    private var calmHistory: [CheckInRecord] {
        (1...3).map { record(daysAgo: $0) }
    }

    // MARK: 규칙 1 — 신뢰도

    func test_lowReliability_whenAngleNG_suppressesOtherRules() {
        let today = record(browTension: 0.9, deviceAngleOK: false)
        let insight = InsightEngine.evaluate(today: today, history: calmHistory)
        XCTAssertEqual(insight?.kind, .lowReliability)
        XCTAssertNil(insight?.recommendedCategory)
    }

    func test_lowReliability_whenLightingPoor() {
        let today = record(lightingQuality: 0.2)
        XCTAssertEqual(InsightEngine.evaluate(today: today, history: calmHistory)?.kind, .lowReliability)
    }

    func test_lowReliability_whenTrackingLossHigh() {
        let today = record(trackingLossCount: 3)
        XCTAssertEqual(InsightEngine.evaluate(today: today, history: calmHistory)?.kind, .lowReliability)
    }

    func test_reliable_whenTrackingLossUnknown() {
        // 구버전 레코드(payload 없음)는 trackingLossCount nil — 신뢰 불가로 취급하지 않는다.
        let today = record(browTension: 0.26, trackingLossCount: nil)
        XCTAssertEqual(InsightEngine.evaluate(today: today, history: calmHistory)?.kind, .highTension)
    }

    // MARK: 규칙 2 — 긴장도

    func test_highTension_triggersAboveThreshold() {
        let insight = InsightEngine.evaluate(today: record(browTension: 0.26), history: calmHistory)
        XCTAssertEqual(insight?.kind, .highTension)
        XCTAssertEqual(insight?.recommendedCategory, .relax)
    }

    func test_highTension_notTriggered_atThreshold() {
        // 경계값(0.25)은 초과가 아니므로 발동하지 않는다.
        XCTAssertNil(InsightEngine.evaluate(today: record(browTension: 0.25), history: calmHistory))
    }

    func test_noInsight_whenHistoryInsufficient() {
        let history = (1...2).map { record(daysAgo: $0) }
        XCTAssertNil(InsightEngine.evaluate(today: record(browTension: 0.9), history: history))
    }

    func test_unreliableHistoryExcludedFromBaseline() {
        // 신뢰 기록 2 + 신뢰 불가 1 → 유효 표본 2개 → 판정 없음.
        let history = [record(daysAgo: 1), record(daysAgo: 2), record(daysAgo: 3, deviceAngleOK: false)]
        XCTAssertNil(InsightEngine.evaluate(today: record(browTension: 0.9), history: history))
    }

    // MARK: 규칙 3 — 비대칭

    func test_asymmetry_weakSideRight_whenLeftStronger() {
        // 히스토리 |asym| 평균 0.02, std 0 → 임계 0.02 + max(0, 0.03) = 0.05. 오늘 +0.06(좌>우) → 오른쪽이 약함.
        let insight = InsightEngine.evaluate(today: record(smileAsymmetry: 0.06), history: calmHistory)
        XCTAssertEqual(insight?.kind, .asymmetry(weakSide: .right))
        XCTAssertEqual(insight?.recommendedCategory, .lift)
        XCTAssertEqual(insight?.message.contains("오른"), true)
    }

    func test_asymmetry_weakSideLeft_whenRightStronger() {
        let insight = InsightEngine.evaluate(today: record(smileAsymmetry: -0.06), history: calmHistory)
        XCTAssertEqual(insight?.kind, .asymmetry(weakSide: .left))
        XCTAssertEqual(insight?.message.contains("왼"), true)
    }

    func test_asymmetry_skipped_whenTodayValueNil() {
        XCTAssertNil(InsightEngine.evaluate(today: record(smileAsymmetry: nil), history: calmHistory))
    }

    func test_asymmetry_skipped_whenHistoryValuesNil() {
        // 히스토리에 asym 값이 2개뿐(1개 nil) → 유효 표본 부족 → 발동 없음.
        let history = [record(daysAgo: 1), record(daysAgo: 2), record(daysAgo: 3, smileAsymmetry: nil)]
        XCTAssertNil(InsightEngine.evaluate(today: record(smileAsymmetry: 0.9), history: history))
    }

    // MARK: 규칙 4 — 진짜미소

    func test_lowDuchenne_triggersBelowThreshold() {
        // 임계 = 0.4 − max(0, 0.05) = 0.35. 오늘 0.34 → 발동.
        let insight = InsightEngine.evaluate(today: record(duchenneScore: 0.34), history: calmHistory)
        XCTAssertEqual(insight?.kind, .lowDuchenne)
        XCTAssertEqual(insight?.recommendedCategory, .morning)
    }

    // MARK: 우선순위

    func test_priority_tensionBeatsAsymmetry() {
        let today = record(browTension: 0.3, smileAsymmetry: 0.06)
        XCTAssertEqual(InsightEngine.evaluate(today: today, history: calmHistory)?.kind, .highTension)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd CoachingKit && swift test --filter InsightEngineTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `CheckInRecord`, `CheckInInsight`, `InsightEngine` 미정의

- [ ] **Step 3: Write the implementation**

```swift
// CoachingKit/Sources/CoachingKit/InsightEngine.swift
import Foundation

/// 체크인 1회의 판정용 스냅샷. SwiftData 모델과 분리된 값 타입.
public struct CheckInRecord: Equatable, Sendable {
    public let date: Date
    public let browTension: Double
    /// 확장 전 레코드는 nil.
    public let smileAsymmetry: Double?
    public let duchenneScore: Double?
    public let deviceAngleOK: Bool
    public let lightingQuality: Double
    /// payload 디코드 결과. 구버전 레코드는 nil (신뢰 불가로 취급하지 않는다).
    public let trackingLossCount: Int?

    public init(
        date: Date,
        browTension: Double,
        smileAsymmetry: Double?,
        duchenneScore: Double?,
        deviceAngleOK: Bool,
        lightingQuality: Double,
        trackingLossCount: Int?
    ) {
        self.date = date
        self.browTension = browTension
        self.smileAsymmetry = smileAsymmetry
        self.duchenneScore = duchenneScore
        self.deviceAngleOK = deviceAngleOK
        self.lightingQuality = lightingQuality
        self.trackingLossCount = trackingLossCount
    }

    /// 코칭 판정에 쓸 수 없는 기록인지.
    public var isUnreliable: Bool {
        !deviceAngleOK
            || lightingQuality < InsightEngine.poorLightingThreshold
            || (trackingLossCount ?? 0) >= InsightEngine.trackingLossLimit
    }
}

/// 체크인 1회에 대한 코칭 인사이트. 우선순위가 가장 높은 1개만 만들어진다.
public struct CheckInInsight: Equatable, Sendable {
    public enum Side: Equatable, Sendable { case left, right }

    public enum Kind: Equatable, Sendable {
        case lowReliability
        case highTension
        case asymmetry(weakSide: Side)
        case lowDuchenne
    }

    public let kind: Kind
    public let message: String
    /// 케어 탭 추천에 연결할 카테고리. lowReliability는 nil.
    public let recommendedCategory: CareCategory?
}

/// 개인 히스토리 상대 비교로 체크인 인사이트를 판정하는 순수 로직.
/// 날짜 필터링(최근 7일, 오늘 제외)은 호출자 책임 — 여기서는 신뢰도 필터만 한다.
public enum InsightEngine {
    public static let poorLightingThreshold = 0.3  // LightingEvaluator.darkThreshold / referenceIntensity
    public static let trackingLossLimit = 3
    static let minimumHistoryCount = 3
    static let tensionMinDelta = 0.05
    static let asymmetryMinDelta = 0.03
    static let duchenneMinDelta = 0.05

    public static func evaluate(today: CheckInRecord, history: [CheckInRecord]) -> CheckInInsight? {
        if today.isUnreliable {
            return CheckInInsight(
                kind: .lowReliability,
                message: "측정이 조금 흔들렸어요. 내일은 밝은 곳에서 정면으로 찍어봐요",
                recommendedCategory: nil
            )
        }
        let reliable = history.filter { !$0.isUnreliable }

        if let stats = Stats(values: reliable.map(\.browTension)),
           today.browTension > stats.mean + Swift.max(0.5 * stats.std, tensionMinDelta) {
            return CheckInInsight(
                kind: .highTension,
                message: "오늘은 미간 긴장이 평소보다 높아요. 릴랙스 케어로 풀어줘요",
                recommendedCategory: .relax
            )
        }

        if let todayAsymmetry = today.smileAsymmetry,
           let stats = Stats(values: reliable.compactMap(\.smileAsymmetry).map(abs)),
           abs(todayAsymmetry) > stats.mean + Swift.max(0.5 * stats.std, asymmetryMinDelta) {
            // smileAsymmetry = 좌 − 우. 양수면 왼쪽이 더 올라간 것 → 오른쪽이 약한 쪽.
            let weakSide: CheckInInsight.Side = todayAsymmetry > 0 ? .right : .left
            let sideText = weakSide == .right ? "오른" : "왼"
            return CheckInInsight(
                kind: .asymmetry(weakSide: weakSide),
                message: "오늘은 \(sideText)쪽 입꼬리가 덜 올라갔어요. 리프팅으로 균형을 맞춰봐요",
                recommendedCategory: .lift
            )
        }

        if let todayDuchenne = today.duchenneScore,
           let stats = Stats(values: reliable.compactMap(\.duchenneScore)),
           todayDuchenne < stats.mean - Swift.max(0.5 * stats.std, duchenneMinDelta) {
            return CheckInInsight(
                kind: .lowDuchenne,
                message: "입은 웃는데 눈은 아직이에요. 아침 스마일 스트레칭이 도움 돼요",
                recommendedCategory: .morning
            )
        }

        return nil
    }

    /// 표본 minimumHistoryCount개 이상일 때만 만들어지는 평균/표본표준편차.
    private struct Stats {
        let mean: Double
        let std: Double

        init?(values: [Double]) {
            guard values.count >= InsightEngine.minimumHistoryCount else { return nil }
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
            self.mean = mean
            self.std = variance.squareRoot()
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd CoachingKit && swift test --filter InsightEngineTests 2>&1 | tail -5`
Expected: `Executed 14 tests, with 0 failures`

- [ ] **Step 5: 전체 테스트로 회귀 확인 후 Commit**

Run: `cd CoachingKit && swift test 2>&1 | tail -3` → 전체 통과 확인

```bash
git add CoachingKit/Sources/CoachingKit/InsightEngine.swift CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift
git commit -m "feat: add InsightEngine with rule-based check-in insights"
```

---

### Task 2: CheckInSession 매퍼 + evaluateLatest 편의 함수

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/InsightEngine.swift` (파일 끝에 extension 2개 추가)
- Test: `CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift` (테스트 추가)

- [ ] **Step 1: Write the failing tests** — `InsightEngineTests.swift` 클래스 끝에 추가

```swift
    // MARK: 매퍼 + evaluateLatest

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_mapper_decodesTrackingLossFromPayload() throws {
        let payload = CheckInPayload(
            blendshapesFinal: [:], sessionStats: [:],
            pitchDegrees: nil, yawDegrees: nil,
            captureDurationSeconds: 5, trackingLossCount: 5
        )
        let session = CheckInSession(
            date: Date(timeIntervalSince1970: 1_000),
            mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.2,
            lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0,
            smileAsymmetry: 0.01, duchenneScore: 0.3,
            payload: try JSONEncoder().encode(payload)
        )

        let mapped = CheckInRecord(session: session)
        XCTAssertEqual(mapped.trackingLossCount, 5)
        XCTAssertEqual(mapped.smileAsymmetry, 0.01)
        XCTAssertEqual(mapped.duchenneScore, 0.3)
    }

    func test_mapper_leavesTrackingLossNil_whenNoPayload() {
        let session = CheckInSession(
            date: Date(timeIntervalSince1970: 1_000),
            mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.2,
            lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0
        )
        XCTAssertNil(CheckInRecord(session: session).trackingLossCount)
    }

    private func saveCheckIn(_ repository: SessionRepository, daysAgo: Int, browTension: Double) throws {
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: browTension),
            date: Date(timeIntervalSince1970: 1_000_000 - Double(daysAgo) * 86_400),
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0
        )
    }

    func test_evaluateLatest_returnsInsight_fromRepositoryHistory() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        for day in 1...3 { try saveCheckIn(repository, daysAgo: day, browTension: 0.2) }
        try saveCheckIn(repository, daysAgo: 0, browTension: 0.4)

        let insight = try InsightEngine.evaluateLatest(in: repository)
        XCTAssertEqual(insight?.kind, .highTension)
    }

    func test_evaluateLatest_excludesLatestFromItsOwnBaseline() throws {
        // 히스토리 2개뿐 → 최신 기록이 히스토리에 새면 3개가 되어 발동해버린다. nil이어야 정상.
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        for day in 1...2 { try saveCheckIn(repository, daysAgo: day, browTension: 0.2) }
        try saveCheckIn(repository, daysAgo: 0, browTension: 0.9)

        XCTAssertNil(try InsightEngine.evaluateLatest(in: repository))
    }

    func test_evaluateLatest_returnsNil_whenNoCheckIns() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        XCTAssertNil(try InsightEngine.evaluateLatest(in: repository))
    }
```

테스트 파일 상단 import에 `import SwiftData` 추가가 필요하다 (`ModelContext` 사용).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd CoachingKit && swift test --filter InsightEngineTests 2>&1 | tail -5`
Expected: 컴파일 실패 — `CheckInRecord(session:)`, `evaluateLatest` 미정의

- [ ] **Step 3: Write the implementation** — `InsightEngine.swift` 파일 끝에 추가

```swift
public extension CheckInRecord {
    /// SwiftData 모델 → 판정용 값 타입. payload가 있으면 trackingLossCount를 디코드한다.
    init(session: CheckInSession) {
        let payload = session.payload.flatMap { try? JSONDecoder().decode(CheckInPayload.self, from: $0) }
        self.init(
            date: session.date,
            browTension: session.browTension,
            smileAsymmetry: session.smileAsymmetry,
            duchenneScore: session.duchenneScore,
            deviceAngleOK: session.deviceAngleOK,
            lightingQuality: session.lightingQuality,
            trackingLossCount: payload?.trackingLossCount
        )
    }
}

public extension InsightEngine {
    /// 저장소의 최신 체크인을 오늘로, 그 직전 historyDays일을 히스토리로 판정한다.
    /// fetchCheckIns의 상한이 exclusive(date < end)라 최신 기록 자신은 히스토리에 포함되지 않는다.
    static func evaluateLatest(
        in repository: SessionRepository,
        historyDays: Int = 7,
        calendar: Calendar = .current
    ) throws -> CheckInInsight? {
        guard let latest = try repository.fetchLatestCheckIn(),
              let windowStart = calendar.date(byAdding: .day, value: -historyDays, to: latest.date)
        else { return nil }
        let history = try repository.fetchCheckIns(from: windowStart, to: latest.date)
            .map(CheckInRecord.init(session:))
        return evaluate(today: CheckInRecord(session: latest), history: history)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/InsightEngine.swift CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift
git commit -m "feat: map check-in sessions into insight evaluation"
```

---

### Task 3: CareViewModel 추천 교체

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CareViewModel.swift` (`makeRecommendation` 주변)
- Test: `CoachingKit/Tests/CoachingKitTests/CareViewModelTests.swift` (테스트 추가)

- [ ] **Step 1: Write the failing test** — `CareViewModelTests.swift` 클래스 끝에 추가

```swift
    func test_refresh_recommendsFromInsight_whenTensionHigh() throws {
        let context = try makeInMemoryContext()
        let sessionRepository = SessionRepository(modelContext: context)
        // 신뢰 히스토리 3일(긴장도 0.2) + 최신(긴장도 0.4) → highTension → relax 추천.
        for daysAgo in [1, 2, 3] {
            try seedCheckIn(sessionRepository, daysAgo: daysAgo, browTension: 0.2, from: fixedNow)
        }
        try seedCheckIn(sessionRepository, daysAgo: 0, browTension: 0.4, from: fixedNow)
        let viewModel = makeViewModel(context: context)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recommendation?.routine.category, .relax)
        XCTAssertEqual(viewModel.recommendation?.reason.contains("긴장"), true)
    }

    private func seedCheckIn(_ repository: SessionRepository, daysAgo: Int, browTension: Double, from now: Date) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let noon = calendar.date(byAdding: .hour, value: 12, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: browTension),
            date: noon,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0
        )
    }
```

기존 테스트(`test_refresh_recommendsLiftWithPositiveYesterdayScore` 등)는 히스토리가 3개 미만이라 인사이트가 nil → 기존 fallback 경로를 그대로 타므로 **수정 없이 통과해야 한다**. 이것이 fallback 회귀 검증이다.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CoachingKit && swift test --filter CareViewModelTests 2>&1 | tail -5`
Expected: 신규 테스트 FAIL — 추천 카테고리가 `.lift`(기존 고정 로직)로 나옴

- [ ] **Step 3: CareViewModel 수정** — `makeRecommendation()` 메서드를 아래로 교체 (기존 본문은 fallback으로 유지)

```swift
    /// 인사이트 기반 추천 → 없으면 어제 측정값 기반 기존 추천.
    private func makeRecommendation() throws -> CareRecommendation? {
        if let insightRecommendation = try makeInsightRecommendation() {
            return insightRecommendation
        }
        return try makeScoreRecommendation()
    }

    private func makeInsightRecommendation() throws -> CareRecommendation? {
        guard let insight = try InsightEngine.evaluateLatest(in: sessionRepository, calendar: calendar),
              let category = insight.recommendedCategory,
              let routine = routines.first(where: { $0.category == category })
        else { return nil }
        return CareRecommendation(routine: routine, reason: insight.message)
    }

    /// 어제 측정값 기반 추천. 기록이 없으면 첫 케어 안내. (기존 로직 그대로)
    private func makeScoreRecommendation() throws -> CareRecommendation? {
        guard let lift = routines.first(where: { $0.category == .lift }) else { return nil }

        let today = calendar.startOfDay(for: now())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let session = try sessionRepository.fetchLatestCheckIn(onDayOf: yesterday, calendar: calendar)
        else {
            return CareRecommendation(
                routine: lift,
                reason: "첫 케어로 입꼬리 근육을 깨워봐요. 측정을 쌓으면 맞춤 추천을 드려요."
            )
        }

        let score = ScoreCalculator.displayValue(session.scoreDelta)
        let scoreText = String(format: "%.1f", score)
        if score < 0 {
            return CareRecommendation(
                routine: lift,
                reason: "어제 \(scoreText)°로 내려갔어요. 리프팅으로 다시 끌어올려봐요."
            )
        }
        return CareRecommendation(
            routine: lift,
            reason: "어제 +\(scoreText)°였어요. 입꼬리 근육을 깨우는 리프팅으로 오늘 기록을 올려봐요."
        )
    }
```

(`makeScoreRecommendation`의 본문은 현재 `makeRecommendation`의 본문을 이름만 바꿔 그대로 옮긴 것 — 내용 수정 금지.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과 (신규 1개 + 기존 CareViewModelTests 전부)

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/CareViewModel.swift CoachingKit/Tests/CoachingKitTests/CareViewModelTests.swift
git commit -m "feat: recommend care routines from check-in insights"
```

---

### Task 4: 저장 완료 화면 인사이트 노출 (앱 레이어)

**Files:**
- Modify: `SmileDay/Views/Coaching/SaveConfirmView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingTabView.swift`

자동 테스트 없음(SwiftUI 뷰) — xcodebuild 성공으로 검증. 두 파일을 먼저 읽고 내용 기준으로 수정한다.

- [ ] **Step 1: SaveConfirmView에 인사이트 카드 추가**

프로퍼티 추가 (`reminderOffer` 선언 아래, `onMoodSelected` 위):

```swift
    /// 룰 기반 코칭 인사이트 1줄. nil이면 카드를 그리지 않는다.
    var insightMessage: String? = nil
```

body에서 "어제보다 올라갔어요" 배지 블록(`if let yesterdayScore, todayScore > yesterdayScore { ... }`) **아래**, 무드 섹션(`if onMoodSelected != nil`) **위**에 추가:

```swift
                if let insightMessage {
                    Label(insightMessage, systemImage: "lightbulb.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SDColor.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
```

- [ ] **Step 2: CoachingTabView 연결**

`SessionResult` 구조체에 필드 추가:

```swift
        let insightMessage: String?
```

`onCompleted` 클로저에서 `result = SessionResult(...)` 만들기 **전에** 인사이트 계산 추가:

```swift
                    let insight = (try? InsightEngine.evaluateLatest(in: SessionRepository(modelContext: modelContext))) ?? nil
```

`SessionResult(...)` 생성에 `insightMessage: insight?.message` 인자 추가.

`SaveConfirmView(...)` 호출에 `insightMessage: result.insightMessage,` 인자 추가 (`reminderOffer:` 인자 뒤, `onMoodSelected:` 앞).

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add SmileDay/Views/Coaching/SaveConfirmView.swift SmileDay/Views/Coaching/CoachingTabView.swift
git commit -m "feat: surface check-in insight on save confirmation"
```

---

### Task 5: 최종 검증

- [ ] **Step 1: 전체 테스트**

Run: `cd CoachingKit && swift test 2>&1 | tail -3`
Expected: 전체 통과, 0 failures

- [ ] **Step 2: 앱 빌드**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | tail -3`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 시뮬레이터 스모크 (데모 데이터)**

`-seedDemoData` 런치 인자로 실행 → 케어 탭 추천이 표시되는지 확인. 데모 데이터는 확장 지표(smileAsymmetry 등)가 nil이고 히스토리 browTension이 다양하므로, 인사이트 발동 여부와 무관하게 **추천 카드가 항상 그려지는지**(fallback 포함)만 확인한다.

---

## 스펙 대비 커버리지

| 스펙 항목 | 태스크 |
|---|---|
| InsightEngine 판정 4종 + 우선순위 | Task 1 |
| 신뢰 불가 기록 억제/제외 | Task 1 |
| CheckInRecord 매퍼 (payload 디코드) | Task 2 |
| 최신 체크인 기준 평가 (7일 윈도우, 자기 제외) | Task 2 |
| 케어 추천 교체 + fallback 보존 | Task 3 |
| 저장 완료 화면 노출 | Task 4 |
| 테스트 §5 (1~8) | Task 1 (1,2,3,4,5,6), Task 2 (7), Task 3 (8) |
