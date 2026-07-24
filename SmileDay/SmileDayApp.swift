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

    var sharedModelContainer: ModelContainer = {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                // 앱 카피가 전부 한국어라 날짜·차트 축 표기도 한국어로 고정한다.
                .environment(\.locale, Locale(identifier: "ko_KR"))
                .environment(appDelegate.router)
        }
        .modelContainer(sharedModelContainer)
    }
}
