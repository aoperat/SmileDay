# 영어 지원 설계

- 날짜: 2026-08-15
- 상태: 승인됨 — **1단계(배관) 구현 완료 (2026-08-15, 브랜치 `feature/live-smile-monitor`, `d6f638f`…)**. 자동 검증 전부 통과: CoachingKit 301 tests, 앱 테스트, 카탈로그 게이트 181키/`missing_lang=0`/`needs_review=183`, CoachingKit 사용자 문자열 0(마이그레이션 스냅샷 8줄 제외), 한국어 보존 diff(placeholder 치환 외 차이 없음). 시뮬레이터: 한국어 기록 화면 정상, 영어 기기에서 영어 UI·"SmileDay" 아이콘. **실기기/탭이 필요해 남긴 것**: 영국 지역 요일 헤더 7열, 로컬 알림 언어 전환(push 경로로는 통과), v1→v2 업그레이드 경로, `.accessibility5`+SE. 계획 Task 14 Step 3–6 참조. 2단계(영어 집필 — `needs_review` 183개)와 7절(스토어·정책)은 미착수.
- 배경: 앱은 한국어 단일 언어로 빌드된다 (`developmentRegion = ko`, `knownRegions = (ko, Base)`). String Catalog도 `.strings`도 없고 사용자 문구 약 200개(실측: 앱 타깃 176 + CoachingKit 25)가 Swift 리터럴로 흩어져 있다. `SmileDayApp.swift:29`가 로케일을 `ko_KR`로 고정해 기기 언어를 무시한다. 이미 출시되어 실사용자가 있으므로 저장된 데이터와 기기에 예약된 알림을 깨지 않아야 한다.
- 선행 문서: `docs/english-copy-deck.md` (2026-07-31) — 톤 규칙과 문구 초안 약 40개. 이 설계는 그 문서의 "나중에 할 엔지니어링" 절을 실행 가능한 형태로 확정하되, **소스 언어에 대한 그 문서의 결정은 뒤집는다**(3절).

## 1. 목표

- 한 바이너리로 한국어와 영어를 모두 지원한다. 기기 언어에 따라 iOS가 고른다.
- 지원하지 않는 언어의 사용자는 한국어가 아니라 **영어**를 본다.
- 기존 한국어 사용자의 화면·기록·알림이 오늘과 동일하게 동작한다. 예외는 하나뿐이다 — 앱 이름 통일(4.4절), 의도된 변화다.
- App Store에 한국어 페이지 옆에 영어 페이지를 추가한다.

## 2. 제품 원칙

`docs/english-copy-deck.md`의 다섯 규칙을 영어 문구 전체에 적용한다.

1. 감정을 명령하지 않는다. `Let's!`가 아니라 조건절(`if you're up for it`).
2. 웃지 않은 날은 실패가 아니다. `You haven't…`, `Don't forget`, `streak`, `goal`, `missed` 금지.
3. 외모를 말하지 않는다. 칭찬도 평가다.
4. 과장하지 않는다. `Great job!`, `Amazing!`, 축하 이모지 금지.
5. 건강·미용 효과를 말하지 않는다 (App Store 1.4.1).

영어권 심사에서 더 직접적으로 걸리는 단어: `lift`, `tone`, `firm`, `anti-aging`, `rejuvenate`, `wrinkle`, `therapy`, `therapeutic`, `treatment`, `cure`, `heal`, `depression`, `anxiety`, `mood disorder`, `clinically`.

이 금지어들은 문서 규칙이 아니라 **테스트로 강제한다**(4.5절). 지금 한국어 금지어는 `SmileCueTests`·`ReminderMessageTests`가 지키고 있는데, 문구가 카탈로그로 이동하면 그 보증이 대체 없이 사라지고 영어 금지어는 검사 자체가 없다 — 심사 방어가 지금보다 약해진 채로 새 언어를 출시하게 된다.

**영어화는 한국어 문구를 고치는 계기가 아니다.** 한국어 카피는 이번 작업에서 한 글자도 바꾸지 않는다(예외: 4.4절 앱 이름).

## 3. 언어 결정과 폴백

- `developmentRegion = en`, `knownRegions = (en, ko, Base)`.
- `CFBundleDevelopmentRegion`은 표기가 아니라 **폴백 언어**다. iOS는 기기의 선호 언어 목록을 1순위부터 훑고(`en-GB` → `en` 같은 방언→일반 폴백 포함), **전부 안 맞을 때만** 이 값의 지역화를 고른다.
  - 실제 대상은 "프랑스어 기기" 전부가 아니라 **선호 언어에 영어가 없는 기기**다. 프랑스어 1순위·영어 2순위 기기는 `ko`로 둬도 영어를 본다.
  - 그런 기기가 소수라도 한국어보다 영어가 낫고, Apple 문서상 이걸 바꾸는 다른 손잡이는 없다. `CFBundleAllowMixedLocalizations`는 무관하고 Base Internationalization도 폴백 규칙을 바꾸지 않는다.
