import SwiftUI
import CoachingKit

enum AppTab: Hashable, CaseIterable {
    case home, coaching, care, history, settings

    var title: String {
        switch self {
        case .home: "홈"
        case .coaching: SharedStrings.smileTabTitle
        case .care: SharedStrings.restTabTitle
        case .history: "기록"
        case .settings: "설정"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .coaching: "face.smiling"
        // 평가나 미용이 아니라 잠깐의 쉼을 나타내는 심볼.
        case .care: "leaf"
        case .history: "chart.bar"
        case .settings: "gearshape"
        }
    }
}

/// 얼굴 측정 시절의 5탭 화면.
///
/// 알림 중심 MVP(`2026-07-28-notification-smile-mvp-design.md`)에서는 `RootView`와 알림이
/// 이 화면을 더 이상 열지 않는다. 저장 데이터 호환을 위해 파일만 남겨둔 상태이고,
/// 실제 삭제는 별도 정리 작업에서 한다.
struct MainTabView: View {
    let baseline: Baseline
    let onBaselineUpdated: (Baseline) -> Void
    @State private var selection: AppTab
    @State private var coachingPrompt: String? = nil

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
            HomeView(onStartCoaching: { selection = .coaching })
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.home)

            CoachingTabView(
                baseline: baseline,
                promptText: coachingPrompt,
                onFinished: {
                    coachingPrompt = nil
                    selection = .home
                },
                onExit: {
                    coachingPrompt = nil
                    selection = .home
                }
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
            // 미소 시간(촬영·완료) 중에는 탭바를 숨긴다 — 나가기는 좌상단 X 버튼.
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
