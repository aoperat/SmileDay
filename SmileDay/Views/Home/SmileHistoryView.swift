import SwiftUI
import SwiftData
import CoachingKit

struct SmileHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: SmileHistoryViewModel?
    @State private var loadFailed = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = SDFormat.koreanLocale
        value.timeZone = .current
        value.firstWeekday = 1
        return value
    }

    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            if loadFailed {
                AppDataLoadFailureView(onRetry: refresh)
            } else if let viewModel {
                ScrollView {
                    VStack(spacing: 16) {
                        monthNavigation(viewModel)
                        monthSummary(viewModel)
                        monthCalendar(viewModel)

                        if let selectedDate = viewModel.selectedDate,
                           let selectedDayCount = viewModel.selectedDayCount {
                            selectedDayCard(date: selectedDate, count: selectedDayCount)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = SmileHistoryViewModel(
                    momentRepository: SmileMomentRepository(modelContext: modelContext),
                    calendar: calendar
                )
            }
            refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refresh()
        }
    }

    private func monthNavigation(_ viewModel: SmileHistoryViewModel) -> some View {
        HStack {
            Button {
                changeMonth { try viewModel.showPreviousMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("이전 달")

            Spacer()

            Text(viewModel.displayedMonth.formatted(.dateTime.locale(SDFormat.koreanLocale).year().month()))
                .font(.title3.bold())
                .foregroundStyle(SDColor.ink)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button {
                changeMonth { try viewModel.showNextMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canShowNextMonth)
            .opacity(viewModel.canShowNextMonth ? 1 : 0.3)
            .accessibilityLabel("다음 달")
        }
        .foregroundStyle(SDColor.sunDeep)
    }

    private func monthSummary(_ viewModel: SmileHistoryViewModel) -> some View {
        HStack(spacing: 12) {
            HistoryStat(title: "이번 달 미소", value: "\(viewModel.monthTotal)번")
            Divider()
            HistoryStat(title: "웃어본 날", value: "\(viewModel.activeDayCount)일")
        }
        .frame(maxWidth: .infinity)
        .sdCard()
        .accessibilityElement(children: .combine)
    }

    private func monthCalendar(_ viewModel: SmileHistoryViewModel) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(["일", "월", "화", "수", "목", "금", "토"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SDColor.muted)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlankCount(for: viewModel.days), id: \.self) { _ in
                    Color.clear.frame(height: 54)
                }

                ForEach(viewModel.days) { day in
                    HistoryDayCell(
                        day: day,
                        isSelected: viewModel.selectedDate.map {
                            calendar.isDate($0, inSameDayAs: day.date)
                        } ?? false,
                        isSelectable: viewModel.isSelectable(day.date),
                        onSelect: { viewModel.select(day.date) }
                    )
                }
            }
        }
        .sdCard()
    }

    private func selectedDayCard(date: Date, count: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(.dateTime.locale(SDFormat.koreanLocale).month().day().weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(SDColor.muted)

                Text(count == 0 ? "기록이 비어 있어요" : "웃어본 순간")
                    .font(.headline)
                    .foregroundStyle(SDColor.ink)
            }

            Spacer()

            Text("\(count)번")
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(SDColor.ink)
        }
        .sdCard()
        .accessibilityElement(children: .combine)
    }

    private func leadingBlankCount(for days: [SmileDayCount]) -> Int {
        guard let firstDate = days.first?.date else { return 0 }
        return calendar.component(.weekday, from: firstDate) - 1
    }

    private func changeMonth(_ action: () throws -> Void) {
        do {
            try action()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    private func refresh() {
        do {
            try viewModel?.refresh()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

private struct HistoryStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(SDColor.muted)

            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(SDColor.ink)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HistoryDayCell: View {
    let day: SmileDayCount
    let isSelected: Bool
    let isSelectable: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(day.date.formatted(.dateTime.locale(SDFormat.koreanLocale).day()))
                    .font(.subheadline.weight(isSelected ? .bold : .regular).monospacedDigit())

                Text(day.hasSmile ? "\(day.count)번" : " ")
                    .font(.caption2.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(SDColor.ink)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(day.hasSmile ? SDColor.sun : SDColor.shell.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? SDColor.ink : (day.hasSmile ? SDColor.sunDeep : .clear), lineWidth: isSelected ? 2.5 : 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
        .opacity(isSelectable ? 1 : 0.35)
        .accessibilityLabel(
            "\(day.date.formatted(.dateTime.locale(SDFormat.koreanLocale).month().day())) \(day.count)번"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
