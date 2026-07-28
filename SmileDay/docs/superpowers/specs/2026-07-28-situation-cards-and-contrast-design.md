# 상황 카드와 색 대비 설계

- 날짜: 2026-07-28
- 상태: 승인됨
- 보완 대상: `2026-07-28-notification-smile-mvp-design.md` (대체가 아니라 두 부분을 고친다)
- 배경: MVP를 쓰던 중 두 가지가 드러났다. 첫째, 보조 텍스트가 잘 읽히지 않는다. 둘째, 목록의 3개 항목이 표정의 종류(편안한/인사/활짝)라서 "언제 웃어야 하는지"를 알려주지 못한다. 사용자가 미소를 잊는 건 표정을 몰라서가 아니라 순간을 놓쳐서다.

## 1. 고치는 것

1. 본문·캡션 색이 WCAG AA 본문 기준(4.5:1)에 못 미친다.
2. 가이드 목록을 표정 종류에서 **상황 카드**로 바꾸고, 개수를 늘린다.
3. 사용자가 카드를 직접 추가하고 제거할 수 있게 한다.

MVP 원칙은 그대로다. 카메라·점수·기준선 없음, 완료는 자기 보고, 5초 고정, 쉬어간 날을 실패로 표현하지 않음.

## 2. 색 대비

### 문제

측정값(sRGB 상대휘도 기준):

| 색 | 흰 배경 | 크림 배경 | 판정 |
|---|---|---|---|
| `muted` `#A08B96` | 3.17:1 | 2.97:1 | 본문 실패 |
| `coral` `#F65D73` | 3.12:1 | 2.92:1 | 본문 실패 |
| `coralWarm` `#FB7E62` | 2.54:1 | 2.38:1 | 큰 글자도 실패 |
| 아이콘 칩 위 흰 글리프 | `sun` 1.54:1 · `apricot` 1.90:1 · `lilac` 2.36:1 · `mint` 2.73:1 | | 비텍스트 3:1 실패 |

`muted`는 캡션, 요일 라벨, "다음 알림" 같은 보조 텍스트 대부분에 쓰인다. 여기가 가장 크게 걸린다.

### 바꿀 값

| 대상 | 지금 | 바꿀 값 | 결과 |
|---|---|---|---|
| `muted` | `#A08B96` | `#7E6A74` | 5.00:1 흰 / 4.68:1 크림 |
| `primaryGradient` | coral → coralWarm | coralDeep → coral | 4.08:1 → 3.12:1 |
| 카운트다운 숫자 72pt | `coral` | `ink` | 11.04:1 |
| 저장 실패 문구 | `coralDeep` | 새 `alert` `#C8324C` | 5.23:1 흰 / 4.90:1 크림 |
| 아이콘 칩 글리프 | 흰색 | `ink` | 6.9:1 이상 |

`shell`, `sun`, `apricot`, `lilac`, `mint`는 배경으로만 남으므로 값을 바꾸지 않는다.

버튼 라벨은 15pt 굵은 글씨라 WCAG 큰 글자 기준 3:1이 적용된다. 카운트다운도 72pt라 3:1이지만 `ink`로 넉넉히 넘긴다.

### 회귀를 막는 방법

색 hex 값을 `CoachingKit/SDPalette.swift`에 `UInt32` 상수로 옮기고, `SmileDay/Views/Theme.swift`의 `SDColor`는 그 상수를 `Color`로 감싸기만 한다. 앱 타깃에는 테스트 번들이 없어 대비를 검증할 수 없지만, CoachingKit으로 옮기면 `swift test`가 잡는다.

`SDPaletteTests`는 상대휘도와 대비비를 직접 계산해 다음을 확인한다.

- 본문에 쓰는 색은 흰 배경과 크림 배경 모두에서 4.5:1 이상
- 버튼 배경 위 흰 글자는 3:1 이상
- 아이콘 칩 배경 위 `ink` 글리프는 3:1 이상

## 3. 상황 카드

### 타입

타입 이름 `SmileGuide`는 유지한다. 알림·기록·뷰모델이 모두 이 이름을 쓰고 있고, 이름 자체는 여전히 맞다.

`notificationText`는 없앤다. 알림 제목에 카드 이름, 본문에 안내 문구를 그대로 쓰면 되므로 문구를 두 벌 관리할 이유가 없다.

