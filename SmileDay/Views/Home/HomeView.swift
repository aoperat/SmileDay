import SwiftUI
import SwiftData
import CoachingKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HomeViewModel?

    let baseline: Baseline
    let onStartCoaching: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "camera")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                if viewModel?.hasCheckedInToday == true {
                    Label("오늘 체크인을 완료했습니다", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("오늘의 표정 습관을 기록해보세요")
                        .font(.headline)
                    Button("오늘 시작하기") {
                        onStartCoaching()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))

            if let viewModel {
                StreakDotsView(days: viewModel.recentDays, streak: viewModel.streakDays)
            }
        }
        .padding()
        .onAppear {
            let vm = viewModel ?? HomeViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
        }
    }
}
