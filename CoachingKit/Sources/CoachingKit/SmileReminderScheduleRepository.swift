import Foundation
import SwiftData

public final class SmileReminderScheduleRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchCurrent() throws -> SmileReminderSchedule? {
        var descriptor = FetchDescriptor<SmileReminderSchedule>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    public func save(
        pattern: SmileReminderPattern,
        isEnabled: Bool,
        notificationGroupID: String? = nil,
        now: Date = Date()
    ) throws -> SmileReminderSchedule {
        if let current = try fetchCurrent() {
            // 저장에 실패해도 뷰모델은 이 객체를 계속 들고 화면에 보여준다. 되돌릴 값을
            // 먼저 떠 둔다 — rollback()은 컨텍스트를 공유하는 다른 리포지토리의 미저장
            // 변경까지 버리고, 이미 들고 있는 참조의 값도 되돌려주지 않는다.
            let previous = Snapshot(current)

            current.startHour = pattern.startTime.hour
            current.startMinute = pattern.startTime.minute
            current.endHour = pattern.endTime.hour
            current.endMinute = pattern.endTime.minute
            current.intervalMinutes = pattern.intervalMinutes
            current.isEnabled = isEnabled
            if let notificationGroupID {
                current.notificationGroupID = notificationGroupID
            }
            current.updatedAt = now

            do {
                try modelContext.save()
            } catch {
                previous.restore(to: current)
                throw error
            }
            return current
        }

        let schedule = SmileReminderSchedule(
            pattern: pattern,
            isEnabled: isEnabled,
            notificationGroupID: notificationGroupID ?? UUID().uuidString,
            updatedAt: now
        )
        modelContext.insert(schedule)
        do {
            try modelContext.save()
        } catch {
            // 완료 기록과 같은 이유로 국소 정리한다.
            modelContext.delete(schedule)
            throw error
        }
        return schedule
    }

    /// 저장 실패 시 되돌릴 기존 일정의 값.
    private struct Snapshot {
        let startHour: Int
        let startMinute: Int
        let endHour: Int
        let endMinute: Int
        let intervalMinutes: Int
        let isEnabled: Bool
        let notificationGroupID: String
        let updatedAt: Date

        init(_ schedule: SmileReminderSchedule) {
            startHour = schedule.startHour
            startMinute = schedule.startMinute
            endHour = schedule.endHour
            endMinute = schedule.endMinute
            intervalMinutes = schedule.intervalMinutes
            isEnabled = schedule.isEnabled
            notificationGroupID = schedule.notificationGroupID
            updatedAt = schedule.updatedAt
        }

        func restore(to schedule: SmileReminderSchedule) {
            schedule.startHour = startHour
            schedule.startMinute = startMinute
            schedule.endHour = endHour
            schedule.endMinute = endMinute
            schedule.intervalMinutes = intervalMinutes
            schedule.isEnabled = isEnabled
            schedule.notificationGroupID = notificationGroupID
            schedule.updatedAt = updatedAt
        }
    }
}
