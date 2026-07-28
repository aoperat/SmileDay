import Foundation

/// 알림과 화면에서 안내할 미소 한 가지. SwiftData가 아니라 앱에 고정된 값 타입이다.
///
/// 얼굴을 측정하지 않으므로 "얼마나 잘 웃었는지"는 어디에도 없다. 문구는 지금 할 수 있는
/// 행동만 짧게 안내하고, 표정으로 인상이나 기분이 나아진다고 약속하지 않는다.
public struct SmileGuide: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let instruction: String
    public let notificationText: String
    public let durationSeconds: Int

    public init(id: String, title: String, instruction: String, notificationText: String, durationSeconds: Int) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.notificationText = notificationText
        self.durationSeconds = durationSeconds
    }
}

/// MVP 가이드 3개. 사용자가 문구를 직접 만들지 않고 이 중에서만 고른다.
public enum SmileGuideCatalog {
    public static let all: [SmileGuide] = [
        SmileGuide(
            id: "soft-smile",
            title: "편안한 미소",
            instruction: "턱과 어깨 힘을 빼고 입꼬리를 살짝 올려보세요.",
            notificationText: "지금 5초만 입꼬리를 살짝 올려볼까요?",
            durationSeconds: 5
        ),
        SmileGuide(
            id: "greeting-smile",
            title: "인사 미소",
            instruction: "눈가에 힘을 빼고 반갑게 인사하는 표정을 지어보세요.",
            notificationText: "다음 사람을 만나기 전, 인사 미소를 준비해볼까요?",
            durationSeconds: 5
        ),
        SmileGuide(
            id: "bright-smile",
            title: "활짝 미소",
            instruction: "편한 만큼 밝게 웃어보세요.",
            notificationText: "잠시 멈춰 있다면 편한 만큼 밝게 웃어보세요.",
            durationSeconds: 5
        ),
    ]

    /// 저장된 ID가 사라지거나 깨져도 알림·화면이 멈추지 않도록 항상 이 가이드로 돌아온다.
    public static let `default`: SmileGuide = all[0]

    /// 알 수 없는 ID와 nil(가이드가 없던 시절의 리마인더)은 기본 가이드로 대체한다.
    public static func guide(id: String?) -> SmileGuide {
        guard let id, let match = all.first(where: { $0.id == id }) else { return `default` }
        return match
    }
}
