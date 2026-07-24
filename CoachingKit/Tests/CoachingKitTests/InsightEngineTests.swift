import SwiftData
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
}
