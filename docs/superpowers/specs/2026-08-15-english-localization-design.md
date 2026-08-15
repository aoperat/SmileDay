# 영어 지원 설계

- 날짜: 2026-08-15
- 상태: 승인됨
- 배경: 앱은 한국어 단일 언어로 빌드된다 (`developmentRegion = ko`, `knownRegions = (ko, Base)`). String Catalog도 `.strings`도 없고 사용자 문구 약 200개가 Swift 리터럴로 흩어져 있다. `SmileDayApp.swift:29`가 로케일을 `ko_KR`로 고정해 기기 언어를 무시한다. 이미 출시되어 실사용자가 있으므로 저장된 데이터와 기기에 예약된 알림을 깨지 않아야 한다.
- 선행 문서: `docs/english-copy-deck.md` (2026-07-31) — 톤 규칙과 문구 초안 약 40개. 이 설계는 그 문서의 "나중에 할 엔지니어링" 절을 실행 가능한 형태로 확정한다.

## 1. 목표

- 한 바이너리로 한국어와 영어를 모두 지원한다. 기기 언어에 따라 iOS가 고른다.
- 지원하지 않는 언어의 사용자는 한국어가 아니라 **영어**를 본다.
- 기존 한국어 사용자의 화면·기록·알림이 오늘과 동일하게 동작한다.
- App Store에 한국어 페이지 옆에 영어 페이지를 추가한다.

## 2. 제품 원칙

`docs/english-copy-deck.md`의 다섯 규칙을 영어 문구 전체에 적용한다. 요약하면:

1. 감정을 명령하지 않는다. `Let's!`가 아니라 조건절(`if you're up for it`).
2. 웃지 않은 날은 실패가 아니다. `You haven't…`, `Don't forget`, `streak`, `goal`, `missed` 금지.
3. 외모를 말하지 않는다. 칭찬도 평가다.
4. 과장하지 않는다. `Great job!`, `Amazing!`, 축하 이모지 금지.
5. 건강·미용 효과를 말하지 않는다 (App Store 1.4.1).

영어권 심사에서 더 직접적으로 걸리는 단어: `lift`, `tone`, `firm`, `anti-aging`, `rejuvenate`, `wrinkle`, `therapy`, `therapeutic`, `treatment`, `cure`, `heal`, `depression`, `anxiety`, `mood disorder`, `clinically`.

**영어화는 한국어 문구를 고치는 계기가 아니다.** 한국어 카피는 이번 작업에서 한 글자도 바꾸지 않는다.

## 3. 언어 결정과 폴백

- `developmentRegion = en`, `knownRegions = (en, ko, Base)`.
- `CFBundleDevelopmentRegion`은 표기가 아니라 **폴백 언어**다. 기기 언어와 맞는 `.lproj`가 없을 때 iOS가 이 값을 고른다. `ko`로 두면 프랑스어·독일어·스페인어 기기가 한국어 앱을 본다.
- String Catalog의 소스 언어가 영어가 되고 한국어가 번역 열로 내려간다. 실행 동작에는 영향이 없다. 한국어 문구는 처음부터 `ko` 열에 넣고 소스 열은 2단계에서 채운다(9절).
- **이 값은 1단계 시작 시점에 바꾼다.** 나중에 뒤집으려면 pbxproj뿐 아니라 카탈로그의 소스 언어까지 Xcode에서 손으로 옮겨야 하고, 그 시점엔 항목이 200개다.
- `SmileDayApp.swift:29`의 `.environment(\.locale, Locale(identifier: "ko_KR"))`를 제거한다.
- **앱 안에 언어 선택 화면을 만들지 않는다.** iOS 13+는 두 개 이상의 지역화를 담은 앱에 설정 앱 → SmileDay → 언어 항목을 자동으로 만든다. 직접 만들면 두 곳이 되어 서로 어긋난다.

기기를 영어로 쓰는 기존 한국 사용자는 업데이트 후 앱이 영어로 바뀐다. iOS 표준 동작이며 설정 앱에서 앱만 한국어로 되돌릴 수 있다.

## 4. 문자열 배치

앱 타깃에 String Catalog 두 개를 둔다.

| 파일 | 담는 것 |
|---|---|
| `Localizable.xcstrings` | 화면 문구 전부 |
| `InfoPlist.xcstrings` | `NSCameraUsageDescription`, 앱 표시 이름 |

카메라 권한 설명은 지금 `project.pbxproj`의 `INFOPLIST_KEY_NSCameraUsageDescription`에 있다. **빌드 세팅에 있으면 번역되지 않으므로** `InfoPlist.xcstrings`로 옮기고 빌드 세팅에서 지운다.

### 4.1 키 규칙

