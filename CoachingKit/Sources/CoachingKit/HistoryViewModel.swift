import Foundation
import Observation

/// 하루치 미소 시간 활동. 점수가 아니라 "몇 번 웃어봤고 좋은 순간을 남겼는지"만 담는다.
public struct SmileDayActivity: Equatable, Identifiable {
    public let date: Date
    public let checkInCount: Int
    public let hasMomentNote: Bool
    public var id: Date { date }

    public init(date: Date, checkInCount: Int, hasMomentNote: Bool) {
        self.date = date
        self.checkInCount = checkInCount
        self.hasMomentNote = hasMomentNote
    }

    public var didCheckIn: Bool { checkInCount > 0 }
}

/// 다시 볼 수 있게 남긴 회고 한 건.
public struct SmileMomentEntry: Equatable, Identifiable {
    public let date: Date
    public let mood: String?
    public let note: String?
    public let promptText: String?
    public var id: Date { date }

    public init(date: Date, mood: String?, note: String?, promptText: String?) {
        self.date = date
        self.mood = mood
        self.note = note
        self.promptText = promptText
    }
}

/// 기록 화면 상태.
///
/// 얼굴 점수와 전날 대비 비교를 다루지 않는다. 웃어본 날, 미소 시간 횟수,
/// 남긴 좋은 순간만 보여준다.
@Observable
public final class HistoryViewModel {
    /// 오늘로 끝나는 최근 7일 활동. 기록이 없는 날도 0회로 포함한다.
    public private(set) var recentActivity: [SmileDayActivity] = []
    /// 이번 달에 체크인이 있는 날짜(일). 캘린더 표시에 쓴다.
    public private(set) var monthCheckInDays: Set<Int> = []
    /// 이번 달 웃어본 고유 일수.
    public private(set) var monthCheckInDayCount: Int = 0
    /// 이번 달에 남긴 좋은 순간 수.
    public private(set) var monthMomentNoteCount: Int = 0
    public private(set) var streakDays: Int = 0
    /// 이번 달 시간대별 미소 시간 횟수. 기록이 없는 버킷은 0.
    public private(set) var bucketCheckInCounts: [TimeBucket: Int] = [:]
    /// 최근에 남긴 좋은 순간(최신순).
    public private(set) var recentMoments: [SmileMomentEntry] = []

    /// 목록에 한 번에 보여줄 최근 회고 수. 전체 보관함은 이후 Pro 후보다.
    public static let recentMomentLimit = 20

    private let repository: SessionRepository
    private let now: () -> Date
    private let calendar: Calendar

    public init(repository: SessionRepository, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
    }

    public func refresh() throws {
        let today = calendar.startOfDay(for: now())
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let weekDigest = CheckInDigest(
            sessions: try repository.fetchCheckIns(from: sixDaysAgo, to: tomorrow),
            calendar: calendar
        )
        recentActivity = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return SmileDayActivity(
                date: day,
                checkInCount: weekDigest.count(onDayOf: day),
                hasMomentNote: weekDigest.hasMomentNote(onDayOf: day)
            )
        }

        streakDays = try repository.checkInStreak(endingOn: now(), calendar: calendar)

        guard let monthRange = calendar.dateInterval(of: .month, for: now()) else { return }
        let monthSessions = try repository.fetchCheckIns(from: monthRange.start, to: monthRange.end)

        monthCheckInDays = Set(monthSessions.map { calendar.component(.day, from: $0.date) })
        monthCheckInDayCount = monthCheckInDays.count
        monthMomentNoteCount = monthSessions.filter { $0.smileMomentNote != nil }.count

        var counts: [TimeBucket: Int] = [:]
        for bucket in TimeBucket.allCases { counts[bucket] = 0 }
        for session in monthSessions {
            let bucket = TimeBucket(hour: calendar.component(.hour, from: session.date))
            counts[bucket, default: 0] += 1
        }
        bucketCheckInCounts = counts

        // 기분이나 한 줄 기록 중 하나라도 남긴 항목만 최신순으로 모은다.
        recentMoments = monthSessions
            .reversed()
            .filter { $0.mood != nil || $0.smileMomentNote != nil }
            .prefix(Self.recentMomentLimit)
            .map {
                SmileMomentEntry(
                    date: $0.date,
                    mood: $0.mood,
                    note: $0.smileMomentNote,
                    promptText: $0.promptText
                )
            }
    }

    /// 해당 날짜의 시간대별 미소 시간 횟수. 기록이 없는 버킷은 0.
    /// 버킷 귀속은 달력일 기준 — 새벽 기록은 그 날짜의 저녁 버킷으로 분류된다.
    public func bucketCounts(onDayOf date: Date) throws -> [TimeBucket: Int] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [:] }
        var counts: [TimeBucket: Int] = [:]
        for bucket in TimeBucket.allCases { counts[bucket] = 0 }
        for session in try repository.fetchCheckIns(from: start, to: end) {
            let bucket = TimeBucket(hour: calendar.component(.hour, from: session.date))
            counts[bucket, default: 0] += 1
        }
        return counts
    }
}
