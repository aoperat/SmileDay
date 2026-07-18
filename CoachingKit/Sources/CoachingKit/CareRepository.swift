import Foundation
import SwiftData

public final class CareRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func saveCompletion(routineID: String, date: Date) throws {
        modelContext.insert(CareSession(date: date, routineID: routineID))
        try modelContext.save()
    }

    public func fetchCompletions(from start: Date, to end: Date) throws -> [CareSession] {
        let descriptor = FetchDescriptor<CareSession>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor)
    }

    public func hasCompletion(onDayOf date: Date, calendar: Calendar = .current) throws -> Bool {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        return try !fetchCompletions(from: start, to: end).isEmpty
    }
}
