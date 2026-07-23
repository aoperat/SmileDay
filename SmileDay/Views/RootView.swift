import SwiftUI
import SwiftData
import CoachingKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var baseline: Baseline?
    @State private var isLoading = true
    @State private var hasSeenIntro = false

    var body: some View {
        Group {
            if isLoading {
                SplashView()
                    .transition(.opacity)
            } else if let baseline {
                MainTabView(baseline: baseline, onBaselineUpdated: { self.baseline = $0 })
            } else if hasSeenIntro {
                BaselineCaptureView(
                    onBaselineSaved: { savedBaseline in
                        baseline = savedBaseline
                    },
                    onCancel: { hasSeenIntro = false }
                )
            } else {
                OnboardingIntroView {
                    hasSeenIntro = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        .task {
            async let minimumSplashDuration: Void? = try? Task.sleep(for: .seconds(1.3))

            let repository = SessionRepository(modelContext: modelContext)
            #if DEBUG
            if CommandLine.arguments.contains("-seedDemoData") {
                try? DemoSeeder.seedIfNeeded(repository: repository)
            }
            #endif
            let fetchedBaseline = try? repository.fetchLatestBaseline()

            _ = await minimumSplashDuration
            baseline = fetchedBaseline
            isLoading = false
        }
    }
}
