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

@Observable
public final class HomeViewModel {
    public private(set) var hasCheckedInToday: Bool = false
    public private(set) var streakDays: Int = 0
    /// 어제 체크인의 표시 점수(°). 어제 기록이 없으면 nil.
    public private(set) var yesterdayScore: Int?
    /// 오늘 체크인의 표시 점수(°). 오늘 기록이 없으면 nil.
    public private(set) var todayScore: Int?
    /// 오늘로 끝나는 최근 7일. 주 경계를 넘어도 최근 활동이 보이도록 롤링 윈도로 계산한다.
    public private(set) var recentWeek: [DayCheckIn] = []
    /// 이번 주(월요일~오늘) 체크인 횟수.
    public private(set) var weekCheckInCount: Int = 0
    /// 최근 7일 중 기록이 있는 날들의 표시 점수 평균. 기록이 없으면 nil.
    public private(set) var weeklyAverageScore: Double?

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
        var latestDeltaByDay: [Date: Double] = [:]
        for session in sessions { // 날짜 오름차순이라 같은 날은 마지막 기록이 남는다
            latestDeltaByDay[calendar.startOfDay(for: session.date)] = session.scoreDelta
        }

        hasCheckedInToday = latestDeltaByDay[today] != nil
        todayScore = latestDeltaByDay[today].map(ScoreCalculator.displayScore)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            yesterdayScore = latestDeltaByDay[yesterday].map(ScoreCalculator.displayScore)
        } else {
            yesterdayScore = nil
        }

        recentWeek = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCheckIn(date: day, checkedIn: latestDeltaByDay[day] != nil)
        }

        weekCheckInCount = (0...mondayOffset).reduce(0) { count, offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return count }
            return count + (latestDeltaByDay[day] != nil ? 1 : 0)
        }

        let recentScores = recentWeek.compactMap { latestDeltaByDay[$0.date].map(ScoreCalculator.displayScore) }
        weeklyAverageScore = recentScores.isEmpty ? nil : Double(recentScores.reduce(0, +)) / Double(recentScores.count)

        streakDays = try repository.checkInStreak(endingOn: now(), calendar: calendar)
    }
}
