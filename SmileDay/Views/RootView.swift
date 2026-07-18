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
                ProgressView()
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
        .task {
            let repository = SessionRepository(modelContext: modelContext)
            #if DEBUG
            if CommandLine.arguments.contains("-seedDemoData") {
                try? DemoSeeder.seedIfNeeded(repository: repository)
            }
            #endif
            baseline = try? repository.fetchLatestBaseline()
            isLoading = false
        }
    }
}
