import Foundation
import SwiftData

@Model
public final class SmileReminderSchedule {
    // 아래 기본값들은 **저장소 마이그레이션 계약**이다. 이 컬럼이 없던 시절의 레코드를 열 때
    // SwiftData가 채워 넣는 값이라, 제품이 권하는 시간창(`SmileReminderPattern.recommended`)과
    // 숫자가 같더라도 그쪽에서 파생시키지 않는다 — 추천값을 바꾸는 순간 옛 레코드가 읽히는
    // 방식까지 따라 바뀌면 안 된다. 리터럴로 고정해 둔다.
    public var startHour: Int = 9
    public var startMinute: Int = 0
    public var endHour: Int = 21
    public var endMinute: Int = 0
    public var intervalMinutes: Int = 180
    public var isEnabled: Bool = true
    public var notificationGroupID: String = UUID().uuidString
    public var updatedAt: Date = Date()

    public init(
        pattern: SmileReminderPattern,
        isEnabled: Bool = true,
        notificationGroupID: String = UUID().uuidString,
        updatedAt: Date = Date()
    ) {
        startHour = pattern.startTime.hour
        startMinute = pattern.startTime.minute
        endHour = pattern.endTime.hour
        endMinute = pattern.endTime.minute
        intervalMinutes = pattern.intervalMinutes
        self.isEnabled = isEnabled
        self.notificationGroupID = notificationGroupID
        self.updatedAt = updatedAt
    }

    public var pattern: SmileReminderPattern? {
        SmileReminderPattern(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            intervalMinutes: intervalMinutes
        )
    }
}
