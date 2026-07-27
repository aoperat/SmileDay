import XCTest
import SwiftData
@testable import CoachingKit

final class CoachingViewModelTests: XCTestCase {
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
        XCTAssertEqual(viewModel.phase, .completed)

        // 점수는 UI 결과로 돌려주지 않지만 데이터 호환을 위해 계속 저장한다.
        let saved = try repository.fetchLatestCheckIn()
        XCTAssertEqual(saved?.scoreDelta ?? -1, 0.3, accuracy: 0.0001)
    }

    func test_complete_persistsPromptText_whenEnteredFromReminder() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)
        let prompt = "오늘 고마웠던 일 하나를 떠올려볼까요?"

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        try viewModel.complete(promptText: prompt)

        XCTAssertEqual(try repository.fetchLatestCheckIn()?.promptText, prompt)
    }

    func test_complete_leavesPromptNil_whenEnteredDirectly() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        try viewModel.complete()

        XCTAssertNil(try repository.fetchLatestCheckIn()?.promptText)
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

    func test_displayedMeasurement_signalsReadiness_andDoesNotChurnPerFrame() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        // 얼굴이 잡히기 전에는 저장할 수 없다.
        XCTAssertNil(viewModel.displayedMeasurement)

        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        XCTAssertNotNil(viewModel.displayedMeasurement)

        // 이후 프레임은 관찰 값을 다시 건드리지 않는다. 점수를 표시하지 않으므로 값이 바뀔 이유가 없다.
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.9, mouthCornerRight: 0.9, browTension: 0.9))
        XCTAssertEqual(viewModel.displayedMeasurement?.mouthCornerLeft ?? -1, 0.4, accuracy: 0.0001)

        // 저장에 쓰는 원시 측정값은 항상 최신을 유지한다.
        XCTAssertEqual(viewModel.latestMeasurement?.mouthCornerLeft ?? -1, 0.9, accuracy: 0.0001)
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

    func test_isAngleOK_defaultsTrue_andFollowsTrackingQualityUpdates() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        XCTAssertTrue(viewModel.isAngleOK)
        mockSession.emitTrackingQuality(false)
        XCTAssertFalse(viewModel.isAngleOK)
        mockSession.emitTrackingQuality(true)
        XCTAssertTrue(viewModel.isAngleOK)
    }

    func test_complete_persistsMeasuredDeviceAngleOK() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        mockSession.emitTrackingQuality(false)
        try viewModel.complete()

        XCTAssertFalse(try XCTUnwrap(repository.fetchLatestCheckIn()).deviceAngleOK)
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

    func test_complete_buildsHabitContextFromBehaviourOnly() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1, lightingQuality: 1.0, deviceAngleOK: true)
        let mockSession = MockFaceTrackingSession()
        let viewModel = CoachingViewModel(session: mockSession, repository: repository, baseline: baseline)

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.4))
        try viewModel.complete()

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        let encouragement = HabitEncouragementEngine.evaluate(try repository.habitContext(for: saved))

        XCTAssertEqual(encouragement.kind, .first)
    }

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
}
