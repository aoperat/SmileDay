import Foundation

/// 카드가 어울리는 시간대. `anytime`은 시간과 무관한 카드다.
public enum DaySlot: String, CaseIterable, Equatable, Hashable, Sendable {
    case morning
    case afternoon
    case evening
    case anytime

    /// 시각으로부터 고른다. `anytime`은 돌려주지 않는다.
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
        case .anytime: "언제든"
        }
    }

    /// 목록에 보여주는 순서.
    public var sortIndex: Int {
        switch self {
        case .morning: 0
        case .afternoon: 1
        case .evening: 2
        case .anytime: 3
        }
    }

    public static var displayOrder: [DaySlot] {
        allCases.sorted { $0.sortIndex < $1.sortIndex }
    }
}

/// 알림과 화면에서 안내할 상황 카드 하나.
///
/// 표정의 종류가 아니라 "언제 무엇을 하는지"를 가리킨다. 사용자가 미소를 잊는 건
/// 표정을 몰라서가 아니라 순간을 놓쳐서다.
///
/// 얼굴을 측정하지 않으므로 "얼마나 잘 웃었는지"는 어디에도 없다. 문구는 지금 할 수 있는
/// 행동만 짧게 안내하고, 표정으로 인상이나 기분이 나아진다고 약속하지 않는다.
public struct SmileGuide: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let instruction: String
    public let slot: DaySlot
    public let durationSeconds: Int
    public let isBuiltIn: Bool

    public init(
        id: String,
        title: String,
        instruction: String,
        slot: DaySlot,
        durationSeconds: Int = SmileGuideCatalog.defaultDurationSeconds,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.slot = slot
        self.durationSeconds = durationSeconds
        self.isBuiltIn = isBuiltIn
    }
}

/// 앱에 내장된 상황 카드. 사용자가 만든 카드까지 합친 목록은 `SmileGuideLibrary`가 낸다.
///
/// SwiftData로 시딩하지 않고 코드 상수로 두는 이유: 다음 업데이트에서 문구를 고치면
/// 기존 사용자에게도 그대로 닿아야 하고, 첫 실행 시딩이라는 실패 지점을 만들지 않으려는 것이다.
public enum SmileGuideCatalog {
    public static let defaultDurationSeconds = 5
    /// 사용자가 안내 문구를 비웠을 때 쓰는 문장.
    public static let defaultInstruction = "턱과 어깨 힘을 빼고 입꼬리를 살짝 올려보세요."

    public static let builtIn: [SmileGuide] = [
        SmileGuide(id: "morning-greeting", title: "출근 후 웃으며 인사하기",
                   instruction: "어깨 힘을 빼고, 반갑게 인사하는 표정을 지어보세요.",
                   slot: .morning, isBuiltIn: true),
        SmileGuide(id: "morning-mirror", title: "거울 볼 때 한 번 웃기",
                   instruction: "거울 속 나를 보며 입꼬리를 살짝 올려보세요.",
                   slot: .morning, isBuiltIn: true),
        SmileGuide(id: "morning-leaving", title: "집을 나서기 전 한 번 웃기",
                   instruction: "문을 나서기 전, 턱 힘을 빼고 웃어보세요.",
                   slot: .morning, isBuiltIn: true),
        SmileGuide(id: "morning-coffee", title: "첫 커피 마시며 숨 고르기",
                   instruction: "한 모금 마시고 천천히 숨을 내쉬며 웃어보세요.",
                   slot: .morning, isBuiltIn: true),

        SmileGuide(id: "noon-before-meeting", title: "회의 시작 전 표정 풀기",
                   instruction: "이마와 미간의 힘을 빼고 입꼬리를 올려보세요.",
                   slot: .afternoon, isBuiltIn: true),
        SmileGuide(id: "noon-before-lunch", title: "점심 먹기 전 숨 고르고 웃기",
                   instruction: "수저를 들기 전 어깨를 내리고 웃어보세요.",
                   slot: .afternoon, isBuiltIn: true),
        SmileGuide(id: "noon-before-call", title: "전화 받기 전 입꼬리 올리기",
                   instruction: "목소리를 내기 전에 표정을 먼저 준비해보세요.",
                   slot: .afternoon, isBuiltIn: true),
        SmileGuide(id: "noon-stand-up", title: "자리에서 일어날 때 어깨 내리기",
                   instruction: "일어서면서 어깨를 내리고 한 번 웃어보세요.",
                   slot: .afternoon, isBuiltIn: true),

        SmileGuide(id: "evening-after-work", title: "퇴근 후 어깨 힘 빼고 웃기",
                   instruction: "하루를 내려놓듯 어깨를 낮추고 웃어보세요.",
                   slot: .evening, isBuiltIn: true),
        SmileGuide(id: "evening-coming-home", title: "집에 들어가며 인사하기",
                   instruction: "문을 열기 전, 반갑게 인사하는 표정을 지어보세요.",
                   slot: .evening, isBuiltIn: true),
        SmileGuide(id: "evening-before-dinner", title: "저녁 먹기 전 한 번 웃기",
                   instruction: "자리에 앉아 숨을 고르고 입꼬리를 올려보세요.",
                   slot: .evening, isBuiltIn: true),
        SmileGuide(id: "evening-before-sleep", title: "잠들기 전 얼굴 힘 빼기",
                   instruction: "이마, 눈가, 턱 순서로 힘을 빼보세요.",
                   slot: .evening, isBuiltIn: true),

        SmileGuide(id: "anytime-pause", title: "하던 일 멈추고 웃기",
                   instruction: "손을 멈추고 5초만 편하게 웃어보세요.",
                   slot: .anytime, isBuiltIn: true),
        SmileGuide(id: "anytime-soft", title: "편안한 미소 짓기",
                   instruction: defaultInstruction,
                   slot: .anytime, isBuiltIn: true),
    ]

    /// 상황에 매이지 않아 어떤 대체 상황에서도 말이 된다.
    public static let `default`: SmileGuide = builtIn.first { $0.id == "anytime-soft" }!

    /// 표정 종류를 쓰던 시절의 ID. 저장된 알림과 기록이 엉뚱한 카드로 바뀌지 않게 연결한다.
    static let legacyIDAliases: [String: String] = [
        "soft-smile": "anytime-soft",
        "greeting-smile": "morning-greeting",
        "bright-smile": "anytime-pause",
    ]

    public static func builtInGuide(id: String?) -> SmileGuide? {
        guard let id else { return nil }
        let resolved = legacyIDAliases[id] ?? id
        return builtIn.first { $0.id == resolved }
    }

    /// 기본 카드만 찾는다. 사용자 카드까지 포함한 조회는 `SmileGuideLibrary`를 쓴다.
    public static func guide(id: String?) -> SmileGuide {
        builtInGuide(id: id) ?? `default`
    }

    public static func builtIn(in slot: DaySlot) -> [SmileGuide] {
        builtIn.filter { $0.slot == slot }
    }
}
