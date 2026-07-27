import Foundation

/// 쉬어가기 콘텐츠의 의도. 얼굴 부위가 아니라 그 시간에 무엇을 하고 싶은지로 나눈다.
public enum SmilePracticeCategory: String, CaseIterable, Sendable {
    /// 잠깐 멈춤.
    case pause
    /// 좋은 순간 떠올리기.
    case recall
    /// 숨 고르기.
    case breathe
    /// 따뜻한 연결.
    case connect

    public var displayName: String {
        switch self {
        case .pause: "잠깐 멈춤"
        case .recall: "좋은 순간"
        case .breathe: "숨 고르기"
        case .connect: "따뜻한 연결"
        }
    }
}

/// 한 단계. 몇 초 동안 무엇을 해보자는 안내다.
public struct SmilePracticeStep: Equatable, Sendable {
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

/// 하루 중 잠깐 쉬어가는 짧은 콘텐츠.
///
/// 근육·붓기·좌우 균형처럼 외모 변화를 약속하는 콘텐츠는 두지 않는다.
/// 각 practice는 그 시간에 실제로 하는 일만 설명한다.
public struct SmilePractice: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: SmilePracticeCategory
    public let steps: [SmilePracticeStep]
    /// 이 시간이 어떤 시간인지에 대한 담백한 설명. 효과를 약속하지 않는다.
    public let purpose: String
    /// 번들 내 영상 파일 이름(확장자 제외). 파일이 없으면 플레이어가 아이콘 히어로를 보여준다.
    public let videoFileName: String

    public init(
        id: String,
        title: String,
        category: SmilePracticeCategory,
        steps: [SmilePracticeStep],
        purpose: String,
        videoFileName: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.steps = steps
        self.purpose = purpose
        self.videoFileName = videoFileName
    }

    public var totalSeconds: Int {
        steps.reduce(0) { $0 + $1.seconds * $1.reps }
    }

    public var durationText: String {
        totalSeconds < 60 ? "\(totalSeconds)초" : "\(Int((Double(totalSeconds) / 60).rounded(.up)))분"
    }
}

public extension SmilePractice {
    /// 번들 기본 카탈로그.
    ///
    /// ID는 `smile-` 접두사를 쓴다. 과거 케어 루틴 ID(`lift-…`, `relax-…` 등)와 겹치지 않아야
    /// 기존 `CareSession` 기록이 새 콘텐츠 기록과 섞이지 않는다.
    static let catalog: [SmilePractice] = [
        SmilePractice(
            id: "smile-breath",
            title: "30초 숨 고르고 미소 짓기",
            category: .breathe,
            steps: [
                SmilePracticeStep(title: "어깨에 힘을 빼고 앉기", seconds: 10, systemImage: "figure.seated.side"),
                SmilePracticeStep(title: "천천히 들이쉬고 내쉬기", seconds: 10, reps: 2, systemImage: "lungs.fill"),
                SmilePracticeStep(title: "그대로 살짝 미소 짓기", seconds: 10, systemImage: "face.smiling"),
            ],
            purpose: "하던 일을 잠깐 멈추고 숨을 고르는 30초예요.",
            videoFileName: "smile_breath"
        ),
        SmilePractice(
            id: "smile-recall",
            title: "오늘의 좋은 순간 떠올리기",
            category: .recall,
            steps: [
                SmilePracticeStep(title: "눈을 감고 오늘을 되짚기", seconds: 20, systemImage: "moon.stars.fill"),
                SmilePracticeStep(title: "떠오른 장면 하나에 머무르기", seconds: 30, systemImage: "sparkles"),
                SmilePracticeStep(title: "떠오르지 않으면 그대로 쉬기", seconds: 20, systemImage: "cloud.fill"),
            ],
            purpose: "오늘 하루에서 마음에 남은 장면 하나를 찾아보는 시간이에요. 떠오르지 않아도 괜찮아요.",
            videoFileName: "smile_recall"
        ),
        SmilePractice(
            id: "smile-gratitude",
            title: "고마운 사람 한 명 떠올리기",
            category: .connect,
            steps: [
                SmilePracticeStep(title: "떠오르는 얼굴 하나 고르기", seconds: 20, systemImage: "person.fill"),
                SmilePracticeStep(title: "고마웠던 순간 하나 떠올리기", seconds: 30, systemImage: "heart.fill"),
                SmilePracticeStep(title: "그 마음 그대로 미소 짓기", seconds: 20, systemImage: "face.smiling"),
            ],
            purpose: "고마운 사람을 떠올리며 잠시 머무는 시간이에요.",
            videoFileName: "smile_gratitude"
        ),
        SmilePractice(
            id: "smile-unwind",
            title: "어깨 힘 빼고 편안하게 웃기",
            category: .pause,
            steps: [
                SmilePracticeStep(title: "어깨를 올렸다 툭 떨어뜨리기", seconds: 15, reps: 2, systemImage: "arrow.down.circle.fill"),
                SmilePracticeStep(title: "턱에 들어간 힘 풀기", seconds: 20, systemImage: "wind"),
                SmilePracticeStep(title: "편안한 표정으로 잠깐 있기", seconds: 20, systemImage: "face.smiling"),
            ],
            purpose: "몸에 들어간 힘을 빼고 편안한 상태로 돌아오는 시간이에요.",
            videoFileName: "smile_unwind"
        ),
        SmilePractice(
            id: "smile-morning-start",
            title: "하루를 여는 1분",
            category: .pause,
            steps: [
                SmilePracticeStep(title: "창밖이나 방 안 둘러보기", seconds: 20, systemImage: "sun.max.fill"),
                SmilePracticeStep(title: "오늘 기대되는 것 하나 떠올리기", seconds: 20, systemImage: "sparkles"),
                SmilePracticeStep(title: "가볍게 미소 지어보기", seconds: 20, systemImage: "face.smiling"),
            ],
            purpose: "하루를 시작하며 잠시 자기 페이스를 찾는 1분이에요.",
            videoFileName: "smile_morning_start"
        ),
        SmilePractice(
            id: "smile-warm-look",
            title: "따뜻한 표정 건네보기",
            category: .connect,
            steps: [
                SmilePracticeStep(title: "오늘 만날 사람 떠올리기", seconds: 20, systemImage: "person.2.fill"),
                SmilePracticeStep(title: "건네고 싶은 표정 지어보기", seconds: 30, systemImage: "face.smiling"),
            ],
            purpose: "누군가에게 건네고 싶은 표정을 한 번 지어보는 시간이에요.",
            videoFileName: "smile_warm_look"
        ),
    ]
}
