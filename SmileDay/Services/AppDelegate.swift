import SwiftData
import UIKit
import UserNotifications
import CoachingKit

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = NotificationRouter()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        // 버튼은 알림이 아니라 카테고리에 붙는다. 앱이 백그라운드로 깨어난 실행에서도
        // 여기까지는 돈다 — 등록을 미루면 사용자가 누른 버튼을 해석할 수 없다.
        center.setNotificationCategories([Self.reminderCategory])
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case ReminderNotificationAction.recordSmile.rawValue:
            recordSmileWithoutOpeningTheApp(userInfo: userInfo)

        case ReminderNotificationAction.openGuide.rawValue, UNNotificationDefaultActionIdentifier:
            router.handleNotificationTap(userInfo: userInfo)

        default:
            // 알림을 지운 것(`UNNotificationDismissActionIdentifier`)이나 모르는 식별자.
            // 무시하지 않고 가이드를 열면 지운 사람 앞에 화면이 뜬다.
            break
        }
    }

    // 앱 사용 중 도착한 알림도 배너로 보여준다 (기본값은 무표시).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - 알림 액션

    /// 잠금화면 버튼으로 들어온 기록. 화면을 열지 않고 저장만 한다.
    ///
    /// 여기서는 사용자에게 알릴 방법이 없다. 진동도 못 쓴다 — iOS는 앱이 foreground active가
    /// 아니면 `UIFeedbackGenerator`를 무시한다(Apple 프레임워크 팀 확인). 그래서 저장이
    /// 실패해도 조용히 끝난다. 알림이 사라지는 것 자체가 iOS가 주는 유일한 피드백이고,
    /// 이는 미리 알림 앱의 "완료로 표시"와 같은 동작이다.
    private func recordSmileWithoutOpeningTheApp(userInfo: [AnyHashable: Any]) {
        guard case .success(let container) = PersistenceController.shared else { return }

        // 예약 당시의 가이드 ID를 그대로 남긴다. 파싱이 안 되는 옛 알림이면 기본 가이드로 적는다.
        let guideID = ReminderNotificationPayload(userInfo: userInfo)?.guideID
            ?? SmileGuideCatalog.default.id

        let repository = SmileMomentRepository(modelContext: ModelContext(container))
        guard (try? repository.save(guideID: guideID, source: .notificationAction)) != nil else { return }

        // 앱이 이미 떠 있는 채로 배너에서 눌렀다면 scenePhase가 바뀌지 않아 홈이 다시 읽지 않는다.
        router.noteRecordedWithoutGuide()
    }

    /// "웃었어요"는 앱을 열지 않고, "가이드 열기"는 앞으로 가져온다.
    private static var reminderCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: ReminderNotificationCategory.identifier,
            actions: ReminderNotificationAction.allCases.map { action in
                UNNotificationAction(
                    identifier: action.rawValue,
                    title: action.title,
                    options: action.opensApp ? [.foreground] : []
                )
            },
            intentIdentifiers: [],
            options: []
        )
    }
}
