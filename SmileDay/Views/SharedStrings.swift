import Foundation

enum SharedStrings {
    static let saveFailed = "저장에 실패했습니다. 다시 시도해주세요."

    // MARK: - 미소 시간

    /// 아직 얼굴이 잡히지 않았을 때의 안내.
    static let alignFaceGuide = "얼굴을 가이드 안에 맞춰주세요"
    /// 얼굴이 잡힌 뒤의 초대 문구. 잘 웃으라고 요구하지 않는다.
    static let smileInvitation = "편하게 숨을 쉬고 살짝 미소 지어보세요"
    static let saveSmileAction = "오늘의 미소 남기기"

    // MARK: - 회고

    static let momentNoteQuestion = "오늘 나를 미소 짓게 한 순간이 있었나요?"
    static let momentNotePlaceholder = "떠오르는 순간을 짧게 남겨보세요"
    static let momentNoteOptionalHint = "비워두어도 괜찮아요"
    static let moodQuestion = "지금 기분은 어때요?"
    static let checkInCompleted = "오늘도 잠시 웃어봤어요"

    // MARK: - 탭

    static let smileTabTitle = "미소"
    static let restTabTitle = "쉬어가기"

    // MARK: - 알림 중심 미소 (MVP)

    static let smileNowAction = "지금 미소 짓기"
    static let guideStartAction = "시작"
    /// 타이머를 끝까지 본 뒤의 문구. 표정이 어땠는지는 말하지 않는다.
    static let guideCompleted = "오늘의 미소를 남겼어요"
    static let guideSaveFailed = "기록을 저장하지 못했어요. 다시 시도해주세요."
    static let todayCountTitle = "오늘 미소"
    static let weekActiveDaysTitle = "이번 주"
    static let recentSevenDaysTitle = "최근 7일"
    static let nextReminderTitle = "다음 알림"
    static let noReminderYet = "설정된 알림이 없어요"
    /// 쉬어간 날을 실패로 표현하지 않는다.
    static let noSmileYetToday = "아직 오늘의 미소가 없어요"
    static let notificationDeniedNotice = "알림이 꺼져 있어요. 설정 앱에서 켜면 정한 시간에 알려드릴게요."
    static let openSystemSettings = "설정 앱 열기"
}
