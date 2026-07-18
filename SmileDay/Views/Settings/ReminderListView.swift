import SwiftUI
import CoachingKit

struct ReminderListView: View {
    let viewModel: SettingsViewModel
    @State private var newTime = Date()

    var body: some View {
        List {
            Section {
                ForEach(viewModel.reminders, id: \.notificationID) { reminder in
                    HStack {
                        Text(String(format: "%02d:%02d", reminder.hour, reminder.minute))
                            .font(.title3.monospacedDigit())
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
    }
}
