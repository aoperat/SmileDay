import XCTest
import SwiftData
@testable import CoachingKit

final class HomeViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    func test_refresh_setsHasCheckedInToday_true_whenCheckInExistsToday() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        try repository.saveCheckIn(measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1), date: Date(), lightingQuality: 1.0, deviceAngleOK: true, scoreDelta: 0.0)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertTrue(viewModel.hasCheckedInToday)
    }

    func test_refresh_setsHasCheckedInToday_false_whenNoCheckInToday() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertFalse(viewModel.hasCheckedInToday)
    }

    private func saveCheckIn(_ repository: SessionRepository, daysAgo: Int) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        let noon = calendar.date(byAdding: .hour, value: 12, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: noon,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.0
        )
    }

    func test_refresh_computesStreakDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        try saveCheckIn(repository, daysAgo: 1)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.streakDays, 2)
    }

    func test_refresh_computesRecentWeek_rollingSevenDays_oldestToNewest() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        try saveCheckIn(repository, daysAgo: 3)
        let viewModel = HomeViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentWeek.map(\.checkedIn), [false, false, false, true, false, false, true])
        XCTAssertEqual(viewModel.recentWeek.last?.date, Calendar.current.startOfDay(for: Date()))
    }

    private func saveCheckIn(
        _ repository: SessionRepository,
        daysAgo: Int,
        from now: Date,
        hour: Int = 12,
        note: String? = nil
    ) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let at = calendar.date(byAdding: .hour, value: hour, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: at,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.0
        )
        if note != nil {
            try repository.updateReflectionOnLatestCheckIn(SmileReflection(momentNote: note))
        }
    }

    // 2026-07-15 수요일 정오 고정
    private var fixedNow: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
    }

    func test_refresh_todayCheckInCount_countsEveryCheckInToday() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 0, from: now, hour: 8)
        try saveCheckIn(repository, daysAgo: 0, from: now, hour: 11)
        try saveCheckIn(repository, daysAgo: 1, from: now)
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.todayCheckInCount, 2)
        XCTAssertTrue(viewModel.hasCheckedInToday)
    }

    func test_refresh_todayCheckInCount_isZero_whenNoCheckInToday() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let viewModel = HomeViewModel(repository: repository, now: { self.fixedNow })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.todayCheckInCount, 0)
        XCTAssertFalse(viewModel.hasCheckedInToday)
    }

    func test_refresh_weekCheckInDayCount_countsMondayThroughTodayAsDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 0, from: now, hour: 8)  // 수 — 같은 날 2회
        try saveCheckIn(repository, daysAgo: 0, from: now, hour: 20) // 수
        try saveCheckIn(repository, daysAgo: 2, from: now)           // 월
        try saveCheckIn(repository, daysAgo: 3, from: now)           // 지난주 일 — 이번 주 아님
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weekCheckInDayCount, 2, "같은 날 2회는 하루로 센다")
        XCTAssertEqual(viewModel.todayCheckInCount, 2, "오늘 횟수에는 2회 모두 반영한다")
        // 롤링 7일에는 지난주 일요일 기록도 그대로 보인다.
        XCTAssertEqual(viewModel.recentWeek.filter(\.checkedIn).count, 3)
    }

    func test_refresh_weekMomentNoteCount_countsNotesNotDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 0, from: now, hour: 8, note: "아침 햇빛")
        try saveCheckIn(repository, daysAgo: 0, from: now, hour: 20, note: "저녁 산책")
        try saveCheckIn(repository, daysAgo: 2, from: now)                        // 메모 없음
        try saveCheckIn(repository, daysAgo: 3, from: now, note: "지난주 기록")     // 이번 주 아님
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weekMomentNoteCount, 2)
    }

    func test_refresh_latestMomentNote_picksMostRecentNote() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 3, from: now, note: "오래된 순간")
        try saveCheckIn(repository, daysAgo: 1, from: now, note: "가장 최근 순간")
        try saveCheckIn(repository, daysAgo: 0, from: now)  // 메모 없이 완료
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.latestMomentNote, "가장 최근 순간")
    }

    func test_refresh_latestMomentNote_isNil_whenNoNotesEverSaved() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 0, from: now)
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertNil(viewModel.latestMomentNote)
    }

    func test_refresh_isEmptyButSafe_whenNoRecords() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let viewModel = HomeViewModel(repository: repository, now: { self.fixedNow })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weekCheckInDayCount, 0)
        XCTAssertEqual(viewModel.weekMomentNoteCount, 0)
        XCTAssertEqual(viewModel.streakDays, 0)
        XCTAssertNil(viewModel.latestMomentNote)
        XCTAssertEqual(viewModel.recentWeek.count, 7)
        XCTAssertTrue(viewModel.recentWeek.allSatisfy { !$0.checkedIn })
    }

    /// 과거에 저장된 레코드는 mood/note가 nil이다. 홈이 그 기록도 정상적으로 센다.
    func test_refresh_handlesLegacyRecordsWithoutReflection() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let now = fixedNow
        try saveCheckIn(repository, daysAgo: 0, from: now)
        try saveCheckIn(repository, daysAgo: 1, from: now)
        let viewModel = HomeViewModel(repository: repository, now: { now })

        try viewModel.refresh()

        XCTAssertEqual(viewModel.weekCheckInDayCount, 2)
        XCTAssertEqual(viewModel.weekMomentNoteCount, 0)
        XCTAssertNil(viewModel.latestMomentNote)
    }
}
