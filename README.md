# 스마일데이 (SmileDay)

평소 잘 웃지 않는 사람을 위한 iOS 앱. 하루에 몇 번, 짧게 웃어보는 시간을 만듭니다.

표정을 채점하지 않고, 연속 기록을 끊었다고 나무라지 않습니다. **웃어본 횟수만 이 기기에 기록합니다.**
서버가 없고 네트워크 코드도 없습니다.

- iOS 17+ · SwiftUI · SwiftData
- 한국어와 영어. 기기 언어를 따르고, 둘 다 아니면 영어로 보여줍니다
- 외부 의존성 없음 (Apple 프레임워크만)

## 핵심 루프

```
반복 알림 → 비평가적 큐 → 5초 미소 → 완료 저장 → 오늘·최근 7일
```

이 루프가 제품의 전부이고, **카메라를 쓰지 않습니다.** 카메라 권한은 온보딩에 등장하지 않고
완료를 기록하는 데 필요하지도 않습니다.

잠금화면 알림을 길게 누르면 나오는 **"웃었어요"** 버튼은 앱을 열지 않고 그 자리에서 기록합니다.
이때 iOS는 앱을 백그라운드로만 깨우므로, 이 경로는 뷰 계층이 아니라 `PersistenceController.shared`를
통해 저장소에 닿습니다.

## 선택 기능: 실시간 미소 확인

홈의 보조 카드에서만 들어가는 별도 모드입니다. 사용자가 명시적으로 시작하는 동안에만
TrueDepth 카메라로 입꼬리 blend shape가 세션 시작 시 편한 표정에서 얼마나 올라왔는지를 읽어
0~100 신호로 보여줍니다.

경계가 분명합니다.

- 카메라 **화면**은 기본으로 꺼져 있고, 사용자가 토글로 그 세션에만 켭니다.
- `ARFrame.capturedImage`를 어디서도 읽지 않습니다 — **사진이 아예 만들어지지 않습니다.**
- 프레임·blend shape·신호·타임라인 중 무엇도 SwiftData·UserDefaults·파일·네트워크에 닿지 않습니다.
  종료 후 요약은 메모리에만 있고 화면을 닫으면 사라집니다.
- 완료 횟수에 더하지 않습니다. 실시간 확인을 도는 것과 미소를 완료하는 것은 다른 행동입니다.
- 신호는 센서 값이지 평가가 아닙니다. 외모·감정·좌우대칭을 판단하지 않습니다.

## 빌드와 테스트

```bash
# CoachingKit 전체 테스트 (순수 Swift — 시뮬레이터 없이 macOS에서 바로 실행)
cd CoachingKit && swift test

# 특정 테스트 클래스만
cd CoachingKit && swift test --filter SmileMomentRepositoryTests

# 앱 타깃 빌드 (SwiftUI 뷰의 검증 수단)
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build

# 앱 타깃 단위 테스트 (시뮬레이터 필요)
xcodebuild test -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# 문자열 카탈로그의 미번역 항목 세기 (STRICT=1이면 남아 있을 때 실패)
scripts/check-catalogs.sh
```

린트 설정은 없습니다.

`SmileDayTests/`는 앱 타깃의 **순수 로직만** 덮습니다 — 알림 식별자 형식, `NotificationRouter`,
`SDFormat`, `Color` 토큰 래퍼, 그리고 카탈로그 키가 실제로 해석되는지. SwiftUI 뷰 자체에는
자동 테스트가 없어 `xcodebuild` 성공이 뷰 변경의 검증입니다.
**UIKit이나 ARKit 없이 테스트할 수 있는 것은 앱 타깃이 아니라 `CoachingKit`에 넣으세요.**

> `swift test`의 마지막 줄은 Swift Testing 러너가 찍는 `0 tests in 0 suites passed`입니다.
> 이 저장소의 테스트는 XCTest 기반이라 **실패가 아닙니다.** `Test Suite 'All tests' passed`를 확인하세요.

## 구조

두 계층이 프로토콜 경계로 갈라져 있습니다.

| | |
|---|---|
| **`CoachingKit/`** | 플랫폼과 무관한 전부 — SwiftData `@Model`, 리포지토리, `@Observable` 뷰모델, 값 타입. macOS도 타깃으로 두는 이유는 오직 시뮬레이터 없이 `swift test`를 돌리기 위해서입니다. **새 로직은 테스트와 함께 여기에 넣습니다.** |
| **`SmileDay/`** | 앱 타깃 — SwiftUI 뷰(`Views/`)와 플랫폼 서비스(`Services/`). CoachingKit의 두 프로토콜을 구현합니다: `ReminderScheduling`(→ `UserNotificationReminderScheduler`), `LiveSmileMonitoring`(→ `ARKitLiveSmileMonitor`). |

