# 정직한 피드백 개선 설계안

## 배경

앱 리뷰 과정에서 세 가지 개선점이 나왔다:

1. 홈 화면의 "입꼬리 각도" 표현이 실제로는 그 순간의 표정 동작(베이스라인 대비 지금 얼마나 크게 웃는지)을 측정하는 것인데, 마치 정밀한 해부학적 측정치처럼 읽힌다.
2. 베이스라인 재촬영 기능(`SettingsViewModel.shouldRecommendReset`, 4주 경과 시 true)은 이미 존재하지만, 설정 화면에 들어가야만 보이는 수동적인 형태라 대부분의 사용자가 놓친다.
3. 케어 루틴(입꼬리 리프팅, 광대 마사지 등)에 어떤 근거로 도움이 되는지에 대한 설명이 전혀 없다.

이번 설계는 이 세 가지를 다룬다. 근거 인용은 하지 않기로 했다(정확성 검증 없이 특정 연구를 인용하는 건 위험) — 대신 각 루틴이 실제로 무엇을 하는지 담백하게 설명한다.

## 범위

### 1. "오늘의 미소 크기" 문구 변경
- `SmileDay/Views/Home/HomeView.swift`: `ArcGaugeView` 라벨 `"오늘의 입꼬리 각도"` → `"오늘의 미소 크기"`, `"어제의 입꼬리 각도"` → `"어제의 미소 크기"`
- `SmileDay/Views/History/HistoryView.swift`: `Chart`의 `y: .value("점수", ...)` → `y: .value("미소 크기", ...)`
- 계산 로직(`ScoreCalculator`, `SDFormat.signedDegrees`, `°` 단위)은 변경하지 않는다. 텍스트 레이블만 바꾼다.

### 2. 홈 화면 베이스라인 재촬영 유도 카드

**재사용**: 새 임계값을 만들지 않고 기존 `SettingsViewModel.shouldRecommendReset`과 동일한 4주 기준을 쓴다. 홈과 설정이 서로 다른 기준으로 재촬영을 권하지 않도록 한다.

**계산 로직 통합**: `CoachingKit/Sources/CoachingKit/Baseline.swift`에 확장 추가:
```swift
public extension Baseline {
    func ageWeeks(now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(calendar.dateComponents([.weekOfYear], from: capturedAt, to: now).weekOfYear ?? 0, 0)
    }
}
```
`SettingsViewModel.refresh()`는 기존 인라인 계산 대신 `baseline.ageWeeks(now: now())`를 호출하도록 정리한다. 동작(반환값)은 동일해야 하며 기존 `SettingsViewModelTests`가 그대로 통과해야 한다.

**스누즈 상태 저장** — `ReminderNudge.swift`와 동일한 프로토콜/UserDefaults 패턴으로 신규 파일 `CoachingKit/Sources/CoachingKit/BaselineResetNudge.swift` 추가:
```swift
public protocol BaselineResetNudgeStateStoring: AnyObject {
    var snoozedUntil: Date? { get set }
}

public final class UserDefaultsBaselineResetNudgeState: BaselineResetNudgeStateStoring {
    // UserDefaults 키: "baselineResetNudgeSnoozedUntil"
}

public final class InMemoryBaselineResetNudgeState: BaselineResetNudgeStateStoring {
    public var snoozedUntil: Date?
    public init() {}
}

public struct BaselineResetNudge {
    public init(store: BaselineResetNudgeStateStoring)

    /// shouldRecommendReset(4주 경과)이고, 스누즈 기간이 지났으면 true.
    public func shouldShowHomeCard(shouldRecommendReset: Bool, now: Date) -> Bool

    /// "나중에" 탭 시 호출. 기본 7일 스누즈.
    public func snooze(now: Date, days: Int = 7)

    /// 재촬영 완료 시 호출.
    public func clearSnooze()
}
```

`ReminderNudge`는 "한 번 닫으면 영구 dismiss"인데, 베이스라인 재촬영은 4주마다 반복되는 권유라 영구 dismiss가 맞지 않다. 그래서 스누즈(기간 후 재노출) 방식을 쓴다.

