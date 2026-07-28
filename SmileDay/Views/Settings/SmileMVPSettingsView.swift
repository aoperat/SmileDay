import SwiftUI
import SwiftData
import CoachingKit

/// 알림 CRUD와 데이터 저장 위치만 있는 설정. 기준선 재촬영과 Pro는 없다.
struct SmileMVPSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?
    @State private var newTime = Date()
    @State private var newGuideID: String = SmileGuideCatalog.default.id

    var body: some View {
        List {
            if let viewModel {
                if viewModel.authorizationStatus == .denied {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(SharedStrings.notificationDeniedNotice)
                                .font(.footnote)
                                .foregroundStyle(SDColor.ink)

                            Button(SharedStrings.openSystemSettings) {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url)
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(SDColor.coral)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.white)
                }

                Section("내 알림") {
                    if viewModel.reminders.isEmpty {
                        Text(SharedStrings.noReminderYet)
                            .font(.subheadline)
                            .foregroundStyle(SDColor.muted)
                    }

                    ForEach(viewModel.reminders, id: \.notificationID) { reminder in
                        ReminderRow(reminder: reminder, viewModel: viewModel)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            try? viewModel.removeReminder(viewModel.reminders[index])
                        }
                    }
                }
                .listRowBackground(Color.white)

                Section("알림 추가") {
                    DatePicker("시간", selection: $newTime, displayedComponents: .hourAndMinute)

                    GuidePickerRow(selectedID: newGuideID, guides: SmileGuideCatalog.all) { guideID in
                        newGuideID = guideID
                    }
                    .padding(.vertical, 4)

                    Button("추가") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                        Task {
                            try? await viewModel.addReminder(
                                hour: components.hour ?? 9,
                                minute: components.minute ?? 0,
                                guideID: newGuideID
                            )
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .listRowBackground(Color.white)

                Section {
                    Label("모든 기록은 이 기기에만 저장됩니다", systemImage: "iphone")
                    Label("외부 서버로 전송되지 않습니다", systemImage: "lock.shield")
                    Label("앱을 삭제하면 모든 기록이 함께 삭제됩니다", systemImage: "trash")
                } header: {
                    Text("데이터 저장 위치")
                } footer: {
                    Text("완료한 시각과 어떤 미소였는지만 저장해요. 사진과 영상은 찍지도, 저장하지도 않아요.")
                        .font(.caption)
                        .foregroundStyle(SDColor.muted)
                }
                .listRowBackground(Color.white)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SDColor.cream)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let vm = viewModel ?? SettingsViewModel(
                reminderRepository: ReminderRepository(modelContext: modelContext),
                sessionRepository: SessionRepository(modelContext: modelContext),
                scheduler: UserNotificationReminderScheduler()
            )
            viewModel = vm
            try? vm.refresh()
            await vm.refreshAuthorizationStatus()
        }
    }
}

private struct ReminderRow: View {
    let reminder: ReminderSetting
    let viewModel: SettingsViewModel

    private var time: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = reminder.hour
                components.minute = reminder.minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                Task {
                    try? await viewModel.updateReminderTime(
                        reminder,
                        hour: components.hour ?? reminder.hour,
                        minute: components.minute ?? reminder.minute
                    )
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DatePicker("알림 시간", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()

                Spacer()

                Toggle("알림 켜기", isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { _ in Task { try? await viewModel.toggleReminder(reminder) } }
                ))
                .labelsHidden()
            }

            GuidePickerRow(selectedID: reminder.guide.id, guides: SmileGuideCatalog.all) { guideID in
                Task { try? await viewModel.updateReminderGuide(reminder, guideID: guideID) }
            }
        }
        .padding(.vertical, 4)
    }
}