- 출시된 앱에서 이 값을 바꾸는 것은 안전하다. 앱 바이너리의 development region과 App Store Connect의 Primary Language는 별개 시스템이다. 기존 한국어 사용자는 `ko` 지역화가 그대로 매치되므로 폴백이 발동하지 않는다.
- String Catalog의 소스 언어가 영어가 되고 한국어가 번역 열로 내려간다. **`english-copy-deck.md`는 "한국어가 소스 언어다"라고 적어뒀고, 이 설계는 그 결정을 뒤집는다.** 폴백이 소스 언어에 묶여 있어 둘을 따로 고를 수 없기 때문이다.
- **이 값은 1단계 시작 시점에 바꾼다.** 나중에 뒤집으려면 pbxproj뿐 아니라 카탈로그의 소스 언어까지 손으로 옮겨야 하고, 그 시점엔 항목이 200개다.
- `SmileDayApp.swift:29`의 `.environment(\.locale, Locale(identifier: "ko_KR"))`를 제거하고 그 자리에 `.environment(\.calendar, ...)`를 둔다(6.1절).
- **앱 안에 언어 선택 화면을 만들지 않는다.** iOS 13+는 두 개 이상의 지역화를 담은 앱에 설정 앱 → SmileDay → 언어 항목을 자동으로 만든다. 직접 만들면 두 곳이 되어 서로 어긋난다.
- **UI 언어와 날짜·숫자 포맷은 별개 축이다.** "프랑스에 사는 영어 사용자" 기기(언어 en, 지역 FR)는 UI는 영어, 날짜는 프랑스식으로 본다. iOS 표준 동작이고 **의도다** — 버그로 보고하지 않는다.

기기를 영어로 쓰는 기존 한국 사용자는 업데이트 후 앱이 영어로 바뀐다. iOS 표준 동작이며 설정 앱에서 앱만 한국어로 되돌릴 수 있다.

## 4. 문자열 배치

### 4.1 카탈로그가 키의 출처다

**규율: 문구는 String Catalog에서 만들고, 코드는 생성된 심볼로만 참조한다. 코드에 키 리터럴을 쓰지 않는다.**

프로젝트에 `STRING_CATALOG_GENERATE_SYMBOLS = YES`가 이미 켜져 있고(`project.pbxproj:282, 316`) 설치된 Xcode는 26.6이다. 카탈로그에서 직접 추가한 키는 타입 안전한 Swift 심볼이 자동 생성된다 — 값이 없는 문구는 `static var`, 플레이스홀더가 있는 문구는 이름 붙은 파라미터를 가진 함수. 타입은 `LocalizedStringResource`(iOS 16+ 요구, 이 앱은 17+라 무관)다.

```swift
Text(.todayCountTitle)                          // SwiftUI에 바로
String(localized: .todayCountTitle)             // String이 필요한 자리
```

**Swift 래퍼 계층을 만들지 않는다.** `String` 계산 프로퍼티 200개를 손으로 쓰는 안은 오타가 조용히 실패한다 — 키를 틀리면 키 문자열이 화면에 뜬다. 심볼을 쓰면 같은 오타가 빌드 실패가 된다.

`SharedStrings.swift`는 삭제한다. 호출부 84곳이 `SharedStrings.foo` → `.foo`로 바뀐다. 뷰에 인라인으로 박힌 문구도 별도 Swift 프로퍼티로 승격하지 않고 카탈로그 키로 직행한다.

**배열 상수는 카탈로그로 못 간다.** `SharedStrings.liveMonitorIntroPoints`(문자열 5개 배열)는 개별 키 5개(`liveMonitorIntroCamera`, `liveMonitorIntroPreview`, …)로 쪼개고 배열은 호출부(`LiveSmileMonitorView:150`)에서 조립한다. 지금 그 `ForEach`는 `id: \.self`인데, 카탈로그의 독립 항목 5개가 되는 순간 두 번역이 같아지면 id가 충돌해 줄이 조용히 빠진다 — 조립한 배열에는 `id: \.offset`을 쓴다(6.2절의 요일 머리글과 같은 함정이다).

주의: 자동 추출된 키(소스의 문자열 리터럴에서 Xcode가 긁어온 것)는 심볼이 **생기지 않는다.** 카탈로그에서 직접 추가하거나 Refactor → "Convert Strings to Symbols"를 명시적으로 돌려야 한다.

### 4.2 이름 공간은 카탈로그 파일이다

키 이름에 점을 넣어 이름 공간을 흉내 내지 않는다. **string table이 정식 이름 공간이고, table은 곧 `.xcstrings` 파일이다.**

| 파일 | 테이블 | 담는 것 |
|---|---|---|
| `Localizable.xcstrings` | 기본 | 공용 문구, **알림 문구 전부**(5.1절), 앱 시작 실패 화면(`AppStartupFailureView` 5개), 스플래시(`SplashView` 2개), `Theme.swift:120`의 접근성 라벨 |
| `Home.xcstrings` | `Home` | 홈·기록 화면 (`SmileHistoryView`는 `Views/Home/`에 있다) |
| `Onboarding.xcstrings` | `Onboarding` | 온보딩 |
| `Settings.xcstrings` | `Settings` | 설정·알림 문구 관리 |
| `Coaching.xcstrings` | `Coaching` | 가이드·실시간 확인 |
| `InfoPlist.xcstrings` | — | 4.4절 |

기본 테이블은 `.title`, 다른 테이블은 `.Home.title`로 참조된다. 테이블 간 키 충돌은 없다.

**알림 문구는 기본 테이블에 있어야 한다.** 5.1절이 쓰는 `NSString.localizedUserNotificationString(forKey:arguments:)`에는 테이블 파라미터가 없다.

### 4.3 CoachingKit에서 문구 25개를 걷어낸다 — 취향이 아니라 강제다