```swift
public enum DaySlot: String, CaseIterable, Sendable {
    case morning     // 05–10시
    case afternoon   // 11–16시
    case evening     // 17–04시
    case anytime     // 시간과 무관

    public init(hour: Int)          // anytime을 돌려주지 않는다
    public var displayName: String  // 아침 / 낮 / 저녁 / 언제든
}

public struct SmileGuide: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String        // "출근 후 웃으며 인사하기"
    public let instruction: String  // 5초 동안의 안내
    public let slot: DaySlot
    public let durationSeconds: Int // 5 고정
    public let isBuiltIn: Bool
}
```

### 기본 카탈로그 14개

| slot | id | title | instruction |
|---|---|---|---|
| morning | `morning-greeting` | 출근 후 웃으며 인사하기 | 어깨 힘을 빼고, 반갑게 인사하는 표정을 지어보세요. |
| morning | `morning-mirror` | 거울 볼 때 한 번 웃기 | 거울 속 나를 보며 입꼬리를 살짝 올려보세요. |
| morning | `morning-leaving` | 집을 나서기 전 한 번 웃기 | 문을 나서기 전, 턱 힘을 빼고 웃어보세요. |
| morning | `morning-coffee` | 첫 커피 마시며 숨 고르기 | 한 모금 마시고 천천히 숨을 내쉬며 웃어보세요. |
| afternoon | `noon-before-meeting` | 회의 시작 전 표정 풀기 | 이마와 미간의 힘을 빼고 입꼬리를 올려보세요. |
| afternoon | `noon-before-lunch` | 점심 먹기 전 숨 고르고 웃기 | 수저를 들기 전 어깨를 내리고 웃어보세요. |
| afternoon | `noon-before-call` | 전화 받기 전 입꼬리 올리기 | 목소리를 내기 전에 표정을 먼저 준비해보세요. |
| afternoon | `noon-stand-up` | 자리에서 일어날 때 어깨 내리기 | 일어서면서 어깨를 내리고 한 번 웃어보세요. |
| evening | `evening-after-work` | 퇴근 후 어깨 힘 빼고 웃기 | 하루를 내려놓듯 어깨를 낮추고 웃어보세요. |
| evening | `evening-coming-home` | 집에 들어가며 인사하기 | 문을 열기 전, 반갑게 인사하는 표정을 지어보세요. |
| evening | `evening-before-dinner` | 저녁 먹기 전 한 번 웃기 | 자리에 앉아 숨을 고르고 입꼬리를 올려보세요. |
| evening | `evening-before-sleep` | 잠들기 전 얼굴 힘 빼기 | 이마, 눈가, 턱 순서로 힘을 빼보세요. |
| anytime | `anytime-pause` | 하던 일 멈추고 웃기 | 손을 멈추고 5초만 편하게 웃어보세요. |
| anytime | `anytime-soft` | 편안한 미소 짓기 | 턱과 어깨 힘을 빼고 입꼬리를 살짝 올려보세요. |

기본 카드는 `anytime-soft`다. 상황에 매이지 않아 어떤 대체 상황에서도 말이 되고, 사용자가 문구를 비웠을 때 쓰는 기본 안내와 같은 문장이다.

"퇴근길"이 아니라 "퇴근 후"로 쓴 것은 이동 중 화면 사용을 유도하지 않기 위해서다. 금지어 테스트를 `instruction`뿐 아니라 `title`에도 적용한다.

## 4. 저장 구조

기본 카드는 **코드 상수**로 두고 사용자 데이터만 저장한다. 기본 카드를 SwiftData로 시딩하면 다음 업데이트에서 문구를 고쳐도 기존 사용자에게 닿지 않고, 첫 실행 시딩이라는 실패 지점이 하나 늘어난다.

### `CustomSmileCard`

```swift
@Model
public final class CustomSmileCard {
    public var id: String            // UUID 문자열
    public var title: String
    public var instructionText: String?  // nil이면 기본 안내 문구
    public var slotRawValue: String
    public var createdAt: Date
}
```

`PersistenceSchema.models`에 추가한다. 기존 5개 모델은 그대로 둔다.

### 숨긴 기본 카드

```swift
public protocol HiddenSmileGuideStoring: AnyObject {
    var hiddenGuideIDs: Set<String> { get set }
}
```

UserDefaults 구현과 InMemory 구현을 둔다. 기존 `SmilePracticeFavoritesStoring` 패턴과 같다.

### `SmileGuideLibrary`

기본 카드와 내 카드를 합쳐 내놓는 한 곳.

