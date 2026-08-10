import Foundation

enum SharedStrings {
    // MARK: - 알림 중심 미소 (MVP)

    static let smileNowAction = "지금 한 번 웃기"
    static let guideStartAction = "시작"
    /// 타이머를 끝까지 본 뒤의 문구. 표정이 어땠는지는 말하지 않는다.
    static let guideCompleted = "오늘 한 번 더 웃어봤어요"
    static let guideSaveFailed = "기록을 저장하지 못했어요. 다시 시도해주세요."
    /// 위 문구가 안내하는 행동. 5초를 다시 세지 않고 같은 완료를 그대로 재저장한다.
    static let guideRetrySaveAction = "다시 시도"
    static let todayCountTitle = "오늘 미소"
    static let recentSevenDaysTitle = "최근 7일"
    static let nextReminderTitle = "다음 알림"
    static let noReminderYet = "설정된 알림이 없어요"
    /// 쉬어간 날을 실패로 표현하지 않는다.
    static let noSmileYetToday = "아직 오늘의 미소가 없어요"
    static let notificationDeniedNotice = "알림이 꺼져 있어요. 설정 앱에서 켜면 정한 시간에 알려드릴게요."
    static let openSystemSettings = "설정 앱 열기"

    // MARK: - 알림이 도착하지 못할 때

    /// 이 앱은 알림 → 5초 → 기록이 전부다. 알림이 끊기면 남는 흐름이 없어 홈에서 짚어준다.
    /// 다만 문구는 재촉이 아니라 사실과 고치는 방법만 말한다.
    static let reminderBlockedTitle = "알림이 오지 않아요"
    static let reminderBlockedDetail = "iOS 설정에서 알림이 꺼져 있어요. 켜야 정한 시간에 알려드릴 수 있어요."
    static let reminderNotRequestedTitle = "알림을 켜면 잊지 않아요"
    static let reminderNotRequestedDetail = "정한 시간에 짧게 알려드릴게요. 지금 켤 수 있어요."
    static let reminderOffTitle = "알림이 꺼져 있어요"
    static let reminderOffDetail = "이 앱은 알림으로 미소를 떠올리게 해요. 설정에서 언제든 켤 수 있어요."
    static let reminderTurnOnAction = "알림 켜기"
    /// 종료가 시작보다 이른 시각일 때. 잘못 고른 것이 아니라 밤을 넘기는 창으로 읽었다고 말한다.
    static let reminderWindowCrossesMidnight = "자정을 넘는 시간창이에요. 종료 시간은 다음 날로 봐요."

    // MARK: - 온보딩에서 알림을 건너뛸 때

    static let skipRemindersConfirmTitle = "알림 없이 시작할까요?"
    /// 겁주지 않되, 무엇이 없어지는지는 분명히 말한다.
    static let skipRemindersConfirmMessage = "스마일데이는 정한 시간에 알림으로 미소를 떠올리게 해요. 알림이 없으면 앱을 직접 열어야 기억할 수 있어요. 나중에 설정에서 켤 수 있어요."
    static let skipRemindersConfirmAction = "알림 없이 시작"
    static let skipRemindersCancelAction = "알림 받을래요"

    static let onboardingPermissionDeniedTitle = "알림이 꺼진 채로 시작해요"
    static let onboardingPermissionDeniedMessage = "알림 권한이 거부돼서 정한 시간에 알려드릴 수 없어요. iOS는 이 요청을 한 번만 물어보기 때문에, 켜려면 설정 앱에서 바꿔야 해요."
    static let onboardingContinueAnyway = "이대로 시작하기"

    // MARK: - 설정에서 알림을 끌 때

    static let disableRemindersConfirmTitle = "정말 알림을 끌까요?"
    static let disableRemindersConfirmMessage = "예약된 알림이 모두 취소돼요. 앱을 직접 열어야 미소 시간을 시작할 수 있어요. 언제든 다시 켤 수 있어요."
    static let disableRemindersConfirmAction = "알림 끄기"
    static let disableRemindersCancelAction = "그대로 둘래요"

    // MARK: - 실시간 미소 확인 (선택형)

    /// 카메라 허용 없이는 이 기능 자체가 성립하지 않는다. 측정 화면에 들여보내고 실패를
    /// 보여주는 대신, 들어가기 전에 무엇이 필요한지와 어디서 켜는지를 말한다.
    static let liveMonitorCameraRequiredTitle = "카메라 허용이 있어야 쓸 수 있어요"
    static let liveMonitorCameraRequiredDetail = "실시간 미소 확인은 전면 카메라로 입꼬리 움직임만 읽어요. 사진과 영상은 저장하지도 전송하지도 않아요."
    static let liveMonitorOpenCameraSettings = "카메라 허용 설정하기"

    static let liveMonitorTitle = "실시간 미소 확인"
    static let liveMonitorEntrySummary = "카메라 화면 없이 미소 신호만 보여드려요. 원하면 화면을 켤 수도 있어요."
    /// 측정 중 항상 보이는 프라이버시 고지. 화면 표시 여부와 무관하게 저장하지 않는다는 약속이다.
    static let liveMonitorPrivacyBadge = "카메라 사용 중 · 영상과 측정값은 저장하지 않아요"
    static let liveMonitorLevelLabel = "지금 미소 신호"
    static let liveMonitorStartAction = "시작하기"
    static let liveMonitorRecalibrateAction = "다시 보정"
    static let liveMonitorCloseAction = "종료"
    static let liveMonitorShowPreview = "카메라 화면 보기"
    static let liveMonitorHidePreview = "카메라 화면 숨기기"

