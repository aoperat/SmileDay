//
//  SmileDayApp.swift
//  SmileDay
//
//  Created by 이종환 on 7/18/26.
//

import SwiftUI
import SwiftData
import CoachingKit

@main
struct SmileDayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            Group {
                // 알림 액션도 같은 컨테이너에 써야 해서 뷰 밖(`PersistenceController`)에 있다.
                switch PersistenceController.shared {
                case .success(let modelContainer):
                    RootView()
                        .modelContainer(modelContainer)
                case .failure:
                    AppStartupFailureView()
                }
            }
                .environment(\.calendar, Self.displayCalendar)
                .environment(appDelegate.router)
        }
    }

    /// 화면이 날짜를 계산하고 그릴 때 함께 쓰는 캘린더.
    ///
    /// 체계는 그레고리력으로 고정한다 — 기록은 그레고리력 날짜이고, `.current`를 그대로 쓰면
    /// 불기·연호 기기에서 격자와 헤더가 다른 달을 가리킨다. 요일 시작과 이름은 로케일에서
    /// 온다(locale을 대입하면 firstWeekday도 따라온다 — 실측). 언어는 iOS가 기기 설정으로
    /// 고르므로 여기서 로케일을 고정하지 않는다.
    private static var displayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        return calendar
    }
}
