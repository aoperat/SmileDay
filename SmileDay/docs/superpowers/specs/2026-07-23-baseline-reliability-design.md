# 기준선 신뢰성 & 관리 개선 구현 계획

**상태**: 승인됨
**작성일**: 2026-07-23
**프로젝트**: SmileDay (Xcode + SwiftUI)

## 1. 배경

`Baseline`은 앱의 모든 점수(`ScoreCalculator.delta`)가 비교되는 영구 기준점이다. 최근 체크인(코칭 세션) 쪽에는 조명·각도·트래킹 유실 신뢰도 판정을 추가했지만(`CoachingViewModel.isLightingPoor`/`isAngleOK`, `ARKitFaceTrackingSession`의 `isTracked` 가드), 정작 그 기준이 되는 기준선 촬영 자체는 이 신뢰도 판정을 전혀 거치지 않는다. 또한 기준선 재설정을 관리하는 주변 기능(재설정 시점 안내, 오래된 기준선 정리)도 비어 있다. 이번 작업은 이 다섯 가지 공백을 한 번에 메운다.

## 2. 다루는 항목과 결정 사항

| # | 항목 | 결정 |
|---|---|---|
| 1 | 촬영 시 조명/각도 낮으면? | 경고 배너만 표시, 저장은 허용 |
| 2 | 재설정 시 촬영 가이드 문구 | 공유 화면(`BaselineCaptureView`)에 상시 노출로 이동 |
| 3 | 재설정 권장 시점 | 기준선 경과 4주부터 권장 표시 |
| 4 | 촬영 안정화 시간 | 허용 오차 내에서 1초 유지되어야 저장 가능 |
| 5 | 오래된 기준선 정리 | 최신 포함 최근 5개만 보존, 나머지 자동 삭제 |

## 3. 데이터 모델 변경

`CoachingKit/Sources/CoachingKit/Baseline.swift`에 `CheckInSession`과 동일한 신뢰도 필드를 추가한다.

```swift
@Model
public final class Baseline {
    public var capturedAt: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double
    public var lightingQuality: Double   // 신규
    public var deviceAngleOK: Bool       // 신규
    ...
}
```

`SessionRepository.saveBaseline`도 이 두 값을 받도록 시그니처를 확장한다:

```swift
public func saveBaseline(
    _ measurement: FaceMeasurement,
    capturedAt: Date,
    lightingQuality: Double,
    deviceAngleOK: Bool
) throws -> Baseline
```

기존 호출부(`BaselineCaptureViewModel`, `DemoSeeder`)는 새 파라미터를 채워서 갱신한다. `DemoSeeder`는 합성 데이터이므로 `lightingQuality: 1.0, deviceAngleOK: true` 고정값을 넘긴다.

## 4. 항목 1 — 촬영 시 조명/각도 경고

`BaselineCaptureViewModel`에 `CoachingViewModel`과 동일한 패턴을 이식한다:

- `public private(set) var isLightingPoor: Bool = false`
- `public private(set) var isAngleOK: Bool = true`
- `@ObservationIgnored public private(set) var latestAmbientIntensity: Double?`
- `init`에서 `session.onLightingUpdate`/`session.onTrackingQualityUpdate`를 위 프로퍼티에 연결 (`CoachingViewModel.swift` 46~57번 줄과 동일 구조)
- `captureBaseline()`에서 `saveBaseline` 호출 시 `lightingQuality: latestAmbientIntensity.map(LightingEvaluator.quality(ambientIntensity:)) ?? 1.0`, `deviceAngleOK: isAngleOK`를 전달

`SmileDay/Views/Onboarding/BaselineCaptureView.swift`에 `CoachingSessionView`의 경고 배너와 같은 스타일로 두 배너를 추가한다 (`isLightingPoor`/`isAngleOK == false`일 때만 노출, 저장 버튼은 막지 않음).

## 5. 항목 2 — 재설정 시에도 촬영 가이드 노출

현재 "밝은 곳에서 정면을 바라보고 무표정으로 촬영해주세요"라는 안내는 `OnboardingIntroView`의 세 번째 페이지에만 있고, 설정 화면에서 재설정할 때는 이 인트로를 건너뛰므로 보이지 않는다.

`BaselineCaptureView.swift`의 기존 안내 문구("무표정으로 얼굴을 타원 안에 맞춰주세요") 위나 아래에 조명/정면 관련 한 줄을 추가해 상시 노출한다. 새 화면이나 다이얼로그는 만들지 않는다. `OnboardingIntroView`의 세 번째 페이지 문구는 그대로 유지(최초 사용자에게는 여전히 유용한 사전 안내이므로 중복이어도 무방).

## 6. 항목 3 — 4주 경과 시 재설정 권장 표시

