# 버킷 단위 리마인더 유도 설계

**상태**: 승인됨
**작성일**: 2026-07-23
**프로젝트**: SmileDay (Xcode + SwiftUI, CoachingKit 패키지)

## 1. 배경과 목표

기존 넛지([[2026-07-23-reminder-nudge-design]])는 "리마인더 0개"일 때만 유도하므로, 하나를 등록하는 순간 모든 유도가 멈춘다. 하루 세 번(아침/낮/저녁) 알림을 받는 것이 표정 습관 형성에 이상적이므로, 리마인더 문구 로테이션에서 이미 쓰는 `TimeBucket`(아침 05–10 / 낮 11–16 / 저녁 17–04)을 재사용해 **비어 있는 시간대(버킷)를 채우도록** 유도를 확장한다.

판단 기준을 "리마인더 개수 == 0"에서 "각 버킷에 리마인더가 있는가"(`Set<TimeBucket>`)로 바꾼다. 앱은 아직 출시 전이므로 기존 넛지 플래그의 마이그레이션은 하지 않고 로직을 교체한다.

## 2. 동작 정의

### A. 체크인 직후 제안

- **노출 조건**: 체크인한 시각이 속한 버킷에 리마인더가 없음 AND 그 버킷을 거절한 적 없음
- 아침 리마인더를 등록한 사용자가 저녁에 체크인하면 "이 시간(19:30)에도 알려드릴까요?"가 다시 뜬다. 쓰다 보면 자연스럽게 3개까지 채워진다.
- **거절 플래그는 버킷별 저장**: 아침 제안을 거절해도 낮/저녁 제안은 뜬다. 같은 버킷은 다시 묻지 않는다.

### B. 홈 유도 카드

- **노출 조건**: 3개 버킷 중 하나라도 비어 있음 AND 체크인 이력 1회 이상 AND (아래 닫기 조건에 걸리지 않음)
- **문구 동적화**: 전부 비었으면 "매일 잊지 않게 알려드릴까요?", 일부만 비었으면 빈 버킷 이름을 나열해 "낮·저녁 리마인더도 설정해볼까요?"
- **닫기(X)**: 닫는 시점의 "빈 버킷 조합"을 스냅샷으로 저장한다. 빈 버킷 조합이 스냅샷과 같으면 계속 숨기고, 리마인더 추가/삭제로 조합이 달라지면 카드를 다시 보여준다. (영구 숨김이면 유도가 끊기고, 무조건 재노출이면 성가시므로 그 중간)

## 3. 컴포넌트 설계 (CoachingKit)

```swift
// TimeBucket에 표시 이름 추가 (ReminderPrompt.swift)
public extension TimeBucket {
    var displayName: String {
        switch self {
        case .morning: "아침"
        case .afternoon: "낮"
        case .evening: "저녁"
        }
    }
}

// ReminderNudge.swift 교체
public protocol ReminderNudgeStateStoring: AnyObject {
    /// 체크인 제안을 거절한 버킷들.
    var declinedBuckets: Set<TimeBucket> { get set }
    /// 홈 카드를 닫은 시점의 "빈 버킷" 조합. nil이면 닫은 적 없음.
    var dismissedHomeCardMissingBuckets: Set<TimeBucket>? { get set }
}

public struct ReminderNudge {
    public func shouldOfferAfterCheckIn(registeredBuckets: Set<TimeBucket>, checkInHour: Int) -> Bool
    // = 해당 버킷 미등록 && 해당 버킷 미거절

    public func declineCheckInPrompt(forHour hour: Int)
    // declinedBuckets에 해당 버킷 추가

    public func missingBuckets(registeredBuckets: Set<TimeBucket>) -> [TimeBucket]
    // TimeBucket.allCases 순서 유지한 빈 버킷 목록 (카드 문구용)

    public func shouldShowHomeCard(registeredBuckets: Set<TimeBucket>, hasAnyCheckIn: Bool) -> Bool
    // = 빈 버킷 존재 && hasAnyCheckIn && 빈 버킷 조합 != 닫기 스냅샷

    public func dismissHomeCard(registeredBuckets: Set<TimeBucket>)
    // 현재 빈 버킷 조합을 스냅샷으로 저장
}
```

`UserDefaultsReminderNudgeState`는 버킷 rawValue 문자열 배열로 저장한다. 스냅샷의 nil(닫은 적 없음)과 저장된 값은 `stringArray(forKey:)`의 nil 여부로 구분한다. 기존 키(`reminderNudgeDeclinedCheckInPrompt`, `reminderNudgeDismissedHomeCard`)는 삭제한다.

```swift
// ReminderRepository에 편의 메서드 추가
public func registeredBuckets() throws -> Set<TimeBucket>
// = Set(fetchAll().map { TimeBucket(hour: $0.hour) })
```

## 4. 앱 연결 (SmileDay 타겟)

- **CoachingTabView**: `shouldOfferAfterCheckIn(registeredBuckets:checkInHour:)`로 판단하고, 거절 콜백에서 `declineCheckInPrompt(forHour:)`에 체크인 시각을 넘긴다. `SaveConfirmView`는 변경 없음.
- **HomeView**: `refreshReminderNudge()`에서 `registeredBuckets()`를 읽어 노출과 문구(빈 버킷 목록)를 결정한다. `ReminderNudgeCard`는 title/subtitle을 파라미터로 받도록 바꾼다. X 버튼은 `dismissHomeCard(registeredBuckets:)`를 호출한다.

## 5. 테스트 관점

- `shouldOfferAfterCheckIn`: 버킷 등록/거절 조합별 노출 여부 (다른 버킷 거절이 영향을 주지 않는지 포함)
- `missingBuckets`: 순서와 내용
- `shouldShowHomeCard` / `dismissHomeCard`: 스냅샷이 같으면 숨김 유지, 조합이 달라지면 재노출, 전부 채워지면 항상 숨김
- `UserDefaultsReminderNudgeState`: 새 인스턴스에서 버킷 집합·스냅샷(nil 포함) 유지
- `ReminderRepository.registeredBuckets()`: hour → 버킷 매핑

## 6. 이번 설계에 포함하지 않는 것

- 기존 넛지 플래그의 마이그레이션 (출시 전이므로 불필요)
- 버킷별 추천 기본 시각 제안 (체크인 시각을 그대로 쓰는 기존 방식 유지)
- 하루 3회를 초과하는 리마인더에 대한 안내
