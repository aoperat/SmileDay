# 리마인더 표정 질문 로테이션 설계

**상태**: 승인됨
**작성일**: 2026-07-23
**프로젝트**: SmileDay (Xcode + SwiftUI, CoachingKit 패키지)

## 1. 배경과 목표

현재 리마인더(`ReminderSetting` + `UserNotificationReminderScheduler`)는 사용자가 지정한 시각마다 알림을 보내지만, 문구가 "스마일데이 / 오늘의 표정 습관을 기록해보세요" 하나로 고정되어 있다. 앱을 "기록해야 하는 일"로만 느끼게 만드는 문구다.

이번 설계의 목표는 하루 중 실제로 웃는(미소든 큰 웃음이든) 시간을 늘리는 쪽으로 리마인더의 역할을 넓히는 것이다. 알림을 열었을 때 "지금 기록하세요"가 아니라, 스스로에게 던지는 짧은 표정 질문을 마주치게 한다. 작은 미소와 큰 웃음을 동등하게 다루고, 자기 성찰형 질문과 관계형 질문(사랑하는 사람이 나를 어떤 표정으로 봐줬으면 하는지 등)을 함께 순환시킨다.

**범위**: 알림 문구 콘텐츠와 로테이션 전략까지만 다룬다. 앱 내 화면(홈/케어 탭)에 오늘의 질문을 카드로 노출하는 것은 이번 설계에 포함하지 않는다. 기존 리마인더 시각 설정 UI(`ReminderListView`, `SettingsViewModel`)는 그대로 유지한다.

## 2. 콘텐츠 톤 원칙

- 답을 요구하는 설문이 아니라, 혼잣말처럼 떠오르는 질문 형태를 유지한다. ("~해보세요"가 아니라 "~해볼까요?", "~인가요?")
- 작은 미소와 큰 웃음(소리 내서 웃기 포함)을 별도 카테고리로 분리하지 않고, 같은 문구 풀 안에서 자연스럽게 섞는다.
- 자기 성찰형(지금 내 표정)과 관계형(타인이 보는 내 표정, 사랑하는 사람과의 표정) 질문을 함께 배치한다.
- "리프팅", "교정", "치료" 등 의학적 효과를 암시하는 표현은 쓰지 않는다 (기존 [[2026-07-18-expression-coach-design]] 원칙과 동일).

## 3. 시간대 구분과 문구 목록

알림의 `hour` 값을 기준으로 3개 시간대로 자동 분류한다.

| 시간대 | 시각 범위 |
|---|---|
| 아침 | 05:00 ~ 10:59 |
| 낮 | 11:00 ~ 16:59 |
| 저녁 | 17:00 ~ 04:59 |

각 시간대마다 8개씩, 총 24개 문구를 순환시킨다.

**아침 (05–10시) — 하루를 여는 톤**
1. 오늘 하루, 당신의 표정이 어떤 모습이었으면 좋겠나요?
2. 지금 거울을 본다면, 어떤 표정을 보고 싶나요?
3. 오늘 처음 마주치는 사람에게 어떤 표정을 보여주고 싶나요?
4. 지금 입꼬리를 살짝 올려볼까요? 아니면 오늘은 소리 내서 웃어볼까요?
5. 오늘 하루 중 가장 크게 웃고 싶은 순간은 언제일까요?
6. 오늘 가장 기대되는 일을 떠올려볼까요? 자연스럽게 표정이 풀릴 거예요.
7. 지금 이 순간, 몸에 힘을 빼고 살짝 웃어볼까요?
8. 오늘 하루를 시작하며, 나에게 짓고 싶은 표정 하나를 골라볼까요?

**낮 (11–16시) — 일상·관계 속 표정**
1. 지금 누군가 당신을 본다면, 어떤 표정을 보고 있을까요?
2. 내가 사랑하는 사람이 나를 어떤 표정으로 봐 줬으면 하나요?
3. 오늘 누군가에게 웃어 보인 적이 있나요? 지금 한 번 웃어볼까요?
4. 지금 잠깐, 소리 내서 웃어볼까요?
5. 옆에 있는 사람이 본다면 편안해 보일 표정을 짓고 있나요?
6. 최근에 있었던 재미있는 순간을 떠올리며 웃어볼까요?
7. 오늘 나를 웃게 한 사람은 누구였나요? 그 표정을 다시 지어볼까요?
8. 지금 화면이 아니라, 진짜 당신의 표정은 어떤가요?

**저녁 (17–04시) — 하루 마무리·회고**
1. 오늘 하루, 가장 크게 웃었던 순간은 언제였나요?
2. 오늘 나의 표정은 대체로 어땠나요?
3. 잠들기 전, 오늘 하루에 감사한 일을 떠올리며 웃어볼까요?
4. 오늘 하루를 마치며, 지금 어떤 표정을 짓고 있나요?
5. 내일 아침, 어떤 표정으로 하루를 시작하고 싶나요?
6. 오늘 나를 웃게 한 순간을 하나만 떠올려볼까요?
7. 지금 큰 소리로 한 번 웃어볼까요? 하루의 긴장이 풀릴 거예요.
8. 사랑하는 사람과 나눈 표정 중, 오늘 가장 따뜻했던 순간은 언제였나요?

## 4. 로테이션 전략

버킷(아침/낮/저녁)마다 독립적인 순환 커서를 둔다. 순서대로 8개를 다 사용하면 그 시점에 한 번 섞고(shuffle) 처음부터 다시 순환한다. 완전 랜덤을 쓰지 않는 이유는 같은 날 비슷한 문구가 겹쳐 뜨는 걸 막기 위해서다.