`CoachingKit/Sources/CoachingKit/SettingsViewModel.swift`에 계산 프로퍼티 추가:

```swift
public var shouldRecommendReset: Bool {
    (baselineAgeWeeks ?? 0) >= 4
}
```

`SmileDay/Views/Settings/SettingsView.swift`의 "기준선 재설정" 행에서 `shouldRecommendReset == true`일 때 "N주 전" 텍스트 색을 강조(`SDColor.coral`)로 바꾸고 그 아래 "재설정을 권장해요" 서브텍스트를 추가한다. 강제 팝업이나 알림은 만들지 않는다 (조용한 시각적 힌트만).

## 7. 항목 4 — 저장 전 1초 안정화 요구

`BaselineCaptureViewModel`에 안정화 추적 로직을 추가한다.

```swift
public private(set) var isStable: Bool = false

private var stabilityReference: FaceMeasurement?
private var stabilityWindowStart: Date?
private let stabilityDuration: TimeInterval = 1.0
private let stabilityTolerance: Double = 0.02  // blendShape 계수 단위
```

`onUpdate` 콜백 안에서:
1. `stabilityReference`가 없거나, 현재 측정값이 `stabilityReference`와 각 축(mouthCornerLeft/Right, browTension)에서 `stabilityTolerance`를 초과해 벗어났으면 → `stabilityReference`를 현재값으로, `stabilityWindowStart`를 `now()`로 리셋하고 `isStable = false`
2. 벗어나지 않았고 `now().timeIntervalSince(stabilityWindowStart) >= stabilityDuration`이면 → `isStable = true`

`captureBaseline()`은 `isStable`도 확인해서, 안정화되지 않았으면 조용히 리턴한다(버튼이 `isStable == false`일 때 비활성화되므로 실제로는 UI에서 막힘).

`BaselineCaptureView.swift`의 저장 버튼 `disabled` 조건에 `viewModel?.isStable != true` 추가. 안정화 중임을 알리는 진행 표시(예: "안정화 중..." 캡션 또는 프로그레스 링)를 버튼 위에 추가한다.

**알려진 단순화**: 촬영 중 얼굴 트래킹이 잠깐 끊겼다가 돌아오는 경우 안정화 경과 시간 계산이 실제 유지 시간보다 길게 잡힐 수 있다(트래킹 끊긴 구간도 경과 시간에 포함됨). 이 앱 규모에서는 감수할 수 있는 엣지케이스로 보고 별도 처리하지 않는다.

## 8. 항목 5 — 오래된 기준선 자동 정리

`SessionRepository`에 추가:

```swift
public func pruneOldBaselines(keeping: Int = 5) throws {
    var descriptor = FetchDescriptor<Baseline>(sortBy: [SortDescriptor(\.capturedAt, order: .reverse)])
    let all = try modelContext.fetch(descriptor)
    guard all.count > keeping else { return }
    for baseline in all.dropFirst(keeping) {
        modelContext.delete(baseline)
    }
    try modelContext.save()
}
```

`BaselineCaptureViewModel.captureBaseline()`에서 `saveBaseline` 성공 직후 `try repository.pruneOldBaselines()` 호출. 최초 촬영이든 재설정이든 같은 메서드를 타므로 자동으로 적용된다.

## 9. 테스트 계획

`CoachingKit/Tests/CoachingKitTests/`에 추가/보강:

- `BaselineCaptureViewModelTests`: `isLightingPoor`/`isAngleOK` 신호 반영 확인, `isStable`이 허용 오차 내 유지 시간에 따라 true/false로 바뀌는지(주입 가능한 `now: () -> Date` 사용), `captureBaseline()`이 `isStable == false`일 때 아무 것도 저장하지 않는지, 저장 시 `lightingQuality`/`deviceAngleOK`가 올바르게 전달되는지
- `SettingsViewModelTests`: `shouldRecommendReset`이 4주 미만/이상 경계에서 올바르게 바뀌는지
- `SessionRepositoryTests`: `pruneOldBaselines`가 정확히 최근 N개만 남기고 나머지를 지우는지, 개수가 N 이하일 때는 아무것도 안 지우는지

기존 `saveBaseline` 호출부(테스트 포함)는 새 파라미터(`lightingQuality`, `deviceAngleOK`) 반영해서 갱신한다.

## 10. 범위 밖

- 여러 프레임 평균을 내는 정교한 스무딩(단순 "N초간 유지" 안정화 판정으로 대체)
- 기준선 변경 이력을 보여주는 UI (최근 5개를 DB에 보존은 하지만, 이를 조회/시각화하는 화면은 이번 범위 밖 — 필드/데이터만 남겨 향후 확장 여지를 준다)
- 트래킹 유실 중 안정화 타이머 정밀 보정
