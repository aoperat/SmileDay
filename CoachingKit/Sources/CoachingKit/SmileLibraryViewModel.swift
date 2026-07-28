import Foundation
import Observation

/// 카드를 지우기 전에 보여줄 영향 범위.
public struct GuideRemovalImpact: Equatable, Sendable {
    public let guide: SmileGuide
    /// 이 카드를 쓰는 알림의 시각. "09:00" 형식.
    public let affectedReminderTimes: [String]
    public let replacement: SmileGuide

    public var isInUse: Bool { !affectedReminderTimes.isEmpty }

    public init(guide: SmileGuide, affectedReminderTimes: [String], replacement: SmileGuide) {
        self.guide = guide
        self.affectedReminderTimes = affectedReminderTimes
        self.replacement = replacement
    }
}

/// 미소 카드 목록 관리 화면 상태.
@MainActor
@Observable
public final class SmileLibraryViewModel {
    public private(set) var guides: [SmileGuide] = []
    public private(set) var hiddenGuides: [SmileGuide] = []
    public private(set) var errorMessage: String?

    private let library: SmileGuideLibrary
    private let reminderRepository: ReminderRepository
    private let scheduler: ReminderScheduling

    public init(
        library: SmileGuideLibrary,
        reminderRepository: ReminderRepository,
        scheduler: ReminderScheduling
    ) {
        self.library = library
        self.reminderRepository = reminderRepository
        self.scheduler = scheduler
    }

    public func refresh() throws {
        guides = try library.visibleGuides()
        hiddenGuides = library.hiddenBuiltInGuides()
    }

    /// 만든 카드를 돌려준다. 목록은 시간대순이라 "마지막 항목"이 방금 만든 카드가 아니다.
    @discardableResult
    public func addCard(title: String, instruction: String?, slot: DaySlot) throws -> SmileGuide {
        let added: SmileGuide
        do {
            added = try library.addCustom(title: title, instruction: instruction, slot: slot)
            errorMessage = nil
        } catch SmileGuideLibraryError.blankTitle {
            errorMessage = "상황 이름을 적어주세요."
            throw SmileGuideLibraryError.blankTitle
        }
        try refresh()
        return added
    }

    /// 지우기 전에 보여줄 내용. 화면이 이걸로 확인 문구를 만든다.
    public func removalImpact(for guide: SmileGuide) throws -> GuideRemovalImpact {
        let affected = try reminderRepository.reminders(usingGuideID: guide.id)
        return GuideRemovalImpact(
            guide: guide,
            affectedReminderTimes: affected.map { String(format: "%02d:%02d", $0.hour, $0.minute) },
            replacement: replacement(for: guide)
        )
    }

    /// 기본 카드는 숨기고 내 카드는 지운다. 그 카드를 쓰던 알림은 대체 카드로 바꿔 다시 예약한다.
    public func remove(_ guide: SmileGuide) async throws {
        let affected = try reminderRepository.reminders(usingGuideID: guide.id)
        let replacement = replacement(for: guide)

        for reminder in affected {
            try reminderRepository.updateGuide(reminder, guideID: replacement.id)
        }

        if guide.isBuiltIn {
            library.hideBuiltIn(id: guide.id)
        } else {
            try library.removeCustom(id: guide.id)
        }

        // 이미 예약된 14일치가 사라진 카드의 문구를 그대로 들고 나가지 않도록 다시 채운다.
        for reminder in affected where reminder.isEnabled {
            await scheduler.scheduleRollingWindow(
                id: reminder.notificationID,
                hour: reminder.hour,
                minute: reminder.minute,
                guide: replacement,
                days: reminderRollingWindowDays
            )
        }

        try refresh()
    }

    public func restore(_ guide: SmileGuide) throws {
        library.restoreBuiltIn(id: guide.id)
        try refresh()
    }

    /// 같은 시간대의 다른 카드로 넘기고, 없으면 아무 카드로, 그것도 없으면 기본 카드로.
    private func replacement(for guide: SmileGuide) -> SmileGuide {
        let candidates = (try? library.visibleGuides()) ?? []
        if let sameSlot = candidates.first(where: { $0.slot == guide.slot && $0.id != guide.id }) {
            return sameSlot
        }
        if let any = candidates.first(where: { $0.id != guide.id }) {
            return any
        }
        return SmileGuideCatalog.default
    }
}
