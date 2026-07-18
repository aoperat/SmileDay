import Foundation
import Observation

@Observable
public final class HomeViewModel {
    public private(set) var hasCheckedInToday: Bool = false
    public private(set) var streakDays: Int = 0
    public private(set) var recentDays: [Bool] = []

    private let repository: SessionRepository

    public init(repository: SessionRepository) {
        self.repository = repository
    }

    public func refresh() throws {
        hasCheckedInToday = try repository.hasCheckInToday()
        streakDays = try repository.checkInStreak()
        recentDays = try repository.recentCheckInDays(count: 5)
    }
}