```swift
public final class SmileGuideLibrary {
    public func visibleGuides() throws -> [SmileGuide]   // 숨김 제외, slot 순 → 기본 먼저 → 생성순
    public func guide(id: String?) -> SmileGuide          // 숨기거나 지운 카드도 찾아준다
    public func hiddenBuiltInGuides() -> [SmileGuide]
    @discardableResult
    public func addCustom(title: String, instruction: String?, slot: DaySlot) throws -> SmileGuide
    public func removeCustom(id: String) throws
    public func hideBuiltIn(id: String)
    public func restoreBuiltIn(id: String)
}
```

`guide(id:)`가 숨기거나 지운 카드도 찾아주는 것이 중요하다. 지난 기록과 예약된 알림이 이름을 잃으면 안 된다. 완전히 사라진 ID만 기본 카드로 떨어진다.

빈 제목이나 공백만 있는 제목은 `addCustom`에서 거부한다.

## 5. 삭제와 숨기기

| 대상 | 동작 | 되돌리기 |
|---|---|---|
| 기본 카드 | 목록에서 숨김 | 설정에서 복구 |
| 내 카드 | 저장소에서 삭제 | 없음 |

둘 다 그 카드를 쓰는 알림이 있으면 **먼저 보여준다**.

```
이 카드를 쓰는 알림이 2개 있어요.
09:00, 13:00

지우면 이 알림들은 '편안한 미소 짓기'로 바뀝니다.

[취소]  [지우기]
```

진행하면 해당 알림들의 `guideID`를 기본 카드로 바꾸고 **재예약까지** 한다. 재예약하지 않으면 이미 예약된 14일치 알림이 사라진 카드의 문구를 그대로 들고 나간다.

이를 위해 `ReminderRepository.reminders(usingGuideID:)`를 추가한다. `guideID`가 nil인 알림은 기본 카드를 쓰는 것으로 친다.

## 6. 화면

카드가 14개 이상이라 지금의 가로 칩 3개는 쓸 수 없다.

### 공용 `SmileGuidePickerSheet`

- 시간대별 섹션(아침 / 낮 / 저녁 / 언제든)
- 행마다 제목과 안내 문구 한 줄
- 현재 선택된 카드에 체크
- 하단에 "내 카드 추가"

홈, 설정의 알림 행, 온보딩이 모두 이 시트를 쓴다.

### 홈

`오늘 미소 N번` 아래에 선택된 카드 이름을 두고, 탭하면 시트가 열린다. 그 아래가 `지금 미소 짓기`. 첫 진입 시 현재 시간대의 첫 카드를 기본 선택한다.

### 설정

"미소 카드" 섹션을 새로 만든다.

- 보이는 카드 목록 (내 카드는 스와이프 삭제)
- 카드 추가 (제목 필수, 안내 문구 선택, 시간대 선택)
- 숨긴 기본 카드 목록과 복구

### 온보딩

권장 기본값을 상황 카드로 바꾼다.

- 09:00 → 출근 후 웃으며 인사하기
- 13:00 → 점심 먹기 전 숨 고르고 웃기
- 18:00 → 퇴근 후 어깨 힘 빼고 웃기

## 7. 마이그레이션

기존 ID는 별칭으로 연결한다. 배포 이력은 없지만 개발 기기의 알림과 기록이 엉뚱한 카드로 바뀌는 것을 막는다.

| 옛 ID | 새 ID |
|---|---|
| `soft-smile` | `anytime-soft` |
| `greeting-smile` | `morning-greeting` |
| `bright-smile` | `anytime-pause` |

별칭에도 없는 ID는 기존대로 기본 카드로 떨어진다.

`SmileMoment`와 `ReminderSetting`의 저장 필드는 바뀌지 않는다. `CustomSmileCard`만 스키마에 추가되므로 기존 데이터는 그대로 열린다.

## 8. 완료 기준

- 본문에 쓰는 모든 색이 흰 배경과 크림 배경에서 4.5:1 이상이고, 테스트가 이를 확인한다.
- 목록에 시간대별 상황 카드 14개가 보인다.
- 사용자가 제목만으로 카드를 추가할 수 있고, 문구를 비우면 기본 안내가 쓰인다.
- 내 카드는 삭제되고 기본 카드는 숨겨졌다가 복구된다.
- 카드를 지우기 전에 그 카드를 쓰는 알림을 보여주고, 진행하면 기본 카드로 바꿔 재예약한다.
- 숨기거나 지운 카드의 ID로도 이름을 찾을 수 있다.
- 옛 ID 3개가 새 카드로 연결된다.
- 전체 패키지 테스트와 앱 빌드가 통과한다.