**SwiftPM은 `.xcstrings`를 컴파일하지 못한다.** 실측: 스크래치 패키지에 카탈로그를 리소스로 넣으면 `swift build`/`swift test`는 통과하지만, SwiftPM이 카탈로그를 `.lproj/*.strings`로 컴파일하지 않고 **그대로 복사만** 한다. 결과적으로 `String(localized:bundle:.module)`이 **조용히 키 문자열을 반환한다.** 크래시도 경고도 없고 테스트는 초록색이다 — 빌드가 깨지는 것보다 나쁘다. CLAUDE.md가 규정한 CoachingKit 검증 명령이 `cd CoachingKit && swift test`이므로 이 침묵 실패를 잡을 방법도 없다. 나중에 "CoachingKit에 그냥 두는 게 낫지 않나"로 되돌리려는 사람은 이 문단을 먼저 반박해야 한다.

추가로 패키지의 `Bundle.module`은 자체 폴백 체인을 갖고 앱 타깃의 언어 해석과 합쳐지지 않는다 — 언어 결정이 두 벌이 된다.

| 대상 | 개수 | 처리 |
|---|---|---|
| `SmileCueCatalog` | 8 | `SmileCue`에서 `text` 제거. `id`와 배열 순서는 유지(`SmileCueCursorStore`가 순환에 쓴다). 구조체는 남긴다 |
| `ReminderMessageCatalog` | 8 | `text`를 옵셔널로 (5.2절) |
| `ReminderNotificationAction.title` | 2 | 앱 타깃으로. 카테고리를 등록하는 `AppDelegate`가 이미 앱 타깃이다 |
| `ReminderMessageViewModel.errorMessage` | 4 | 오류 `enum`으로 |
| `SmileReminderScheduleViewModel` 오류 문구 | 2 | 오류 `enum`으로 |
| `SmileReminderScheduleViewModel.invalidPatternMessage` | 1 | **오류가 아니라 검증 상태다** — `patternIsValid: Bool`로 노출하고 문구는 뷰가 든다 |

```swift
public enum ReminderMessageError: Equatable, Sendable {
    case empty
    case tooLong(limit: Int)
    case duplicate
    case lastRemaining
}
```

**`SmileCue.text` 제거로 깨지는 곳 전수** (검토에서 실측):

```
컴파일 에러
  SmileDay/Views/Coaching/SmileGuideView.swift:67          Text(cue.text)
  CoachingKit/Tests/CoachingKitTests/SmileCueTests.swift:11, 13, 19
  CoachingKit/Tests/CoachingKitTests/ReminderMessageTests.swift:51   add(text: only.text) — String? 전달

컴파일 되지만 런타임 실패
  ReminderMessageTests.swift:12    Set(messages.map(\.text)) — 전부 nil이면 크기 1 ≠ 8

오류 enum 전환으로 같이 바뀌는 호출부
  ReminderMessageManagementView.swift:75 (validationMessage 클로저 — String? 브릿지), :99, :107
  SmileMVPSettingsView.swift:59-60, :64
  SmileMVPOnboardingView.swift:134-135, :140
  ReminderMessageTests.swift:49, 52, 55 / SmileReminderScheduleViewModelTests.swift:195  한국어 단언 → enum 단언
```

주석은 한국어로 남긴다. 개발자를 위한 글이고 사용자에게 보이지 않는다.

### 4.4 Info.plist와 앱 이름

**`INFOPLIST_KEY_NSCameraUsageDescription`을 빌드 세팅에서 지우면 안 된다.** 이 프로젝트는 `GENERATE_INFOPLIST_FILE = YES`이고(`project.pbxproj:268, 302`) `Info.plist` 파일이 없다 — 모든 키가 빌드 세팅에서 생성된다. `InfoPlist.xcstrings`는 **이미 존재하는 키의 값을 런타임에 덮어쓸 뿐 키를 만들지 못하므로**, 빌드 세팅을 지우면 생성된 Info.plist에 키 자체가 없어진다. 결과는 App Store Connect 업로드 거부(`ITMS-90683`)와 `ARSession` 시작 시 앱 종료 — 실시간 미소 확인 전체가 죽는다.

처리: **빌드 세팅은 유지하되 값을 영어로 교체**하고(소스 언어가 영어이므로), `InfoPlist.xcstrings`에 `NSCameraUsageDescription` 키를 두어 `ko`에 현재 한국어 문구를 그대로 담는다.

검증: 빌드 후 `plutil -p <app>/Info.plist | grep NSCamera` — 키가 있어야 한다. 그리고 한국어·영어 기기 각각에서 권한 대화상자 문구 확인.

**앱 이름 — A안으로 확정.** 지금은 `CFBundleDisplayName`이 없어 홈 화면 아이콘이 두 언어 모두 "SmileDay"(`PRODUCT_NAME`)인데 알림 제목은 "스마일데이"다 — 불일치가 이미 있다. 언어별로 통일한다:

| | 홈 화면 아이콘 | 알림 제목 |
|---|---|---|
| 한국어 | 스마일데이 | 스마일데이 (현행 유지) |
| 영어 | SmileDay | SmileDay |

- `INFOPLIST_KEY_CFBundleDisplayName = "SmileDay"`를 빌드 세팅에 추가하고(키를 만들기 위해 — 위와 같은 이유), `InfoPlist.xcstrings`의 `ko`에 "스마일데이"를 담는다.
- 알림 제목은 5.1절의 지연 해석 키(`ko` = "스마일데이", `en` = "SmileDay")로 간다.
- **기존 한국 사용자의 홈 화면 아이콘 이름이 "SmileDay" → "스마일데이"로 바뀐다. 의도된 변화이고**, 10절 "한국어 기기에서 모든 화면이 오늘과 동일" 기준의 명시적 예외다.

### 4.5 문구 보증을 카탈로그 검사로 옮긴다

