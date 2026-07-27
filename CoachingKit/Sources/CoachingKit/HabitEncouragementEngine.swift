import Foundation

/// 격려 문구를 만들 때 참고하는 행동 이력. 얼굴 측정값은 일부러 포함하지 않는다.
public struct HabitContext: Equatable, Sendable {
    /// 오늘 완료한 미소 시간 횟수(방금 완료한 것 포함).
    public let todayCheckInCount: Int
    /// 오늘까지 이어진 연속 일수.
    public let streakDays: Int
    /// 최근 7일 중 미소 시간을 가진 고유 일수.
    public let recentSevenDayCount: Int
    /// 직전 체크인과의 간격(일). 첫 기록이면 nil, 같은 날이면 0.
    public let daysSincePreviousCheckIn: Int?
    /// 이번 미소 시간에 한 줄 기록을 남겼는지.
    public let hasMomentNote: Bool

    public init(
        todayCheckInCount: Int,
        streakDays: Int,
        recentSevenDayCount: Int,
        daysSincePreviousCheckIn: Int?,
        hasMomentNote: Bool
    ) {
        self.todayCheckInCount = todayCheckInCount
        self.streakDays = streakDays
        self.recentSevenDayCount = recentSevenDayCount
        self.daysSincePreviousCheckIn = daysSincePreviousCheckIn
        self.hasMomentNote = hasMomentNote
    }

    /// 한 줄 기록 여부만 바꾼 사본.
    ///
    /// 완료 화면은 회고를 저장하기 전에 격려 문구를 보여주므로, 사용자가 메모를 쓰는 동안
    /// 저장소를 다시 읽지 않고 문구만 다시 계산할 때 쓴다.
    public func withMomentNote(_ hasMomentNote: Bool) -> HabitContext {
        HabitContext(
            todayCheckInCount: todayCheckInCount,
            streakDays: streakDays,
            recentSevenDayCount: recentSevenDayCount,
            daysSincePreviousCheckIn: daysSincePreviousCheckIn,
            hasMomentNote: hasMomentNote
        )
    }
}

/// 미소 시간을 마친 뒤 보여줄 한 줄 격려.
public struct HabitEncouragement: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// 공백 뒤 다시 돌아온 날.
        case returning
        /// 첫 미소 시간.
        case first
        /// 같은 날 두 번째 이상.
        case repeatedToday
        /// 연속 기록이 쌓이는 중.
        case streak
        /// 이번 미소 시간에 한 줄 기록을 남김.
        case momentNote
        /// 그 밖의 평상시.
        case steady
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}

/// 행동 이력만으로 격려 문구를 고르는 순수 로직.
///
/// 얼굴 지표를 보지 않으므로 잘 웃었는지 평가하지 않는다. 쉬어간 날을 실패로 부르지 않고,
/// 공백 일수 자체를 문구에 노출하지 않는다.
public enum HabitEncouragementEngine {
    /// 이 일수 이상 벌어졌다면 "다시 돌아온 날"로 본다. 1이면 어제 이어감이므로 제외한다.
    public static let returningGapDays = 2
    /// 연속 기록을 언급하기 시작하는 최소 일수.
    public static let streakThresholdDays = 3
    /// 이번 주가 쌓이고 있다고 말할 최소 일수.
    static let weekBuildingDayCount = 2

    /// 고정 우선순위: 공백 후 복귀 → 첫 기록 → 하루 반복 → 연속 기록 → 한 줄 기록 → 기본.
    public static func evaluate(_ context: HabitContext) -> HabitEncouragement {
        if let gap = context.daysSincePreviousCheckIn, gap >= returningGapDays {
            return HabitEncouragement(
                kind: .returning,
                message: "다시 돌아온 오늘이 새로운 시작이에요."
            )
        }

        if context.daysSincePreviousCheckIn == nil {
            return HabitEncouragement(
                kind: .first,
                message: "첫 미소 시간을 남겼어요. 내일도 부담 없이 들러보세요."
            )
        }

        if context.todayCheckInCount >= 2 {
            return HabitEncouragement(
                kind: .repeatedToday,
                message: "오늘 벌써 두 번째 미소예요. 잠깐의 여유가 하나 더 쌓였어요."
            )
        }

        if context.streakDays >= streakThresholdDays {
            return HabitEncouragement(
                kind: .streak,
                message: "연속 \(context.streakDays)일째 웃어보는 시간을 만들고 있어요."
            )
        }

        if context.hasMomentNote {
            return HabitEncouragement(
                kind: .momentNote,
                message: "오늘의 좋은 순간도 함께 남겼어요."
            )
        }

        if context.recentSevenDayCount >= weekBuildingDayCount {
            return HabitEncouragement(
                kind: .steady,
                message: "이번 주에 웃어본 날이 하나 더 쌓였어요."
            )
        }

        return HabitEncouragement(
            kind: .steady,
            message: "오늘의 미소 하나가 기록되었어요."
        )
    }
}