**모든 사용자 문구는 이름 붙은 Swift 프로퍼티가 되고, 카탈로그 키는 그 프로퍼티 이름과 같다.** 지금 뷰 안에 인라인으로 박힌 약 95개도 프로퍼티로 끌어올린다.

`SharedStrings`는 그대로 두고 (키 84개, 이름 변경 없음) 화면 전용 문구는 화면 옆에 둔다:

```
Views/SharedStrings.swift          기존 84개 — 두 화면 이상이 쓰는 문구
Views/Home/HomeStrings.swift       홈·기록 화면 전용
Views/Onboarding/OnboardingStrings.swift
Views/Settings/SettingsStrings.swift
Views/Coaching/CoachingStrings.swift  가이드·실시간 확인
```

한 파일에 200개를 몰면 문구 한 화면을 통째로 읽으며 말투를 맞추기 어렵고 병합 충돌이 잦다.

카탈로그 키는 두 규칙을 쓴다.

- `SharedStrings`의 기존 84개는 **프로퍼티 이름 그대로**. 이미 서로 겹치지 않고, 이름을 바꾸면 호출부가 딸려 온다.
- 새로 만드는 화면별 문구는 **`<화면>.<이름>`**. 카탈로그 키는 앱 전체에서 하나의 이름 공간이라 `title` 같은 이름이 화면마다 부딪힌다.

### 4.2 `let`에서 계산 프로퍼티로

```swift
enum SharedStrings {
    static var todayCountTitle: String {
        String(localized: "todayCountTitle")
    }
}
```

호출부 84곳을 한 줄도 바꾸지 않는다. 계산 프로퍼티라 언어가 바뀌면 다음 접근부터 따라온다.

`defaultValue:`를 쓰지 않는다. 한국어와 영어 모두 카탈로그가 들고 있고, 코드에는 키만 남는다.

### 4.3 CoachingKit에서 문구 25개를 걷어낸다

CLAUDE.md는 CoachingKit을 플랫폼 독립 로직 계층으로 정의한다. 사용자 문구가 거기 있는 것이 원래 예외였고, 이번 작업이 그것을 정리한다.

| 대상 | 개수 | 처리 |
|---|---|---|
| `SmileCueCatalog` | 8 | `SmileCue`에서 `text` 제거. `id`만 남는다 |
| `ReminderMessageCatalog` | 8 | `text`를 옵셔널로 (5절 참조) |
| `ReminderNotificationAction.title` | 2 | 앱 타깃으로. 카테고리를 등록하는 `AppDelegate`가 이미 앱 타깃이다 |
| `ReminderMessageViewModel.errorMessage` | 4 | 오류 케이스로 |
| `SmileReminderScheduleViewModel` 오류 문구 | 3 | 오류 케이스로 |

```swift
// CoachingKit — 문구가 아니라 케이스를 노출한다
public enum ReminderMessageError: Equatable, Sendable {
    case empty
    case tooLong(limit: Int)
    case duplicate
    case lastRemaining
}

// 앱 타깃 — 케이스를 문구로 옮긴다
extension ReminderMessageError {
    var message: String {
        switch self {
        case .empty: SettingsStrings.messageEmpty
        case .tooLong(let limit): SettingsStrings.messageTooLong(limit)
        case .duplicate: SettingsStrings.messageDuplicate
        case .lastRemaining: SettingsStrings.messageLastRemaining
        }
    }
}
```

`SmileCue`의 `id`와 배열 순서는 그대로 유지한다. `SmileCueCursorStore`가 순환 선택에 쓰는 값이다.

주석은 한국어로 남긴다. 개발자를 위한 글이고 사용자에게 보이지 않는다.

## 5. 살아있는 데이터

### 5.1 이미 예약된 알림

`UserNotificationReminderScheduler.scheduleDailyPattern`은 예약 시점의 텍스트를 `UNMutableNotificationContent`에 굳혀 iOS에 넘긴다. `UNCalendarNotificationTrigger(repeats: true)`라 그 문자열이 매일 그대로 나온다. **번역만 넣으면 영어 기기에서도 알림만 한국어로 계속 울린다.** 알림이 이 앱의 유일한 진입 경로이므로 이는 영어화 실패와 같다.

**판단은 `SmileHomeViewModel`에 둔다.** 이 뷰모델은 이미 `scheduleRepository`와 `scheduler`를 둘 다 주입받으므로(`SmileMVPHomeView:90-92`) 재예약에 필요한 것이 전부 있고, CoachingKit 안이라 가짜 스케줄러로 테스트할 수 있다. 뷰에 두면 검증할 방법이 없다.