여러 개의 리마인더가 같은 시간대(예: 낮 12시, 낮 15시 리마인더 두 개)에 있어도 버킷 커서는 공유한다. 즉 "낮" 버킷의 다음 차례 문구는 그 시간대의 모든 리마인더가 함께 소비한다.

## 5. 컴포넌트 설계 (CoachingKit)

```swift
public enum TimeBucket: CaseIterable {
    case morning, afternoon, evening

    public init(hour: Int) {
        switch hour {
        case 5...10: self = .morning
        case 11...16: self = .afternoon
        default: self = .evening // 17...23, 0...4
        }
    }
}

public struct ReminderPrompt: Equatable {
    public let bucket: TimeBucket
    public let text: String
}

public enum ReminderPromptCatalog {
    public static let prompts: [ReminderPrompt] = [ /* 24개, 위 목록 그대로 */ ]
    public static func prompts(for bucket: TimeBucket) -> [ReminderPrompt] {
        prompts.filter { $0.bucket == bucket }
    }
}

public protocol ReminderPromptCursorStoring: AnyObject {
    func nextIndex(for bucket: TimeBucket, poolCount: Int) -> Int
    // 내부적으로 UserDefaults에 버킷별 (순서 배열, 다음 위치)를 저장하고,
    // 순서 배열을 다 소진하면 새로 셔플해서 재생성한다.
}

public final class UserDefaultsReminderPromptCursorStore: ReminderPromptCursorStoring { ... }

public struct ReminderPromptSelector {
    private let catalog: (TimeBucket) -> [ReminderPrompt]
    private let cursorStore: ReminderPromptCursorStoring

    // hour로부터 버킷을 정하고, 커서 저장소에서 다음 인덱스를 받아 문구를 반환한다.
    public func nextPrompt(forHour hour: Int) -> ReminderPrompt
}
```

`UserDefaultsReminderPromptCursorStore`는 기존 `UserDefaultsCareFavorites`와 동일한 패턴(간단한 UserDefaults 래퍼)을 따른다.

## 6. 알림 예약 구조 변경

**현재 문제**: `UserNotificationReminderScheduler.scheduleDaily`가 `UNCalendarNotificationTrigger(dateMatching:repeats: true)`로 알림 1건만 등록한다. `repeats: true` 트리거의 콘텐츠는 등록 시점에 고정되므로, 이 구조에서는 매일 다른 문구를 보여줄 수 없다.

**변경안**: `repeats: true` 단일 알림 대신, 향후 14일치를 각각 `repeats: false` 개별 알림으로 미리 예약한다.

```swift
public protocol ReminderScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleRollingWindow(id: String, hour: Int, minute: Int, days: Int) async
    func cancel(id: String)
}
```

`scheduleRollingWindow`는:
1. `id`로 시작하는 기존 예약을 모두 취소한다 (`"\(id)-0"` ~ `"\(id)-13"`).
2. `dayOffset in 0..<days`마다:
   - 오늘부터 `dayOffset`일 후, 지정된 `hour:minute`의 정확한 날짜(`DateComponents(year:month:day:hour:minute:)`)를 계산한다.
   - `ReminderPromptSelector.nextPrompt(forHour: hour)`로 그날의 문구를 하나 꺼낸다.
   - 식별자 `"\(id)-\(dayOffset)"`, `repeats: false`인 `UNCalendarNotificationTrigger`로 알림을 등록한다.

**리프레쉬 시점**:
- 앱이 포그라운드로 전환될 때(`RootView`에서 `@Environment(\.scenePhase)` 관찰) — 활성화된 모든 리마인더에 대해 `scheduleRollingWindow`를 다시 호출해 14일치를 채운다. 이미 지난 날짜의 알림은 1번 단계에서 자연히 정리된다.
- 리마인더를 새로 추가하거나 껐다가 다시 켤 때 (`SettingsViewModel.addReminder` / `toggleReminder`) — 기존과 동일하게 그 시점에 `scheduleRollingWindow`를 호출한다.

앱을 14일 이상 열지 않으면 마지막에 예약된 알림까지만 오고 그 이후로는 알림이 끊긴다. 이는 로컬 알림만 쓰는 이 앱의 구조상 감수하는 트레이드오프이며, 대부분의 사용자는 그보다 자주 앱을 열 것으로 예상한다.

## 7. 테스트 관점

- `TimeBucket(hour:)` 경계값(4, 5, 10, 11, 16, 17시)이 올바른 버킷으로 분류되는지
- `ReminderPromptSelector`가 8개를 소진할 때까지 중복 없이 순환하고, 소진 후 셔플되는지 (버킷별 독립적으로)
- `UserDefaultsReminderPromptCursorStore`가 앱 재시작(새 인스턴스) 후에도 커서 상태를 유지하는지
- `scheduleRollingWindow`가 기존 pending 알림을 정리하고 정확히 `days`개를 재등록하는지 (mock scheduler로 검증, 기존 `SettingsViewModelTests`의 `MockScheduler` 패턴 확장)

## 8. 이번 설계에 포함하지 않는 것

- 앱 내 화면에 오늘의 질문을 카드로 노출하는 것 (향후 별도 설계로 다룰 수 있음)
- 사용자가 알림 카테고리(아침/낮/저녁)나 톤을 직접 선택하는 설정 UI
- 서버 기반 원격 푸시 (이 앱은 기기 내 저장만 사용하며 서버가 없음)
