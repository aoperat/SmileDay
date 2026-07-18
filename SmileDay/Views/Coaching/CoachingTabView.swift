import SwiftUI
import CoachingKit

struct CoachingTabView: View {
    let baseline: Baseline
    let onFinished: () -> Void
    @State private var result: SessionResult?

    struct SessionResult {
        let todayScore: Int
        let yesterdayScore: Int?
    }

    var body: some View {
        if let result {
            SaveConfirmView(todayScore: result.todayScore, yesterdayScore: result.yesterdayScore) {
                self.result = nil
                onFinished()
            }
        } else {
            CoachingSessionView(baseline: baseline) { today, yesterday in
                result = SessionResult(todayScore: today, yesterdayScore: yesterday)
            }
        }
    }
}
