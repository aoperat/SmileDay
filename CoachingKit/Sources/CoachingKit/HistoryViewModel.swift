import Foundation
import Observation

public struct DailyScore: Equatable, Identifiable {
    public let date: Date
    public let displayScore: Int
    public var id: Date { date }

    public init(date: Date, displayScore: Int) {
        self.date = date
        self.displayScore = displayScore
    }
}

@Observable
public final class HistoryViewModel {
    public private(set) var weeklyScores: [DailyScore] = []
    public private(set) var monthCheckInDays: Set<Int> = []

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
                scores.append(DailyScore(date: day, displayScore: ScoreCalculator.displayScore(session.scoreDelta)))
            }
        }
        weeklyScores = scores

        guard let monthRange = calendar.dateInterval(of: .month, for: now()) else { return }
        let sessions = try repository.fetchCheckIns(from: monthRange.start, to: monthRange.end)
        monthCheckInDays = Set(sessions.map { calendar.component(.day, from: $0.date) })
    }
}
