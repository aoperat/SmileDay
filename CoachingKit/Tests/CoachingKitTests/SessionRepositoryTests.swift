import XCTest
import SwiftData
@testable import CoachingKit

final class SessionRepositoryTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_saveBaseline_thenFetchLatestBaseline_returnsSavedValues() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let measurement = FaceMeasurement(mouthCornerLeft: 0.12, mouthCornerRight: 0.14, browTension: 0.2)

        try repository.saveBaseline(measurement, capturedAt: Date(timeIntervalSince1970: 1_000))

        let fetched = try repository.fetchLatestBaseline()
        XCTAssertEqual(fetched?.mouthCornerLeft, 0.12)
        XCTAssertEqual(fetched?.mouthCornerRight, 0.14)
        XCTAssertEqual(fetched?.browTension, 0.2)
    }

    func test_fetchLatestBaseline_returnsNil_whenNoneSaved() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())

        XCTAssertNil(try repository.fetchLatestBaseline())
    }

    func test_saveCheckIn_thenFetchLatestCheckIn_returnsMostRecentByDate() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let older = FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1)
        let newer = FaceMeasurement(mouthCornerLeft: 0.2, mouthCornerRight: 0.2, browTension: 0.2)

        try repository.saveCheckIn(measurement: older, date: Date(timeIntervalSince1970: 1_000), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)
        try repository.saveCheckIn(measurement: newer, date: Date(timeIntervalSince1970: 2_000), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.1)

        let latest = try repository.fetchLatestCheckIn()
        XCTAssertEqual(latest?.mouthCornerLeft, 0.2)
    }

    func test_hasCheckInToday_isFalse_whenLatestCheckInIsYesterday() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        try repository.saveCheckIn(measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1), date: yesterday, lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)

        XCTAssertFalse(try repository.hasCheckInToday(calendar: calendar, now: Date()))
    }

    func test_hasCheckInToday_isTrue_whenLatestCheckInIsToday() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try repository.saveCheckIn(measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1), date: Date(), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)

        XCTAssertTrue(try repository.hasCheckInToday())
    }
}
