import Foundation
import Observation

@Observable
public final class HomeViewModel {
    public private(set) var hasCheckedInToday: Bool = false

    private let repository: SessionRepository

    public init(repository: SessionRepository) {
        self.repository = repository
    }

    public func refresh() throws {
        hasCheckedInToday = try repository.hasCheckInToday()
    }
}
