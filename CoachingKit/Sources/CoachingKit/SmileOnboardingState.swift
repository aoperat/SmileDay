import Foundation
import Observation

/// 온보딩을 끝냈는지만 저장한다. 알림 권한 상태는 여기 두지 않는다 —
/// 사용자가 설정 앱에서 언제든 바꾸므로 저장된 값은 곧 거짓말이 된다.
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

/// 온보딩에서 사용자가 확정하기 전의 알림 한 줄.
public struct ReminderDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var hour: Int
    public var minute: Int
    public var guideID: String

    public init(id: UUID = UUID(), hour: Int, minute: Int, guideID: String) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.guideID = guideID
    }

}

/// 첫 실행 설정 상태.
///
/// 기준선 촬영과 카메라 권한이 없다. 사용자가 시간을 확정한 다음에야 알림 권한을 묻고,
/// 거부해도 앱에는 들어갈 수 있다.
@MainActor
@Observable
public final class SmileOnboardingViewModel {
    /// 권장 기본값. 사용자가 화면에서 지우거나 바꿀 수 있다.
    public static var recommendedDrafts: [ReminderDraft] {
        [
            ReminderDraft(hour: 9, minute: 0, guideID: "morning-greeting"),
            ReminderDraft(hour: 13, minute: 0, guideID: "noon-before-lunch"),
            ReminderDraft(hour: 18, minute: 0, guideID: "evening-after-work"),
        ]
    }

    public private(set) var drafts: [ReminderDraft]
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?
    /// 저장과 예약이 모두 끝났을 때만 true가 된다.
    public private(set) var didComplete = false
    /// 확정 후의 권한 상태. 거부여도 앱 진입은 막지 않는다.
    public private(set) var authorizationStatus: ReminderAuthorizationStatus?

    /// 고를 수 있는 상황 카드. 사용자가 첫 실행에 만든 카드도 반영된다.
    public private(set) var guides: [SmileGuide]

    private let reminderRepository: ReminderRepository
    private let library: SmileGuideLibrary
    private let scheduler: ReminderScheduling
    private let store: SmileOnboardingStoring

    public init(
        reminderRepository: ReminderRepository,
        library: SmileGuideLibrary,
        scheduler: ReminderScheduling,
        store: SmileOnboardingStoring,
        drafts: [ReminderDraft]? = nil
    ) {
        self.reminderRepository = reminderRepository
        self.library = library
        self.scheduler = scheduler
        self.store = store
        self.drafts = drafts ?? Self.recommendedDrafts
        self.guides = (try? library.visibleGuides()) ?? SmileGuideCatalog.builtIn
    }

    public func refreshGuides() {
        guides = (try? library.visibleGuides()) ?? SmileGuideCatalog.builtIn
    }

    public func guide(for draft: ReminderDraft) -> SmileGuide {
        library.guide(id: draft.guideID)
    }

    public func updateTime(draftID: UUID, hour: Int, minute: Int) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].hour = hour
        drafts[index].minute = minute
    }

    public func updateGuide(draftID: UUID, guideID: String) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].guideID = guideID
    }

    public func addDraft(hour: Int = 15, minute: Int = 0, guideID: String = SmileGuideCatalog.default.id) {
        drafts.append(ReminderDraft(hour: hour, minute: minute, guideID: guideID))
    }

    public func removeDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
    }

    /// 사용자가 시간을 확정한 뒤 호출한다. 권한 요청 → 저장 → 예약이 모두 끝나야 완료로 기록한다.
    public func confirm() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        _ = await scheduler.requestAuthorization()
        authorizationStatus = await scheduler.currentAuthorizationStatus()

        var savedReminders: [ReminderSetting] = []
        do {
            for draft in drafts {
                savedReminders.append(
                    try reminderRepository.add(hour: draft.hour, minute: draft.minute, guideID: guide(for: draft).id)
                )
            }
        } catch {
            // 절반만 저장된 상태로 두지 않는다.
            try? savedReminders.forEach { try reminderRepository.delete($0) }
            errorMessage = "알림을 저장하지 못했어요. 다시 시도해주세요."
            return
        }

        for reminder in savedReminders {
            await scheduler.scheduleRollingWindow(
                id: reminder.notificationID,
                hour: reminder.hour,
                minute: reminder.minute,
                guide: library.guide(id: reminder.guideID),
                days: reminderRollingWindowDays
            )
        }

        store.hasCompletedOnboarding = true
        didComplete = true
    }

    /// 알림 없이 시작하기. 저장할 것이 없으므로 완료만 기록한다.
    public func skipReminders() {
        store.hasCompletedOnboarding = true
        didComplete = true
    }
}