앱 타깃에는 **테스트 타깃이 없다**(`project.pbxproj`에 `PBXNativeTarget`이 application 하나뿐). 문구 25개를 CoachingKit 밖으로 내보내면 다음 보증이 대체 없이 사라진다:

- `SmileCueTests.swift:9-15` — 한국어 금지어 + 공백 검사
- `SmileCueTests.swift:18-20` — "떠오르는 장면이 없어도 괜찮아요"가 존재해야 한다는 제품 불변식
- `ReminderMessageTests.swift:14-20` — 한국어 금지어
- `ReminderNotificationActionTests.swift:42-63` — 버튼 문구 비어있지 않음 + 금지어

**해법: `.xcstrings`는 그냥 JSON이다.** CoachingKit 테스트가 `#filePath` 기준 상대 경로로 앱 타깃의 카탈로그 파일을 읽어 파싱한다 — 번들 리소스가 아니므로 4.3절의 SPM 제약을 타지 않고, macOS `swift test`에서 그대로 돈다. 한 테스트 파일에서 검사한다:

1. `ko` 값의 한국어 금지어 (기존 목록)
2. `en` 값의 영어 금지어 (2절 목록) — **새 보증**
3. 모든 키에 `ko`·`en` 값이 비어 있지 않음
4. `SmileCueCatalog.all.map(\.id)`·`ReminderMessageCatalog.defaults.map(\.id)` 전부에 대응 키 존재 — id는 CoachingKit, 문구는 앱 타깃으로 갈라진 뒤 어긋남을 잡는 유일한 장치
5. 기본 알림 문구 8개의 `en` 값이 서로 다름 (5.2절 중복 검사의 전제)
6. `ko` 값 어딘가에 "떠오르는 장면이 없어도 괜찮아요"가 존재 (제품 불변식 이전)

## 5. 살아있는 데이터

### 5.1 알림 — 배달 시점에 해석시킨다

`UNCalendarNotificationTrigger(repeats: true)`로 예약한 알림의 텍스트는 예약 시점에 확정되어 기기에 남는다. 언어가 바뀌어도 이미 예약된 알림은 바뀌지 않는다.

**언어를 감지해서 재예약하지 않는다.** `NSString.localizedUserNotificationString(forKey:arguments:)`는 키를 들고 있다가 **알림이 표시되기 직전에** 현재 언어로 해석한다. iOS 10+, deprecated 아님(iOS 26.5 SDK 헤더 확인). `UNNotificationContent`의 title·subtitle·body와 `UNNotificationAction` 버튼 문구가 명시된 적용 대상이다.

```swift
// UserNotificationReminderScheduler.scheduleDailyPattern 안
content.title = NSString.localizedUserNotificationString(
    forKey: "notificationAppName", arguments: nil        // ko "스마일데이" / en "SmileDay" (4.4절)
)

let message = availableMessages[index % availableMessages.count]
content.body = message.text                               // 사용자가 쓴 문구 → 평문 그대로, 영원히 번역 안 함
    ?? NSString.localizedUserNotificationString(          // 기본 문구 → 키로 지연 해석
        forKey: "reminderMessage.\(message.id)", arguments: nil
    )
```

`message.id`는 이미 안정 식별자다(`"gentle-five-seconds"` 등). 이 분기는 5.2절의 옵셔널 설계에 **의존한다** — 둘은 한 묶음이다.

**키 문자열이 영구 호환 계약이 된다.** 오늘 예약된 반복 알림이 `"reminderMessage.gentle-five-seconds"`를 기기에 들고 남는다. 나중에 그 키를 카탈로그에서 지우거나 이름을 바꾸면 잠금화면에 날 키가 그대로 뜬다. `ReminderNotificationAction`·`ReminderNotificationCategory.identifier`가 이미 같은 종류의 계약을 문서화하고 있다 — 같은 자리에 같은 톤으로 적는다.

**착수 전 최우선 확인**: String Catalog는 빌드 시 `.strings`로 컴파일되므로 이 API가 카탈로그 키를 찾을 것으로 본다 — **추정이다. 1단계 첫 작업으로 실기기에서 확인한다.** 실패하면 이 절을 재예약 설계로 되돌려야 하고 그 비용이 크므로, 다른 작업보다 먼저 확정한다.

**남는 것은 1회 마이그레이션 하나.** 옛 빌드가 기기에 굳혀둔 평문 알림은 이 API로 바꿔도 그대로다. 업데이트 후 한 번 다시 예약한다. **`ReminderActionBackfill.swift`의 형제로 만들어 `RootView.swift:60` 옆에 둔다** — 같은 종류의 1회 마이그레이션이 이미 있고 테스트가 8개 있다. 그 파일의 규칙을 그대로 따른다:

- 순서: 새 `groupID`로 전부 등록 → 저장값 교체 → **마지막에** 옛 그룹 취소. 같은 identifier를 덮어쓰다 실패하면 부분 등록 롤백이 기존 요청까지 지운다(`ReminderActionBackfill.swift:29-30`의 주석이 문서화한 위험).
- 실패 시 플래그를 남기지 않고 다음 실행에 재시도. 예약이 없으면 플래그만 찍고 끝(신규 설치가 불필요한 재예약을 도는 것을 막는다).
- `SmileHomeViewModel`에 두지 않는다 — 거기엔 `messageStore`도 `groupIDFactory`도 없고, `messages: []`를 넘기면 scheduler가 기본값으로 치환해 **컴파일도 예약도 성공하면서 사용자가 편집한 문구만 조용히 사라진다.**

