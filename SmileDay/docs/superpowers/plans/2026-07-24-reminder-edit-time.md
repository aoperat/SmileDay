# 리마인더 시간 수정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 등록된 리마인더의 시간을 삭제 후 재생성 없이 직접 수정할 수 있게 한다.

**Architecture:** `ReminderRepository.updateTime`으로 SwiftData 모델을 갱신하고, `SettingsViewModel.updateReminderTime`이 활성 리마인더면 같은 `notificationID`로 롤링 윈도를 재예약한다. UI는 `ReminderListView`에서 행을 탭하면 시트로 편집한다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, XCTest.

**설계 문서:** `SmileDay/docs/superpowers/specs/2026-07-24-reminder-edit-time-design.md`

---

### Task 1: ReminderRepository.updateTime + SettingsViewModel.updateReminderTime (TDD)

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/ReminderRepository.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderRepositoryTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift`

- [ ] **Step 1: 실패하는 테스트 추가**

`ReminderRepositoryTests.swift`에 추가:

```swift
    func test_updateTime_changesHourAndMinute() throws {
        let repository = ReminderRepository(modelContext: try makeInMemoryContext())
        let reminder = try repository.add(hour: 9, minute: 0)

        try repository.updateTime(reminder, hour: 20, minute: 30)

        let updated = try XCTUnwrap(repository.fetchAll().first)
        XCTAssertEqual(updated.hour, 20)
        XCTAssertEqual(updated.minute, 30)
    }
```

`SettingsViewModelTests.swift`에 추가:

```swift
    func test_updateReminderTime_enabledReminder_reschedules() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.updateReminderTime(reminder, hour: 20, minute: 30)

        XCTAssertEqual(viewModel.reminders.first?.hour, 20)
        XCTAssertEqual(viewModel.reminders.first?.minute, 30)
        let newlyScheduled = scheduler.scheduled.suffix(from: scheduledBefore)
        XCTAssertEqual(newlyScheduled.count, 1)
        XCTAssertEqual(newlyScheduled.first?.hour, 20)
        XCTAssertEqual(newlyScheduled.first?.minute, 30)
    }

    func test_updateReminderTime_disabledReminder_doesNotReschedule() async throws {
        let (viewModel, _, scheduler) = try makeViewModel()
        try await viewModel.addReminder(hour: 9, minute: 0)
        let reminder = try XCTUnwrap(viewModel.reminders.first)
        try await viewModel.toggleReminder(reminder) // 끈다
        let scheduledBefore = scheduler.scheduled.count

        try await viewModel.updateReminderTime(reminder, hour: 20, minute: 30)

        XCTAssertEqual(viewModel.reminders.first?.hour, 20)
        XCTAssertEqual(scheduler.scheduled.count, scheduledBefore, "꺼진 리마인더는 시간만 바뀌고 재예약되면 안 된다")
    }
```

- [ ] **Step 2: 실패 확인**

Run: `cd CoachingKit && swift test --filter "ReminderRepositoryTests|SettingsViewModelTests"`
Expected: FAIL to build — `updateTime`, `updateReminderTime` 없음.

- [ ] **Step 3: 구현**

`ReminderRepository.swift`에 추가 (`setEnabled` 아래):

```swift
    public func updateTime(_ reminder: ReminderSetting, hour: Int, minute: Int) throws {
        reminder.hour = hour
        reminder.minute = minute
        try modelContext.save()
    }
```

`SettingsViewModel.swift`에 추가 (`toggleReminder` 아래):

```swift
    public func updateReminderTime(_ reminder: ReminderSetting, hour: Int, minute: Int) async throws {
        try reminderRepository.updateTime(reminder, hour: hour, minute: minute)
        if reminder.isEnabled {
            await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: hour, minute: minute, days: reminderRollingWindowDays)
        }
        try refresh()
    }
```

- [ ] **Step 4: 통과 확인**

Run: `cd CoachingKit && swift test`
Expected: PASS — 전체 통과.

- [ ] **Step 5: Commit**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderRepository.swift CoachingKit/Sources/CoachingKit/SettingsViewModel.swift CoachingKit/Tests/CoachingKitTests/ReminderRepositoryTests.swift CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift
git commit -m "feat: add reminder time update with conditional rescheduling"
```

---

### Task 2: ReminderListView 편집 시트

**Files:**
- Modify: `SmileDay/Views/Settings/ReminderListView.swift`

- [ ] **Step 1: 시간 텍스트를 탭 가능한 버튼으로, 편집 시트 추가**

`ReminderListView` 전체를 아래로 교체한다:

```swift
// SmileDay/Views/Settings/ReminderListView.swift
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
```

- [ ] **Step 2: 빌드 확인**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Views/Settings/ReminderListView.swift
git commit -m "feat: allow editing existing reminder times"
```

---

### Task 3: 최종 검증

- [ ] **Step 1: CoachingKit 전체 테스트**

Run: `cd CoachingKit && swift test`
Expected: PASS.
