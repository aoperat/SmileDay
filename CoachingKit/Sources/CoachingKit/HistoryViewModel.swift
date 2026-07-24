import Foundation
import Observation

public struct DailyScore: Equatable, Identifiable {
    public let date: Date
    public let displayScore: Double
    public var id: Date { date }

    public init(date: Date, displayScore: Double) {
        self.date = date
        self.displayScore = displayScore
    }
}

@Observable
public final class HistoryViewModel {
    public private(set) var weeklyScores: [DailyScore] = []
    public private(set) var monthCheckInDays: Set<Int> = []
    public private(set) var streakDays: Int = 0
    /// 최근 7일 중 기록이 있는 날들의 표시 점수 평균. 기록이 없으면 nil.
    public private(set) var weeklyAverageScore: Double?
    /// 이번 달 체크인 횟수(세션 수 기준 — 같은 날 여러 번도 각각 센다).
    public private(set) var monthCheckInCount: Int = 0

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
        var scores: [DailyScore] = []
        for offset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if let session = try repository.fetchLatestCheckIn(onDayOf: day, calendar: calendar) {
                scores.append(DailyScore(date: day, displayScore: ScoreCalculator.displayValue(session.scoreDelta)))
            }
        }
        weeklyScores = scores
        weeklyAverageScore = scores.isEmpty ? nil : scores.map(\.displayScore).reduce(0, +) / Double(scores.count)
        streakDays = try repository.checkInStreak(endingOn: now(), calendar: calendar)

        guard let monthRange = calendar.dateInterval(of: .month, for: now()) else { return }
        let sessions = try repository.fetchCheckIns(from: monthRange.start, to: monthRange.end)
        monthCheckInDays = Set(sessions.map { calendar.component(.day, from: $0.date) })
        monthCheckInCount = sessions.count
    }

    /// 해당 날짜의 버킷별 대표 점수(표시 점수). 같은 버킷은 마지막 기록이 남는다.
    /// 버킷 귀속은 달력일 기준 — 새벽 기록은 그 날짜의 저녁 버킷으로 분류된다.
    public func bucketScores(onDayOf date: Date) throws -> [TimeBucket: Double] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [:] }
        var scores: [TimeBucket: Double] = [:]
        for session in try repository.fetchCheckIns(from: start, to: end) {
            let bucket = TimeBucket(hour: calendar.component(.hour, from: session.date))
            scores[bucket] = ScoreCalculator.displayValue(session.scoreDelta)
        }
        return scores
    }
}