**앱을 열지 않고 알림의 "웃었어요"만 누르는 사용자**는 백그라운드로만 깨어나 `RootView`가 그려지지 않으므로 이 마이그레이션이 다음 포그라운드 실행까지 미뤄진다. 받아들인다 — 그동안 알림은 지금과 똑같은 한국어 평문이다. 회귀가 아니다.

### 5.2 `ReminderMessage`

사용자가 편집할 수 있고 `UserDefaults`에 **id가 아니라 텍스트로** 저장된다. 한 항목만 고쳐도 기본 8개가 통째로 그 시점 언어로 굳는다.

```swift
public struct ReminderMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    /// nil이면 기본 문구 — 표시·예약 시점에 id로 해석한다. 값이 있으면 사용자가 직접 쓴 문구다.
    public var text: String?
}
```

**Codable 호환은 실측됐다.** 합성 `Decodable`은 옵셔널에 `decodeIfPresent`를 쓰므로 기존 JSON(`text` 있음)은 그대로 디코딩된다. 반대로 `text: nil`을 인코딩하면 키가 생략되어 **구버전 빌드는 그 JSON을 디코딩하지 못한다** — 그리고 `UserDefaultsReminderMessageStore.messages`의 getter가 `try?`로 실패를 삼키고 기본값을 돌려주므로, 구버전이 그 데이터를 읽는 순간 사용자가 쓴 문구가 조용히 사라진다.

**그래서 저장 키를 올린다: `reminderMessages.v1` → `reminderMessages.v2`. v1은 건드리지 않는다.** 신 버전은 v2가 없으면 **매 읽기마다** v1을 읽어 승격한 값을 돌려주고, v2는 **다음 저장(추가·수정·삭제·순서 변경) 시점에** 처음 쓴다 — 읽기만으로는 v2가 생기지 않는다. 한 번도 편집하지 않는 사용자는 v1이 계속 원본이므로, 앞으로 v3를 만들 때 v2가 있다고 가정하면 안 된다. 구버전(TestFlight 병행 설치, 백업 복원, 심사자의 구버전 검증)은 v1을 온전히 본다.

**승격 규칙:**

> 항목의 id가 기본 카탈로그에 있고, text가 **1.x가 출하한 한국어 원문**과 정확히 같으면 → `text = nil`

- **비교값은 CoachingKit 안의 동결된 한국어 상수 테이블이다** (`private static let legacyKoreanDefaults: [String: String]` — id → 1.x 원문 8개). **카탈로그를 조회하면 안 된다** — 카탈로그는 현재 언어로 해석되므로 영어 기기에서 영어가 나와 영원히 불일치하고, 기본 문구 8개가 "사용자 문구"로 굳어 **영어 기기에서 영영 한국어 알림이 온다.** 그 사용자가 정확히 이 절이 존재하는 이유다. 마이그레이션 데이터는 역사적 사실이지 지역화 대상이 아니다.
- **1회성 플래그로 게이트하지 않는다. v1을 읽을 때마다 적용하는 순수 함수다** — 멱등이고, 백업 복원으로 옛 v1이 되살아나도 다시 돈다. 비용은 문자열 비교 8회다.
- 순서: 승격이 5.1절의 1회 마이그레이션보다 **먼저** 돈다. 아니면 재예약이 옛 한국어를 새 요청에 다시 굳힌다.

**받아들이는 허점** (문자열만으로 의도를 구분할 수 없다):

| 시나리오 | 결과 |
|---|---|
| 기본 문구를 지웠다가 똑같이 다시 입력 | 새 UUID id라 승격 안 됨 → 그 항목만 한국어로 남는다 |
| 고쳤다가 원문으로 되돌림 | 승격됨 → 번역을 따라간다 |
| 순서만 바꿈 | 정상 승격 (id·text 보존 확인됨) |

**편집 화면의 함정 둘을 같이 고친다:**

- `ReminderMessageManagementView`에서 기본 문구를 탭해 열고 **고치지 않고 저장만 눌러도** `update(id:text:)`가 무조건 `text`를 쓴다 → 그 항목이 현재 언어 평문으로 영구히 굳는다. `update`가 입력값을 해석된 기본값과 비교해 같으면 `text = nil`로 되돌린다.
- 중복 검사(`validated`)는 CoachingKit 안이라 해석을 직접 할 수 없다(4.3절). **`ReminderMessageViewModel.init`에 `resolve: (ReminderMessage) -> String`을 주입한다.** 앱은 카탈로그 해석 클로저를, 테스트는 항등 함수를 넘긴다. 중복·글자수(100자 — 영어 기본 문구가 넘지 않는지 4.5절 검사에 포함) 검증이 전부 해석된 텍스트 기준이 된다.

### 5.3 `ReminderScheduleApplier`를 뽑는다

`SmileReminderScheduleViewModel.save():223-268`은 단순 재예약이 아니라 4단계 트랜잭션이다 — 새 그룹 등록 → 저장 → 실패 시 롤백 → 옛 그룹·레거시 ID 취소. 호출자가 셋이 된다: 설정 저장, 문구 변경, 5.1절의 1회 마이그레이션. **이 앱에서 가장 위험한 코드의 사본을 세 벌 두지 않는다.** CoachingKit에 `ReminderScheduleApplier`로 뽑고 셋이 공유한다.

### 5.4 손대지 않는 것

`SmileMoment.guideID`, `SmileGuideCatalog.default.id` (`"anytime-soft"`), 알림 identifier 형식, `ReminderNotificationPayload`의 키는 전부 식별자라 언어와 무관하다. SwiftData 스키마는 바꾸지 않는다.

