import Foundation

public struct ReminderPromptSelector {
    private let catalog: [ReminderPrompt]
    private let cursorStore: ReminderPromptCursorStoring

    public init(catalog: [ReminderPrompt] = ReminderPromptCatalog.prompts, cursorStore: ReminderPromptCursorStoring) {
        self.catalog = catalog
        self.cursorStore = cursorStore
    }

    public func nextPrompt(forHour hour: Int) -> ReminderPrompt {
        let bucket = TimeBucket(hour: hour)
        let pool = catalog.filter { $0.bucket == bucket }
        let index = cursorStore.nextIndex(for: bucket, poolCount: pool.count)
        return pool[index]
    }
}
