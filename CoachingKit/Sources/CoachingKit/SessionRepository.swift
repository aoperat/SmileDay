import Foundation
import SwiftData

public final class SessionRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func saveBaseline(_ measurement: FaceMeasurement, capturedAt: Date) throws -> Baseline {
        let baseline = Baseline(
            capturedAt: capturedAt,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension
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

    public func saveCheckIn(
        measurement: FaceMeasurement,
        date: Date,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double
    ) throws {
        let session = CheckInSession(
            date: date,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension,
            lightingQuality: lightingQuality,
            deviceAngleOK: deviceAngleOK,
            scoreDelta: scoreDelta
        )
        modelContext.insert(session)
        try modelContext.save()
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

    public func checkInStreak(endingOn now: Date = Date(), calendar: Calendar = .current) throws -> Int {
        var day = calendar.startOfDay(for: now)
        if try !hasCheckIn(onDayOf: day, calendar: calendar) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while try hasCheckIn(onDayOf: day, calendar: calendar) {
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
}