## 6. 로케일에 의존하는 UI

### 6.1 계산과 표시에 같은 캘린더를 쓴다

`SmileHistoryView`는 격자 계산에 자기 `Calendar(identifier: .gregorian)`을 쓰지만(`:14-20`), **`date.formatted(.dateTime...)`는 그 캘린더를 참조하지 않는다** — 포맷 스타일 자신의 캘린더(기본값 current)를 쓴다. 기기 캘린더를 이슬람력·히브리력으로 설정한 사용자는 헤더의 월 이름과 격자가 서로 다른 달을 가리킨다.

수정:

1. `SmileDayApp`에서 지우는 `.environment(\.locale, ko_KR)` 자리에 그레고리력 + 현재 로케일의 캘린더를 `.environment(\.calendar, ...)`로 한 번 둔다. **실측: `Calendar(identifier: .gregorian)`에 locale을 대입하면 `firstWeekday`가 따라온다** (en_GB·fr_FR → 2, ko_KR·en_US → 1) — 별도 설정이 필요 없다.
2. `SmileHistoryView:14-20`이 자기 캘린더를 만드는 대신 `@Environment(\.calendar)`를 읽는다.
3. 아래 8곳을 `Text(x.formatted(.dateTime...))` → `Text(x, format: .dateTime...)`로 바꾼다. **이 형태만 환경의 locale·calendar를 상속한다.**

```
SmileHistoryView.swift:74, 137, 207, 225      헤더·선택일·날짜 셀·접근성 라벨
SmileMVPHomeView.swift:262, 380, 387          다음 알림 시각·요일·접근성 라벨
Theme.swift:126                                SDFormat.koreanLocale 정의부 — 삭제
```

### 6.2 달력 격자 — 일요일 시작 가정과 `ForEach` id 충돌

| 줄 | 지금 | 고칠 것 |
|---|---|---|
| `SmileHistoryView:18` | `value.firstWeekday = 1` | 삭제 — 환경 캘린더가 로케일에서 가져온다(6.1 실측) |
| `SmileHistoryView:108` | `ForEach(["일",…,"토"], id: \.self)` | 아래 참조 |
| `SmileHistoryView:158` | `component(.weekday, …) - 1` | `(weekday - calendar.firstWeekday + 7) % 7` |

**`:108`은 배열 교체만으로 안 된다.** `veryShortWeekdaySymbols`는 항상 일요일부터 오므로 `firstWeekday - 1`만큼 회전시키는 것까지는 맞는데, 실측하면 **영어는 `["S","M","T","W","T","F","S"]`로 "S"·"T"가 겹치고 프랑스어는 "M"이 겹친다.** `id: \.self`에 중복 id가 들어가면 SwiftUI가 열을 빠뜨려 7열 격자가 5열로 그려지고 날짜 전체가 어긋난다. 한국어(전부 다름)에서는 절대 재현되지 않는다.

```swift
ForEach(Array(rotatedSymbols.enumerated()), id: \.offset) { _, symbol in
```

### 6.3 숫자·시간·퍼센트는 복수 문제가 아니라 포맷 문제다

**손으로 짠 duration 포매터 셋을 지운다.** `Duration.UnitsFormatStyle`이 로케일별로 맞게 그리고 복수도 처리한다.

```
SmileMVPSettingsView.intervalLabel(_:)         "\(minutes)분 \(remainder)초"
SmileMVPOnboardingView.intervalLabel(_:)       "\(minutes)분마다" / "\(minutes / 60)시간마다"
LiveSmileSessionSummaryView:146-147            같은 계산 세 번째
```

**퍼센트 두 곳을 `.formatted(.percent)`로 바꾼다** (`LiveSmileSessionSummaryView:95, 103`). 로케일마다 기호 위치와 공백이 달라 `"\(Int(...))%"`는 i18n상 틀린 코드다. 덤으로 Xcode 26에는 리터럴 `%`가 오파싱되어 빌드를 깨는 미해결 버그가 있고(포럼 792268) 이 두 줄이 정확히 그 모양이다.

`"\(count)"` 보간은 그룹 구분자를 넣지 않는다 → `count.formatted()`. `LiveSmileMonitorView:343`의 `"\(count)단계 중 \(filled)단계"`는 복수 항목이 아니다("Step 2 of 5").

### 6.4 진짜 복수 규칙

| 파일 | 문구 |
|---|---|
| `SmileMVPHomeView:162, 171, 334, 387` | `"\(count)번"`, `"오늘 미소 \(count)번"`, `"총 \(totalCount)번"` |
| `SmileHistoryView:96, 98, 148, 210, 225` | `"\(count)번"`, `"\(activeDayCount)일"` |
| `SmileMVPOnboardingView:258` | `"하루 \(count)번 알려드려요"` |
| `SmileGuideView:96, 114` | `"\(duration)초 동안 함께 있어요"`, `"\(remainingSeconds)초 남았어요"` |
| `SmileMVPSettingsView:94` | `"\(count)개"` |

카탈로그에서 해당 인자에 Vary by Plural을 적용한다. 심볼은 함수 형태(`.todaySmileCount(count:)`)로 생성된다.

**접근성 라벨의 덫:** `.accessibilityLabel("\(date...) \(count)번")` 같은 보간 리터럴은 `LocalizedStringKey` 오버로드로 잡혀 `%@ %lld번` 꼴 키로 자동 추출된다. 심볼 키로 갈지 명시적 `String(localized:)`로 갈지 정해 통일한다. `LiveSmileMonitorView:340`의 `accessibilityValue`도 대상이다.

