import Foundation
import SwiftData

public final class SessionRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func saveBaseline(
        _ measurement: FaceMeasurement,
        capturedAt: Date,
        lightingQuality: Double,
        deviceAngleOK: Bool
    ) throws -> Baseline {
        let baseline = Baseline(
            capturedAt: capturedAt,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension,
            lightingQuality: lightingQuality,
            deviceAngleOK: deviceAngleOK
        )
        modelContext.insert(baseline)
        try modelContext.save()
        return baseline
    }

    public func fetchLatestBaseline() throws -> Baseline? {
        var descriptor = FetchDescriptor<Baseline>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    public func saveCheckIn(
        measurement: FaceMeasurement,
        date: Date,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double,
        summary: SessionMetricsAccumulator.Summary? = nil,
        payload: CheckInPayload? = nil,
        promptText: String? = nil
    ) throws -> CheckInSession {
        let payloadData = try payload.map { try JSONEncoder().encode($0) }
        let session = CheckInSession(
            date: date,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension,
            lightingQuality: lightingQuality,
            deviceAngleOK: deviceAngleOK,
            scoreDelta: scoreDelta,
            smileMean: summary?.smileMean,
            smileMax: summary?.smileMax,
            smileStability: summary?.smileStability,
            smileAsymmetry: summary?.smileAsymmetry,
            duchenneScore: summary?.duchenneScore,
            payload: payloadData,
            payloadVersion: CheckInPayload.currentVersion,
            promptText: SmileReflection.normalizedMomentNote(promptText)
        )
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    public func fetchLatestCheckIn() throws -> CheckInSession? {
        var descriptor = FetchDescriptor<CheckInSession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func hasCheckInToday(calendar: Calendar = .current, now: Date = Date()) throws -> Bool {
        guard let latest = try fetchLatestCheckIn() else { return false }
        return calendar.isDate(latest.date, inSameDayAs: now)
    }

    public func fetchCheckIns(from start: Date, to end: Date) throws -> [CheckInSession] {
        let descriptor = FetchDescriptor<CheckInSession>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func fetchLatestCheckIn(onDayOf date: Date, calendar: Calendar = .current) throws -> CheckInSession? {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return try fetchCheckIns(from: start, to: end).last
    }

    public func hasCheckIn(onDayOf date: Date, calendar: Calendar = .current) throws -> Bool {
        try fetchLatestCheckIn(onDayOf: date, calendar: calendar) != nil
    }

    private func fetchAllCheckIns(before end: Date) throws -> [CheckInSession] {
        let descriptor = FetchDescriptor<CheckInSession>(
            predicate: #Predicate { $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func checkInStreak(endingOn now: Date = Date(), calendar: Calendar = .current) throws -> Int {
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: today) else { return 0 }
        let checkInDays = Set(try fetchAllCheckIns(before: end).map { calendar.startOfDay(for: $0.date) })

        var day = today
        if !checkInDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while checkInDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    public func recentCheckInDays(count: Int, endingOn now: Date = Date(), calendar: Calendar = .current) throws -> [Bool] {
        let today = calendar.startOfDay(for: now)
        return try (0..<count).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return false }
            return try hasCheckIn(onDayOf: day, calendar: calendar)
        }
    }

    public func pruneOldBaselines(keeping: Int = 5) throws {
        let descriptor = FetchDescriptor<Baseline>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
        let all = try modelContext.fetch(descriptor)
        guard all.count > keeping else { return }
        for baseline in all.dropFirst(keeping) {
            modelContext.delete(baseline)
        }
        try modelContext.save()
    }

    /// 방금 저장된 체크인에 회고(기분·한 줄 기록)를 한 번에 기록한다. 체크인이 없으면 무시.
    ///
    /// 회고는 완료 화면에서 한 번만 확정하므로 전달된 값이 곧 최종 상태다.
    /// 비워둔 항목은 nil로 남겨 "기록하지 않음"을 그대로 표현한다.
    public func updateReflectionOnLatestCheckIn(_ reflection: SmileReflection) throws {
        guard let latest = try fetchLatestCheckIn() else { return }
        latest.mood = reflection.mood
        latest.smileMomentNote = reflection.momentNote
        try modelContext.save()
    }
}

// MARK: - 습관 집계
//
// 화면이 SwiftData를 직접 다루지 않도록 하는 조회 모음이다.
// 한 화면에서 여러 지표가 필요할 때는 `fetchCheckIns(from:to:)`를 한 번만 호출한 뒤
// `CheckInDigest`로 집계해 날짜별 N+1 조회를 피한다.
public extension SessionRepository {
    /// 해당 날짜의 체크인 횟수. 같은 날 여러 번 기록했다면 모두 센다.
    func checkInCount(onDayOf date: Date, calendar: Calendar = .current) throws -> Int {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return try fetchCheckIns(from: start, to: end).count
    }

    /// `[start, end)` 구간에서 체크인이 있는 고유 날짜 수. 같은 날 여러 번은 하루로 센다.
    func checkInDayCount(from start: Date, to end: Date, calendar: Calendar = .current) throws -> Int {
        try CheckInDigest(sessions: fetchCheckIns(from: start, to: end), calendar: calendar).checkInDayCount
    }

    /// `[start, end)` 구간에 남은 한 줄 기록 수. 같은 날 여러 개면 각각 센다.
    func momentNoteCount(from start: Date, to end: Date) throws -> Int {
        try fetchCheckIns(from: start, to: end).filter { $0.smileMomentNote != nil }.count
    }

    /// 한 줄 기록이 남아 있는 가장 최근 체크인. 없으면 nil.
    func fetchLatestCheckInWithMomentNote() throws -> CheckInSession? {
        var descriptor = FetchDescriptor<CheckInSession>(
            predicate: #Predicate { $0.smileMomentNote != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// 기준 시각보다 앞선 가장 최근 체크인의 시각. 첫 체크인이면 nil.
    func previousCheckInDate(before date: Date) throws -> Date? {
        var descriptor = FetchDescriptor<CheckInSession>(
            predicate: #Predicate { $0.date < date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.date
    }

    /// 방금 저장한 체크인을 기준으로 격려 문구용 행동 이력을 모은다.
    ///
    /// 얼굴 측정값은 읽지 않는다. 최근 7일 구간을 한 번만 조회해 오늘 횟수와 주간 일수를 함께 계산한다.
    func habitContext(
        for checkIn: CheckInSession,
        calendar: Calendar = .current
    ) throws -> HabitContext {
        let today = calendar.startOfDay(for: checkIn.date)
        let windowStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? checkIn.date
        let digest = CheckInDigest(
            sessions: try fetchCheckIns(from: windowStart, to: tomorrow),
            calendar: calendar
        )

        let previous = try previousCheckInDate(before: checkIn.date)
        let gapDays = previous.flatMap {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: today).day
        }

        return HabitContext(
            todayCheckInCount: digest.count(onDayOf: checkIn.date),
            streakDays: try checkInStreak(endingOn: checkIn.date, calendar: calendar),
            recentSevenDayCount: digest.checkInDayCount,
            daysSincePreviousCheckIn: gapDays,
            hasMomentNote: checkIn.smileMomentNote != nil
        )
    }
}

/// 한 번 조회한 체크인 묶음을 날짜 단위로 집계한 결과.
/// 화면이 날짜마다 저장소를 다시 부르지 않도록 순수 계산으로 분리한다.
public struct CheckInDigest {
    /// 날짜(자정 기준) → 그 날의 체크인 횟수.
    public let countsByDay: [Date: Int]
    /// 한 줄 기록이 하나라도 있는 날짜(자정 기준).
    public let momentNoteDays: Set<Date>
    /// 날짜 키를 만들 때 쓴 달력. 조회 시에도 같은 달력을 써야 키가 맞는다.
    private let calendar: Calendar

    public init(sessions: [CheckInSession], calendar: Calendar = .current) {
        var counts: [Date: Int] = [:]
        var noteDays: Set<Date> = []
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            counts[day, default: 0] += 1
            if session.smileMomentNote != nil { noteDays.insert(day) }
        }
        self.countsByDay = counts
        self.momentNoteDays = noteDays
        self.calendar = calendar
    }

    /// 체크인이 있는 고유 날짜 수.
    public var checkInDayCount: Int { countsByDay.count }

    /// 한 줄 기록이 남은 고유 날짜 수.
    public var momentNoteDayCount: Int { momentNoteDays.count }

    public func count(onDayOf date: Date) -> Int {
        countsByDay[calendar.startOfDay(for: date)] ?? 0
    }

    public func hasCheckIn(onDayOf date: Date) -> Bool {
        count(onDayOf: date) > 0
    }

    public func hasMomentNote(onDayOf date: Date) -> Bool {
        momentNoteDays.contains(calendar.startOfDay(for: date))
    }
}
