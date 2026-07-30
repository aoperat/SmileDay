import Foundation
import Observation

public protocol SmileOnboardingStoring: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
}

public final class UserDefaultsSmileOnboardingStore: SmileOnboardingStoring {
    private static let key = "hasCompletedSmileOnboarding"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

public final class InMemorySmileOnboardingStore: SmileOnboardingStoring {
    public var hasCompletedOnboarding: Bool

    public init(hasCompletedOnboarding: Bool = false) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

@MainActor
@Observable
public final class SmileOnboardingViewModel {
    public private(set) var schedule: SmileReminderScheduleViewModel
    public private(set) var didComplete = false

    private let store: SmileOnboardingStoring

    public init(
        schedule: SmileReminderScheduleViewModel,
        store: SmileOnboardingStoring
    ) {
        self.schedule = schedule
        self.store = store
    }

    public var errorMessage: String? {
        schedule.errorMessage
    }

    public var isSaving: Bool {
        schedule.isSaving
    }

    public func confirm() async {
        guard await schedule.save(requestAuthorization: true) else { return }
        store.hasCompletedOnboarding = true
        didComplete = true
    }

    public func skipReminders() async {
        schedule.updateEnabled(false)
        guard await schedule.save() else { return }
        store.hasCompletedOnboarding = true
        didComplete = true
    }
}
