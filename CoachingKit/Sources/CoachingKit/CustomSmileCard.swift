import Foundation
import SwiftData

/// 사용자가 직접 만든 상황 카드. 기본 카드는 코드 상수라 여기 들어오지 않는다.
@Model
public final class CustomSmileCard {
    @Attribute(.unique) public var id: String
    public var title: String
    /// nil이면 기본 안내 문구를 쓴다.
    public var instructionText: String?
    public var slotRawValue: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        instructionText: String? = nil,
        slot: DaySlot,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.instructionText = instructionText
        self.slotRawValue = slot.rawValue
        self.createdAt = createdAt
    }

    /// 알 수 없는 값은 `.anytime`으로 읽는다.
    public var slot: DaySlot {
        get { DaySlot(rawValue: slotRawValue) ?? .anytime }
        set { slotRawValue = newValue.rawValue }
    }

    public var guide: SmileGuide {
        SmileGuide(
            id: id,
            title: title,
            instruction: instructionText ?? SmileGuideCatalog.defaultInstruction,
            slot: slot,
            isBuiltIn: false
        )
    }
}
