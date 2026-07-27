import Foundation

public enum TimeBucket: String, CaseIterable, Equatable, Hashable, Sendable {
    case morning
    case afternoon
    case evening

    public init(hour: Int) {
        switch hour {
        case 5...10: self = .morning
        case 11...16: self = .afternoon
        default: self = .evening
        }
    }

    public var displayName: String {
        switch self {
        case .morning: "아침"
        case .afternoon: "낮"
        case .evening: "저녁"
        }
    }

    /// 빈 버킷을 원탭으로 채울 때 제시하는 기본 추천 시각(정시).
    public var suggestedHour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 13
        case .evening: 20
        }
    }
}

public struct ReminderPrompt: Equatable, Sendable {
    public let bucket: TimeBucket
    public let text: String

    public init(bucket: TimeBucket, text: String) {
        self.bucket = bucket
        self.text = text
    }
}

/// 미소 시간을 여는 짧은 질문 모음.
///
/// 질문은 표정을 평가하거나 좋은 기분을 요구하지 않는다. 타인의 시선을 상상하게 하는
/// 문구를 쓰지 않고, 떠오르는 것이 없어도 그대로 넘어갈 수 있는 초대형 문장으로 쓴다.
public enum ReminderPromptCatalog {
    public static let prompts: [ReminderPrompt] = [
        // 아침 (05–10시) — 기대, 나에게 건네는 여유, 가벼운 미소 초대
        ReminderPrompt(bucket: .morning, text: "오늘 기대되는 작은 일이 있나요? 떠오르지 않아도 괜찮아요."),
        ReminderPrompt(bucket: .morning, text: "잠시 어깨에 힘을 빼고 천천히 숨을 쉬어볼까요?"),
        ReminderPrompt(bucket: .morning, text: "하루를 여는 지금, 살짝 미소 지어볼까요?"),
        ReminderPrompt(bucket: .morning, text: "아침의 나에게 건네고 싶은 말이 있다면 무엇일까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 가고 싶은 곳이나 만나고 싶은 사람을 떠올려볼까요?"),
        ReminderPrompt(bucket: .morning, text: "지금 주변에서 마음에 드는 것 하나를 찾아볼까요?"),
        ReminderPrompt(bucket: .morning, text: "천천히 들이쉬고 내쉬면서, 잠깐 웃어볼까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘이 어떻게 흘러가도, 지금 이 순간은 나를 위한 시간이에요."),

        // 낮 (11–16시) — 숨 고르기, 최근 즐거운 순간, 잠깐의 휴식
        ReminderPrompt(bucket: .afternoon, text: "최근에 기분 좋았던 순간이 떠오르나요? 떠오르지 않아도 괜찮아요."),
        ReminderPrompt(bucket: .afternoon, text: "잠깐 하던 일을 멈추고 숨을 한 번 고를까요?"),
        ReminderPrompt(bucket: .afternoon, text: "어깨와 턱에 들어간 힘을 살짝 풀어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "오늘 먹은 것 중 맛있었던 한 입을 떠올려볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "창밖을 잠깐 바라보고, 다시 돌아와 미소 지어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "지금 마시고 싶은 것 하나를 떠올려볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "하루의 절반을 지나온 나에게 잠깐의 쉼을 줄까요?"),
        ReminderPrompt(bucket: .afternoon, text: "지금 이 30초는 편하게 웃어봐도 되는 시간이에요."),

        // 저녁 (17–04시) — 감사한 일, 웃게 한 순간, 부드러운 마무리
        ReminderPrompt(bucket: .evening, text: "오늘 나를 웃게 한 순간이 있었나요? 없어도 괜찮아요."),
        ReminderPrompt(bucket: .evening, text: "오늘 고마웠던 일 하나를 떠올려볼까요?"),
        ReminderPrompt(bucket: .evening, text: "하루를 마치며 어깨에 힘을 빼고 숨을 고를까요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 만난 사람 중 떠오르는 얼굴이 있나요?"),
        ReminderPrompt(bucket: .evening, text: "오늘도 여기까지 왔어요. 잠시 미소 지어볼까요?"),
        ReminderPrompt(bucket: .evening, text: "내일의 나에게 남기고 싶은 한마디가 있나요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 잘한 일 하나만 조용히 떠올려볼까요?"),
        ReminderPrompt(bucket: .evening, text: "잠들기 전, 몸에 힘을 빼고 편하게 웃어볼까요?"),
    ]

    public static func prompts(for bucket: TimeBucket) -> [ReminderPrompt] {
        prompts.filter { $0.bucket == bucket }
    }
}
