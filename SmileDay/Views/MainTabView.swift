import SwiftUI
import CoachingKit

enum AppTab: Hashable, CaseIterable {
    case home, coaching, care, history, settings

    var title: String {
        switch self {
        case .home: "홈"
        case .coaching: "코칭"
        case .care: "케어"
        case .history: "기록"
        case .settings: "설정"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .coaching: "video"
        case .care: "heart"
        case .history: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

struct MainTabView: View {
    let baseline: Baseline
    let onBaselineUpdated: (Baseline) -> Void
    @State private var selection: AppTab

    init(baseline: Baseline, onBaselineUpdated: @escaping (Baseline) -> Void) {
        self.baseline = baseline
        self.onBaselineUpdated = onBaselineUpdated

        var initialTab: AppTab = .home
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "initialTab") {
        case "coaching": initialTab = .coaching
        case "care": initialTab = .care
        case "history": initialTab = .history
        case "settings": initialTab = .settings
        default: break
        }
        #endif
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        // 탭별 상태(내비게이션 스택, 필터, 스크롤 위치)를 보존하기 위해 네이티브 TabView를 쓰고,
        // 기본 탭바만 숨긴 채 커스텀 필 탭바를 올린다.
        TabView(selection: $selection) {
            HomeView(baseline: baseline, onStartCoaching: { selection = .coaching })
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.home)

            CoachingTabView(
                baseline: baseline,
                onFinished: { selection = .home },
                onExit: { selection = .home }
            )
            .toolbar(.hidden, for: .tabBar)
            .tag(AppTab.coaching)

            CareView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.care)

            HistoryView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.history)

            SettingsView(onBaselineUpdated: onBaselineUpdated)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.settings)
        }
        .safeAreaInset(edge: .bottom) {
            // 코칭(측정·저장 완료) 중에는 탭바를 숨긴다 — 나가기는 좌상단 X 버튼.
            if selection != .coaching {
                SDTabBar(selection: $selection)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .tint(SDColor.coral)
    }
}

/// 플로팅 필 탭바.
struct SDTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: isSelected ? tab.icon + ".fill" : tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(isSelected ? .white : SDColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(SDColor.primaryGradient)
                                .shadow(color: SDColor.coral.opacity(0.5), radius: 7, y: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.white, in: Capsule())
        .shadow(color: SDColor.ink.opacity(0.16), radius: 14, y: 6)
    }
}
