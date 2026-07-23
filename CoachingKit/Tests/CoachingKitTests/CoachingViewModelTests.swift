import XCTest
import SwiftData
@testable import CoachingKit

final class CoachingViewModelTests: XCTestCase {
    private final class MockFaceTrackingSession: FaceTrackingSession {
        var onUpdate: ((FaceMeasurement) -> Void)?
        var onError: ((Error) -> Void)?
        var onLightingUpdate: ((Double) -> Void)?
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
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_complete_savesCheckIn_andTransitionsToCompletedPhase() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
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
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        try viewModel.complete()

        XCTAssertEqual(viewModel.phase, .tracking)
        XCTAssertNil(try repository.fetchLatestCheckIn())
    }

    func test_complete_secondCallAfterCompleted_doesNotPersistDuplicate() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline, now: { Date(timeIntervalSince1970: 5_000) })

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        try viewModel.complete()
        XCTAssertEqual(mockSession.stopCallCount, 1)

        // Simulate a double-tap: a new measurement arrives and complete() is called again.
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.9, mouthCornerRight: 0.9, browTension: 0.9))
        try viewModel.complete()
        XCTAssertEqual(mockSession.stopCallCount, 1)

        let allCheckIns = try context.fetch(FetchDescriptor<CheckInSession>())
        XCTAssertEqual(allCheckIns.count, 1)
    }

    func test_displayedMeasurement_updatesOnlyWhenDisplayScoreChanges() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        XCTAssertEqual(viewModel.displayedMeasurement?.mouthCornerLeft ?? -1, 0.4, accuracy: 0.0001)

        // 표시 점수(0.1° 단위)가 같은 미세 변화는 UI 관찰값을 갱신하지 않는다.
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4004, mouthCornerRight: 0.4, browTension: 0.4))
        XCTAssertEqual(viewModel.displayedMeasurement?.mouthCornerLeft ?? -1, 0.4, accuracy: 0.0001)
        // 원시 측정값은 항상 최신을 유지해 저장 시 정확한 값을 쓴다.
        XCTAssertEqual(viewModel.latestMeasurement?.mouthCornerLeft ?? -1, 0.4004, accuracy: 0.0001)

        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.5, mouthCornerRight: 0.5, browTension: 0.5))
        XCTAssertEqual(viewModel.displayedMeasurement?.mouthCornerLeft ?? -1, 0.5, accuracy: 0.0001)
    }

    func test_isLightingPoor_true_whenAmbientBelowThreshold() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        XCTAssertFalse(viewModel.isLightingPoor)
        mockSession.emitLighting(200)
        XCTAssertTrue(viewModel.isLightingPoor)
        mockSession.emitLighting(800)
        XCTAssertFalse(viewModel.isLightingPoor)
    }

    func test_complete_persistsMeasuredLightingQuality() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        mockSession.emitLighting(500)
        try viewModel.complete()

        XCTAssertEqual(try XCTUnwrap(repository.fetchLatestCheckIn()).lightingQuality, 0.5, accuracy: 0.001)
    }

    func test_complete_persistsNeutralLighting_whenNoLightingReceived() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        try viewModel.complete()

        XCTAssertEqual(try XCTUnwrap(repository.fetchLatestCheckIn()).lightingQuality, 1.0, accuracy: 0.001)
    }

    func test_yesterdayDelta_returnsYesterdaysLatestScoreDelta() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        XCTAssertNil(try viewModel.yesterdayDelta())

        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: yesterday,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.2
        )

        XCTAssertEqual(try XCTUnwrap(viewModel.yesterdayDelta()), 0.2, accuracy: 0.001)
    }
}
