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
    public static let allowedIntervals = [30, 60, 120, 180, 240]

    static let minutesPerDay = 24 * 60

    public let startTime: ReminderTime
    public let endTime: ReminderTime
    public let intervalMinutes: Int

    public static let recommended = SmileReminderPattern(
        uncheckedStart: ReminderTime(uncheckedHour: 9, minute: 0),
        end: ReminderTime(uncheckedHour: 21, minute: 0),
        intervalMinutes: 180
    )

    /// 시작이 종료보다 늦으면 자정을 넘는 시간창이다 — 22:00~02:00처럼 밤에 일하는
    /// 사람에게는 이 창이 하루 전부다. 같은 시각만 거부한다: 길이가 0인지 24시간인지
    /// 구분할 방법이 없다.
    public init(
        startTime: ReminderTime,
        endTime: ReminderTime,
        intervalMinutes: Int
    ) throws {
        guard startTime != endTime else {
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

    /// 저장된 시·분 네 개에서 조립한다. 하나라도 성립하지 않으면 nil.
    ///
    /// 모델(`SmileReminderSchedule`)과 뷰모델(`SmileReminderScheduleViewModel`)이 똑같이
    /// 필요로 하던 조립이다. 예전에는 양쪽에 같은 9줄이 따로 있었고, 유효성 규칙을 바꾸면
    /// 두 곳을 함께 고쳐야 했다 — 한쪽만 고치면 화면은 받아주는 값을 저장소가 되읽지 못한다.
    public init?(
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        intervalMinutes: Int
    ) {
        guard let start = try? ReminderTime(hour: startHour, minute: startMinute),
              let end = try? ReminderTime(hour: endHour, minute: endMinute),
              let pattern = try? SmileReminderPattern(
                  startTime: start,
                  endTime: end,
                  intervalMinutes: intervalMinutes
              ) else {
            return nil
        }
        self = pattern
    }

    /// 종료가 시작보다 이른 시각이면 그 창은 다음 날 종료 시각까지 이어진다.
    public var crossesMidnight: Bool {
        endTime.minutesSinceMidnight < startTime.minutesSinceMidnight
    }

    /// 시작부터 종료까지의 길이(분). 자정을 넘으면 하루를 더해서 잰다.
    var spanMinutes: Int {
        let raw = endTime.minutesSinceMidnight - startTime.minutesSinceMidnight
        return raw > 0 ? raw : raw + Self.minutesPerDay
    }

    /// 시작 시각부터 주기마다, 창의 길이를 넘지 않을 때까지. 종료 시각은 주기에 정확히
    /// 맞아떨어질 때만 포함된다.
    ///
    /// 창이 지나가는 순서대로 돌려준다 — 시계 순이 아니다. 자정을 넘는 창은 22:00, 23:00,
    /// 00:00 순이 된다. 알림 문구가 이 순서로 돌기 때문에 사용자가 겪는 순서와 같아야 한다.
    /// 시계 순이 필요한 쪽(다음 알림 계산)은 받아서 정렬한다.
    public func occurrences() -> [ReminderTime] {
        stride(from: 0, through: spanMinutes, by: intervalMinutes).compactMap { offset in
            let minutes = (startTime.minutesSinceMidnight + offset) % Self.minutesPerDay
            return try? ReminderTime(hour: minutes / 60, minute: minutes % 60)
        }
    }
}

private extension ReminderTime {
    init(uncheckedHour hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}
