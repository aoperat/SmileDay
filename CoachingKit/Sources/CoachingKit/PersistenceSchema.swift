import SwiftData

public enum PersistenceSchema {
    /// 기존 모델은 업데이트 호환을 위해 남겨둔다.
    /// 새 흐름은 `SmileReminderSchedule`과 `SmileMoment`만 새로 쓴다.
    /// 개별 알림과 상황 카드는 업데이트 호환을 위해 남긴다.
    public static let models: [any PersistentModel.Type] = [
        Baseline.self, CheckInSession.self, ReminderSetting.self, CareSession.self,
        SmileMoment.self, CustomSmileCard.self, SmileReminderSchedule.self,
    ]

    public static var schema: Schema {
        Schema(models)
    }
}