**HomeView 변경**:
- `HomeView`가 `onBaselineUpdated: (Baseline) -> Void` 파라미터를 새로 받는다 (기존 `SettingsView`가 받는 것과 동일한 콜백). `MainTabView`에서 `HomeView(baseline:onStartCoaching:onBaselineUpdated:)`로 한 줄 추가 연결.
- `@State private var showBaselineResetNudgeCard`, `@State private var isRecapturingBaseline` 추가.
- `onAppear`/재촬영 완료 후 `refreshBaselineResetNudge()`에서 `baseline.ageWeeks()`로 `shouldRecommendReset`을 계산하고, `BaselineResetNudge(store: UserDefaultsBaselineResetNudgeState()).shouldShowHomeCard(...)`로 카드 노출 여부 결정. (`ReminderNudgeCard`와 같은 `refreshReminderNudge()` 패턴.)
- 새 뷰 `BaselineResetNudgeCard` (`ReminderNudgeCard`와 동일한 시각 스타일):
  - 제목: "기준 얼굴을 다시 찍을 때가 됐어요"
  - 본문: "지난 촬영 후 4주가 지났어요. 다시 찍으면 오늘의 미소 크기가 더 정확해져요."
  - 탭 → `isRecapturingBaseline = true`
  - 닫기(x) → `BaselineResetNudge(...).snooze(now:)` 호출 후 카드 숨김
- `.fullScreenCover(isPresented: $isRecapturingBaseline)`로 기존 `BaselineCaptureView` 재사용:
  - `onBaselineSaved`: `onBaselineUpdated(newBaseline)` 호출, `BaselineResetNudge(...).clearSnooze()`, 카드 재계산
  - `onCancel`: 그냥 닫기
- 리마인더 유도 카드와 동시에 뜰 수 있으나(둘 다 노출 조건이 다르므로), 이번 범위에서는 우선순위 조정 없이 순서대로(리마인더 카드 → 베이스라인 카드) 쌓아서 보여준다.

### 3. 케어 루틴 정직한 목적 설명

`CoachingKit/Sources/CoachingKit/CareRoutine.swift`의 `CareRoutine`에 필드 추가:
```swift
public let purpose: String
```

5개 카탈로그 루틴에 채울 문구 (결과를 약속하지 않고 무엇을 하는지만 서술):

| id | purpose |
|---|---|
| lift-smile | "입꼬리 주변 근육을 움직이고 마사지하는 스트레칭이에요." |
| lift-cheek | "광대 주변을 눌러 풀고 쓸어 올리는 마사지예요." |
| relax-brow | "미간과 눈가 주변 근육의 긴장을 풀어주는 간단한 스트레칭이에요." |
| depuff-morning | "목과 얼굴의 림프 흐름을 도와주는 마사지예요." |
| morning-1min | "아침에 표정 근육을 가볍게 깨우는 1분 스트레칭이에요." |

표시 위치: `SmileDay/Views/Care/CarePlayerView.swift` 상단 타이틀(`Text(routine.title)`) 바로 아래에 `purpose`를 캡션으로 추가. 루틴 목록(`RoutineRow`), 추천 카드(`RecommendationCard`)는 이번 범위에서 변경하지 않는다 (이미 있는 `reason` 텍스트와 역할이 다름).

루틴 `title`이나 `CareCategory` 이름 자체는 변경하지 않는다 (범위 밖).

## 테스트

- `CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift`: `purpose`가 빈 문자열이 아닌지 검증하는 테스트 추가 (기존 `systemImage` 테스트와 동일 패턴)
- `CoachingKit/Tests/CoachingKitTests/BaselineResetNudgeTests.swift` 신규: `ReminderNudgeTests.swift`와 동일한 패턴으로 `shouldShowHomeCard`/`snooze`/`clearSnooze` 동작 검증
- 기존 `SettingsViewModelTests.swift`는 리팩터링 후에도 그대로 통과해야 한다 (동작 변경 없음)

## 범위 밖

- 케어 루틴에 과학적 근거/출처 인용 (정확성 검증 없이 인용하는 리스크 때문에 제외)
- 루틴 제목·카테고리 이름 변경
- 베이스라인 재촬영 임계값 자체 변경 (기존 4주 유지)
- 케어 루틴 목록/추천 카드에 `purpose` 노출 (재생 화면에만 노출)
