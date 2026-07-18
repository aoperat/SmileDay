import SwiftUI
import CoachingKit

enum AppTab: Hashable {
    case home, coaching, history, settings
}

struct MainTabView: View {
    let baseline: Baseline
    let onBaselineUpdated: (Baseline) -> Void
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(baseline: baseline, onStartCoaching: { selection = .coaching })
                .tabItem { Label("홈", systemImage: "house") }
                .tag(AppTab.home)

            CoachingTabView(baseline: baseline, onFinished: { selection = .home })
                .tabItem { Label("코칭", systemImage: "video") }
                .tag(AppTab.coaching)

            HistoryView()
                .tabItem { Label("기록", systemImage: "chart.bar") }
                .tag(AppTab.history)

            SettingsView(onBaselineUpdated: onBaselineUpdated)
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
    }
}
