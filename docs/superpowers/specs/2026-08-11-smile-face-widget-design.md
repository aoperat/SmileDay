# 미소 얼굴 위젯 설계

- 날짜: 2026-08-11
- 상태: 승인됨 — 구현 미착수
- 배경: 마지막으로 웃은 뒤 시간이 얼마나 지났는지를 홈 화면과 잠금화면에서 흘깃 보고 알 수 있게 한다. 출발점은 듀오링고의 표정이 변하는 위젯이었지만, 죄책감으로 굴리는 그쪽 방식은 이 앱이 하지 않기로 한 것이라 방향을 뒤집었다.

## 1. 목표

- 마지막 완료로부터 흐른 시간을 얼굴 표정 하나로 보여준다.
- 앱이 실행되지 않아도 3·6·24시간 경계에서 표정이 바뀐다.
- 홈 화면과 잠금화면 두 곳에 둘 수 있다.
- 위젯을 탭하면 5초 가이드가 열린다.

## 2. 제품 원칙

- **시든 얼굴로 사용자를 평가하지 않는다.** 24시간이 지난 얼굴은 잠든 얼굴이지 슬픈 얼굴이 아니다. 표현하는 대상은 사용자의 실패가 아니라 캐릭터의 상태다.
- 숫자를 얹지 않는다. 오늘 횟수도, 연속 일수도, 목표 달성률도 위젯에 넣지 않는다. 홈 화면 안에서는 맥락이 있지만 위젯은 흘깃 보는 자리라, 숫자를 두면 그 자리에서 자기 채점이 시작된다.
- 쉬어간 시간은 실패가 아니다. 앱을 그만 쓴 사람의 홈 화면에 비난이 남지 않아야 한다.
- 얼굴 사진·영상·실시간 센서값은 위젯에 들어오지 않는다. 위젯이 읽는 값은 마지막 완료 시각 하나뿐이다.

## 3. 왜 앱 아이콘이 아니라 위젯인가

처음 안은 앱 아이콘을 바꾸는 것이었다. **iOS에서는 불가능하다.**

`setAlternateIconName`은 실행 중인 앱만 호출할 수 있고 예약 수단이 없다. 앱이 깨어나는 기회는 사용자가 앱을 열었다 닫을 때, "웃었어요" 알림 버튼으로 백그라운드 실행될 때, 그리고 `BGAppRefreshTask`뿐이다. 마지막 것은 iOS 재량이라 시각 정확도를 보장하지 않는다.

그래서 "웃었다 → 밝아진다"는 되지만 "3시간이 지났다 → 옅어진다"는 트리거가 없다. 아이콘은 마지막으로 웃은 순간의 표정에 얼어붙고, 하루 종일 안 웃어도 계속 웃는 얼굴이 남는다 — 의도와 정확히 반대다.

WidgetKit 타임라인은 **미래 시각의 엔트리를 미리 반환**할 수 있고, 시스템이 그 시각에 앱 없이 다시 그린다. 이 기능이 성립하는 유일한 자리다.

## 4. 표정 4단계

눈과 배경은 앱 아이콘(`AppIcon-light.png`)의 좌표를 그대로 쓴다. 배경 `sun`(`0xFFC93C`), 획 `ink`(`0x46323C`). 단계 사이에서 바뀌는 것은 **입 곡선의 제어점 하나**다.

| 상태 | 조건 | 곡률 | 눈 |
|------|------|------|-----|
| `bright` | 0 ~ 3시간 | 1.00 | 뜸 |
| `soft` | 3 ~ 6시간 | 0.45 | 뜸 |
| `calm` | 6 ~ 24시간, **그리고 기록 없음** | 0.15 | 뜸 |
| `asleep` | 24시간 ~ | 0.15 | 감음 |

입은 `x=222`에서 `x=802`까지 가는 2차 곡선 하나이고, 양 끝은 `y=578`에 고정된다. 곡률이 정하는 것은 제어점의 `y`뿐이다(1024×1024 기준):

```
제어점 y = 578 + 244 × 곡률
```

곡률 1.00이면 `y=822`로 앱 아이콘의 입 그대로다. 0.15는 `y≈615` — 직선이 아니라 아주 옅게 올라간 곡선이다. **완전한 직선은 "평온"이 아니라 "시무룩"으로 읽힌다.**

`asleep`의 감은 눈은 뜬 눈의 원을 아래로 굽은 짧은 호로 바꾼다. 입은 `calm`과 같은 0.15를 쓴다 — 잠든 얼굴과 쉬는 얼굴의 차이는 눈에만 둔다.

