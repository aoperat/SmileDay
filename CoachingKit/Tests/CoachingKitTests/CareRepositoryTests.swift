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
