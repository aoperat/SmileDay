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

    /// 권한을 물었더니 거부당했다. 시스템 대화상자는 한 번뿐이라 여기서 짚지 않으면
    /// 사용자는 알림이 켜진 줄 알고 홈으로 나가고, 아무것도 오지 않는 채로 며칠이 지난다.
    public private(set) var wasPermissionDenied = false

    public func confirm() async {
        guard await schedule.save(requestAuthorization: true) else { return }

        if schedule.authorizationStatus == .denied {
            wasPermissionDenied = true
            return
        }

        finish()
    }

    /// 권한 거부를 확인하고도 그대로 시작한다. 막지는 않는다 — 알림 없이도 홈에서
    /// 직접 시작할 수 있고, 강요는 이 앱이 하는 방식이 아니다.
    public func continueWithoutPermission() {
        finish()
    }

    /// 알림 없이 시작한다. 화면이 한 번 더 확인한 뒤에 부른다.
    public func skipReminders() async {
        schedule.updateEnabled(false)
        guard await schedule.save() else { return }
        finish()
    }

    private func finish() {
        store.hasCompletedOnboarding = true
        didComplete = true
    }
}
