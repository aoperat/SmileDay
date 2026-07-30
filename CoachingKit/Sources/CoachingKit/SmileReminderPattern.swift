import Foundation

public struct ReminderTime: Equatable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw SmileReminderPatternError.invalidTime
        }
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int {
        hour * 60 + minute
    }
}

public enum SmileReminderPatternError: Error, Equatable, Sendable {
    case invalidTime
    case invalidRange
    case unsupportedInterval
}

public struct SmileReminderPattern: Equatable, Sendable {
    public static let allowedIntervals = [60, 120, 180, 240]

    public let startTime: ReminderTime
    public let endTime: ReminderTime
    public let intervalMinutes: Int

    public static let recommended = SmileReminderPattern(
        uncheckedStart: ReminderTime(uncheckedHour: 9, minute: 0),
        end: ReminderTime(uncheckedHour: 21, minute: 0),
        intervalMinutes: 180
    )

    public init(
        startTime: ReminderTime,
        endTime: ReminderTime,
        intervalMinutes: Int
    ) throws {
        guard startTime.minutesSinceMidnight < endTime.minutesSinceMidnight else {
            throw SmileReminderPatternError.invalidRange
        }
        guard Self.allowedIntervals.contains(intervalMinutes) else {
            throw SmileReminderPatternError.unsupportedInterval
        }
        self.startTime = startTime
        self.endTime = endTime
        self.intervalMinutes = intervalMinutes
    }

    private init(
        uncheckedStart: ReminderTime,
        end: ReminderTime,
        intervalMinutes: Int
    ) {
        startTime = uncheckedStart
        endTime = end
        self.intervalMinutes = intervalMinutes
    }

    public func occurrences() -> [ReminderTime] {
        let end = endTime.minutesSinceMidnight
        return sequence(
            first: startTime.minutesSinceMidnight,
            next: { $0 + intervalMinutes }
        )
        .prefix { $0 <= end }
        .compactMap { minutes in
            try? ReminderTime(hour: minutes / 60, minute: minutes % 60)
        }
    }
}

private extension ReminderTime {
    init(uncheckedHour hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}
