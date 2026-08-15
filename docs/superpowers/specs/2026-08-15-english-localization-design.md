# 영어 지원 설계

- 날짜: 2026-08-15
- 상태: 승인됨 (2026-08-15 검토 반영으로 개정)
- 배경: 앱은 한국어 단일 언어로 빌드된다 (`developmentRegion = ko`, `knownRegions = (ko, Base)`). String Catalog도 `.strings`도 없고 사용자 문구 약 200개가 Swift 리터럴로 흩어져 있다. `SmileDayApp.swift:29`가 로케일을 `ko_KR`로 고정해 기기 언어를 무시한다. 이미 출시되어 실사용자가 있으므로 저장된 데이터와 기기에 예약된 알림을 깨지 않아야 한다.
- 선행 문서: `docs/english-copy-deck.md` (2026-07-31) — 톤 규칙과 문구 초안 약 40개. 이 설계는 그 문서의 "나중에 할 엔지니어링" 절을 실행 가능한 형태로 확정하되, **소스 언어에 대한 그 문서의 결정은 뒤집는다**(3절).

## 1. 목표

- 한 바이너리로 한국어와 영어를 모두 지원한다. 기기 언어에 따라 iOS가 고른다.
- 지원하지 않는 언어의 사용자는 한국어가 아니라 **영어**를 본다.
- 기존 한국어 사용자의 화면·기록·알림이 오늘과 동일하게 동작한다.
- App Store에 한국어 페이지 옆에 영어 페이지를 추가한다.

## 2. 제품 원칙

`docs/english-copy-deck.md`의 다섯 규칙을 영어 문구 전체에 적용한다.

1. 감정을 명령하지 않는다. `Let's!`가 아니라 조건절(`if you're up for it`).
2. 웃지 않은 날은 실패가 아니다. `You haven't…`, `Don't forget`, `streak`, `goal`, `missed` 금지.
3. 외모를 말하지 않는다. 칭찬도 평가다.
4. 과장하지 않는다. `Great job!`, `Amazing!`, 축하 이모지 금지.
5. 건강·미용 효과를 말하지 않는다 (App Store 1.4.1).

영어권 심사에서 더 직접적으로 걸리는 단어: `lift`, `tone`, `firm`, `anti-aging`, `rejuvenate`, `wrinkle`, `therapy`, `therapeutic`, `treatment`, `cure`, `heal`, `depression`, `anxiety`, `mood disorder`, `clinically`.

**영어화는 한국어 문구를 고치는 계기가 아니다.** 한국어 카피는 이번 작업에서 한 글자도 바꾸지 않는다.

## 3. 언어 결정과 폴백

- `developmentRegion = en`, `knownRegions = (en, ko, Base)`.
- `CFBundleDevelopmentRegion`은 표기가 아니라 **폴백 언어**다. iOS는 기기의 선호 언어 목록을 1순위부터 훑고(`en-GB` → `en` 같은 방언→일반 폴백 포함), **전부 안 맞을 때만** 이 값의 지역화를 고른다.
  - 따라서 실제 대상은 "프랑스어 기기" 전부가 아니라 **선호 언어에 영어가 없는 기기**다. 프랑스어 1순위·영어 2순위 기기는 `ko`로 둬도 영어를 본다.
  - 그런 기기가 소수라도 한국어를 보여주는 것보다 영어를 보여주는 게 낫고, Apple 문서상 이걸 바꾸는 다른 손잡이는 없다. `CFBundleAllowMixedLocalizations`는 무관하고(한 번들이 여러 `.lproj`에서 리소스를 섞어 가져올지만 제어) Base Internationalization도 폴백 규칙을 바꾸지 않는다.