아직 한 번도 웃지 않은 사용자는 `calm`으로 시작한다. 기록 없음을 24시간 취급하면 위젯을 달자마자 잠든 얼굴을 보게 된다.

아트워크 파일은 만들지 않는다. 눈 두 개와 곡선 하나라 SwiftUI `Path`로 그린다. 잠금화면은 색을 벗겨 단색으로 그리는데, 이 얼굴은 획만으로 이루어져 그대로 살아남는다.

## 5. 데이터와 로직

**SwiftData 스토어는 옮기지 않는다.** 공유 컨테이너로 이전하면 기존 사용자의 스토어를 마이그레이션해야 하는데, 위젯 하나를 위해 감수할 위험이 아니다.

대신 App Group `group.dolparo.smileDay`의 `UserDefaults`에 **마지막 완료 시각 하나**를 스냅샷으로 쓴다. 위젯이 필요한 전부다.

- 발행 지점은 `SmileMomentRepository.save()` **한 곳**이다. 현재 저장 경로가 둘인데(`SmileGuideViewModel`, `AppDelegate`의 알림 액션) 모두 이 메서드를 지나므로, 여기 한 번만 걸면 백그라운드 경로까지 덮인다. 호출부에 흩뿌리면 언젠가 하나를 빠뜨린다.
- 저장이 실패하면 발행하지 않는다(`save()`의 rollback 경로 뒤).
- `WidgetCenter`는 iOS 전용이라 CoachingKit에 둘 수 없다. `ReminderScheduling`·`LiveSmileMonitoring`과 같은 방식으로 프로토콜만 패키지에 두고 앱이 구현한다.

```swift
// CoachingKit — 순수
public protocol SmileRecordPublishing {
    func publish(lastSmileAt: Date)
}
// SmileDay — App Group 쓰기 + WidgetCenter.shared.reloadAllTimelines()
```

기존 사용자는 스냅샷이 없다. 앱 시작 시 없으면 SwiftData에서 마지막 완료를 한 번 읽어 채운다 — `ReminderActionBackfill.swift`와 같은 패턴이다.

상태 계산은 순수 함수로 둔다.

```swift
public enum SmileFaceState { case bright, soft, calm, asleep }
static func at(_ now: Date, lastSmile: Date?) -> SmileFaceState
/// 이 상태가 끝나는 시각. `asleep`이면 nil.
static func nextTransition(after now: Date, lastSmile: Date?) -> Date?
```

## 6. 위젯 구성

| 종류 | 내용 | 탭 |
|------|------|-----|
| `systemSmall` | 얼굴만. 숫자·글자 없음 | 가이드 열기 |
| `accessoryCircular` | 같은 얼굴, 단색 | 가이드 열기 |

잠금화면 원형이 이 기능의 핵심이다. 크기가 아이콘만 하고, 하루에 수십 번 보는 화면이다.

타임라인:

```
경계  = [lastSmile+3h, +6h, +24h] 중 현재보다 미래인 것
엔트리 = [지금] + 경계들
정책   = 남은 경계 있으면 .atEnd, 없으면 .never
```

`.never`가 맞다. `asleep`은 다음 완료 전까지 변하지 않고, 그 완료가 `reloadAllTimelines()`로 직접 깨운다.

탭은 `widgetURL(smileday://guide)` → `onOpenURL` → 기존 `NotificationRouter`로 흘린다. 알림 "가이드 열기"가 이미 여는 화면이라 새 경로가 아니다. URL 스킴 등록은 새로 필요하다.

`SmileFaceShape`는 CoachingKit에 둔다. 위젯 익스텐션은 앱 타깃 코드를 볼 수 없어, 앱과 위젯이 공유할 수 있는 자리가 여기뿐이다. `SDPalette`가 이미 패키지에 있어 색도 그대로 쓴다.

## 7. 위젯 추가 유도

iOS에는 위젯을 홈 화면에 추가하는 API도, 위젯 갤러리를 여는 URL 스킴도 없다. 제스처를 안내하는 수밖에 없다.

띄우는 조건 — 셋 다 참일 때만:

- `WidgetCenter.getCurrentConfigurations`가 비어 있음 (이미 단 사람에게는 묻지 않는다)
- 아직 한 번도 묻지 않음
- 누적 완료 3회 이상

띄우는 자리는 5초를 끝낸 직후의 완료 화면이다. 기분이 가장 좋은 순간이고, "이걸 홈 화면에 남길까요"가 말이 되는 유일한 자리다.

**거절하면 다시 묻지 않는다.** 반복 유도는 이 앱이 하지 않는다. 대신 설정에 상시 입구를 둔다(`liveMonitorNudgeSection` 옆).

## 8. 프라이버시 매니페스트

