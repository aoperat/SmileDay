import Foundation
import SwiftData

public final class SessionRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func saveBaseline(_ measurement: FaceMeasurement, capturedAt: Date) throws {
        let baseline = Baseline(
            capturedAt: capturedAt,
            mouthCornerLeft: measurement.mouthCornerLeft,
            mouthCornerRight: measurement.mouthCornerRight,
            browTension: measurement.browTension
        )
        modelContext.insert(baseline)
        try modelContext.save()
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
}
