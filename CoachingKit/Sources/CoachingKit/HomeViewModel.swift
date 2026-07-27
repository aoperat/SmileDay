import Foundation
import Observation

/// 하루 단위 체크인 여부. 홈의 최근 7일 도트에 쓴다.
public struct DayCheckIn: Equatable {
    public let date: Date
    public let checkedIn: Bool

    public init(date: Date, checkedIn: Bool) {
        self.date = date
        self.checkedIn = checkedIn
    }
}

/// 홈 화면 상태.
///
/// 점수를 노출하지 않는다. 오늘 잠시 웃어봤는지, 이번 주에 며칠 웃어봤는지,
/// 어떤 좋은 순간을 남겼는지처럼 행동과 회고만 보여준다.
@Observable
public final class HomeViewModel {
    public private(set) var hasCheckedInToday: Bool = false
    public private(set) var streakDays: Int = 0
    /// 오늘의 미소 시간 횟수. 같은 날 여러 번이면 모두 센다.
    public private(set) var todayCheckInCount: Int = 0
    /// 오늘로 끝나는 최근 7일. 주 경계를 넘어도 최근 활동이 보이도록 롤링 윈도로 계산한다.
    public private(set) var recentWeek: [DayCheckIn] = []
    /// 이번 주(월요일~오늘) 중 웃어본 고유 일수. 같은 날 여러 번은 하루로 센다.
    public private(set) var weekCheckInDayCount: Int = 0
    /// 이번 주에 남긴 좋은 순간 수. 같은 날 여러 개면 각각 센다.
    public private(set) var weekMomentNoteCount: Int = 0
    /// 가장 최근에 남긴 좋은 순간. 없으면 nil이며, 빈 상태를 따로 만들지 않는다.
    public private(set) var latestMomentNote: String?

    private let repository: SessionRepository
    private let calendar: Calendar
    private let now: () -> Date

    public init(repository: SessionRepository, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
    }

    public func refresh() throws {
        let today = calendar.startOfDay(for: now())
        // weekday: 일=1 … 토=7 → 월요일까지의 거리(월=0 … 일=6)
        let mondayOffset = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) ?? today
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        // 홈에 필요한 구간(이번 주 ∪ 최근 7일)을 한 번의 범위 조회로 읽는다.
        let sessions = try repository.fetchCheckIns(from: min(monday, sixDaysAgo), to: tomorrow)
        let digest = CheckInDigest(sessions: sessions, calendar: calendar)

        todayCheckInCount = digest.count(onDayOf: today)
        hasCheckedInToday = todayCheckInCount > 0

        recentWeek = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCheckIn(date: day, checkedIn: digest.hasCheckIn(onDayOf: day))
        }

        let thisWeek = sessions.filter { $0.date >= monday }
        weekCheckInDayCount = Set(thisWeek.map { calendar.startOfDay(for: $0.date) }).count
        weekMomentNoteCount = thisWeek.filter { $0.smileMomentNote != nil }.count

        latestMomentNote = try repository.fetchLatestCheckInWithMomentNote()?.smileMomentNote

        streakDays = try repository.checkInStreak(endingOn: now(), calendar: calendar)
    }
}
