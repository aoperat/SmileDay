import Foundation
import SwiftData

/// 하루치 활동 요약. 쉬어간 날은 실패가 아니라 `count == 0`일 뿐이다.
public struct SmileDayCount: Identifiable, Equatable, Sendable {
    /// 그 날의 시작(startOfDay).
    public let date: Date
    public let count: Int

    public var id: Date { date }
    public var hasSmile: Bool { count > 0 }

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

public final class SmileMomentRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func save(guideID: String, source: SmileMomentSource, date: Date = Date()) throws -> SmileMoment {
        let moment = SmileMoment(date: date, guideID: guideID, source: source)
        modelContext.insert(moment)
        try modelContext.save()
        return moment
    }

    /// `start` 이상 `end` 미만. 오래된 것부터 정렬한다.
    public func fetch(from start: Date, to end: Date) throws -> [SmileMoment] {
        let descriptor = FetchDescriptor<SmileMoment>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// 같은 날 여러 번 완료하면 그만큼 센다.
    public func count(onDayOf date: Date, calendar: Calendar = .current) throws -> Int {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return try fetch(from: start, to: end).count
    }

    /// `date`를 포함한 7일치를 오래된 날부터 반환한다. 기록이 없는 날도 `count: 0`으로 채운다.
    public func recentSevenDays(endingOn date: Date, calendar: Calendar = .current) throws -> [SmileDayCount] {
        let lastDay = calendar.startOfDay(for: date)
        guard let firstDay = calendar.date(byAdding: .day, value: -6, to: lastDay),
              let end = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return [] }

        let moments = try fetch(from: firstDay, to: end)
        var countsByDay: [Date: Int] = [:]
        for moment in moments {
            countsByDay[calendar.startOfDay(for: moment.date), default: 0] += 1
        }

        var days: [SmileDayCount] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
            days.append(SmileDayCount(date: day, count: countsByDay[day] ?? 0))
        }
        return days
    }

    /// `date`가 속한 달력 주(캘린더의 `firstWeekday` 기준)에서 한 번이라도 완료한 날의 수.
    /// 같은 날 여러 번 완료해도 하루로 센다.
    public func weekActiveDayCount(endingOn date: Date, calendar: Calendar = .current) throws -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        let moments = try fetch(from: week.start, to: week.end)
        return Set(moments.map { calendar.startOfDay(for: $0.date) }).count
    }
}
