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

/// 완료 한 건을 기록하는 경계.
///
/// 저장 실패는 실기기에서만 나는 일이라 테스트가 재현하기 어렵다. 가이드 화면의 재시도가
/// 실제로 동작하는지 보려면 "한 번 실패한 뒤 성공하는" 저장소가 필요해서 이음새를 뒀다.
/// `ReminderScheduling`, `LiveSmileMonitoring`과 같은 방식이다.
public protocol SmileMomentRecording {
    @discardableResult
    func save(guideID: String, source: SmileMomentSource, date: Date) throws -> SmileMoment
}

extension SmileMomentRepository: SmileMomentRecording {}

public final class SmileMomentRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    public func save(guideID: String, source: SmileMomentSource, date: Date = Date()) throws -> SmileMoment {
        let moment = SmileMoment(date: date, guideID: guideID, source: source)
        modelContext.insert(moment)
        do {
            try modelContext.save()
        } catch {
            // 실패한 삽입을 그대로 두면 같은 컨텍스트의 다음 save()가 이것까지 밀어 넣는다 —
            // 저장하지 못했다고 안내한 완료가 뒤늦게 기록된다.
            //
            // rollback()은 컨텍스트 전체의 미저장 변경을 버린다. 뷰들이 SwiftUI mainContext
            // 하나를 공유하고 알림 일정 리포지토리도 같은 컨텍스트 위에 올라가므로, 우리가
            // 만든 것만 지운다.
            modelContext.delete(moment)
            throw error
        }
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
