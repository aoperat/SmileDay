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

        try repository.saveBaseline(measurement, capturedAt: Date(timeIntervalSince1970: 1_000), lightingQuality: 1.0, deviceAngleOK: true)

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

    func test_checkInStreak_isZero_whenNoCheckIns() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())

        XCTAssertEqual(try repository.checkInStreak(), 0)
    }

    func test_checkInStreak_countsLongConsecutiveStreak() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        for offset in 0..<50 {
            try saveCheckIn(repository, date: day(-offset))
        }

        XCTAssertEqual(try repository.checkInStreak(), 50)
    }

    func test_checkInStreak_ignoresOlderStreak_separatedByGap() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0))
        try saveCheckIn(repository, date: day(-1))
        // gap at day(-2)
        try saveCheckIn(repository, date: day(-5))
        try saveCheckIn(repository, date: day(-6))
        try saveCheckIn(repository, date: day(-7))

        XCTAssertEqual(try repository.checkInStreak(), 2)
    }

    func test_recentCheckInDays_returnsOldestToNewest() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0))
        try saveCheckIn(repository, date: day(-2))

        XCTAssertEqual(try repository.recentCheckInDays(count: 3), [true, false, true])
    }

    func test_pruneOldBaselines_keepsOnlyMostRecentN() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        for offset in 0..<8 {
            try repository.saveBaseline(
                FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
                capturedAt: day(-offset),
                lightingQuality: 1.0,
                deviceAngleOK: true
            )
        }

        try repository.pruneOldBaselines(keeping: 5)

        let remaining = try context.fetch(FetchDescriptor<Baseline>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]))
        XCTAssertEqual(remaining.count, 5)
        XCTAssertEqual(remaining.first?.capturedAt, day(0))
        XCTAssertEqual(remaining.last?.capturedAt, day(-4))
    }

    func test_pruneOldBaselines_doesNothing_whenCountAtOrBelowLimit() throws {
        let context = try makeInMemoryContext()
        let repository = SessionRepository(modelContext: context)
        for offset in 0..<3 {
            try repository.saveBaseline(
                FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
                capturedAt: day(-offset),
                lightingQuality: 1.0,
                deviceAngleOK: true
            )
        }

        try repository.pruneOldBaselines(keeping: 5)

        let remaining = try context.fetch(FetchDescriptor<Baseline>())
        XCTAssertEqual(remaining.count, 3)
    }

    func test_saveCheckIn_persistsSummaryColumnsAndPayload() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let stats = [
            DerivedMetric.smile: MetricStats(mean: 0.4, max: 0.6, std: 0.2),
            DerivedMetric.smileAsymmetry: MetricStats(mean: 0.05, max: 0.1, std: 0.02),
            DerivedMetric.duchenne: MetricStats(mean: 0.3, max: 0.5, std: 0.1),
        ]
        let summary = SessionMetricsAccumulator.Summary(stats: stats, durationSeconds: 10, trackingLossCount: 1)
        let payload = CheckInPayload(
            blendshapesFinal: ["jawOpen": 0.2],
            sessionStats: stats,
            pitchDegrees: 2.0,
            yawDegrees: -3.0,
            captureDurationSeconds: 10,
            trackingLossCount: 1
        )

        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.4, mouthCornerRight: 0.4, browTension: 0.1),
            date: Date(timeIntervalSince1970: 1_000),
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.2,
            summary: summary,
            payload: payload
        )

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertEqual(saved.smileMean ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(saved.smileMax ?? -1, 0.6, accuracy: 0.0001)
        XCTAssertEqual(saved.smileStability ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(saved.smileAsymmetry ?? -1, 0.05, accuracy: 0.0001)
        XCTAssertEqual(saved.duchenneScore ?? -1, 0.3, accuracy: 0.0001)
        XCTAssertEqual(saved.payloadVersion, CheckInPayload.currentVersion)
        let decoded = try JSONDecoder().decode(CheckInPayload.self, from: XCTUnwrap(saved.payload))
        XCTAssertEqual(decoded, payload)
    }

    func test_saveCheckIn_withoutSummary_leavesNewColumnsNil() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 1_000))

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertNil(saved.smileMean)
        XCTAssertNil(saved.mood)
        XCTAssertNil(saved.payload)
        XCTAssertNil(saved.promptText)
        XCTAssertNil(saved.smileMomentNote)
    }

    // MARK: - 회고 (질문 / 기분 / 한 줄 기록)

    func test_saveCheckIn_persistsPromptText() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let prompt = "오늘 나를 미소 짓게 한 순간이 있었나요?"

        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: Date(timeIntervalSince1970: 1_000),
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.0,
            promptText: prompt
        )

        XCTAssertEqual(try repository.fetchLatestCheckIn()?.promptText, prompt)
    }

    func test_saveCheckIn_normalizesBlankPromptToNil() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())

        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: Date(timeIntervalSince1970: 1_000),
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.0,
            promptText: "   "
        )

        XCTAssertNil(try repository.fetchLatestCheckIn()?.promptText)
    }

    func test_updateReflectionOnLatestCheckIn_savesMoodAndNoteTogether() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 1_000))
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 2_000))

        try repository.updateReflectionOnLatestCheckIn(
            SmileReflection(mood: "😊", momentNote: "동료가 건넨 커피")
        )

        let sessions = try repository.fetchCheckIns(from: .distantPast, to: .distantFuture)
        XCTAssertNil(sessions.first?.mood)
        XCTAssertNil(sessions.first?.smileMomentNote)
        XCTAssertEqual(sessions.last?.mood, "😊")
        XCTAssertEqual(sessions.last?.smileMomentNote, "동료가 건넨 커피")
    }

    func test_updateReflectionOnLatestCheckIn_storesBlankNoteAsNil() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 1_000))

        try repository.updateReflectionOnLatestCheckIn(SmileReflection(mood: "🙂", momentNote: "   \n "))

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertEqual(saved.mood, "🙂")
        XCTAssertNil(saved.smileMomentNote)
    }

    func test_updateReflectionOnLatestCheckIn_acceptsEmptyReflection() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 1_000))

        try repository.updateReflectionOnLatestCheckIn(SmileReflection())

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertNil(saved.mood)
        XCTAssertNil(saved.smileMomentNote)
    }

    func test_updateReflectionOnLatestCheckIn_truncatesNoteAtLimit() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: Date(timeIntervalSince1970: 1_000))
        let tooLong = String(repeating: "가", count: SmileReflection.momentNoteLimit + 25)

        try repository.updateReflectionOnLatestCheckIn(SmileReflection(momentNote: tooLong))

        let saved = try XCTUnwrap(repository.fetchLatestCheckIn())
        XCTAssertEqual(saved.smileMomentNote?.count, SmileReflection.momentNoteLimit)
    }

    func test_updateReflectionOnLatestCheckIn_doesNothing_whenNoCheckIns() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())

        XCTAssertNoThrow(try repository.updateReflectionOnLatestCheckIn(SmileReflection(mood: "😊")))
        XCTAssertNil(try repository.fetchLatestCheckIn())
    }

    // MARK: - 습관 집계

    private func saveCheckIn(_ repository: SessionRepository, date: Date, note: String?) throws {
        try repository.saveCheckIn(
            measurement: FaceMeasurement(mouthCornerLeft: 0.1, mouthCornerRight: 0.1, browTension: 0.1),
            date: date,
            lightingQuality: 1.0,
            deviceAngleOK: true,
            scoreDelta: 0.0
        )
        try repository.updateReflectionOnLatestCheckIn(SmileReflection(momentNote: note))
    }

    func test_checkInCount_onDayOf_countsEveryCheckInThatDay() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0, hour: 8))
        try saveCheckIn(repository, date: day(0, hour: 14))
        try saveCheckIn(repository, date: day(-1, hour: 20))

        XCTAssertEqual(try repository.checkInCount(onDayOf: day(0)), 2)
        XCTAssertEqual(try repository.checkInCount(onDayOf: day(-1)), 1)
        XCTAssertEqual(try repository.checkInCount(onDayOf: day(-2)), 0)
    }

    func test_checkInCount_onDayOf_respectsDayBoundaries() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0, hour: 0))
        try saveCheckIn(repository, date: day(0, hour: 23))
        try saveCheckIn(repository, date: day(1, hour: 0))

        XCTAssertEqual(try repository.checkInCount(onDayOf: day(0)), 2)
        XCTAssertEqual(try repository.checkInCount(onDayOf: day(1)), 1)
    }

    func test_checkInDayCount_countsSameDayOnce() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-2, hour: 9))
        try saveCheckIn(repository, date: day(-2, hour: 21))
        try saveCheckIn(repository, date: day(0, hour: 12))

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day(-6))
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day(0)))!

        XCTAssertEqual(try repository.checkInDayCount(from: start, to: end), 2)
    }

    func test_momentNoteCount_countsOnlySavedNotes() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-1, hour: 9), note: "산책")
        try saveCheckIn(repository, date: day(-1, hour: 18), note: "   ")
        try saveCheckIn(repository, date: day(0, hour: 12), note: "동생 전화")
        try saveCheckIn(repository, date: day(0, hour: 20), note: nil)

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day(-6))
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day(0)))!

        XCTAssertEqual(try repository.momentNoteCount(from: start, to: end), 2)
    }

    func test_fetchLatestCheckInWithMomentNote_skipsRecordsWithoutNote() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-3), note: "오래된 기록")
        try saveCheckIn(repository, date: day(-1), note: "가장 최근 메모")
        try saveCheckIn(repository, date: day(0), note: nil)

        XCTAssertEqual(try repository.fetchLatestCheckInWithMomentNote()?.smileMomentNote, "가장 최근 메모")
    }

    func test_fetchLatestCheckInWithMomentNote_isNil_whenNoNotesExist() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0))

        XCTAssertNil(try repository.fetchLatestCheckInWithMomentNote())
    }

    func test_previousCheckInDate_returnsMostRecentBefore() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-5))
        try saveCheckIn(repository, date: day(-2))

        XCTAssertEqual(try repository.previousCheckInDate(before: day(0)), day(-2))
        XCTAssertEqual(try repository.previousCheckInDate(before: day(-2)), day(-5))
        XCTAssertNil(try repository.previousCheckInDate(before: day(-5)))
    }

    // MARK: - habitContext

    func test_habitContext_firstCheckIn_hasNoPreviousGap() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0))
        let latest = try XCTUnwrap(repository.fetchLatestCheckIn())

        let context = try repository.habitContext(for: latest)

        XCTAssertEqual(context.todayCheckInCount, 1)
        XCTAssertEqual(context.streakDays, 1)
        XCTAssertEqual(context.recentSevenDayCount, 1)
        XCTAssertNil(context.daysSincePreviousCheckIn)
        XCTAssertFalse(context.hasMomentNote)
    }

    func test_habitContext_secondCheckInSameDay_reportsZeroGap() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0, hour: 9))
        try saveCheckIn(repository, date: day(0, hour: 19))
        let latest = try XCTUnwrap(repository.fetchLatestCheckIn())

        let context = try repository.habitContext(for: latest)

        XCTAssertEqual(context.todayCheckInCount, 2)
        XCTAssertEqual(context.daysSincePreviousCheckIn, 0)
        XCTAssertEqual(context.recentSevenDayCount, 1)
    }

    func test_habitContext_afterGap_reportsDayDistance() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-4))
        try saveCheckIn(repository, date: day(0))
        let latest = try XCTUnwrap(repository.fetchLatestCheckIn())

        let context = try repository.habitContext(for: latest)

        XCTAssertEqual(context.daysSincePreviousCheckIn, 4)
        XCTAssertEqual(context.streakDays, 1)
        XCTAssertEqual(context.recentSevenDayCount, 2)
    }

    func test_habitContext_countsWeekDaysNotSessions() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-2, hour: 9))
        try saveCheckIn(repository, date: day(-2, hour: 20))
        try saveCheckIn(repository, date: day(-1))
        try saveCheckIn(repository, date: day(0))
        let latest = try XCTUnwrap(repository.fetchLatestCheckIn())

        let context = try repository.habitContext(for: latest)

        XCTAssertEqual(context.recentSevenDayCount, 3)
        XCTAssertEqual(context.streakDays, 3)
    }

    func test_habitContext_excludesDaysOutsideSevenDayWindow() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-9))
        try saveCheckIn(repository, date: day(-6))
        try saveCheckIn(repository, date: day(0))
        let latest = try XCTUnwrap(repository.fetchLatestCheckIn())

        let context = try repository.habitContext(for: latest)

        XCTAssertEqual(context.recentSevenDayCount, 2, "9일 전 기록은 최근 7일 창 밖이다")
    }

    func test_habitContext_reflectsMomentNote() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(0), note: "옆자리 웃음소리")
        let latest = try XCTUnwrap(repository.fetchLatestCheckIn())

        XCTAssertTrue(try repository.habitContext(for: latest).hasMomentNote)
    }

    // MARK: - CheckInDigest

    func test_checkInDigest_aggregatesCountsAndNoteDays() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        try saveCheckIn(repository, date: day(-1, hour: 9), note: "첫 메모")
        try saveCheckIn(repository, date: day(-1, hour: 18), note: nil)
        try saveCheckIn(repository, date: day(0, hour: 12), note: nil)

        let digest = CheckInDigest(
            sessions: try repository.fetchCheckIns(from: .distantPast, to: .distantFuture),
            calendar: .current
        )

        XCTAssertEqual(digest.checkInDayCount, 2)
        XCTAssertEqual(digest.count(onDayOf: day(-1)), 2)
        XCTAssertEqual(digest.count(onDayOf: day(0)), 1)
        XCTAssertEqual(digest.count(onDayOf: day(-5)), 0)
        XCTAssertTrue(digest.hasCheckIn(onDayOf: day(0)))
        XCTAssertFalse(digest.hasCheckIn(onDayOf: day(-5)))
        XCTAssertTrue(digest.hasMomentNote(onDayOf: day(-1)))
        XCTAssertFalse(digest.hasMomentNote(onDayOf: day(0)))
        XCTAssertEqual(digest.momentNoteDayCount, 1)
    }

    func test_checkInDigest_isEmpty_forNoSessions() {
        let digest = CheckInDigest(sessions: [], calendar: .current)

        XCTAssertEqual(digest.checkInDayCount, 0)
        XCTAssertEqual(digest.momentNoteDayCount, 0)
        XCTAssertFalse(digest.hasCheckIn(onDayOf: Date()))
    }

    func test_checkInDigest_handlesMonthBoundary() throws {
        let repository = SessionRepository(modelContext: try makeInMemoryContext())
        let calendar = Calendar.current
        let firstOfMonth = calendar.dateInterval(of: .month, for: Date())!.start
        let lastOfPreviousMonth = calendar.date(byAdding: .day, value: -1, to: firstOfMonth)!

        try saveCheckIn(repository, date: calendar.date(byAdding: .hour, value: 23, to: lastOfPreviousMonth)!)
        try saveCheckIn(repository, date: calendar.date(byAdding: .hour, value: 1, to: firstOfMonth)!)

        let digest = CheckInDigest(
            sessions: try repository.fetchCheckIns(from: .distantPast, to: .distantFuture),
            calendar: calendar
        )

        XCTAssertEqual(digest.checkInDayCount, 2, "월 경계를 넘는 두 기록은 서로 다른 날이다")
        XCTAssertEqual(digest.count(onDayOf: firstOfMonth), 1)
        XCTAssertEqual(digest.count(onDayOf: lastOfPreviousMonth), 1)
    }
}
