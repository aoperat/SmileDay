import Foundation

public enum CareCategory: String, CaseIterable, Sendable {
    case lift
    case relax
    case depuff
    case morning

    public var displayName: String {
        switch self {
        case .lift: "입꼬리"
        case .relax: "릴랙스"
        case .depuff: "붓기"
        case .morning: "아침 1분"
        }
    }
}

public enum CareDifficulty: String, Sendable {
    case beginner
    case intermediate

    public var displayName: String {
        switch self {
        case .beginner: "초급"
        case .intermediate: "중급"
        }
    }
}

public struct CareStep: Equatable, Sendable {
    public let title: String
    public let seconds: Int
    public let reps: Int
    /// 히어로 영역에 표시할 SF Symbol 이름.
    public let systemImage: String

    public init(title: String, seconds: Int, reps: Int = 1, systemImage: String) {
        self.title = title
        self.seconds = seconds
        self.reps = reps
        self.systemImage = systemImage
    }
}

public struct CareRoutine: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: CareCategory
    public let difficulty: CareDifficulty
    public let steps: [CareStep]
    /// 이 루틴이 실제로 무엇을 하는지에 대한 담백한 설명. 효과를 약속하지 않는다.
    public let purpose: String
    /// 번들 내 영상 파일 이름(확장자 제외). 파일이 없으면 플레이어가 아이콘 히어로를 보여준다.
    public let videoFileName: String

    public init(
        id: String,
        title: String,
        category: CareCategory,
        difficulty: CareDifficulty,
        steps: [CareStep],
        purpose: String,
        videoFileName: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.difficulty = difficulty
        self.steps = steps
        self.purpose = purpose
        self.videoFileName = videoFileName
    }

    public var totalSeconds: Int {
        steps.reduce(0) { $0 + $1.seconds * $1.reps }
    }

    public var durationText: String {
        let minutes = Int((Double(totalSeconds) / 60).rounded(.up))
        return "\(minutes)분"
    }
}

public extension CareRoutine {
    /// 번들 기본 루틴 카탈로그.
    static let catalog: [CareRoutine] = [
        CareRoutine(
            id: "lift-smile",
            title: "입꼬리 리프팅 루틴",
            category: .lift,
            difficulty: .beginner,
            steps: [
                CareStep(title: "손바닥 비벼 데우기", seconds: 30, systemImage: "hands.and.sparkles.fill"),
                CareStep(title: "입꼬리 올려 10초 유지", seconds: 10, reps: 3, systemImage: "mouth.fill"),
                CareStep(title: "광대 쓸어올리기", seconds: 30, systemImage: "hand.draw.fill"),
                CareStep(title: "입꼬리 옆 지그시 원 그리기", seconds: 60, systemImage: "arrow.triangle.2.circlepath"),
            ],
            purpose: "입꼬리 주변 근육을 움직이고 마사지하는 스트레칭이에요.",
            videoFileName: "care_lift_smile"
        ),
        CareRoutine(
            id: "lift-cheek",
            title: "광대 리프팅 마사지",
            category: .lift,
            difficulty: .beginner,
            steps: [
                CareStep(title: "손바닥 비벼 데우기", seconds: 30, systemImage: "hands.and.sparkles.fill"),
                CareStep(title: "광대뼈 아래 눌러 풀기", seconds: 60, systemImage: "hand.point.down.fill"),
                CareStep(title: "광대 바깥으로 쓸어올리기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "관자놀이 지그시 누르기", seconds: 30, reps: 2, systemImage: "hand.point.down.fill"),
            ],
            purpose: "광대 주변을 눌러 풀고 쓸어 올리는 마사지예요.",
            videoFileName: "care_lift_cheek"
        ),
        CareRoutine(
            id: "relax-brow",
            title: "미간 긴장 풀기",
            category: .relax,
            difficulty: .beginner,
            steps: [
                CareStep(title: "눈썹 위 지그시 누르기", seconds: 30, systemImage: "hand.point.down.fill"),
                CareStep(title: "미간 바깥으로 쓸어내기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "눈 감고 깊게 호흡", seconds: 30, systemImage: "lungs.fill"),
            ],
            purpose: "미간과 눈가 주변 근육의 긴장을 풀어주는 간단한 스트레칭이에요.",
            videoFileName: "care_relax_brow"
        ),
        CareRoutine(
            id: "depuff-morning",
            title: "아침 붓기 케어",
            category: .depuff,
            difficulty: .intermediate,
            steps: [
                CareStep(title: "목 옆 림프 쓸어내리기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "턱선 따라 쓸어올리기", seconds: 60, systemImage: "hand.draw.fill"),
                CareStep(title: "눈 밑 가볍게 두드리기", seconds: 60, systemImage: "hand.tap.fill"),
                CareStep(title: "얼굴 전체 바깥으로 쓸기", seconds: 60, reps: 2, systemImage: "hand.draw.fill"),
            ],
            purpose: "목과 얼굴의 림프 흐름을 도와주는 마사지예요.",
            videoFileName: "care_depuff_morning"
        ),
        CareRoutine(
            id: "morning-1min",
            title: "아침 1분 스마일 스트레칭",
            category: .morning,
            difficulty: .beginner,
            steps: [
                CareStep(title: "입 크게 벌려 아·에·이·오·우", seconds: 30, systemImage: "mouth.fill"),
                CareStep(title: "입꼬리 올려 10초 유지", seconds: 10, reps: 3, systemImage: "mouth.fill"),
            ],
            purpose: "아침에 표정 근육을 가볍게 깨우는 1분 스트레칭이에요.",
            videoFileName: "care_morning_1min"
        ),
    ]
}
