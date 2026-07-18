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

    private func saveCheckIn(_ repository: SessionRepository, date: Date, scoreDelta: Double = 0.0) throws {
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: date,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: scoreDelta
        )
    }

    private func day(_ offset: Int, hour: Int = 12, calendar: Calendar = .current) -> Date {
        let start = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
        return calendar.date(byAdding: .hour, value: hour, to: start)!
    }

    func test_fetchCheckIns_returnsOnlyThoseInRange_sortedAscending() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-2), scoreDelta: 0.0)
        try saveCheckIn(repository, date: day(0), scoreDelta: 0.2)
        try saveCheckIn(repository, date: day(-1), scoreDelta: 0.1)

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day(-1))
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day(0)))!
        let result = try repository.fetchCheckIns(from: start, to: end)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.scoreDelta), [0.1, 0.2])
    }

    func test_fetchLatestCheckIn_onDayOf_returnsThatDaysLatest() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-1, hour: 9), scoreDelta: 0.1)
        try saveCheckIn(repository, date: day(-1, hour: 20), scoreDelta: 0.3)

        XCTAssertEqual(try repository.fetchLatestCheckIn(onDayOf: day(-1))?.scoreDelta, 0.3)
        XCTAssertNil(try repository.fetchLatestCheckIn(onDayOf: day(0)))
    }

    func test_checkInStreak_countsConsecutiveDaysEndingToday() throws {
        let consecutive = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(consecutive, date: day(0))
        try saveCheckIn(consecutive, date: day(-1))
        try saveCheckIn(consecutive, date: day(-2))
        XCTAssertEqual(try consecutive.checkInStreak(), 3)

        let gapped = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(gapped, date: day(0))
        try saveCheckIn(gapped, date: day(-1))
        try saveCheckIn(gapped, date: day(-3))
        XCTAssertEqual(try gapped.checkInStreak(), 2)
    }

    func test_checkInStreak_allowsYesterdayAnchor_whenTodayMissing() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-1))
        try saveCheckIn(repository, date: day(-2))

        XCTAssertEqual(try repository.checkInStreak(), 2)
    }

    func test_recentCheckInDays_returnsOldestToNewest() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0))
        try saveCheckIn(repository, date: day(-2))

        XCTAssertEqual(try repository.recentCheckInDays(count: 3), [true, false, true])
    }
}
