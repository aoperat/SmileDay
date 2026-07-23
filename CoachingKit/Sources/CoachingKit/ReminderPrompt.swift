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
}

public struct ReminderPrompt: Equatable, Sendable {
    public let bucket: TimeBucket
    public let text: String

    public init(bucket: TimeBucket, text: String) {
        self.bucket = bucket
        self.text = text
    }
}

public enum ReminderPromptCatalog {
    public static let prompts: [ReminderPrompt] = [
        // 아침 (05–10시)
        ReminderPrompt(bucket: .morning, text: "오늘 하루, 당신의 표정이 어떤 모습이었으면 좋겠나요?"),
        ReminderPrompt(bucket: .morning, text: "지금 거울을 본다면, 어떤 표정을 보고 싶나요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 처음 마주치는 사람에게 어떤 표정을 보여주고 싶나요?"),
        ReminderPrompt(bucket: .morning, text: "지금 입꼬리를 살짝 올려볼까요? 아니면 오늘은 소리 내서 웃어볼까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 하루 중 가장 크게 웃고 싶은 순간은 언제일까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 가장 기대되는 일을 떠올려볼까요? 자연스럽게 표정이 풀릴 거예요."),
        ReminderPrompt(bucket: .morning, text: "지금 이 순간, 몸에 힘을 빼고 살짝 웃어볼까요?"),
        ReminderPrompt(bucket: .morning, text: "오늘 하루를 시작하며, 나에게 짓고 싶은 표정 하나를 골라볼까요?"),

        // 낮 (11–16시)
        ReminderPrompt(bucket: .afternoon, text: "지금 누군가 당신을 본다면, 어떤 표정을 보고 있을까요?"),
        ReminderPrompt(bucket: .afternoon, text: "내가 사랑하는 사람이 나를 어떤 표정으로 봐 줬으면 하나요?"),
        ReminderPrompt(bucket: .afternoon, text: "오늘 누군가에게 웃어 보인 적이 있나요? 지금 한 번 웃어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "지금 잠깐, 소리 내서 웃어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "옆에 있는 사람이 본다면 편안해 보일 표정을 짓고 있나요?"),
        ReminderPrompt(bucket: .afternoon, text: "최근에 있었던 재미있는 순간을 떠올리며 웃어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "오늘 나를 웃게 한 사람은 누구였나요? 그 표정을 다시 지어볼까요?"),
        ReminderPrompt(bucket: .afternoon, text: "지금 화면이 아니라, 진짜 당신의 표정은 어떤가요?"),

        // 저녁 (17–04시)
        ReminderPrompt(bucket: .evening, text: "오늘 하루, 가장 크게 웃었던 순간은 언제였나요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 나의 표정은 대체로 어땠나요?"),
        ReminderPrompt(bucket: .evening, text: "잠들기 전, 오늘 하루에 감사한 일을 떠올리며 웃어볼까요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 하루를 마치며, 지금 어떤 표정을 짓고 있나요?"),
        ReminderPrompt(bucket: .evening, text: "내일 아침, 어떤 표정으로 하루를 시작하고 싶나요?"),
        ReminderPrompt(bucket: .evening, text: "오늘 나를 웃게 한 순간을 하나만 떠올려볼까요?"),
        ReminderPrompt(bucket: .evening, text: "지금 큰 소리로 한 번 웃어볼까요? 하루의 긴장이 풀릴 거예요."),
        ReminderPrompt(bucket: .evening, text: "사랑하는 사람과 나눈 표정 중, 오늘 가장 따뜻했던 순간은 언제였나요?"),
    ]

    public static func prompts(for bucket: TimeBucket) -> [ReminderPrompt] {
        prompts.filter { $0.bucket == bucket }
    }
}
