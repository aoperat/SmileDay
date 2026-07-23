# 리마인더 시간 수정 설계

**상태**: 승인됨
**작성일**: 2026-07-24
**프로젝트**: SmileDay (Xcode + SwiftUI, CoachingKit 패키지)

## 1. 배경과 목표

`ReminderListView`는 리마인더를 추가/삭제/토글만 할 수 있고 시간 수정이 불가능하다. 시간을 바꾸려면 삭제 후 다시 추가해야 하는데, 그러면 `notificationID`가 바뀌어 기존 예약이 완전히 새로 생성된다. 기존 리마인더의 시간을 직접 수정하는 기능을 추가한다.

## 2. 동작 정의

- 리마인더 행을 탭하면 편집 시트가 뜬다. 시트에는 그 리마인더의 현재 시각으로 초기화된 `DatePicker`와 "저장"/"취소" 버튼이 있다.
- **저장**: 새 시각으로 `ReminderSetting.hour/minute`을 갱신하고, 같은 `notificationID`로 롤링 윈도를 다시 예약한다 (버킷이 바뀌면 그날그날 문구도 새 시간대 풀에서 나온다). 시트를 닫는다.
- **취소**: 아무 것도 바꾸지 않고 시트를 닫는다.
- 토글(on/off)과 스와이프 삭제는 기존 그대로 둔다. 탭 제스처가 이 두 기존 컨트롤과 겹치지 않도록, 행 전체가 아니라 `Button`으로 시간 텍스트 영역만 탭 가능하게 한다 (Toggle은 여전히 별도 컨트롤로 동작).

## 3. 컴포넌트 설계

**CoachingKit**:

```swift
// ReminderRepository.swift에 추가
public func updateTime(_ reminder: ReminderSetting, hour: Int, minute: Int) throws {
    reminder.hour = hour
    reminder.minute = minute
    try modelContext.save()
}
```

```swift
// SettingsViewModel.swift에 추가
public func updateReminderTime(_ reminder: ReminderSetting, hour: Int, minute: Int) async throws {
    try reminderRepository.updateTime(reminder, hour: hour, minute: minute)
    if reminder.isEnabled {
        await scheduler.scheduleRollingWindow(id: reminder.notificationID, hour: hour, minute: minute, days: reminderRollingWindowDays)
    }
    try refresh()
}
```

비활성 리마인더는 시간만 바꾸고 재예약하지 않는다 (토글 on 될 때 새 시간으로 예약됨 — 기존 `toggleReminder` 로직 그대로 재사용).

**SmileDay 타겟** — `ReminderListView`에 편집 시트:

```swift
@State private var editingReminder: ReminderSetting?

// 리마인더 행의 시간 Text를 Button으로 감싸 탭하면 editingReminder = reminder
// Toggle은 그대로 별도 컨트롤 유지

.sheet(isPresented: Binding(
    get: { editingReminder != nil },
    set: { if !$0 { editingReminder = nil } }
)) {
    if let editingReminder {
        ReminderEditSheet(reminder: editingReminder, viewModel: viewModel)
    }
}
```

`ReminderSetting`이 `Identifiable`을 명시적으로 준수하는지 불확실하므로 `sheet(item:)` 대신 `isPresented` + 옵셔널 상태 조합을 쓴다. 추가 프로토콜 준수 없이 안전하게 동작한다.

`ReminderEditSheet`(신규, `ReminderListView.swift` 파일 내 private struct):
- `@State private var editedTime: Date` — `reminder.hour/minute`으로 초기화
- DatePicker(.hourAndMinute) + "취소"/"저장" 툴바 버튼
- 저장 시 `viewModel.updateReminderTime(reminder, hour:minute:)` 호출 후 dismiss

## 4. 테스트 관점 (CoachingKit)

- `ReminderRepository.updateTime`: hour/minute이 갱신되는지
- `SettingsViewModel.updateReminderTime`: 활성 리마인더는 재예약(scheduler.scheduled에 반영)되는지, 비활성 리마인더는 재예약되지 않는지, 목록이 새 시간 기준으로 정렬되는지

UI(시트)는 관례대로 빌드 검증만 한다.

## 5. 이번 설계에 포함하지 않는 것

- 리마인더별 개별 문구 미리보기/선택
- 편집 시 알림 권한 재요청 (이미 활성 상태였으므로 불필요)
