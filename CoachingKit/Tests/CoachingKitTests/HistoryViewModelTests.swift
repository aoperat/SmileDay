import XCTest
import SwiftData
@testable import CoachingKit

final class HistoryViewModelTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func saveCheckIn(
        _ repository: SessionRepository,
        daysAgo: Int,
        hour: Int = 12,
        mood: String? = nil,
        note: String? = nil,
        promptText: String? = nil
    ) throws {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date()))!
        let at = calendar.date(byAdding: .hour, value: hour, to: start)!
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: at,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.0,
            promptText: promptText
        )
        if mood != nil || note != nil {
            try repository.updateReflectionOnLatestCheckIn(SmileReflection(mood: mood, momentNote: note))
        }
    }

    // MARK: - 최근 7일 활동

    func test_refresh_recentActivity_coversSevenDaysIncludingEmptyOnes() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        try saveCheckIn(repository, daysAgo: 2)
        try saveCheckIn(repository, daysAgo: 8) // 범위 밖
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentActivity.count, 7)
        XCTAssertEqual(viewModel.recentActivity.map(\.didCheckIn), [false, false, false, false, true, false, true])
        XCTAssertEqual(viewModel.recentActivity.last?.date, Calendar.current.startOfDay(for: Date()))
    }

    func test_refresh_recentActivity_countsMultipleCheckInsPerDay() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 8)
        try saveCheckIn(repository, daysAgo: 0, hour: 13)
        try saveCheckIn(repository, daysAgo: 0, hour: 21)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentActivity.last?.checkInCount, 3)
    }

    func test_refresh_recentActivity_marksDaysWithMomentNote() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 1, note: "동네 고양이")
        try saveCheckIn(repository, daysAgo: 0)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentActivity.map(\.hasMomentNote).suffix(2), [true, false])
    }

    // MARK: - 이번 달

    func test_refresh_collectsMonthCheckInDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertTrue(viewModel.monthCheckInDays.contains(Calendar.current.component(.day, from: Date())))
    }

    func test_refresh_monthCheckInDayCount_countsSameDayOnce() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 9)
        try saveCheckIn(repository, daysAgo: 0, hour: 20)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.monthCheckInDayCount, 1)
        XCTAssertEqual(viewModel.monthCheckInDays.count, 1)
    }

    func test_refresh_monthMomentNoteCount_countsEveryNote() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 9, note: "첫 순간")
        try saveCheckIn(repository, daysAgo: 0, hour: 20, note: "두 번째 순간")
        try saveCheckIn(repository, daysAgo: 0, hour: 22)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.monthMomentNoteCount, 2)
    }

    // MARK: - 시간대별 횟수

    func test_refresh_bucketCheckInCounts_alwaysCoversEveryBucket() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 9)   // 아침
        try saveCheckIn(repository, daysAgo: 0, hour: 20)  // 저녁
        try saveCheckIn(repository, daysAgo: 0, hour: 21)  // 저녁
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.bucketCheckInCounts[.morning], 1)
        XCTAssertEqual(viewModel.bucketCheckInCounts[.afternoon], 0)
        XCTAssertEqual(viewModel.bucketCheckInCounts[.evening], 2)
    }

    func test_bucketCounts_onDayOf_mapsSessionsToBuckets() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 9)
        try saveCheckIn(repository, daysAgo: 0, hour: 13)
        let viewModel = HistoryViewModel(repository: repository)

        let counts = try viewModel.bucketCounts(onDayOf: Date())

        XCTAssertEqual(counts[.morning], 1)
        XCTAssertEqual(counts[.afternoon], 1)
        XCTAssertEqual(counts[.evening], 0)
    }

    func test_bucketCounts_earlyMorningBelongsToEveningBucket() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 2) // 새벽 2시 → 저녁 버킷(달력일 기준)
        let viewModel = HistoryViewModel(repository: repository)

        let counts = try viewModel.bucketCounts(onDayOf: Date())

        XCTAssertEqual(counts[.evening], 1)
        XCTAssertEqual(counts[.morning], 0)
    }

    func test_bucketCounts_allZero_whenNoCheckIns() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let viewModel = HistoryViewModel(repository: repository)

        let counts = try viewModel.bucketCounts(onDayOf: Date())

        XCTAssertEqual(counts.values.reduce(0, +), 0)
        XCTAssertEqual(counts.count, TimeBucket.allCases.count)
    }

    // MARK: - 좋은 순간 목록

    func test_refresh_recentMoments_areNewestFirst() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 9, note: "이른 기록")
        try saveCheckIn(repository, daysAgo: 0, hour: 20, note: "늦은 기록")
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentMoments.map(\.note), ["늦은 기록", "이른 기록"])
    }

    func test_refresh_recentMoments_includeMoodOnlyEntries() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0, hour: 9, mood: "🙂")
        try saveCheckIn(repository, daysAgo: 0, hour: 10) // 아무것도 안 남김
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentMoments.count, 1)
        XCTAssertEqual(viewModel.recentMoments.first?.mood, "🙂")
        XCTAssertNil(viewModel.recentMoments.first?.note)
    }

    func test_refresh_recentMoments_carryPromptText() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let prompt = "오늘 고마웠던 일 하나를 떠올려볼까요?"
        try saveCheckIn(repository, daysAgo: 0, note: "동생의 전화", promptText: prompt)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentMoments.first?.promptText, prompt)
    }

    func test_refresh_recentMoments_areCapped() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        for hour in 0..<(HistoryViewModel.recentMomentLimit + 3) {
            try saveCheckIn(repository, daysAgo: 0, hour: hour, note: "순간 \(hour)")
        }
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentMoments.count, HistoryViewModel.recentMomentLimit)
    }

    /// 회고 필드가 없던 과거 레코드도 활동 수와 캘린더에는 정상 반영된다.
    func test_refresh_handlesLegacyRecordsWithoutReflection() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, daysAgo: 0)
        try saveCheckIn(repository, daysAgo: 1)
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertTrue(viewModel.recentMoments.isEmpty)
        XCTAssertEqual(viewModel.monthMomentNoteCount, 0)
        XCTAssertEqual(viewModel.recentActivity.filter(\.didCheckIn).count, 2)
        XCTAssertTrue(viewModel.recentActivity.allSatisfy { !$0.hasMomentNote })
    }

    func test_refresh_isEmptyButSafe_whenNoRecords() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let viewModel = HistoryViewModel(repository: repository)

        try viewModel.refresh()

        XCTAssertEqual(viewModel.recentActivity.count, 7)
        XCTAssertTrue(viewModel.recentActivity.allSatisfy { !$0.didCheckIn })
        XCTAssertEqual(viewModel.monthCheckInDayCount, 0)
        XCTAssertEqual(viewModel.monthMomentNoteCount, 0)
        XCTAssertEqual(viewModel.streakDays, 0)
        XCTAssertTrue(viewModel.recentMoments.isEmpty)
    }
}