    /// 시작 전 안내. 무엇이 켜지고 무엇이 남지 않는지 먼저 말한다.
    static let liveMonitorIntroPoints = [
        "전면 카메라가 켜지고, iOS 초록색 표시가 나타나요.",
        "카메라 화면은 기본으로 꺼져 있고, 버튼으로 켜고 끌 수 있어요.",
        "끝나면 그동안의 그래프를 보여드려요. 얼굴 사진은 남기지 않아요.",
        "그래프는 화면을 닫으면 사라져요. 저장하거나 전송하지 않아요.",
        "화면을 켜두는 동안 배터리가 평소보다 빨리 줄어요.",
    ]

    static let liveMonitorCalibrating = "편한 표정으로 잠시 바라봐주세요."
    static let liveMonitorFaceNotFound = "얼굴이 카메라에 들어오도록 기기를 조정해주세요."
    /// 화면 중앙에 있을 필요는 없다. 카메라 쪽을 보고 있기만 하면 된다.
    static let liveMonitorNotFacingCamera = "카메라 쪽을 편하게 바라봐주세요."
    static let liveMonitorTooDark = "조금 더 밝은 곳에서 사용해주세요."
    static let liveMonitorUnsupported = "이 기기에서는 실시간 미소 확인을 사용할 수 없어요."
    static let liveMonitorPermissionDenied = "카메라 권한이 필요해요. 설정에서 허용해주세요."
    static let liveMonitorSessionFailed = "카메라를 시작하지 못했어요. 잠시 후 다시 시도해주세요."
    static let liveMonitorInterrupted = "측정을 멈췄어요. 다시 시작할 수 있어요."

    /// 단계별 문구. 잘함·못함이 아니라 지금 신호가 어디쯤인지만 말한다.
    static let liveMonitorLevelResting = "편하게 있다가 천천히 미소 지어보세요."
    static let liveMonitorLevelStarting = "미소 신호가 올라오고 있어요."
    static let liveMonitorLevelHolding = "미소가 이어지고 있어요."
    static let liveMonitorLevelClear = "미소 신호가 또렷하게 잡혀요."

    /// 단계를 값 판단으로 읽지 않도록 화면에 함께 둔다.
    static let liveMonitorLevelMeaning = "이 표시는 웃음의 좋고 나쁨이 아니라, 지금 카메라가 감지한 입꼬리 움직임을 보여줘요."

    // MARK: - 웃지 않을 때 알리기

    static let liveMonitorNudgeTitle = "Smile!"
    static let liveMonitorNudgeBody = "잠깐 입꼬리를 올려볼까요?"
    static let liveMonitorNudgeSectionTitle = "실시간 확인 알림"
    static let liveMonitorNudgeToggle = "웃지 않으면 알리기"
    static let liveMonitorNudgeIntervalLabel = "알림 간격"
    static let liveMonitorNudgeHapticToggle = "진동"
    static let liveMonitorNudgeFooter = "실시간 미소 확인 중, 이 시간만큼 편안한 표정이 이어지면 알려드려요. 얼굴이 보이지 않는 동안은 시간을 세지 않아요."

    // MARK: - 실시간 확인 세션 요약

    static let liveSummaryTitle = "이번 실시간 확인"
    /// 분모가 "카메라를 켠 시간"이 아니라 "얼굴을 판정할 수 있던 시간"이라 이렇게 쓴다.
    static let liveSummaryRatioLabel = "얼굴이 보인 동안 미소"
    static let liveSummaryLegendSmiling = "미소"
    static let liveSummaryLegendNotSmiling = "안 웃음"
    static let liveSummaryLegendUnknown = "알 수 없음"
    static let liveSummaryCloseAction = "닫기"
    /// 분모에서 알 수 없음을 뺐으므로 그 비율을 항상 함께 보여준다.
    static let liveSummaryLowConfidence = "인식된 시간이 짧아 이 숫자는 참고만 해주세요."
    static let liveSummaryNoMeasurement = "측정된 시간이 없어요."
    /// 사용자가 종료를 누르지 않았는데 요약이 떴을 때, 왜 끝났는지 먼저 말한다.
    /// 이유 없이 요약이 나타나면 자기가 뭘 잘못 눌렀다고 생각한다.
    static let liveSummaryEndedByLeavingApp = "화면을 벗어나서 카메라를 껐어요. 그때까지 측정한 내용이에요."
    static let liveSummaryEndedByInterruption = "카메라가 멈춰서 측정을 마쳤어요. 그때까지 측정한 내용이에요."
    /// 숫자를 값 판단으로 읽지 않도록 함께 둔다.
    static let liveSummaryMeaning = "이 비율은 웃음의 좋고 나쁨이 아니라, 카메라가 입꼬리 움직임을 감지한 시간의 비율이에요."
}