```swift
public protocol ScheduledLanguageStoring: AnyObject {
    var lastScheduledLanguage: String? { get set }
}
```

`UserDefaultsReminderMessageStore`, `SmileCueCursorStore`와 같은 꼴이다.

- 현재 언어는 앱 타깃이 `Bundle.main.preferredLocalizations.first`로 읽어 넘긴다. CoachingKit은 `Bundle`을 모른다.
- **`Locale.current`를 쓰지 않는다.** 앱이 `ko`/`en`만 담고 있어 프랑스어 기기는 실제로 영어로 뜨는데 `Locale.current`는 `fr`이라, 매번 다르다고 판단해 활성화할 때마다 무한히 재예약한다.
- 호출 시점은 홈의 `refresh()` 경로다. `scenePhase` 활성화, 설정 화면에서 복귀, 앱 시작이 모두 이 경로를 지난다.
- 재예약은 저장 경로를 그대로 부른다. `cancelGroup(id:)`가 하루치 식별자 공간을 통째로 비우고 다시 거는 기존 동작이 이 경우에도 맞다.
- 실패하면 (권한 없음 등) 조용히 넘어가고 저장한 언어를 갱신하지 않는다. 다음 활성화에서 다시 시도한다.
- 사용자에게 아무것도 보여주지 않는다.

`content.title = "스마일데이"`도 번역 대상이다.

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

> 저장된 항목의 **id가 카탈로그에 있고** **text가 그 카탈로그의 한국어 원문과 정확히 같으면** → `text = nil`로 승격

문구를 고친 사람은 text가 달라 승격되지 않는다. 직접 쓴 문장은 그대로 남고 손대지 않은 기본값만 번역을 따라간다.

**사용자가 한국어로 쓴 문구는 영어 기기에서도 한국어로 나온다.** 고칠 수 없고 고쳐서도 안 된다.

중복 검사(`validated(_:excludingID:)`)는 해석된 텍스트끼리 비교하도록 고친다.

### 5.3 손대지 않는 것

`SmileMoment.guideID`, `SmileGuideCatalog.default.id` (`"anytime-soft"`), 알림 identifier 형식, `ReminderNotificationPayload`의 키는 전부 식별자라 언어와 무관하다. SwiftData 스키마는 바꾸지 않는다.

## 6. 로케일에 의존하는 UI

### 6.1 달력이 일요일 시작으로 굳어 있다

`SmileHistoryView`의 네 곳이 맞물려 일요일 시작을 가정한다.

| 줄 | 지금 | 고칠 것 |
|---|---|---|
| `:16` | `value.locale = SDFormat.koreanLocale` | `.current` |
| `:18` | `value.firstWeekday = 1` | `Calendar.current.firstWeekday` |
| `:108` | `["일","월","화","수","목","금","토"]` | `calendar.veryShortWeekdaySymbols`를 회전 |
| `:158` | `component(.weekday, …) - 1` | `(weekday - calendar.firstWeekday + 7) % 7` |

세부 세 가지를 지킨다.

- **`Calendar(identifier: .gregorian)`은 유지한다.** `Calendar.current`로 바꾸면 태국 기기가 불기(2569년), 일본 기기가 연호로 날짜를 그린다. 이 앱의 기록은 그레고리력 날짜이고 `SmileHistoryViewModel` 테스트도 그것을 전제한다. 지역에서 가져올 것은 달력 체계가 아니라 `locale`과 `firstWeekday`뿐이다.
- **`locale`을 바꿔도 `firstWeekday`는 따라오지 않는다.** `Calendar(identifier:)`의 기본값은 로케일과 무관하게 1이므로 `Calendar.current.firstWeekday`를 명시적으로 넣어야 한다.
- `veryShortWeekdaySymbols`는 `firstWeekday`와 무관하게 항상 일요일부터 온다. `firstWeekday - 1`만큼 회전시킨다.

폴백이 영어이므로 영국·프랑스·독일 기기가 영어 앱을 본다. 그 지역은 월요일 시작이라 지금 코드는 요일 머리글·빈 칸·날짜가 하루씩 어긋난다.

### 6.2 날짜와 시각

`SDFormat.koreanLocale` 사용처 8곳(`SmileHistoryView:16, 74, 137, 207, 225`, `SmileMVPHomeView:262, 380, 387`)에서 `.locale(...)`을 지운다. 기본값이 현재 로케일이라 날짜·요일·12/24시간제가 자동으로 갈린다. `Theme.swift:126`의 정의도 지운다.

### 6.3 복수 규칙

한국어는 "1번"과 "14번"이 같은 꼴이지만 영어는 갈린다. String Catalog의 plural variation으로 옮길 자리:

