# 리마인더 추천 시간 원탭 추가 설계

**상태**: 승인됨
**작성일**: 2026-07-24
**프로젝트**: SmileDay (Xcode + SwiftUI, CoachingKit 패키지)

## 1. 배경과 목표

버킷 단위 넛지([[2026-07-23-bucket-reminder-nudge-design]])가 빈 시간대를 채우도록 유도하지만, 정작 리마인더 화면에서는 DatePicker로 시간을 하나씩 골라야 해서 번거롭다. 빈 버킷마다 추천 시간을 미리 제시하고 원탭으로 추가할 수 있게 한다.

**기본 추천 시간** (각 버킷 범위에 부합):

| 버킷 | 범위 | 추천 시간 |
|---|---|---|
| 아침 | 05–10시 | 09:00 |
| 낮 | 11–16시 | 13:00 |
| 저녁 | 17–04시 | 20:00 |

## 2. 동작 정의

`ReminderListView`(설정 경로·홈 카드 시트 공통) 상단에 **추천 섹션**을 추가한다.

- **노출 조건**: 빈 버킷이 하나라도 있을 때. 등록된 리마인더의 hour를 버킷으로 매핑해 빈 버킷을 계산한다.
- **행 구성**: 버킷 이름 + 추천 시각(예: "아침 · 09:00") + [추가] 버튼
- **[추가] 탭**: 기존 `SettingsViewModel.addReminder(hour:minute:)` 호출 (권한 요청 + 롤링 윈도 예약 포함). 추가되면 목록이 갱신되고 그 버킷 행은 추천 섹션에서 자동으로 사라진다.
- 3개 버킷이 모두 차면 추천 섹션 자체가 사라진다.
- 체크인 직후 제안(SaveConfirm)은 체크인 시각을 그대로 쓰는 기존 방식 유지 — 사용자가 실제로 앱을 쓰는 시간이 최선의 추천이므로.

## 3. 컴포넌트 설계

**CoachingKit** — `TimeBucket`에 추천 시각 추가 (ReminderPrompt.swift):

```swift
public extension TimeBucket {
    /// 빈 버킷을 원탭으로 채울 때 제시하는 기본 추천 시각(정시).
    var suggestedHour: Int {
        switch self {
        case .morning: 9
        case .afternoon: 13
        case .evening: 20
        }
    }
}
```

**SmileDay 타겟** — `ReminderListView`에 추천 섹션:

```swift
private var missingBuckets: [TimeBucket] {
    let registered = Set(viewModel.reminders.map { TimeBucket(hour: $0.hour) })
    return TimeBucket.allCases.filter { !registered.contains($0) }
}

// List 최상단
if !missingBuckets.isEmpty {
    Section("추천 시간") {
        ForEach(missingBuckets, id: \.self) { bucket in
            // "아침 · 09:00"  [추가]
        }
    }
}
```

`SettingsViewModel`은 변경 없음.

## 4. 테스트 관점

- `TimeBucket.suggestedHour`: 값(9/13/20) 확인 + 각 추천 시각이 자기 버킷 범위에 속하는지 (`TimeBucket(hour: bucket.suggestedHour) == bucket`)
- UI(추천 섹션)는 관례대로 빌드 검증

## 5. 이번 설계에 포함하지 않는 것

- 홈 카드에서의 직접 원탭 추가 (리마인더 화면 한 곳으로 집중)
- 사용자별 추천 시간 학습(체크인 패턴 기반) — 향후 고려
- 추천 시각의 분 단위 다양화 (정시 고정)
