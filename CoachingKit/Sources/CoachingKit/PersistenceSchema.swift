import SwiftData

public enum PersistenceSchema {
    public static let models: [any PersistentModel.Type] = [Baseline.self, CheckInSession.self, ReminderSetting.self]

    public static var schema: Schema {
        Schema(models)
    }
}
