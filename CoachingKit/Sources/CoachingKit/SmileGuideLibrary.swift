import Foundation
import SwiftData

public enum SmileGuideLibraryError: Error, Equatable {
    case blankTitle
}

/// 기본 카드와 사용자 카드를 합쳐 내놓는 단 한 곳.
///
/// 알림 예약과 화면 표시는 모두 여기를 거친다. `SmileGuideCatalog`를 직접 부르면
/// 사용자가 만든 카드가 보이지 않는다.
public final class SmileGuideLibrary {
    private let modelContext: ModelContext
    private let hiddenStore: HiddenSmileGuideStoring

    public init(modelContext: ModelContext, hiddenStore: HiddenSmileGuideStoring) {
        self.modelContext = modelContext
        self.hiddenStore = hiddenStore
    }

    /// 목록에 보이는 카드. 시간대순, 같은 시간대에서는 기본 카드가 먼저, 내 카드는 만든 순.
    public func visibleGuides() throws -> [SmileGuide] {
        let hidden = hiddenStore.hiddenGuideIDs
        let builtIn = SmileGuideCatalog.builtIn.filter { !hidden.contains($0.id) }
        let custom = try customCards().map(\.guide)

        return DaySlot.displayOrder.flatMap { slot in
            builtIn.filter { $0.slot == slot } + custom.filter { $0.slot == slot }
        }
    }

    /// 숨기거나 지운 카드도 찾아준다 — 지난 기록과 예약된 알림이 이름을 잃지 않도록.
    /// 어디에도 없는 ID만 기본 카드로 떨어진다.
    public func guide(id: String?) -> SmileGuide {
        guard let id else { return SmileGuideCatalog.default }
        if let builtIn = SmileGuideCatalog.builtInGuide(id: id) { return builtIn }
        if let custom = try? customCard(id: id) { return custom.guide }
        return SmileGuideCatalog.default
    }

    public func hiddenBuiltInGuides() -> [SmileGuide] {
        let hidden = hiddenStore.hiddenGuideIDs
        return SmileGuideCatalog.builtIn.filter { hidden.contains($0.id) }
    }

    @discardableResult
    public func addCustom(title: String, instruction: String?, slot: DaySlot) throws -> SmileGuide {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw SmileGuideLibraryError.blankTitle }

        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let card = CustomSmileCard(
            title: trimmedTitle,
            instructionText: (trimmedInstruction?.isEmpty ?? true) ? nil : trimmedInstruction,
            slot: slot
        )
        modelContext.insert(card)
        try modelContext.save()
        return card.guide
    }

    public func removeCustom(id: String) throws {
        guard let card = try customCard(id: id) else { return }
        modelContext.delete(card)
        try modelContext.save()
    }

    public func hideBuiltIn(id: String) {
        guard SmileGuideCatalog.builtInGuide(id: id) != nil else { return }
        hiddenStore.hiddenGuideIDs.insert(id)
    }

    public func restoreBuiltIn(id: String) {
        hiddenStore.hiddenGuideIDs.remove(id)
    }

    private func customCards() throws -> [CustomSmileCard] {
        try modelContext.fetch(FetchDescriptor<CustomSmileCard>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func customCard(id: String) throws -> CustomSmileCard? {
        try modelContext.fetch(FetchDescriptor<CustomSmileCard>(predicate: #Predicate { $0.id == id })).first
    }
}
