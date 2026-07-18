import SwiftUI
import SwiftData
import Charts
import CoachingKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("주간 추이")
                    .font(.headline)

                if let viewModel, !viewModel.weeklyScores.isEmpty {
                    Chart(viewModel.weeklyScores) { score in
                        BarMark(
                            x: .value("날짜", score.date, unit: .day),
                            y: .value("점수", score.displayScore)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 180)
                } else {
                    Text("아직 기록이 없습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }

                Text("이번 달 체크인")
                    .font(.headline)

                MonthHeatmapView(checkInDays: viewModel?.monthCheckInDays ?? [])
            }
            .padding()
        }
        .onAppear {
            let vm = viewModel ?? HistoryViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
        }
    }
}

struct MonthHeatmapView: View {
    let checkInDays: Set<Int>
    private let calendar = Calendar.current

    var body: some View {
        let dayCount = calendar.range(of: .day, in: .month, for: Date())?.count ?? 30
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(1...dayCount, id: \.self) { day in
                RoundedRectangle(cornerRadius: 4)
                    .fill(checkInDays.contains(day) ? Color.accentColor : Color.secondary.opacity(0.15))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Text("\(day)")
                            .font(.system(size: 9))
                            .foregroundStyle(checkInDays.contains(day) ? .white : .secondary)
                    }
            }
        }
    }
}