- 출시된 앱에서 이 값을 바꾸는 것은 안전하다. 앱 바이너리의 development region과 App Store Connect의 Primary Language는 별개 시스템이다. 기존 한국어 사용자는 `ko` 지역화가 그대로 매치되므로 폴백이 발동하지 않는다.
- String Catalog의 소스 언어가 영어가 되고 한국어가 번역 열로 내려간다. **`english-copy-deck.md`는 "한국어가 소스 언어다"라고 적어뒀고, 이 설계는 그 결정을 뒤집는다.** 폴백이 소스 언어에 묶여 있어 둘을 따로 고를 수 없기 때문이다.
- **이 값은 1단계 시작 시점에 바꾼다.** 나중에 뒤집으려면 pbxproj뿐 아니라 카탈로그의 소스 언어까지 Xcode에서 손으로 옮겨야 하고, 그 시점엔 항목이 200개다.
- `SmileDayApp.swift:29`의 `.environment(\.locale, Locale(identifier: "ko_KR"))`를 제거한다.
- **앱 안에 언어 선택 화면을 만들지 않는다.** iOS 13+는 두 개 이상의 지역화를 담은 앱에 설정 앱 → SmileDay → 언어 항목을 자동으로 만든다. 직접 만들면 두 곳이 되어 서로 어긋난다.

기기를 영어로 쓰는 기존 한국 사용자는 업데이트 후 앱이 영어로 바뀐다. iOS 표준 동작이며 설정 앱에서 앱만 한국어로 되돌릴 수 있다.

## 4. 문자열 배치

### 4.1 카탈로그가 키의 출처다

**규율: 문구는 String Catalog에서 만들고, 코드는 생성된 심볼로만 참조한다. 코드에 키 리터럴을 쓰지 않는다.**

프로젝트에 `STRING_CATALOG_GENERATE_SYMBOLS = YES`가 이미 켜져 있고(`project.pbxproj:282, 316`) 설치된 Xcode는 26.6이다. 카탈로그에서 직접 추가한 키는 타입 안전한 Swift 심볼이 자동 생성된다 — 값이 없는 문구는 `static var`, 플레이스홀더가 있는 문구는 이름 붙은 파라미터를 가진 함수. 타입은 `LocalizedStringResource`(iOS 16+ 요구, 이 앱은 17+라 무관)다.

```swift
Text(.todayCountTitle)                          // SwiftUI에 바로
String(localized: .todayCountTitle)             // String이 필요한 자리
```

**Swift 래퍼 계층을 만들지 않는다.** `SharedStrings` 같은 `enum`에 `String` 계산 프로퍼티 200개를 손으로 쓰는 안은 노동량이 문제가 아니라 **오타가 조용히 실패**한다 — 키를 틀리면 키 문자열이 화면에 뜨고, 그건 9절 1단계의 정상 상태와 화면상 구별되지 않는다. 심볼을 쓰면 같은 오타가 빌드 실패가 된다.

`SharedStrings.swift`는 삭제한다. 호출부 84곳이 `SharedStrings.foo` → `.foo`로 바뀐다. 지금 뷰에 인라인으로 박힌 약 95개도 별도 Swift 프로퍼티로 승격하지 않고 카탈로그 키로 직행한다.

주의: 자동 추출된 키(소스의 문자열 리터럴에서 Xcode가 긁어온 것)는 심볼이 **생기지 않는다.** 카탈로그에서 직접 추가하거나 Refactor → "Convert Strings to Symbols"를 명시적으로 돌려야 한다.

### 4.2 이름 공간은 카탈로그 파일이다

키 이름에 점을 넣어 이름 공간을 흉내 내지 않는다. **string table이 정식 이름 공간이고, table은 곧 `.xcstrings` 파일이다.**

| 파일 | 테이블 | 담는 것 |
|---|---|---|
| `Localizable.xcstrings` | 기본 | 공용 문구, **알림 문구 전부**(5.1절) |
| `Home.xcstrings` | `Home` | 홈·기록 화면 |
| `Onboarding.xcstrings` | `Onboarding` | 온보딩 |
| `Settings.xcstrings` | `Settings` | 설정·알림 문구 관리 |
| `Coaching.xcstrings` | `Coaching` | 가이드·실시간 확인 |
| `InfoPlist.xcstrings` | — | `NSCameraUsageDescription` (4.4절) |

기본 테이블은 `.title`, 다른 테이블은 `.Home.title`로 참조된다. 테이블 간 키 충돌은 없다.

**알림 문구는 기본 테이블에 있어야 한다.** 5.1절이 쓰는 `NSString.localizedUserNotificationString(forKey:arguments:)`에는 테이블 파라미터가 없다. → *미확인: 이 API의 테이블 지원 여부를 구현 시 확인하고, 지원한다면 알림 문구를 별도 테이블로 옮겨도 된다.*

### 4.3 CoachingKit에서 문구 25개를 걷어낸다 — 취향이 아니라 강제다