부수효과가 있는 모든 경계에 프로토콜이 있어서, 패키지 테스트는 `UNUserNotificationCenter`나
ARKit 없이 돕니다. 시간에 의존하는 코드는 `now: () -> Date`와 `Calendar`를 주입받습니다.

저장소는 두 층입니다. 활성 모델은 `SmileMoment`(완료한 미소 하나)와
`SmileReminderSchedule`(반복 일정 하나)뿐이고, `Baseline`·`CheckInSession`·`CareSession`·
`ReminderSetting`·`CustomSmileCard`는 **기존 사용자의 저장소가 열리게 하려고만 남아 있습니다.**

## 바꾸면 안 되는 값

기기에 이미 예약된 알림과 이미 저장된 레코드가 이 문자열들을 그대로 담고 있습니다.
버전 마이그레이션 설계 없이 바꾸면 옛 알림을 해석하거나 취소할 수 없게 됩니다.

- `SmileGuideCatalog.default.id` — `"anytime-soft"`. `SmileMoment.guideID`와 알림 payload에 저장돼 있습니다.
- `ReminderNotificationCategory.identifier` — 알림 버튼이 붙는 카테고리.
- `ReminderNotificationAction`의 rawValue — 눌린 버튼을 해석하는 값.
- `ReminderNotificationPayload`의 key와 구버전 `bucket`/`promptText` 파싱 경로.
- 반복 알림 식별자 형식 — `UserNotificationReminderScheduler.dailyIdentifier(groupID:hour:minute:)`
  한 곳에만 있습니다. **등록과 취소가 반드시 같은 문자열을 만들어야 합니다.**
- 호환 전용 모델들의 저장 프로퍼티, 그리고 `SmileReminderSchedule`의 기본값
  (제품 추천값 `SmileReminderPattern.recommended`와 숫자가 같아도 별개입니다 — 이쪽은 마이그레이션 계약).
- **알림에 실리는 카탈로그 키** — `reminderMessage.<id>`, `notificationAppName`,
  `reminderAction.<rawValue>`, `liveMonitorNudgeTitle`/`Body`.
  알림은 문구가 아니라 이 키를 담은 채로 기기에 예약되고 배달 시점에 기기 언어로 풀립니다.
  이름을 바꾸거나 지우면 이미 예약된 알림이 키를 그대로 보여줍니다.
  `localizedUserNotificationString(forKey:)`에는 table 인자가 없으므로 **기본 `Localizable` 표에 있어야 합니다.**

## 문구 규칙

- 건강 효능 표현 금지 (App Store Guideline 1.4.1): "리프팅", "젊어진다", "교정한다", "치료".
  표정 습관을 기록한다는 틀을 씁니다.
- 순위와 연속 기록 상실 표현을 쓰지 않습니다. 0회인 날은 실패가 아니라 그냥 쉬어간 날입니다.
- "점수"로 보여주는 유일한 숫자는 실시간 모드의 센서 신호이고, 저장하거나 세션끼리 비교하거나
  좋고 나쁨으로 말하지 않습니다.

사용자에게 보이는 문구는 전부 `SmileDay/Resources/`의 String Catalog에 있습니다 —
공용·알림용 `Localizable`과 화면별 `Home`·`Onboarding`·`Settings`·`Coaching`·`InfoPlist`.
원본 언어는 **영어**이고 한국어가 `ko` 열입니다.

코드는 Xcode가 만들어주는 `LocalizedStringResource` 심볼로만 문구를 참조합니다
(`Text(.todayCountTitle)`, `.Home.smileCount(n)`). **키를 문자열 리터럴로 쓰지 마세요.**
예외는 데이터로 정해지는 id(`smileCue.<id>`, `reminderMessage.<id>`)뿐이고, 이때도 키를 먼저
`String`으로 만들어야 합니다 — `String.LocalizationValue("prefix.\(id)")`는 보간을 서식 인자로
취급해서 조용히 키를 그대로 돌려줍니다.

**CoachingKit에는 사용자 문구를 두지 않습니다.** SwiftPM은 `.xcstrings`를 컴파일하지 않고
복사만 하므로 거기서 `String(localized:)`는 키를 그대로 돌려줍니다. `SmileCueCatalog`는
id와 순서만 갖고, 문구는 `Coaching.xcstrings`의 `smileCue.<id>`에 있습니다.

## 문서

| 위치 | 내용 |
|---|---|
| `CLAUDE.md` / `CLAUDE.ko.md` | 아키텍처 요약, 명령, 규칙 (에이전트용) |
| `AGENTS.md` | 디렉터리마다 있는 작업 지침 |
| `docs/superpowers/specs/` | 기능별 설계 문서 (`YYYY-MM-DD-<기능>-design.md`) |
| `docs/superpowers/plans/` | 그에 대응하는 구현 계획 |
| `docs/reports/` | 날짜별 프로젝트 리뷰와 출시 점검 |

기능을 확장하기 전에 해당 설계 문서를 먼저 읽으세요.
