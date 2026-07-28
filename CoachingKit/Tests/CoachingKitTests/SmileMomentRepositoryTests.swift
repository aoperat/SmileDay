import XCTest
import SwiftData
@testable import CoachingKit

final class SmileMomentRepositoryTests: XCTestCase {
    /// 기기 로캘·타임존과 무관하게 같은 결과가 나오도록 고정한다. 한국은 일요일이 주의 첫날.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar.locale = Locale(identifier: "ko_KR")
        calendar.firstWeekday = 1
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func makeRepository() throws -> SmileMomentRepository {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SmileMomentRepository(modelContext: ModelContext(container))
    }

    // MARK: - save

    func test_save_persistsGuideAndSource() throws {
        let repository = try makeRepository()

        let saved = try repository.save(guideID: "greeting-smile", source: .notification, date: date(2026, 7, 28, 9, 30))

        XCTAssertEqual(saved.guideID, "greeting-smile")
        XCTAssertEqual(saved.source, .notification)
        let fetched = try repository.fetch(from: date(2026, 7, 28, 0), to: date(2026, 7, 29, 0))
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.guideID, "greeting-smile")
        XCTAssertEqual(fetched.first?.source, .notification)
    }

    // MARK: - fetch

    func test_fetch_returnsOldestFirst() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 18))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 13))

        let fetched = try repository.fetch(from: date(2026, 7, 28, 0), to: date(2026, 7, 29, 0))

        XCTAssertEqual(fetched.map { calendar.component(.hour, from: $0.date) }, [9, 13, 18])
    }

    /// 시작은 포함, 끝은 제외.
    func test_fetch_isHalfOpenRange() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 0, 0))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 29, 0, 0))

        let fetched = try repository.fetch(from: date(2026, 7, 28, 0), to: date(2026, 7, 29, 0))

        XCTAssertEqual(fetched.count, 1)
    }

    func test_fetch_returnsEmpty_whenNothingSaved() throws {
        let repository = try makeRepository()

        XCTAssertTrue(try repository.fetch(from: date(2026, 7, 1), to: date(2026, 8, 1)).isEmpty)
    }

    // MARK: - count(onDayOf:)

    func test_count_countsEveryCompletionOnThatDay() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))
        try repository.save(guideID: "greeting-smile", source: .notification, date: date(2026, 7, 28, 13))
        try repository.save(guideID: "bright-smile", source: .manual, date: date(2026, 7, 28, 18))

        XCTAssertEqual(try repository.count(onDayOf: date(2026, 7, 28, 21), calendar: calendar), 3)
    }

    /// 자정 직전과 직후는 다른 날이다.
    func test_count_respectsDayBoundary() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 23, 59))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 29, 0, 0))

        XCTAssertEqual(try repository.count(onDayOf: date(2026, 7, 28, 12), calendar: calendar), 1)
        XCTAssertEqual(try repository.count(onDayOf: date(2026, 7, 29, 12), calendar: calendar), 1)
    }

    func test_count_isZero_whenNoCompletionThatDay() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))

        XCTAssertEqual(try repository.count(onDayOf: date(2026, 7, 27, 9), calendar: calendar), 0)
    }

    // MARK: - recentSevenDays

    func test_recentSevenDays_returnsSevenDaysOldestFirst_endingOnGivenDay() throws {
        let repository = try makeRepository()

        let days = try repository.recentSevenDays(endingOn: date(2026, 7, 28, 15), calendar: calendar)

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map { calendar.component(.day, from: $0.date) }, [22, 23, 24, 25, 26, 27, 28])
        XCTAssertEqual(days.map(\.date), days.map { calendar.startOfDay(for: $0.date) })
    }

    func test_recentSevenDays_fillsMissingDaysWithZero() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 18))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 24, 9))

        let days = try repository.recentSevenDays(endingOn: date(2026, 7, 28), calendar: calendar)

        XCTAssertEqual(days.map(\.count), [0, 0, 1, 0, 0, 0, 2])
        XCTAssertEqual(days.map(\.hasSmile), [false, false, true, false, false, false, true])
    }

    /// 7일 창 밖의 기록은 세지 않는다.
    func test_recentSevenDays_excludesOlderAndFutureDays() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 21, 23, 59))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 29, 0, 0))

        let days = try repository.recentSevenDays(endingOn: date(2026, 7, 28), calendar: calendar)

        XCTAssertEqual(days.map(\.count), [0, 0, 0, 0, 0, 0, 0])
    }

    func test_recentSevenDays_returnsAllZeros_whenRepositoryEmpty() throws {
        let repository = try makeRepository()

        let days = try repository.recentSevenDays(endingOn: date(2026, 7, 28), calendar: calendar)

        XCTAssertEqual(days.count, 7)
        XCTAssertTrue(days.allSatisfy { $0.count == 0 })
    }

    // MARK: - weekActiveDayCount

    /// 같은 날 여러 번 완료해도 하루로 센다.
    func test_weekActiveDayCount_countsDistinctDays() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 26, 9))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 9))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 28, 18))

        XCTAssertEqual(try repository.weekActiveDayCount(endingOn: date(2026, 7, 28), calendar: calendar), 2)
    }

    /// 2026-07-28은 화요일. 일요일 시작 주는 07-26 ~ 08-01이라 07-25는 지난 주다.
    func test_weekActiveDayCount_excludesPreviousWeek() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 25, 23, 59))
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 7, 26, 0, 0))

        XCTAssertEqual(try repository.weekActiveDayCount(endingOn: date(2026, 7, 28), calendar: calendar), 1)
    }

    func test_weekActiveDayCount_excludesNextWeek() throws {
        let repository = try makeRepository()
        try repository.save(guideID: "soft-smile", source: .manual, date: date(2026, 8, 2, 9))

        XCTAssertEqual(try repository.weekActiveDayCount(endingOn: date(2026, 7, 28), calendar: calendar), 0)
    }

    func test_weekActiveDayCount_isZero_whenRepositoryEmpty() throws {
        let repository = try makeRepository()

        XCTAssertEqual(try repository.weekActiveDayCount(endingOn: date(2026, 7, 28), calendar: calendar), 0)
    }

    // MARK: - 기존 모델 보존

    /// 새 모델을 넣어도 기존 스키마가 함께 열려야 한다.
    func test_schema_stillContainsLegacyModels() {
        let names = PersistenceSchema.models.map { String(describing: $0) }

        XCTAssertTrue(names.contains("Baseline"))
        XCTAssertTrue(names.contains("CheckInSession"))
        XCTAssertTrue(names.contains("ReminderSetting"))
        XCTAssertTrue(names.contains("CareSession"))
        XCTAssertTrue(names.contains("SmileMoment"))
    }
}
