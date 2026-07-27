import Foundation

/// 미소 시간을 마친 뒤 사용자가 선택적으로 남기는 회고.
///
/// 기분과 한 줄 기록은 모두 선택 사항이다. 둘 다 비워도 미소 시간은 정상 완료되므로
/// 빈 입력을 오류로 다루지 않고 조용히 nil로 정규화한다.
public struct SmileReflection: Equatable, Sendable {
    /// 한 줄 기록의 최대 글자 수. UI 입력 제한과 저장소 절단이 같은 값을 공유한다.
    public static let momentNoteLimit = 200

    public let mood: String?
    public let momentNote: String?

    public init(mood: String? = nil, momentNote: String? = nil) {
        self.mood = Self.trimmedOrNil(mood)
        self.momentNote = Self.normalizedMomentNote(momentNote)
    }

    /// 저장할 내용이 하나도 없는 회고.
    public var isEmpty: Bool { mood == nil && momentNote == nil }

    /// 한 줄 기록 정규화: 앞뒤 공백·줄바꿈 제거 → 비어 있으면 nil → `momentNoteLimit`으로 절단.
    public static func normalizedMomentNote(_ text: String?) -> String? {
        guard let trimmed = trimmedOrNil(text) else { return nil }
        guard trimmed.count > momentNoteLimit else { return trimmed }
        return String(trimmed.prefix(momentNoteLimit))
    }

    private static func trimmedOrNil(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