**`.xcstrings`를 SPM 타깃에 넣으면 `swift build`/`swift test`가 깨진다** (SwiftPM #6993 — `Bundle.module` 미생성). CLAUDE.md가 규정한 CoachingKit 검증 명령이 정확히 `cd CoachingKit && swift test`이므로, 패키지에 카탈로그를 두는 안은 이 프로젝트의 테스트를 못 돌리게 만든다.

추가로 패키지의 `Bundle.module`은 자체 폴백 체인을 갖고 앱 타깃의 언어 해석과 합쳐지지 않는다 — 언어 결정이 두 벌이 된다.

| 대상 | 개수 | 처리 |
|---|---|---|
| `SmileCueCatalog` | 8 | `SmileCue`에서 `text` 제거. `id`와 배열 순서는 유지(`SmileCueCursorStore`가 순환에 쓴다). 구조체는 남긴다 — `Identifiable` 공개 API라 없애면 호출부 churn이 더 크다 |
| `ReminderMessageCatalog` | 8 | `text`를 옵셔널로 (5.2절) |
| `ReminderNotificationAction.title` | 2 | 앱 타깃으로. 카테고리를 등록하는 `AppDelegate`가 이미 앱 타깃이다 |
| `ReminderMessageViewModel.errorMessage` | 4 | 오류 `enum`으로 |
| `SmileReminderScheduleViewModel` 오류 문구 | 2 | 오류 `enum`으로 |
| `SmileReminderScheduleViewModel.invalidPatternMessage` | 1 | **오류가 아니라 검증 상태다**(아래) |

```swift
public enum ReminderMessageError: Equatable, Sendable {
    case empty
    case tooLong(limit: Int)
    case duplicate
    case lastRemaining
}
```

`invalidPatternMessage`는 `public static let`이고 `SmileMVPOnboardingView:140`·`SmileMVPSettingsView:64`가 `save()`와 무관하게 직접 그린다. 오류 enum에 끼워넣지 말고 뷰모델에 `patternIsValid: Bool`을 노출하고 문구는 뷰가 든다.

**같이 고쳐야 할 호출부** — 설계 초안이 빠뜨렸던 목록:

```
SmileDay/Views/Settings/ReminderMessageManagementView.swift:75    validationMessage 클로저 (String? 브릿지 필요)
SmileDay/Views/Settings/ReminderMessageManagementView.swift:99, 107
SmileDay/Views/Settings/SmileMVPSettingsView.swift:59-60
SmileDay/Views/Onboarding/SmileMVPOnboardingView.swift:134-135
CoachingKit/Tests/CoachingKitTests/ReminderMessageTests.swift:49, 52, 55        한국어 단언 → enum 단언
CoachingKit/Tests/CoachingKitTests/SmileReminderScheduleViewModelTests.swift:195  같음
```

주석은 한국어로 남긴다. 개발자를 위한 글이고 사용자에게 보이지 않는다.

### 4.4 Info.plist

카메라 권한 설명은 지금 `project.pbxproj`의 `INFOPLIST_KEY_NSCameraUsageDescription`에 있다. **빌드 세팅에 있으면 번역되지 않으므로** `InfoPlist.xcstrings`로 옮기고 빌드 세팅에서 지운다.

**앱 표시 이름 — 결정 필요.** 프로젝트에 `INFOPLIST_KEY_CFBundleDisplayName`이 없고 `PRODUCT_NAME = $(TARGET_NAME)`이라 홈 화면 이름은 두 언어 모두 "SmileDay"다. 그런데 알림 제목은 `"스마일데이"`다 — **아이콘은 SmileDay, 알림은 스마일데이인 불일치가 오늘 이미 있다.** 둘 중 하나를 고른다:

- (a) 한국어에서 둘 다 "스마일데이" → `InfoPlist.xcstrings`에 `CFBundleDisplayName` 추가
- (b) 둘 다 "SmileDay" → 알림 제목을 바꾼다. 단 이건 한국어 문구 변경이라 2절과 충돌한다

## 5. 살아있는 데이터

### 5.1 알림 — 배달 시점에 해석시킨다

`UNCalendarNotificationTrigger(repeats: true)`로 예약한 알림의 텍스트는 예약 시점에 확정되어 기기에 남는다. 언어가 바뀌어도 이미 예약된 알림은 바뀌지 않는다.

**언어를 감지해서 재예약하지 않는다.** Apple이 그 일을 하는 API를 제공한다 — `NSString.localizedUserNotificationString(forKey:arguments:)`는 키를 들고 있다가 **알림이 표시되기 직전에** 현재 언어로 해석한다.

```swift
// UserNotificationReminderScheduler.scheduleDailyPattern 안
content.title = NSString.localizedUserNotificationString(
    forKey: "notification.appName", arguments: nil
)

let message = availableMessages[index % availableMessages.count]
content.body = message.text                                   // 사용자가 쓴 문구 → 평문 그대로
    ?? NSString.localizedUserNotificationString(               // 기본 문구 → 키로 지연 해석
        forKey: "reminder.message.\(message.id)", arguments: nil
    )
```

`message.id`는 이미 안정 식별자이고 UserDefaults에 저장돼 있다(`"gentle-five-seconds"` 등). 카탈로그 키로 그대로 쓴다.

이 분기는 5.2절의 옵셔널 설계에 **의존한다** — 둘은 한 묶음이다.

**남는 것은 1회 마이그레이션 하나.** 옛 빌드가 기기에 굳혀둔 평문 알림은 이 API로 바꿔도 그대로다. 업데이트 후 한 번 다시 예약해야 한다. 언어 감지가 아니라 플래그 하나다.

**`ReminderActionBackfill.swift`를 그대로 본뜬다.** 같은 종류의 1회 마이그레이션이 이미 있고, `RootView.swift:60`에서 앱 시작 시 호출되며 테스트가 8개 있다. 그 파일의 순서를 반드시 지킨다:

> 새 `groupID`로 전부 등록 → 저장값 교체 → **마지막에** 옛 그룹 취소

`ReminderActionBackfill.swift:29-30`의 주석이 이유를 적어뒀다 — 같은 identifier를 덮어쓰다 중간에 실패하면 scheduler의 부분 등록 롤백이 **이미 존재하던 요청까지** 지운다. `cancelGroup` 후 재등록하는 순서를 쓰면 안 된다.

붙일 자리는 `RootView`다. 홈 화면이 아니다 — `SmileHomeViewModel`은 `momentRepository`·`scheduleRepository`·`scheduler`·`calendar`·`now`만 갖고 있어 `messageStore`도 `groupIDFactory`도 없다.

**알림을 한 번도 열지 않고 "웃었어요"만 누르는 사용자**는 앱이 백그라운드로만 깨어나 `RootView`가 그려지지 않으므로 이 마이그레이션이 돌지 않는다. 받아들인다 — 그 사용자는 한국어 기기의 기존 사용자이고 한국어 알림이 이미 맞는 문구다.

### 5.2 `ReminderMessage`

사용자가 편집할 수 있고 `UserDefaults`에 **id가 아니라 텍스트로** 저장된다. 한 항목만 고쳐도 기본 8개가 통째로 그 시점 언어로 굳는다.

```swift
public struct ReminderMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    /// nil이면 카탈로그 기본값을 id로 조회한다. 값이 있으면 사용자가 직접 쓴 문구다.
    public var text: String?
}
```

기존 데이터는 전부 `text`를 갖고 있으므로 1회성 승격을 넣는다:

> 저장된 항목의 **id가 카탈로그에 있고** **text가 1.x가 실제로 출하한 한국어 문자열과 정확히 같으면** → `text = nil`로 승격

**비교값은 마이그레이션 코드 안의 동결된 한국어 리터럴 테이블이어야 한다. 카탈로그를 조회하면 안 된다.** 카탈로그는 현재 언어로 해석되므로, 영어 기기에서 조회하면 영어가 나오고 저장된 한국어와 영원히 불일치한다 → 기본 문구 8개가 "사용자가 직접 쓴 문구"로 취급되어 **영어 기기에서 영영 한국어 알림이 온다.** 그 사용자가 정확히 이 절이 존재하는 이유인 사람이다. **마이그레이션 데이터는 역사적 사실이지 지역화 대상이 아니다.**

**순서:** 승격은 같은 실행에서 5.1절의 1회 마이그레이션보다 **먼저** 돈다. 아니면 재예약이 옛 한국어를 새 요청에 다시 굳힌다.

**허점은 받아들인다.** 사용자가 기본 문구를 지웠다가 똑같이 다시 입력했으면 승격되어 번역을 따라가게 된다. 복제본도 마찬가지다. 문자열이 같으면 의도를 구분할 방법이 없고, 이 경우 번역을 따라가는 쪽이 덜 나쁘다.

**다운그레이드는 지원 경로가 아니다.** `text`가 옵셔널이 되면 승격된 항목은 JSON에서 키가 빠지고, 옛 빌드의 `decode([ReminderMessage].self)`가 실패해 `UserDefaultsReminderMessageStore.messages`가 조용히 기본값을 돌려준다(사용자가 쓴 문구 소실). App Store는 사용자에게 다운그레이드 경로를 제공하지 않으므로 받아들인다. TestFlight 테스터에게는 알린다.

**중복 검사**(`validated(_:excludingID:)`)는 해석된 텍스트끼리 비교하도록 고친다. 그러면 **기본 문구 8개의 영어 번역도 서로 달라야 한다** — 겹치면 사용자의 정당한 편집이 "같은 메시지가 이미 있어요"로 거부된다. 10절 완료 기준에 넣었다.

### 5.3 `ReminderScheduleApplier`를 뽑는다

`SmileReminderScheduleViewModel.save():223-268`은 단순 재예약이 아니라 4단계 트랜잭션이다 — 새 그룹 등록 → 저장 → 실패 시 `cancelGroup` 롤백 → 이전 그룹 취소 → 레거시 ID 취소.

이제 호출자가 셋이다: 설정 저장, 문구 변경, 5.1절의 1회 마이그레이션. **이 앱에서 가장 위험한 코드의 사본을 세 벌 두지 않는다.** CoachingKit에 `ReminderScheduleApplier`로 뽑고 셋이 공유한다.

경합 주의: 설정 시트를 닫고 홈이 `refresh()`를 도는 동안 `SmileReminderScheduleViewModel`의 디바운스된 `pendingApply`가 아직 떠 있을 수 있다. `isSaving` 가드는 인스턴스 안에서만 유효하다.

### 5.4 손대지 않는 것

`SmileMoment.guideID`, `SmileGuideCatalog.default.id` (`"anytime-soft"`), 알림 identifier 형식, `ReminderNotificationPayload`의 키는 전부 식별자라 언어와 무관하다. SwiftData 스키마는 바꾸지 않는다.

## 6. 로케일에 의존하는 UI

### 6.1 계산과 표시에 같은 캘린더를 쓴다

`SmileHistoryView`는 격자 계산에 자기 `Calendar(identifier: .gregorian)`을 쓰지만(`:14-20`), **`date.formatted(.dateTime...)`는 그 캘린더를 참조하지 않는다** — 포맷 스타일 자신의 캘린더(기본값 current)를 쓴다. 즉 격자를 그레고리력으로 유지해도 헤더는 기기 캘린더로 그려진다. 기기 캘린더를 이슬람력·히브리력으로 설정한 사용자는 **헤더의 월 이름과 격자가 서로 다른 달을 가리킨다.**

수정:

1. 지우는 `.environment(\.locale, ko_KR)` 자리에 `.environment(\.calendar, ...)`를 한 번 둔다.
2. `SmileHistoryView:14-20`이 자기 캘린더를 만드는 대신 `@Environment(\.calendar)`를 읽는다.
3. 아래 8곳을 `Text(x.formatted(.dateTime...))` → `Text(x, format: .dateTime...)`로 바꾼다. **이 형태만 환경의 locale·calendar를 상속한다.**

```
SmileDay/Views/Home/SmileHistoryView.swift:74    년·월 헤더
SmileDay/Views/Home/SmileHistoryView.swift:137   선택한 날 (월·일·요일)
SmileDay/Views/Home/SmileHistoryView.swift:207   날짜 셀
SmileDay/Views/Home/SmileHistoryView.swift:225   접근성 라벨
SmileDay/Views/Home/SmileMVPHomeView.swift:262   다음 알림 시각
SmileDay/Views/Home/SmileMVPHomeView.swift:380   요일 (narrow)
SmileDay/Views/Home/SmileMVPHomeView.swift:387   접근성 라벨
SmileDay/Views/Theme.swift:126                   SDFormat.koreanLocale 정의부 — 삭제
```

### 6.2 달력 격자가 일요일 시작으로 굳어 있다

| 줄 | 지금 | 고칠 것 |
|---|---|---|
| `SmileHistoryView:18` | `value.firstWeekday = 1` | 환경 캘린더의 `firstWeekday` |
| `SmileHistoryView:108` | `["일","월","화","수","목","금","토"]` | `veryShortWeekdaySymbols`를 `firstWeekday - 1`만큼 회전 |
| `SmileHistoryView:158` | `component(.weekday, …) - 1` | `(weekday - calendar.firstWeekday + 7) % 7` |

세부: `Calendar(identifier:)`의 `firstWeekday`는 `locale`을 대입해도 따라오지 않고 1로 남는다. `veryShortWeekdaySymbols`는 `firstWeekday`와 무관하게 항상 일요일부터 온다.

폴백이 영어이므로 영국·프랑스·독일 기기가 영어 앱을 본다. 그 지역은 월요일 시작이라 지금 코드는 요일 머리글·빈 칸·날짜가 하루씩 어긋난다.

### 6.3 숫자·시간·퍼센트는 복수 문제가 아니라 포맷 문제다

**손으로 짠 duration 포매터 셋을 지운다.** `Duration.UnitsFormatStyle`이 로케일별로 맞게 그리고 복수도 처리한다.

```
SmileMVPSettingsView.intervalLabel(_ seconds:)      "\(minutes)분 \(remainder)초"
SmileMVPOnboardingView.intervalLabel(_ minutes:)    "\(minutes)분마다" / "\(minutes / 60)시간마다"
LiveSmileSessionSummaryView:146-147                 같은 계산 세 번째
```

**퍼센트 두 곳을 `.formatted(.percent)`로 바꾼다.**

```
SmileDay/Views/Coaching/LiveSmileSessionSummaryView.swift:95
SmileDay/Views/Coaching/LiveSmileSessionSummaryView.swift:103
```

로케일마다 기호 위치와 공백(일부는 non-breaking space)이 달라 `"\(Int(...))%"`는 i18n상 틀린 코드다. 덤으로 Xcode 26에는 형식 지정자가 아닌 리터럴 `%`가 오파싱되어 빌드를 깨는 미해결 버그가 있고(포럼 792268) 이 두 줄이 정확히 그 모양(`%lld%`, `%@ %lld%`)이다.

**`"\(count)"` 보간은 그룹 구분자를 넣지 않는다** → `count.formatted()`.

**`LiveSmileMonitorView:343` `"\(count)단계 중 \(filled)단계"`는 복수 항목이 아니다.** 영어로는 "Step 2 of 5"라 복수 변형이 없다.

### 6.4 진짜 복수 규칙

| 파일 | 문구 |
|---|---|
| `SmileMVPHomeView:162, 171, 334, 387` | `"\(count)번"`, `"오늘 미소 \(count)번"`, `"총 \(totalCount)번"` |
| `SmileHistoryView:96, 98, 148, 210, 225` | `"\(count)번"`, `"\(activeDayCount)일"` |
| `SmileMVPOnboardingView:258` | `"하루 \(count)번 알려드려요"` |
| `SmileGuideView:96, 114` | `"\(duration)초 동안 함께 있어요"`, `"\(remainingSeconds)초 남았어요"` |
| `SmileMVPSettingsView:94` | `"\(count)개"` |

카탈로그에서 해당 인자에 Vary by Plural을 적용한다. 심볼은 함수 형태(`.todaySmileCount(count:)`)로 생성된다.

**접근성 라벨의 덫:** `.accessibilityLabel("\(date.formatted(...)) \(count)번")`은 보간 리터럴이라 Swift가 `LocalizedStringKey` 오버로드를 고르고, 카탈로그가 생기는 순간 `%@ %lld번` 꼴 키로 자동 추출된다. 그 키를 그대로 쓸지 명시적 `String(localized:)`로 갈지 정하고, 정한 쪽으로 통일한다. `LiveSmileMonitorView:340`의 `accessibilityValue`도 대상이다.

### 6.5 레이아웃 검증

**Double-Length Pseudolanguage는 이 코드베이스에 맞는 도구가 아니다.** 그건 잘림을 찾는 도구인데 `lineLimit`도 `minimumScaleFactor`도 **하나도 없어서** 아무것도 안 잘리고 전부 줄바꿈된다. 실제 실패 모드는 세로 오버플로와 3줄 버튼이다.

**맞는 검증: `.dynamicTypeSize(.accessibility5)` + 영어 + SE 화면.** 특히 `SmileHistoryView:95-99`의 `HStack` + `Divider` 통계 두 칸("Smiles this month" / "Days with a smile")과 홈의 같은 패턴.

## 7. 앱 밖

### 7.1 App Store 영어 현지화

한국어 페이지는 그대로 두고 영어 현지화를 추가한다. 결과는 `docs/marketing/2026-08-05-app-store-metadata-ko.md`와 짝이 되는 `-en.md`로 남긴다.

| 필드 | 처리 |
|---|---|
| 앱 이름 | `SmileDay`. 동명 앱이 있는지 먼저 확인 |
| 부제 (30자) | 한국어판에 없다. 검색 가중치가 붙는 자리라 영어판에 넣는다 |
| 프로모션 텍스트·설명 | 번역. 2절 위험 단어 확인 |
| 키워드 (100자) | **번역이 아니라 재설계**. `미소습관` → `smile habit`은 아무도 검색하지 않는다. `smile reminder`, `daily reminder`, `mood tracker`, `self care`, `mindfulness`, `habit tracker` 계열에서 이 앱이 실제로 하는 일과 겹치는 것만 고른다 |
| 스크린샷 4장 | 영어 시뮬레이터로 재촬영. 기록 데이터가 있는 상태가 필요하다 |
| What's New | 두 언어 모두 필요하다 |

**판매 지역 개방은 이 설계의 범위 밖이다.** 영어 지원과 별개 결정이고 세금·법적 서식과 지원 못 하는 시장 노출이 걸린다.

`docs/reports/2026-08-07-app-review-truedepth-response.md`에 TrueDepth 관련 심사 응답 이력이 있다. 영어 설명이 실시간 모드를 어떻게 쓰느냐에 따라 같은 질문이 다시 온다. 한국어에서 정리한 논리 — 선택형이고, 프레임을 읽지 않고, 아무것도 저장하지 않는다 — 를 그대로 옮긴다.

### 7.2 정책·지원 페이지

`SharedStrings.swift:30, 32`의 URL이 각각 하나뿐이라 영어 사용자가 앱 안에서 눌러도 한국어 페이지가 열린다.

**한 페이지에 두 언어를 담는다.** `dolparo.com/smileday/privacy`와 `/support`의 본문에 영어를 함께 둔다. 앱 코드의 URL은 번역 대상이 아니게 되고 관리할 주소도 늘지 않는다.

이 설계에서 코드로 끝낼 수 없는 유일한 항목이다.

## 8. 하지 않는 것

- 앱 안 언어 선택 화면 (3절)
- 영어 외의 언어. 구조는 열어두되 이번에 번역하지 않는다
- 사용자가 직접 쓴 알림 문구의 번역 (5.2절)
- 영어 전용 별도 앱이나 별도 브랜치
- 한국어 문구 수정 (2절)
- SwiftData 스키마 변경 (5.4절)
- 판매 지역 개방 (7.1절)
- **RTL 대응.** 코드베이스에 `.left`/`.right`가 없고 전부 `.leading`/`.trailing`이라 이미 대응돼 있다. 아랍어·히브리어를 추가할 때 다시 볼 것도 없다
- **타이포그래피 조정.** 커스텀 폰트 0, `lineSpacing`/`kerning`/`tracking` 0. 시스템 폰트가 ko/en을 다 처리한다
- **위젯 지역화.** `2026-08-11-smile-face-widget-design.md`의 위젯은 텍스트를 렌더하지 않으므로 지역화 대상이 갤러리의 `configurationDisplayName`/`description`과 접근성 라벨뿐이다. 위젯은 별도 번들이라 자기 카탈로그가 필요하다 — **위젯을 만들 때 같이 한다.** 여기 적어두는 건 그때 다시 발견하지 않게 하려는 것이다

## 9. 작업 순서

**구조 먼저, 문구는 다음.** 두 단계를 **한 브랜치에서 하고 한 번에 머지한다.**

**1단계 — 배관.** String Catalog 배치, CoachingKit 문구 이동, 알림 지연 해석 + 1회 마이그레이션, 캘린더·포맷·복수 규칙을 끝낸다. 검증 목표는 **한국어 앱이 오늘과 완전히 같게 동작한다**는 것이다.

**1단계에서 `en` 열을 기계적으로 채운다.** deck에 있는 40개는 deck 문구로, 나머지는 **한국어 문자열을 그대로** 넣고, 전 항목의 번역 상태를 `needsReview`로 표시한다.

- 어떤 빌드도 키 문자열을 노출하지 않는다. 최악이 영어 기기에서 한국어인데 **그건 정확히 오늘의 상태다 — 회귀가 아니다.**
- 키가 화면에 뜨면 그건 정상 상태가 아니라 **오타다.** 1단계 내내 오타를 즉시 발견할 수 있다.
- 2단계가 "needs-review 큐를 비우는 일"이 되고 Xcode 카탈로그 편집기가 필터와 개수를 준다.
- 2단계 완료 게이트가 기계 검증 가능해진다(10절).

**2단계 — 문구.** deck의 40개를 톤 기준으로 삼아 나머지 약 160개를 쓴다. deck이 덮지 않는 것: 실시간 확인 상세 문구, 오류·복구 문구, 설정 화면 전체, 알림 권한 안내, 접근성 라벨, 데이터 저장 위치 섹션, 정책·고객지원 항목.

App Store 페이지(7.1)와 정책 페이지(7.2)는 2단계와 함께 간다.

## 10. 완료 기준

**기계 검증**

- `Localizable.xcstrings`를 비롯한 모든 카탈로그(JSON)에 `needsReview` 상태가 0개다. 2단계 종료 게이트다.
- CoachingKit 소스에 사용자 노출 문자열이 0개다. 주석과 테스트의 한국어는 제외하고 검사한다.
- `cd CoachingKit && swift test`가 통과한다 (`Test Suite 'All tests' passed` 확인).
- `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build`가 통과한다.
- 기본 알림 문구 8개의 영어 번역이 서로 중복되지 않는다 (5.2절 중복 검사).

**회귀 없음**

- 한국어 기기에서 모든 화면이 오늘과 동일하다.
- 기존 사용자의 기록·스케줄·편집한 알림 문구가 그대로 남는다.
- 1.x에서 업데이트한 기기에서 손대지 않은 기본 알림 문구가 `text = nil`로 승격된다.
- 승격이 1회 마이그레이션보다 먼저 돈다.

**영어**

- 영어 기기에서 한국어가 보이지 않는다. 전 화면을 훑어 확인한다 — 온보딩, 홈, 가이드, 기록, 설정, 알림 문구 관리, 실시간 확인, 세션 요약, 오류 화면, 알림 권한 안내.
- 카메라 권한 대화상자가 영어로 뜬다.
- 잠금화면 알림의 제목·본문·버튼 두 개가 영어로 뜬다.
- **기기 언어를 바꾸면 재예약 없이 다음 알림부터 새 언어로 나온다.**
- 사용자가 편집한 알림 문구는 언어를 바꿔도 그대로 남는다.

**로케일**

- 선호 언어에 영어가 없는 프랑스어 기기에서 앱이 영어로 뜬다.
- 영국 지역 설정에서 달력이 월요일 시작이고 날짜가 어긋나지 않는다.
- 24시간제 지역에서 알림 시각이 24시간제로 표시된다.
- 기기 캘린더를 불기로 바꿨을 때 격자와 헤더가 같은 달을 가리킨다.

**레이아웃**

- `.accessibility5` + 영어 + SE 화면에서 세로 오버플로가 없다.

**스토어**

- 영어 페이지의 이름·부제·설명·키워드·스크린샷·What's New가 채워져 있다.
- 설명과 부제에 2절의 위험 단어가 없다.
- 정책·지원 페이지를 영어로 읽을 수 있다.

## 11. 미확인 항목

구현 시 실측해서 확정한다.

- `NSString.localizedUserNotificationString(forKey:arguments:)`의 string table 지원 여부. 지원하면 알림 문구를 기본 테이블 밖으로 옮길 수 있다 (4.2절).
- 같은 테이블 안에서 두 키가 sanitize 후 같은 Swift 식별자로 뭉칠 때 Xcode의 처리 (에러/경고/자동 접미사).
