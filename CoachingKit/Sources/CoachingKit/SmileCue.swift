import Foundation

public struct SmileCue: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public enum SmileCueCatalog {
    public static let all: [SmileCue] = [
        SmileCue(
            id: "cared-for",
            text: "나를 아끼는 사람에게 어떤 표정을 보여주고 싶나요?"
        ),
        SmileCue(
            id: "welcome",
            text: "반가운 사람을 만났을 때의 표정을 떠올려보세요."
        ),
        SmileCue(
            id: "self-kindness",
            text: "오늘의 나에게 따뜻한 표정을 보내볼까요?"
        ),
        SmileCue(
            id: "gratitude",
            text: "고마운 사람을 떠올리며 가볍게 미소 지어보세요."
        ),
        SmileCue(
            id: "greeting",
            text: "기분 좋은 인사를 건네듯 표정을 지어보세요."
        ),
        SmileCue(
            id: "enough",
            text: "크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요."
        ),
        SmileCue(
            id: "nothing-needed",
            text: "떠오르는 장면이 없어도 괜찮아요. 잠깐 얼굴의 힘만 빼보세요."
        ),
        SmileCue(
            id: "gentle-invitation",
            text: "지금 괜찮다면 입꼬리를 살짝 올려볼까요?"
        ),
    ]
}
