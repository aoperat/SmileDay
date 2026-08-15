import SwiftUI
import SwiftData
import CoachingKit

struct SmileHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// 격자 계산과 날짜 표시가 같은 달력을 봐야 한다. 앱이 주입한 그레고리력이며,
    /// `firstWeekday`는 지역 설정에서 온다 — 일요일 시작을 가정하지 않는다.
    @Environment(\.calendar) private var calendar

    @State private var viewModel: SmileHistoryViewModel?
    @State private var loadFailed = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    /// `veryShortWeekdaySymbols`는 항상 일요일부터 오므로 `firstWeekday`만큼 돌린다.
    private var weekdayHeaders: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
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
        .navigationTitle(Text(.Home.historyNavigationTitle))
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
            .accessibilityLabel(Text(.Home.previousMonth))

            Spacer()

            Text(viewModel.displayedMonth, format: .dateTime.year().month())
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
            .accessibilityLabel(Text(.Home.nextMonth))
        }
        .foregroundStyle(SDColor.sunDeep)
    }

    private func monthSummary(_ viewModel: SmileHistoryViewModel) -> some View {
        HStack(spacing: 12) {
            HistoryStat(title: .Home.monthSmileTitle, value: .Home.smileCount(viewModel.monthTotal))
            Divider()
            HistoryStat(title: .Home.activeDaysTitle, value: .Home.activeDayCount(viewModel.activeDayCount))
        }
        .frame(maxWidth: .infinity)
        .sdCard()
        .accessibilityElement(children: .combine)
    }

    private func monthCalendar(_ viewModel: SmileHistoryViewModel) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 6) {
                // 영어의 very-short 기호는 S·T가 겹치고 프랑스어는 M이 겹친다 — `id: \.self`면
                // 열이 빠져 격자가 어긋난다. 위치가 id다.
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SDColor.muted)
                        .frame(maxWidth: .infinity)
                }

                // 게으른 격자는 형제 ForEach의 id를 한 이름 공간으로 본다. 머리글이 0…6을
                // 쓰므로 빈 칸이 같은 정수를 쓰면 머리글 칸으로 잡혀 높이가 어긋난다.
                ForEach(leadingBlankIDs(for: viewModel.days), id: \.self) { _ in
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
                Text(date, format: .dateTime.month().day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(SDColor.muted)

                Text(count == 0 ? .Home.emptyDay : .Home.smiledMoments)
                    .font(.headline)
                    .foregroundStyle(SDColor.ink)
            }

            Spacer()

            Text(.Home.smileCount(count))
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(SDColor.ink)
        }
        .sdCard()
        .accessibilityElement(children: .combine)
    }

    private func leadingBlankCount(for days: [SmileDayCount]) -> Int {
        guard let firstDate = days.first?.date else { return 0 }
        return (calendar.component(.weekday, from: firstDate) - calendar.firstWeekday + 7) % 7
    }

    private func leadingBlankIDs(for days: [SmileDayCount]) -> [String] {
        (0..<leadingBlankCount(for: days)).map { "leading-\($0)" }
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
    let title: LocalizedStringResource
    let value: LocalizedStringResource

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
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    let day: SmileDayCount
    let isSelected: Bool
    let isSelectable: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(day.date, format: .dateTime.day())
                    .font(.subheadline.weight(isSelected ? .bold : .regular).monospacedDigit())

                Text(day.hasSmile ? String(localized: .Home.smileCount(day.count)) : " ")
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
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// `Text(_:format:)`만 환경의 캘린더·로캘을 상속한다. String이 필요한 접근성 라벨은
    /// 같은 값을 명시적으로 넘겨 격자의 날짜와 같은 달력으로 읽히게 한다.
    private var accessibilityLabel: String {
        let date = day.date.formatted(Date.FormatStyle(locale: locale, calendar: calendar).month().day())
        return String(localized: .Home.dayAccessibility(date, day.count))
    }
}
