import Foundation
import SwiftData

/// 사용자가 직접 만든 상황 카드. 새 흐름은 카드를 만들거나 읽지 않지만,
/// 기존 저장소를 열려면 스키마에 남아 있어야 한다.
///
/// `slotRawValue`는 사라진 `DaySlot`의 원문 문자열이다. 해석하지 않고 그대로 보관한다.
@Model
public final class CustomSmileCard {
    @Attribute(.unique) public var id: String
    public var title: String
    /// nil이면 기본 안내 문구를 쓰던 카드다.
    public var instructionText: String?
    public var slotRawValue: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        instructionText: String? = nil,
        slotRawValue: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.instructionText = instructionText
        self.slotRawValue = slotRawValue
        self.createdAt = createdAt
    }
}
