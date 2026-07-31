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
                // 앱 카피가 전부 한국어라 날짜·차트 축 표기도 한국어로 고정한다.
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .environment(appDelegate.router)
        }
    }
}
