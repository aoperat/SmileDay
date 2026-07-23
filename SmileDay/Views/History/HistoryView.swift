import SwiftUI
import SwiftData
import Charts
import CoachingKit

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("나의 미소 기록")
                    .font(.title3.bold())
                    .foregroundStyle(SDColor.ink)
                    .padding(.top, 6)

                if let viewModel {
                    HStack(spacing: 8) {
                        SummaryTile(value: "\(viewModel.streakDays)", unit: "일", label: "연속 기록")
                        SummaryTile(value: "\(viewModel.monthCheckInCount)", unit: "회", label: "이번 달")
                        SummaryTile(
                            value: viewModel.weeklyAverageScore.map { SDFormat.signedNumber($0) } ?? "—",
                            unit: viewModel.weeklyAverageScore == nil ? "" : "°",
                            label: "7일 평균"
                        )
                    }
                }

                weeklyChartCard

                monthHeatmapCard
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(SDColor.cream)
        .onAppear {
            let vm = viewModel ?? HistoryViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("주간 추이")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            if let viewModel, !viewModel.weeklyScores.isEmpty {
                Chart(viewModel.weeklyScores) { score in
                    BarMark(
                        x: .value("날짜", score.date, unit: .day),
                        y: .value("미소 크기", score.displayScore),
                        width: .fixed(12)
                    )
                    .foregroundStyle(
                        Calendar.current.isDateInToday(score.date)
                            ? AnyShapeStyle(LinearGradient(colors: [SDColor.coralWarm, SDColor.coral],
                                                           startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color(hex: 0xFFC0AE))
                    )
                    .cornerRadius(6)
                    .annotation(position: .top, spacing: 3) {
                        if Calendar.current.isDateInToday(score.date) {
                            Text(SDFormat.signedDegrees(score.displayScore, fractionDigits: 1))
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(SDColor.coralDeep)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow).locale(SDFormat.koreanLocale), centered: true)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(SDColor.muted)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 150)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar")
                        .font(.title3)
                        .foregroundStyle(SDColor.shell)
                    Text("아직 기록이 없어요. 첫 미소를 기록해보세요")
                        .font(.caption)
                        .foregroundStyle(SDColor.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 110)
            }
        }
        .frame(maxWidth: .infinity)
        .sdCard()
    }

    private var monthHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이번 달 체크인 · \(Calendar.current.component(.month, from: .now))월")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            MonthHeatmapView(checkInDays: viewModel?.monthCheckInDays ?? [])
        }
        .sdCard()
    }
}

struct SummaryTile: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            (Text(value).foregroundStyle(SDColor.ink)
                + Text(unit).font(.caption.bold()).foregroundStyle(SDColor.apricot))
                .font(.system(.body, design: .rounded, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SDColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .sdCard(padding: 0, cornerRadius: 16)
    }
}

struct MonthHeatmapView: View {
    let checkInDays: Set<Int>
    private let calendar = Calendar.current

    var body: some View {
        let today = calendar.component(.day, from: .now)
        let dayCount = calendar.range(of: .day, in: .month, for: .now)?.count ?? 30

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
            ForEach(1...dayCount, id: \.self) { day in
                let checkedIn = checkInDays.contains(day)
                let isFuture = day > today

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(checkedIn ? AnyShapeStyle(SDColor.primaryGradient) : AnyShapeStyle(cellColor(isFuture: isFuture)))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if isFuture {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(SDColor.shell, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                    .overlay {
                        Text("\(day)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(checkedIn ? .white : SDColor.muted.opacity(isFuture ? 0.5 : 1))
                    }
            }
        }
    }

    private func cellColor(isFuture: Bool) -> Color {
        isFuture ? .clear : Color(hex: 0xF6EADF)
    }
}
