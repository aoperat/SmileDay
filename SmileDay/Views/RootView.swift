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
                HomeView(baseline: baseline)
            } else if hasSeenIntro {
                BaselineCaptureView { savedBaseline in
                    baseline = savedBaseline
                }
            } else {
                OnboardingIntroView {
                    hasSeenIntro = true
                }
            }
        }
        .task {
            let repository = SessionRepository(modelContext: modelContext)
            baseline = try? repository.fetchLatestBaseline()
            isLoading = false
        }
    }
}
