import SwiftUI
import SwiftData
import CoachingKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var isResettingBaseline = false

    let onBaselineUpdated: (Baseline) -> Void

    var body: some View {
        NavigationStack {
            List {
                if let viewModel {
                    NavigationLink {
                        ReminderListView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Label("리마인더", systemImage: "bell")
                            Spacer()
                            Text("\(viewModel.reminders.count)개")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        isResettingBaseline = true
                    } label: {
                        HStack {
                            Label("기준선 재설정", systemImage: "arrow.clockwise")
                            Spacer()
                            if let weeks = viewModel.baselineAgeWeeks {
                                Text("\(weeks)주 전")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    NavigationLink {
                        DataLocationView()
                    } label: {
                        Label("데이터 저장 위치", systemImage: "lock")
                    }

                    HStack {
                        Label("계정", systemImage: "person")
                        Spacer()
                        Text("준비 중")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("설정")
        }
        .onAppear {
            let vm = viewModel ?? SettingsViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                sessionRepository: SessionRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler()
            )
            viewModel = vm
            try? vm.refresh()
        }
        .fullScreenCover(isPresented: $isResettingBaseline) {
            BaselineCaptureView { newBaseline in
                onBaselineUpdated(newBaseline)
                isResettingBaseline = false
                try? viewModel?.refresh()
            }
        }
    }
}
