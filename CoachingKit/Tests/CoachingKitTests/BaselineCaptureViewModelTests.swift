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
        let schema = PersistenceSchema.schema
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

    func test_captureBaseline_secondCallAfterSaved_doesNotPersistDuplicate() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let mockSession = MockFaceTrackingSession()
        let viewModel = BaselineCaptureViewModel(session: mockSession, repository: repository, now: { Date(timeIntervalSince1970: 5_000) })

        viewModel.start()
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.11, mouthCornerRight: 0.13, browTension: 0.05))
        try viewModel.captureBaseline()

        XCTAssertEqual(viewModel.phase, .saved)
        XCTAssertEqual(mockSession.stopCallCount, 1)

        // Simulate a double-tap: a new measurement arrives and captureBaseline is called again.
        mockSession.emit(FaceMeasurement(mouthCornerLeft: 0.99, mouthCornerRight: 0.98, browTension: 0.97))
        try viewModel.captureBaseline()

        XCTAssertEqual(viewModel.phase, .saved)
        XCTAssertEqual(mockSession.stopCallCount, 1)

        let allBaselines = try context.fetch(FetchDescriptor<Baseline>())
        XCTAssertEqual(allBaselines.count, 1)
        XCTAssertEqual(allBaselines.first?.mouthCornerLeft, 0.11)
    }
}
