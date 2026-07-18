import SwiftUI
import SwiftData
import CoachingKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?
    @State private var isShowingCoaching = false

    let baseline: Baseline

    var body: some View {
        VStack(spacing: 24) {
            if viewModel?.hasCheckedInToday == true {
                Label("오늘 체크인을 완료했습니다", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("오늘의 표정 습관을 기록해보세요")
                    .font(.headline)
                Button("코칭 시작") {
                    isShowingCoaching = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            let vm = HomeViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
        }
        .fullScreenCover(isPresented: $isShowingCoaching, onDismiss: {
            try? viewModel?.refresh()
        }) {
            CoachingSessionView(baseline: baseline)
        }
    }
}
