# 리마인더 설정 유도(넛지) 설계

**상태**: 승인됨
**작성일**: 2026-07-23
**프로젝트**: SmileDay (Xcode + SwiftUI, CoachingKit 패키지)

## 1. 배경과 목표

리마인더 기능([[2026-07-23-reminder-expression-prompts-design]])은 설정 탭 깊숙이 있어서, 사용자가 스스로 찾아 들어가지 않으면 존재를 모른다. 사용자가 자연스럽게 리마인더를 설정하도록 유도하는 진입점을 만든다.

원칙: 앱의 가치를 경험한 직후(첫 체크인 저장)에 제안하는 것을 메인으로 하고, 홈 화면 카드를 보조로 둔다. 온보딩에는 넣지 않는다 — 온보딩에 이미 카메라 권한 요청이 있어 권한 팝업이 연달아 뜨는 피로를 피한다.

## 2. 유도 지점

### A. 체크인 저장 직후 제안 (메인)

`SaveConfirmView`(기록 저장 완료 화면)에 조건부 제안 섹션을 추가한다.

- **노출 조건**: 등록된 리마인더가 0개 AND 이전에 "나중에"를 누른 적 없음
- **내용**: 확인 버튼 위에 "내일도 이 시간에 알려드릴까요?" 카드. 방금 체크인한 시각(시:분)을 그대로 기본값으로 보여준다.
- **[알림 받기]**: iOS 알림 권한 요청 → 그 시각으로 리마인더 등록(`SettingsViewModel.addReminder`) → 카드가 "리마인더가 설정되었어요" 확인 문구로 바뀐다.
- **[나중에]**: 거절 플래그를 저장하고 카드를 숨긴다. 이후 체크인에서 다시 묻지 않는다 (홈 카드가 이어받음).

권한 팝업이 "방금 기록을 마친" 맥락에서 뜨므로 수락률이 가장 높은 지점이다.

### B. 홈 유도 카드 (보조)

`HomeView`의 주간 스트릭 카드 아래에 작은 카드를 추가한다.

- **노출 조건**: 리마인더 0개 AND 체크인 이력 1회 이상 AND 카드를 닫은 적 없음
- **내용**: "매일 잊지 않게 알려드릴까요?" + 탭하면 리마인더 설정 화면(`ReminderListView`)을 시트로 띄운다.
- **X 버튼**: 닫으면 플래그를 저장하고 다시 보이지 않는다.
- 리마인더를 하나라도 등록하면 (어느 경로로든) 조건이 깨져 자동으로 사라진다.

## 3. 컴포넌트 설계 (CoachingKit)

기존 `CareFavoritesStoring` 패턴(프로토콜 + UserDefaults/인메모리 구현)을 따른다.

```swift
public protocol ReminderNudgeStateStoring: AnyObject {
    var hasDeclinedCheckInPrompt: Bool { get set }
    var hasDismissedHomeCard: Bool { get set }
}

public final class UserDefaultsReminderNudgeState: ReminderNudgeStateStoring { ... }
public final class InMemoryReminderNudgeState: ReminderNudgeStateStoring { ... }

public struct ReminderNudge {
    let store: ReminderNudgeStateStoring

    /// 체크인 저장 화면에서 리마인더 제안을 보여줄지.
    public func shouldOfferAfterCheckIn(reminderCount: Int) -> Bool
    // = reminderCount == 0 && !store.hasDeclinedCheckInPrompt

    /// 홈에 리마인더 유도 카드를 보여줄지.
    public func shouldShowHomeCard(reminderCount: Int, hasAnyCheckIn: Bool) -> Bool
    // = reminderCount == 0 && hasAnyCheckIn && !store.hasDismissedHomeCard

    public func declineCheckInPrompt()  // store.hasDeclinedCheckInPrompt = true
    public func dismissHomeCard()       // store.hasDismissedHomeCard = true
}
```

## 4. 앱 연결 (SmileDay 타겟)

- **CoachingTabView**: `@Environment(\.modelContext)` 추가. 세션 완료 시점의 시각(시:분)을 `SessionResult`에 담는다. `SaveConfirmView`에 제안 노출 여부·시각·수락/거절 콜백을 전달한다. 수락 시 `SettingsViewModel.addReminder(hour:minute:)` 호출(권한 요청 포함).
- **SaveConfirmView**: 제안 카드 UI. 상태는 3가지 — 제안 표시 / 수락 완료("리마인더가 설정되었어요") / 숨김.
- **HomeView**: `ReminderRepository`로 리마인더 개수를 읽고, `ReminderNudge.shouldShowHomeCard`로 노출을 결정한다. 탭하면 `ReminderListView`를 시트로 표시. 시트가 닫힐 때 조건을 다시 평가한다.

## 5. 테스트 관점

- `ReminderNudge` 조건 로직: 리마인더 개수/체크인 이력/플래그 조합별 노출 여부
- 거절/닫기 후 플래그가 저장되어 다시 노출되지 않는지
- `UserDefaultsReminderNudgeState`가 새 인스턴스에서도 플래그를 유지하는지
- UI 연결(SaveConfirmView/HomeView)은 기존 관례대로 유닛 테스트 없이 빌드 검증

## 6. 이번 설계에 포함하지 않는 것

- 온보딩 단계의 리마인더 설정
- 홈 카드의 재노출 정책(닫은 뒤 N일 후 다시 보여주기 등) — 일단 영구 숨김
- 알림 권한이 거부된 경우의 설정 앱 이동 안내