| 파일 | 문구 |
|---|---|
| `SmileMVPHomeView:162, 171, 334, 387` | `"\(count)번"`, `"오늘 미소 \(count)번"`, `"총 \(totalCount)번"` |
| `SmileHistoryView:96, 98, 148, 210, 225` | `"\(count)번"`, `"\(activeDayCount)일"` |
| `SmileMVPOnboardingView:258, 279` | `"하루 \(count)번 알려드려요"`, `"\(minutes)분마다"`, `"\(minutes/60)시간마다"` |
| `SmileGuideView:96, 114` | `"\(duration)초 동안 함께 있어요"`, `"\(remainingSeconds)초 남았어요"` |
| `SmileMVPSettingsView:94, 218, 221` | `"\(count)개"`, `"\(seconds)초"`, `"\(minutes)분 \(remainder)초"` |
| `LiveSmileSessionSummaryView:146, 147` | `"\(remainder)초"`, `"\(minutes)분 \(remainder)초"` |
| `LiveSmileMonitorView:343` | `"\(count)단계 중 \(filled)단계"` |

```swift
static func todaySmileCount(_ count: Int) -> String {
    String(localized: "home.todaySmileCount \(count)")
}
```

카탈로그에서 해당 인자에 Vary by Plural을 적용한다.

### 6.4 레이아웃

영어가 한국어보다 길다. "이 시간으로 시작하기"(9자)가 `Start with these times`(22자)가 된다. 버튼과 카드 제목이 위험하다. Xcode의 Double-Length Pseudolanguage로 전 화면을 훑어 잘리는 자리를 찾는다.

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
| 판매 지역 | 언어와 무관한 별도 설정. 전 세계로 연다 |

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
- SwiftData 스키마 변경 (5.3절)

## 9. 작업 순서

**구조 먼저, 문구는 다음.** 두 단계로 나눈다.

**1단계 — 배관.** 영어 칸을 비운 채 String Catalog 배치, CoachingKit 문구 이동, 알림 재예약, 달력·날짜·복수 규칙을 끝낸다. 이 단계의 검증 목표는 **한국어 앱이 오늘과 완전히 같게 동작한다**는 것이다. 끝나면 채워야 할 키 약 200개의 정확한 목록이 카탈로그에 생긴다.

**2단계 — 문구.** deck의 40개를 톤 기준으로 삼아 나머지 약 160개를 쓴다. deck이 덮지 않는 것: 실시간 확인 상세 문구, 오류·복구 문구, 설정 화면 전체, 알림 권한 안내, 접근성 라벨, 데이터 저장 위치 섹션, 정책·고객지원 항목.

1단계 중에는 영어 기기가 키 문자열을 그대로 본다. 2단계를 마치기 전에는 출시하지 않는다.

App Store 페이지(7.1)와 정책 페이지(7.2)는 2단계와 함께 간다.

## 10. 완료 기준

**회귀 없음**

- 한국어 기기에서 모든 화면이 오늘과 동일하다.
- 기존 사용자의 기록·스케줄·편집한 알림 문구가 그대로 남는다.
- `cd CoachingKit && swift test`가 통과한다 (`Test Suite 'All tests' passed` 확인).
- `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build`가 통과한다.

**영어**

- 영어 기기에서 한국어가 한 글자도 보이지 않는다. 전 화면을 훑어 확인한다 — 온보딩, 홈, 가이드, 기록, 설정, 알림 문구 관리, 실시간 확인, 세션 요약, 오류 화면, 알림 권한 안내.
- CoachingKit 소스에 사용자 노출 문자열이 0개다. 주석의 한국어는 그대로 둔다.
- 카메라 권한 대화상자가 영어로 뜬다.
- 잠금화면 알림의 제목·본문·버튼 두 개가 영어로 뜬다.
- Double-Length Pseudolanguage에서 잘리는 문구가 없다.

**로케일**

- 프랑스어 기기에서 앱이 영어로 뜬다.
- 영국 지역 설정에서 달력이 월요일 시작이고 날짜가 어긋나지 않는다.
- 24시간제 지역에서 알림 시각이 24시간제로 표시된다.

**알림 재예약**

- 언어를 바꾸면 다음 활성화에서 예약된 알림이 새 언어로 다시 걸린다.
- 사용자가 편집한 알림 문구는 언어를 바꿔도 그대로 남는다.
- 손대지 않은 기본 알림 문구는 번역을 따라간다.
- 언어가 그대로면 재예약이 일어나지 않는다.

**스토어**

- 영어 페이지의 이름·부제·설명·키워드·스크린샷이 채워져 있다.
- 설명과 부제에 2절의 위험 단어가 없다.
- 정책·지원 페이지를 영어로 읽을 수 있다.