현재 `PrivacyInfo.xcprivacy`는 UserDefaults 사용 이유로 `CA92.1`(앱 자신만 접근) 하나만 선언한다. App Group으로 공유하는 순간 이 선언이 사실과 달라지므로 **`1C8F.1`**(같은 App Group 멤버 간 공유)을 추가한다. 위젯 익스텐션도 UserDefaults를 읽으므로 **자체 `PrivacyInfo.xcprivacy`** 를 둔다.

App Store Connect 업로드 시 프라이버시 리포트로 검증되는 항목이라 빠뜨리면 경고나 반려로 이어진다. 요구 이유 코드 목록은 Apple이 갱신하므로 작업 시점의 현재 문서로 확인한다.

`NSPrivacyCollectedDataTypes`는 비어 있는 채로 둔다. 기기 밖으로 나가는 데이터가 없다는 사실이 바뀌지 않는다.

## 9. 파일 구성

**CoachingKit** — 신규 3, 수정 1

| 파일 | 내용 |
|------|------|
| `SmileFaceState.swift` | 상태 기계 + `nextTransition` |
| `SmileFaceShape.swift` | 눈·입 `Path`. 앱과 위젯이 공유 |
| `SmileRecordPublishing.swift` | 발행 프로토콜 |
| `LastSmileBackfill.swift` | 스냅샷이 없으면 한 번 채움 |
| `SmileMomentRepository.swift` (수정) | publisher 주입, 저장 성공 후 발행 |

**SmileDay** — 신규 3, 수정 5

| 파일 | 내용 |
|------|------|
| `Services/AppGroupSmileRecordPublisher.swift` | App Group 쓰기 + `reloadAllTimelines()` |
| `Views/Widget/WidgetSetupGuideView.swift` | 추가 유도 화면 |
| `SmileDay.entitlements` | App Groups |
| `SmileGuideView.swift` (수정) | 완료 후 유도 트리거 |
| `SmileMVPSettingsView.swift` (수정) | 위젯 섹션 |
| `SmileDayApp.swift` (수정) | `onOpenURL` |
| `AppDelegate.swift` (수정) | repository에 publisher 주입 |
| `PrivacyInfo.xcprivacy` (수정) | `1C8F.1` 추가 |

**SmileDayWidget** — 새 익스텐션 타깃

`SmileDayWidgetBundle.swift`, `SmileFaceTimelineProvider.swift`, `SmileFaceWidgetView.swift`, `SmileDayWidget.entitlements`, `PrivacyInfo.xcprivacy`

## 10. 사람이 해야 하는 준비 작업

1. Apple Developer 포털에서 App Group `group.dolparo.smileDay` 생성 후 앱 ID에 연결 (팀 `45BNT5RDHP`)
2. Xcode GUI로 Widget Extension 타깃 추가 — `project.pbxproj`를 손으로 쓰면 깨지기 쉽다
3. 두 타깃에 App Groups capability 활성화

익스텐션 타깃 추가는 `project.pbxproj`를 크게 바꾸므로, 다른 미커밋 작업이 없는 상태에서 시작한다.

## 11. 이번 범위에서 제외

- `systemMedium` 위젯과 위젯 위의 숫자 표시 (2절 원칙)
- iOS 18 `RelevantContext` 기반 스마트 스택 노출 — 보조 수단이지 유입 경로가 아니고, 배포 타깃이 iOS 17이라 가용성 분기가 필요하다
- Live Activity, Apple Watch, Control Center 컨트롤
- 표정 경계(3·6·24시간)를 사용자 알림 주기와 연동하는 것. 고정값으로 시작한다

## 12. 완료 기준

- `SmileFaceState`의 네 구간이 패키지 테스트로 검증된다 — **정확히 3·6·24시간 경계**, `lastSmile == nil`, 시계가 뒤로 간 미래 시각, `nextTransition` 반환값.
- 저장 성공 시 발행하고 **저장 실패 시 발행하지 않는다**는 것이 테스트로 고정된다.
- 백필이 스냅샷이 있으면 건드리지 않고, 없으면 채우고, 기록 자체가 없으면 아무것도 쓰지 않는다.
- 실기기에서 **앱을 실행하지 않은 채** 3·6·24시간 경계를 넘겼을 때 위젯이 다시 그려진다.
- 잠금화면 단색 렌더링에서 네 상태가 서로 구분된다.
- 위젯을 이미 설치한 사용자에게 유도 화면이 뜨지 않고, 한 번 거절하면 다시 뜨지 않는다.
- 위젯 탭이 5초 가이드를 연다.
- `swift test`와 iOS simulator·generic/platform=iOS 빌드가 통과한다.
