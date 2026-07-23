import SwiftUI
import CoachingKit

struct ReminderListView: View {
    let viewModel: SettingsViewModel
    @State private var newTime = Date()

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