### 6.5 레이아웃 검증

**Double-Length Pseudolanguage는 이 코드베이스에 맞는 도구가 아니다.** 잘림을 찾는 도구인데 `lineLimit`도 `minimumScaleFactor`도 하나도 없어 아무것도 안 잘리고 전부 줄바꿈된다. 실제 실패 모드는 세로 오버플로와 3줄 버튼이다.

**맞는 검증: `.dynamicTypeSize(.accessibility5)` + 영어 + SE 화면.** 특히 `SmileHistoryView:95-99`의 `HStack` + `Divider` 통계 두 칸과 홈의 같은 패턴.

## 7. 앱 밖

### 7.1 App Store 영어 현지화

한국어 페이지는 그대로 두고 영어 현지화를 추가한다. 결과는 `docs/marketing/2026-08-05-app-store-metadata-ko.md`와 짝이 되는 `-en.md`로 남긴다.

| 필드 | 처리 |
|---|---|
| 앱 이름 | `SmileDay`. 동명 앱이 있는지 먼저 확인 |
| 부제 (30자) | 한국어판에 없다. 검색 가중치가 붙는 자리라 영어판에 넣는다 |
| 프로모션 텍스트·설명 | 번역. 2절 위험 단어 확인 |
| 키워드 (100자) | **번역이 아니라 재설계**. `smile reminder`, `daily reminder`, `mood tracker`, `self care`, `mindfulness`, `habit tracker` 계열에서 이 앱이 실제로 하는 일과 겹치는 것만 |
| 스크린샷 4장 | 영어 시뮬레이터로 재촬영. 기록 데이터가 있는 상태가 필요하다 |
| What's New | 두 언어 모두 |
| **Primary Language** | **영어로 변경을 검토한다.** 앱 폴백을 영어로 바꾸는 3절의 논리가 스토어에도 적용된다 — 한국어로 남으면 현지화 없는 스토어프론트(독일 등) 사용자가 앱은 영어인데 스토어 페이지는 한국어를 본다. 한국 스토어에는 ko 현지화가 그대로 보이므로 기존 노출에 영향 없다 |

**판매 지역 개방은 이 설계의 범위 밖이다.** 영어 지원과 별개 결정이고 세금·법적 서식과 지원 못 하는 시장 노출이 걸린다.

`docs/reports/2026-08-07-app-review-truedepth-response.md`에 TrueDepth 관련 심사 응답 이력이 있다. 영어 설명도 같은 논리를 그대로 옮긴다 — 선택형이고, 프레임을 읽지 않고, 아무것도 저장하지 않는다.

### 7.2 정책·지원 페이지

앱 안 URL(`dolparo.com/smileday/privacy`, `/support`)은 각각 하나뿐이라 영어 사용자가 눌러도 한국어 페이지가 열린다. **한 페이지에 두 언어를 담는다** — 본문에 영어를 함께 둔다. 앱 코드의 URL은 번역 대상이 아니게 되고 관리할 주소도 늘지 않는다. 이 설계에서 코드로 끝낼 수 없는 유일한 항목이다.

## 8. 하지 않는 것

- 앱 안 언어 선택 화면 (3절)
- 영어 외의 언어. 구조는 열어두되 이번에 번역하지 않는다
- 사용자가 직접 쓴 알림 문구의 번역 (5.2절)
- 영어 전용 별도 앱이나 별도 브랜치
- 한국어 문구 수정 (2절 — 예외는 4.4절 앱 이름뿐)
- SwiftData 스키마 변경 (5.4절)
- 판매 지역 개방 (7.1절)
- **RTL 대응.** 코드베이스에 `.left`/`.right`가 없고 전부 `.leading`/`.trailing`이라 이미 대응돼 있다
- **타이포그래피 조정.** 커스텀 폰트 0, `lineSpacing`/`kerning`/`tracking` 0
- **위젯 지역화.** `2026-08-11-smile-face-widget-design.md`의 위젯은 텍스트를 렌더하지 않으므로 지역화 대상이 갤러리 설명과 접근성 라벨뿐이다. 위젯은 별도 번들이라 자기 카탈로그가 필요하다 — **위젯을 만들 때 같이 한다**

## 9. 작업 순서

**구조 먼저, 문구는 다음.** 두 단계를 **한 브랜치에서 하고 한 번에 머지한다.**

**0단계 — 전제 확인 (첫 작업).** `localizedUserNotificationString(forKey:)`가 String Catalog 키를 배달 시점에 해석하는지 실기기로 확인한다. 실패하면 5.1절을 재예약 설계로 되돌려야 하므로 다른 어떤 작업보다 먼저다.

**1단계 — 배관.** String Catalog 배치, CoachingKit 문구 이동 + 4.5절 카탈로그 검사 테스트, 알림 지연 해석 + 1회 마이그레이션 + `ReminderScheduleApplier` 추출, 5.2절 저장 v2 + 승격, 캘린더·포맷·복수 규칙. 검증 목표: **한국어 앱이 오늘과 완전히 같게 동작한다** (예외: 4.4절 앱 이름).

**1단계에서 `en` 열을 기계적으로 채운다.** deck에 있는 40개는 deck 문구로, 나머지는 **한국어 문자열을 그대로** 넣고, 전 항목의 번역 상태를 `needsReview`로 표시한다.

- 어떤 빌드도 키 문자열을 노출하지 않는다. 최악이 영어 기기에서 한국어인데 그건 정확히 오늘의 상태다 — 회귀가 아니다.
- 키가 화면에 뜨면 그건 정상 상태가 아니라 **오타다.** 1단계 내내 즉시 발견된다.
- 2단계 완료 게이트가 기계 검증 가능해진다(10절).

