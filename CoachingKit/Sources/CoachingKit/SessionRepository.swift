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
        payload: CheckInPayload? = nil
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
            payloadVersion: CheckInPayload.currentVersion
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

    /// 방금 저장된 체크인에 기분 이모지를 사후 기록한다. 체크인이 없으면 무시.
    public func updateMoodOnLatestCheckIn(_ mood: String) throws {
        guard let latest = try fetchLatestCheckIn() else { return }
        latest.mood = mood
        try modelContext.save()
    }
}
