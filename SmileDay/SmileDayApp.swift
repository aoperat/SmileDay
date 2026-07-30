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

    private let modelContainerResult: Result<ModelContainer, Error> = Result {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch modelContainerResult {
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