**2단계 — 문구.** deck의 40개를 톤 기준으로 삼아 나머지 약 160개를 쓴다. deck이 덮지 않는 것: 실시간 확인 상세 문구, 오류·복구 문구, 설정 화면 전체, 알림 권한 안내, 접근성 라벨, 데이터 저장 위치 섹션. App Store 페이지(7.1)와 정책 페이지(7.2)도 여기서 간다.

## 10. 완료 기준

**기계 검증** (CI 없이도 명령 한 줄로 확인 가능한 것)

- 한국어 이전 검증: 이동 전 Swift 리터럴에서 추출한 한국어 목록과 카탈로그의 `ko` 값 전체가 `diff`로 일치한다. 오타·공백 하나가 조용한 회귀이자 승격 실패 원인이므로 훑기가 아니라 diff로 확인한다.
- 전 카탈로그(JSON)에서 `en`·`ko` 값이 비었거나 상태가 `new`/`needsReview`인 항목이 0개다 (`jq`) — 2단계 종료 게이트. "한국어가 안 보인다"는 기준은 빈 카탈로그(키 노출)도 통과시키므로 쓰지 않는다.
- 4.5절 카탈로그 검사 테스트가 `swift test`에서 통과한다 (금지어 한/영, 값 누락, id 대응, 영어 기본 문구 8개 상호 중복 없음·100자 이내, 제품 불변식).
- CoachingKit의 public API 중 표시용 `String`을 반환하는 것이 0개다. "한글 문자열 0개" 기준은 `"Smile!"` 같은 영문 표시 문자열을 못 잡으므로 타입 수준으로 검사한다.
- `cd CoachingKit && swift test` 통과 (`Test Suite 'All tests' passed` 확인).
- `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build` 통과.
- 빌드 산출물의 `Info.plist`에 `NSCameraUsageDescription`·`CFBundleDisplayName` 키가 존재한다 (`plutil`).

**회귀 없음**

- 한국어 기기에서 모든 화면이 오늘과 동일하다. 예외는 홈 화면 아이콘 이름 "SmileDay" → "스마일데이" 하나다(4.4절, 의도).
- 구버전 `reminderMessages.v1`을 심은 상태에서: 기록·스케줄·편집한 문구가 그대로 남고, 손대지 않은 기본 문구는 `text = nil`로 승격되며, v1 데이터가 원본 그대로 남아 있다.
- 승격이 알림 마이그레이션보다 먼저 돈다.
- 기본 문구를 편집 화면에서 열고 저장만 눌러도 `text`가 굳지 않는다.

**영어**

- 영어 기기에서 한국어가 보이지 않는다 — 온보딩, 홈, 가이드, 기록, 설정, 알림 문구 관리, 실시간 확인, 세션 요약, 오류 화면, 알림 권한 안내.
- 카메라 권한 대화상자가 영어로 뜬다.
- 잠금화면 알림의 제목·본문·버튼 두 개가 영어로 뜬다.
- **기기 언어를 바꾸면 재예약 없이 다음 알림부터 새 언어로 나온다** (0단계 전제의 최종 확인).
- 사용자가 편집한 알림 문구는 언어를 바꿔도 그대로 남는다.

**로케일**

- 선호 언어에 영어가 없는 프랑스어 기기에서 앱이 영어로 뜬다. 날짜가 프랑스식인 것은 의도다(3절).
- 영국 지역에서 달력이 월요일 시작이고, **영어 요일 머리글(S·T 중복)에서 7열이 전부 그려진다**(6.2절).
- 24시간제 지역에서 알림 시각이 24시간제로 표시된다.
- 기기 캘린더를 불기로 바꿨을 때 격자와 헤더가 같은 달을 가리킨다.

**레이아웃**

- `.accessibility5` + 영어 + SE 화면에서 세로 오버플로가 없다.

**스토어**

- 영어 페이지의 이름·부제·설명·키워드·스크린샷·What's New가 채워져 있다.
- 설명과 부제에 2절의 위험 단어가 없다.
- 정책·지원 페이지를 영어로 읽을 수 있다.

## 11. 미확인 항목

- ~~0단계~~ **실측 통과 (2026-08-15, 계획 Task 1).** String Catalog 키(`probeDeliveryTime`)를 지연 해석 키로 넣은 알림이 시뮬레이터에서 한국어일 때 "탐침-KO", 같은 페이로드를 English로 전환 후 보내면 "PROBE-EN"으로 표시됐다 — 표시 시점 언어를 따른다. (`simctl push`의 `title-loc-key` 경로로 확인; 로컬 알림의 `localizedUserNotificationString`도 같은 `titleLocalizationKey` 경로다. 최종 검증(Task 14)에서 실기기로 한 번 더 본다.)
- ~~심볼 이름 변환 규칙~~ **실측 확정 (계획 Task 8).** `Settings.xcstrings`의 `messageError.tooLong`(값에 `%lld`) → `.Settings.messageErrorTooLong(_:)`, `scheduleError.schedulingFailed` → `.Settings.scheduleErrorSchedulingFailed`. 점 제거 + 세그먼트 camelCase, 플레이스홀더가 있으면 함수. 빌드 통과로 확인.
- 같은 테이블 안에서 두 키가 sanitize 후 같은 Swift 심볼로 뭉칠 때 Xcode의 처리 (에러/경고/접미사) — 아직 미확인. 그런 키 쌍을 만들지 않으면 문제없다.
