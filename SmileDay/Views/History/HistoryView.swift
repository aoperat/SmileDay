import SwiftUI
import SwiftData
import Charts
import CoachingKit

/// 기록 화면.
///
/// 얼굴 점수와 전날 대비 비교를 보여주지 않는다. 웃어본 날, 미소 시간 횟수,
/// 남긴 좋은 순간만 순서대로 보여준다.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?
    @State private var selectedDay: Int = Calendar.current.component(.day, from: .now)
    @State private var selectedBucketCounts: [TimeBucket: Int] = [:]

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
                        SummaryTile(value: "\(viewModel.monthCheckInDayCount)", unit: "일", label: "이번 달 웃어본 날")
                        SummaryTile(value: "\(viewModel.monthMomentNoteCount)", unit: "개", label: "남긴 좋은 순간")
                    }
                }

                weeklyActivityCard

                monthCalendarCard

                bucketDetailCard

                momentListCard
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(SDColor.cream)
        .onAppear {
            let vm = viewModel ?? HistoryViewModel(repository: SessionRepository(modelContext: modelContext))
            viewModel = vm
            try? vm.refresh()
            refreshBucketCounts()
        }
    }

    // MARK: - 1. 최근 7일 활동

    private var weeklyActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("최근 7일 미소 시간")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            if let viewModel, viewModel.recentActivity.contains(where: \.didCheckIn) {
                Chart(viewModel.recentActivity) { activity in
                    BarMark(
                        x: .value("날짜", activity.date, unit: .day),
                        y: .value("미소 시간", activity.checkInCount),
                        width: .fixed(12)
                    )
                    .foregroundStyle(
                        Calendar.current.isDateInToday(activity.date)
                            ? AnyShapeStyle(LinearGradient(colors: [SDColor.coralWarm, SDColor.coral],
                                                           startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color(hex: 0xFFC0AE))
                    )
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow).locale(SDFormat.koreanLocale), centered: true)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(SDColor.muted)
                    }
                }
                .chartYAxis {
                    // 횟수는 정수라 눈금도 정수로만 찍는다.
                    AxisMarks(values: .automatic(desiredCount: 3)) { value in
                        if let count = value.as(Int.self) {
                            AxisValueLabel {
                                Text("\(count)회")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(SDColor.muted)
                            }
                        }
                    }
                }
                .frame(height: 150)
                .accessibilityLabel(Text(weeklySummaryDescription(viewModel.recentActivity)))
            } else {
                EmptyStateView(
                    systemImage: "sun.max",
                    message: "아직 기록이 없어요. 오늘 잠시 웃어보는 것부터 시작해요"
                )
            }
        }
        .frame(maxWidth: .infinity)
        .sdCard()
    }

    private func weeklySummaryDescription(_ activity: [SmileDayActivity]) -> String {
        let days = activity.filter(\.didCheckIn).count
        let total = activity.reduce(0) { $0 + $1.checkInCount }
        return "최근 7일 중 \(days)일, 모두 \(total)번의 미소 시간"
    }

    // MARK: - 2. 월간 웃어본 날

    private var monthCalendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이번 달 웃어본 날 · \(Calendar.current.component(.month, from: .now))월")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            MonthHeatmapView(
                checkInDays: viewModel?.monthCheckInDays ?? [],
                selectedDay: selectedDay,
                onSelectDay: { day in
                    selectedDay = day
                    refreshBucketCounts()
                }
            )
        }
        .sdCard()
    }

    // MARK: - 3. 시간대별 미소 시간

    private var bucketDetailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("시간대별 미소 시간 · \(selectedDay)일")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            HStack(spacing: 8) {
                ForEach(TimeBucket.allCases, id: \.self) { bucket in
                    SummaryTile(
                        value: "\(selectedBucketCounts[bucket] ?? 0)",
                        unit: "회",
                        label: bucket.displayName
                    )
                }
            }
        }
        .sdCard()
    }

    // MARK: - 4. 좋은 순간 목록

    private var momentListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("남긴 좋은 순간")
                .font(.caption.bold())
                .foregroundStyle(SDColor.muted)

            if let moments = viewModel?.recentMoments, !moments.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                        if index > 0 {
                            Divider().overlay(SDColor.shell)
                        }
                        MomentRow(moment: moment)
                    }
                }
            } else {
                EmptyStateView(
                    systemImage: "text.quote",
                    message: "미소 시간을 마친 뒤 떠오르는 순간을 짧게 남겨보세요"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sdCard()
    }

    private func refreshBucketCounts() {
        guard let viewModel else { return }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: .now)
        components.day = selectedDay
        guard let date = calendar.date(from: components) else { return }
        selectedBucketCounts = (try? viewModel.bucketCounts(onDayOf: date)) ?? [:]
    }
}

/// 남긴 회고 한 줄. 기분만 남긴 항목도 그대로 보여준다.
private struct MomentRow: View {
    let moment: SmileMomentEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(moment.mood ?? "·")
                .font(.system(size: 20))
                .frame(width: 26)
                .accessibilityHidden(moment.mood == nil)

            VStack(alignment: .leading, spacing: 3) {
                Text(moment.date.formatted(.dateTime.month().day().hour().minute().locale(SDFormat.koreanLocale)))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SDColor.muted)

                if let note = moment.note {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(SDColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let prompt = moment.promptText {
                    Text(prompt)
                        .font(.caption2)
                        .foregroundStyle(SDColor.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// 기록이 없는 상태. 행동을 초대하되 빠진 것을 탓하지 않는다.
private struct EmptyStateView: View {
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(SDColor.shell)
            Text(message)
                .font(.caption)
                .foregroundStyle(SDColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
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
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .sdCard(padding: 0, cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(label) \(value)\(unit)"))
    }
}

/// 이번 달 "웃어본 날" 캘린더. 빠진 날은 회색으로만 표시하고 경고색이나 실패 아이콘을 쓰지 않는다.
struct MonthHeatmapView: View {
    let checkInDays: Set<Int>
    var selectedDay: Int? = nil
    var onSelectDay: ((Int) -> Void)? = nil
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
                    .overlay {
                        if day == selectedDay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(SDColor.coralDeep, lineWidth: 2)
                        }
                    }
                    .onTapGesture {
                        guard !isFuture else { return }
                        onSelectDay?(day)
                    }
                    .accessibilityLabel(Text("\(day)일"))
                    .accessibilityValue(Text(checkedIn ? "웃어본 날" : ""))
            }
        }
    }

    private func cellColor(isFuture: Bool) -> Color {
        isFuture ? .clear : Color(hex: 0xF6EADF)
    }
}
