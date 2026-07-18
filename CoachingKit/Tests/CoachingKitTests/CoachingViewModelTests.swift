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

    func test_complete_secondCallAfterCompleted_doesNotPersistDuplicate() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let baseline = Baseline(capturedAt: Date(timeIntervalSince1970: 0), mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1)
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
}
