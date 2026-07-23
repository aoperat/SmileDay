import SwiftUI
import CoachingKit

struct ReminderListView: View {
    let viewModel: SettingsViewModel
    @State private var newTime = Date()
    @State private var editingReminder: ReminderSetting?

    /// 아직 리마인더가 없는 시간대. 원탭 추천에 쓴다.
    private var missingBuckets: [TimeBucket] {
        let registered = Set(viewModel.reminders.map { TimeBucket(hour: $0.hour) })
        return TimeBucket.allCases.filter { !registered.contains($0) }
    }

    var body: some View {
        List {
            if !missingBuckets.isEmpty {
                Section("추천 시간") {
                    ForEach(missingBuckets, id: \.self) { bucket in
                        HStack {
                            Text("\(bucket.displayName) · \(String(format: "%02d:00", bucket.suggestedHour))")
                                .font(.body.monospacedDigit())
                            Spacer()
                            Button("추가") {
                                Task { try? await viewModel.addReminder(hour: bucket.suggestedHour, minute: 0) }
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(SDColor.coral, in: Capsule())
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section {
                ForEach(viewModel.reminders, id: \.notificationID) { reminder in
                    HStack {
                        Button {
                            editingReminder = reminder
                        } label: {
                            Text(String(format: "%02d:%02d", reminder.hour, reminder.minute))
                                .font(.title3.monospacedDigit())
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { reminder.isEnabled },
                            set: { _ in Task { try? await viewModel.toggleReminder(reminder) } }
                        ))
                        .labelsHidden()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        try? viewModel.removeReminder(viewModel.reminders[index])
                    }
                }
            }

            Section("리마인더 추가") {
                DatePicker("시간", selection: $newTime, displayedComponents: .hourAndMinute)
                Button("추가") {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                    Task {
                        try? await viewModel.addReminder(hour: components.hour ?? 9, minute: components.minute ?? 0)
                    }
                }
            }
        }
        .navigationTitle("리마인더")
        .sheet(isPresented: Binding(
            get: { editingReminder != nil },
            set: { if !$0 { editingReminder = nil } }
        )) {
            if let editingReminder {
                ReminderEditSheet(reminder: editingReminder, viewModel: viewModel)
            }
        }
    }
}

/// 기존 리마인더의 시간을 수정하는 시트.
private struct ReminderEditSheet: View {
    let reminder: ReminderSetting
    let viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedTime: Date

    init(reminder: ReminderSetting, viewModel: SettingsViewModel) {
        self.reminder = reminder
        self.viewModel = viewModel
        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute
        _editedTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("시간", selection: $editedTime, displayedComponents: .hourAndMinute)
            }
            .navigationTitle("시간 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: editedTime)
                        Task {
                            try? await viewModel.updateReminderTime(
                                reminder,
                                hour: components.hour ?? reminder.hour,
                                minute: components.minute ?? reminder.minute
                            )
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
