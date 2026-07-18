import SwiftUI
import SwiftData
import CoachingKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var baseline: Baseline?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let baseline {
                HomeView(baseline: baseline)
            } else {
                BaselineCaptureView { savedBaseline in
                    baseline = savedBaseline
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
