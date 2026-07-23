import XCTest
import SwiftData
@testable import CoachingKit

final class BaselineCaptureViewModelTests: XCTestCase {
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

    private final class MutableClock {
        var current: Date
        init(_ current: Date) { self.current = current }
        func advance(by seconds: TimeInterval) { current.addTimeInterval(seconds) }
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

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

    func test_captureBaseline_doesNothing_whenNoMeasurementReceivedYet() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository)

        try viewModel.captureBaseline()

        XCTAssertEqual(viewModel.phase, .tracking)
        XCTAssertNil(try repository.fetchLatestBaseline())
    }

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
}
