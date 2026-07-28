# 상황 카드와 색 대비 Implementation Plan

> **For agentic workers:** 구현 전 `SmileDay/docs/superpowers/specs/2026-07-28-situation-cards-and-contrast-design.md`를 전체 읽고 Task를 순서대로 수행한다. 이 계획은 `2026-07-28-notification-smile-mvp.md`를 대체하지 않고 두 부분(색, 가이드 목록)을 고친다.

**Goal:** 보조 텍스트가 WCAG AA를 넘기게 만들고, 표정 3종 목록을 시간대별 상황 카드 14개 + 사용자 카드 CRUD로 바꾼다.

**Architecture:** 색 hex는 `CoachingKit/SDPalette.swift`로 옮겨 테스트로 대비를 고정하고, `SDColor`는 그 값을 감싸기만 한다. 기본 카드는 코드 상수로 두고 사용자 카드(`CustomSmileCard`)와 숨김 ID만 저장한다. 둘을 합쳐 내놓는 곳은 `SmileGuideLibrary` 하나뿐이다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, Observation, XCTest, iOS 17+.

---

### Task 0: 기준 기록

**Files:** none

- [ ] 브랜치와 작업 트리를 확인한다.

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git branch --show-current   # feature/situation-cards-and-contrast
git status --short
```

- [ ] 기준 테스트와 빌드를 기록한다.

```bash
cd CoachingKit && swift test
cd .. && xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected: `Test Suite 'All tests' passed` (330 tests), `** BUILD SUCCEEDED **`.

---

### Task 1: SDPalette와 대비 테스트

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SDPalette.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SDPaletteTests.swift`

- [ ] **Step 1: 대비 계산과 팔레트를 쓴다**

`SDPalette.swift`:

```swift
import Foundation

/// 디자인 토큰의 원시 색값. 앱 타깃에는 테스트 번들이 없어 여기 두고 대비를 테스트로 고정한다.
/// `SmileDay/Views/Theme.swift`의 `SDColor`가 이 값을 SwiftUI `Color`로 감싼다.
public enum SDPalette {
    public static let coral: UInt32 = 0xF65D73
    public static let coralDeep: UInt32 = 0xE04360
    public static let coralWarm: UInt32 = 0xFB7E62
    public static let apricot: UInt32 = 0xFFA94D
    public static let sun: UInt32 = 0xFFC93C
    public static let mint: UInt32 = 0x3BAF8C
    public static let lilac: UInt32 = 0xB79CE4
    public static let cream: UInt32 = 0xFFF6EE
    public static let ink: UInt32 = 0x46323C
    /// 보조 텍스트. 흰 배경과 크림 배경 모두에서 본문 기준을 넘겨야 한다.
    public static let muted: UInt32 = 0x7E6A74
    public static let shell: UInt32 = 0xF1E2D6
    /// 저장 실패 같은 문제 상황 문구.
    public static let alert: UInt32 = 0xC8324C
    public static let white: UInt32 = 0xFFFFFF

    /// 본문·캡션에 쓰는 색. 흰 배경과 크림 배경 모두에서 4.5:1 이상이어야 한다.
    public static let bodyTextColors: [UInt32] = [ink, muted, alert]
    /// 흰 글자를 얹는 배경. 굵은 버튼 글자 기준 3:1 이상이어야 한다.
    public static let whiteOnColorBackgrounds: [UInt32] = [coral, coralDeep]
    /// ink 글리프를 얹는 아이콘 칩 배경. 비텍스트 기준 3:1 이상이어야 한다.
    public static let inkOnChipBackgrounds: [UInt32] = [apricot, sun, mint, lilac, coral, shell]

    /// WCAG 2.1 상대휘도.
    public static func relativeLuminance(_ hex: UInt32) -> Double {
        func channel(_ raw: UInt32) -> Double {
            let value = Double(raw) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = channel((hex >> 16) & 0xFF)
        let green = channel((hex >> 8) & 0xFF)
        let blue = channel(hex & 0xFF)
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    /// WCAG 2.1 대비비. 1.0 ~ 21.0.
    public static func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let first = relativeLuminance(a)
        let second = relativeLuminance(b)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
```

- [ ] **Step 2: 테스트를 쓴다**

`SDPaletteTests.swift`:

```swift
import XCTest
@testable import CoachingKit

final class SDPaletteTests: XCTestCase {
    private func name(_ hex: UInt32) -> String { String(format: "#%06X", hex) }

    func test_contrastRatio_isSymmetricAndBounded() {
        XCTAssertEqual(SDPalette.contrastRatio(0x000000, 0xFFFFFF), 21.0, accuracy: 0.01)
        XCTAssertEqual(SDPalette.contrastRatio(0xFFFFFF, 0x000000), 21.0, accuracy: 0.01)
        XCTAssertEqual(SDPalette.contrastRatio(0x7E6A74, 0x7E6A74), 1.0, accuracy: 0.001)
    }

    /// 본문과 캡션은 흰 카드 위에도, 크림 배경 위에도 올라간다.
    func test_bodyTextColors_meetAAOnBothBackgrounds() {
        for color in SDPalette.bodyTextColors {
            let onWhite = SDPalette.contrastRatio(color, SDPalette.white)
            let onCream = SDPalette.contrastRatio(color, SDPalette.cream)
            XCTAssertGreaterThanOrEqual(onWhite, 4.5, "\(name(color)) on white")
            XCTAssertGreaterThanOrEqual(onCream, 4.5, "\(name(color)) on cream")
        }
    }

    /// 버튼 라벨은 15pt 굵은 글씨라 큰 글자 기준 3:1이 적용된다.
    func test_whiteOnColorBackgrounds_meetLargeTextMinimum() {
        for background in SDPalette.whiteOnColorBackgrounds {
            let ratio = SDPalette.contrastRatio(SDPalette.white, background)
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "white on \(name(background))")
        }
    }

    func test_inkGlyphOnChipBackgrounds_meetNonTextMinimum() {
        for background in SDPalette.inkOnChipBackgrounds {
            let ratio = SDPalette.contrastRatio(SDPalette.ink, background)
            XCTAssertGreaterThanOrEqual(ratio, 3.0, "ink on \(name(background))")
        }
    }

    /// 흰 글자를 쓰면 안 되는 배경이 whiteOnColorBackgrounds에 섞여 들어오지 않게 한다.
    func test_lightChipBackgrounds_areNotUsedForWhiteText() {
        for background in [SDPalette.sun, SDPalette.apricot, SDPalette.lilac, SDPalette.mint] {
            XCTAssertFalse(
                SDPalette.whiteOnColorBackgrounds.contains(background),
                "\(name(background))는 흰 글자를 받기에 너무 밝다"
            )
        }
    }

    func test_countdownColor_isReadableOnCream() {
        XCTAssertGreaterThanOrEqual(SDPalette.contrastRatio(SDPalette.ink, SDPalette.cream), 4.5)
    }
}
```

- [ ] **Step 3: 실행한다**

```bash
cd CoachingKit && swift test --filter SDPaletteTests
```

Expected: 6 tests pass.

- [ ] **Step 4: 커밋한다**

```bash
git add CoachingKit/Sources/CoachingKit/SDPalette.swift CoachingKit/Tests/CoachingKitTests/SDPaletteTests.swift
git commit -m "feat: pin palette contrast with tests in CoachingKit"
```

---

### Task 2: Theme과 뷰의 대비 적용

**Files:**

- Modify: `SmileDay/Views/Theme.swift`
- Modify: `SmileDay/Views/Coaching/SmileGuideView.swift`
- Modify: `SmileDay/Views/Home/SmileMVPHomeView.swift`

- [ ] **Step 1: `SDColor`가 `SDPalette`를 쓰게 한다**

`Theme.swift`의 `SDColor`를 다음으로 바꾼다. `Color(hex:)`는 `UInt32`를 받으므로 시그니처는 그대로다.

```swift
enum SDColor {
    static let coral = Color(hex: SDPalette.coral)
    static let coralDeep = Color(hex: SDPalette.coralDeep)
    static let coralWarm = Color(hex: SDPalette.coralWarm)
    static let apricot = Color(hex: SDPalette.apricot)
    static let sun = Color(hex: SDPalette.sun)
    static let mint = Color(hex: SDPalette.mint)
    static let lilac = Color(hex: SDPalette.lilac)
    static let cream = Color(hex: SDPalette.cream)
    static let ink = Color(hex: SDPalette.ink)
    static let muted = Color(hex: SDPalette.muted)
    static let shell = Color(hex: SDPalette.shell)
    static let alert = Color(hex: SDPalette.alert)

    /// 흰 글자를 얹으므로 밝은 쪽 끝(coralWarm)을 쓰지 않는다.
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [coralDeep, coral], startPoint: .leading, endPoint: .trailing)
    }
}
```

- [ ] **Step 2: 카운트다운 숫자를 `ink`로 바꾼다**

`SmileGuideView.swift`의 `.running` 케이스에서 `.foregroundStyle(SDColor.coral)`을 `.foregroundStyle(SDColor.ink)`로 바꾼다.

- [ ] **Step 3: 저장 실패 문구를 `alert`로 바꾼다**

같은 파일 `.completed` 케이스의 `.foregroundStyle(SDColor.coralDeep)`을 `.foregroundStyle(SDColor.alert)`로 바꾼다.

- [ ] **Step 4: 아이콘 칩 글리프를 `ink`로 바꾼다**

`SmileMVPHomeView.swift`의 `NextReminderCard`에서 종 아이콘의 `.foregroundStyle(.white)`를 `.foregroundStyle(SDColor.ink)`로 바꾼다.

- [ ] **Step 5: 남은 `.white` 글리프와 `coralDeep` 문구를 찾는다**

```bash
rg -n 'foregroundStyle\(\.white\)|SDColor\.coralDeep' \
  SmileDay/Views/Home/SmileMVPHomeView.swift \
  SmileDay/Views/Coaching/SmileGuideView.swift \
  SmileDay/Views/Settings/SmileMVPSettingsView.swift \
  SmileDay/Views/Onboarding/SmileMVPOnboardingView.swift \
  SmileDay/Views/Theme.swift
```

`primaryGradient` 위에 얹힌 흰 글자(버튼 라벨, 선택된 칩, 도트 숫자)는 그대로 둔다. 밝은 단색 칩 위의 흰 글자만 `ink`로 바꾼다.

- [ ] **Step 6: 빌드한다**

```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: 커밋한다**

```bash
git add SmileDay/Views
git commit -m "fix: raise text and glyph contrast to WCAG AA"
```

---

### Task 3: DaySlot과 상황 카드 카탈로그

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/SmileGuide.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileGuideTests.swift`

- [ ] **Step 1: `DaySlot`과 새 `SmileGuide`를 쓴다**

`SmileGuide.swift`를 통째로 바꾼다.

```swift
import Foundation

/// 카드가 어울리는 시간대. `anytime`은 시간과 무관한 카드다.
public enum DaySlot: String, CaseIterable, Equatable, Sendable {
    case morning
    case afternoon
    case evening
    case anytime

    /// 시각으로부터 고른다. `anytime`은 돌려주지 않는다.
    public init(hour: Int) {
        switch hour {
        case 5...10: self = .morning
        case 11...16: self = .afternoon
        default: self = .evening
        }
    }

    public var displayName: String {
        switch self {
        case .morning: "아침"
        case .afternoon: "낮"
        case .evening: "저녁"
        case .anytime: "언제든"
        }
    }

    /// 목록에 보여주는 순서.
    public var sortIndex: Int {
        switch self {
        case .morning: 0
        case .afternoon: 1
        case .evening: 2
        case .anytime: 3
        }
    }
}

/// 알림과 화면에서 안내할 상황 카드 하나.
///
/// 얼굴을 측정하지 않으므로 "얼마나 잘 웃었는지"는 어디에도 없다. 문구는 지금 할 수 있는
/// 행동만 짧게 안내하고, 표정으로 인상이나 기분이 나아진다고 약속하지 않는다.
public struct SmileGuide: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let instruction: String
    public let slot: DaySlot
    public let durationSeconds: Int
    public let isBuiltIn: Bool

    public init(
        id: String,
        title: String,
        instruction: String,
        slot: DaySlot,
        durationSeconds: Int = SmileGuideCatalog.defaultDurationSeconds,
        isBuiltIn: Bool
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.slot = slot
        self.durationSeconds = durationSeconds
        self.isBuiltIn = isBuiltIn
    }
}

public enum SmileGuideCatalog {
    public static let defaultDurationSeconds = 5
    /// 사용자가 안내 문구를 비웠을 때 쓰는 문장.
    public static let defaultInstruction = "턱과 어깨 힘을 빼고 입꼬리를 살짝 올려보세요."

    public static let builtIn: [SmileGuide] = [
        SmileGuide(id: "morning-greeting", title: "출근 후 웃으며 인사하기",
                   instruction: "어깨 힘을 빼고, 반갑게 인사하는 표정을 지어보세요.",
                   slot: .morning, isBuiltIn: true),
        SmileGuide(id: "morning-mirror", title: "거울 볼 때 한 번 웃기",
                   instruction: "거울 속 나를 보며 입꼬리를 살짝 올려보세요.",
                   slot: .morning, isBuiltIn: true),
        SmileGuide(id: "morning-leaving", title: "집을 나서기 전 한 번 웃기",
                   instruction: "문을 나서기 전, 턱 힘을 빼고 웃어보세요.",
                   slot: .morning, isBuiltIn: true),
        SmileGuide(id: "morning-coffee", title: "첫 커피 마시며 숨 고르기",
                   instruction: "한 모금 마시고 천천히 숨을 내쉬며 웃어보세요.",
                   slot: .morning, isBuiltIn: true),

        SmileGuide(id: "noon-before-meeting", title: "회의 시작 전 표정 풀기",
                   instruction: "이마와 미간의 힘을 빼고 입꼬리를 올려보세요.",
                   slot: .afternoon, isBuiltIn: true),
        SmileGuide(id: "noon-before-lunch", title: "점심 먹기 전 숨 고르고 웃기",
                   instruction: "수저를 들기 전 어깨를 내리고 웃어보세요.",
                   slot: .afternoon, isBuiltIn: true),
        SmileGuide(id: "noon-before-call", title: "전화 받기 전 입꼬리 올리기",
                   instruction: "목소리를 내기 전에 표정을 먼저 준비해보세요.",
                   slot: .afternoon, isBuiltIn: true),
        SmileGuide(id: "noon-stand-up", title: "자리에서 일어날 때 어깨 내리기",
                   instruction: "일어서면서 어깨를 내리고 한 번 웃어보세요.",
                   slot: .afternoon, isBuiltIn: true),

        SmileGuide(id: "evening-after-work", title: "퇴근 후 어깨 힘 빼고 웃기",
                   instruction: "하루를 내려놓듯 어깨를 낮추고 웃어보세요.",
                   slot: .evening, isBuiltIn: true),
        SmileGuide(id: "evening-coming-home", title: "집에 들어가며 인사하기",
                   instruction: "문을 열기 전, 반갑게 인사하는 표정을 지어보세요.",
                   slot: .evening, isBuiltIn: true),
        SmileGuide(id: "evening-before-dinner", title: "저녁 먹기 전 한 번 웃기",
                   instruction: "자리에 앉아 숨을 고르고 입꼬리를 올려보세요.",
                   slot: .evening, isBuiltIn: true),
        SmileGuide(id: "evening-before-sleep", title: "잠들기 전 얼굴 힘 빼기",
                   instruction: "이마, 눈가, 턱 순서로 힘을 빼보세요.",
                   slot: .evening, isBuiltIn: true),

        SmileGuide(id: "anytime-pause", title: "하던 일 멈추고 웃기",
                   instruction: "손을 멈추고 5초만 편하게 웃어보세요.",
                   slot: .anytime, isBuiltIn: true),
        SmileGuide(id: "anytime-soft", title: "편안한 미소 짓기",
                   instruction: defaultInstruction,
                   slot: .anytime, isBuiltIn: true),
    ]

    /// 상황에 매이지 않아 어떤 대체 상황에서도 말이 된다.
    public static let `default`: SmileGuide = builtIn.first { $0.id == "anytime-soft" }!

    /// 표정 종류를 쓰던 시절의 ID. 저장된 알림과 기록이 엉뚱한 카드로 바뀌지 않게 연결한다.
    static let legacyIDAliases: [String: String] = [
        "soft-smile": "anytime-soft",
        "greeting-smile": "morning-greeting",
        "bright-smile": "anytime-pause",
    ]

    public static func builtInGuide(id: String?) -> SmileGuide? {
        guard let id else { return nil }
        let resolved = legacyIDAliases[id] ?? id
        return builtIn.first { $0.id == resolved }
    }

    /// 기본 카드만 찾는다. 사용자 카드까지 포함한 조회는 `SmileGuideLibrary`를 쓴다.
    public static func guide(id: String?) -> SmileGuide {
        builtInGuide(id: id) ?? `default`
    }

    public static func builtIn(in slot: DaySlot) -> [SmileGuide] {
        builtIn.filter { $0.slot == slot }
    }
}
```

- [ ] **Step 2: 테스트를 바꾼다**

`SmileGuideTests.swift`를 통째로 바꾼다.

```swift
import XCTest
@testable import CoachingKit

final class SmileGuideTests: XCTestCase {
    func test_catalog_hasFourteenGuides() {
        XCTAssertEqual(SmileGuideCatalog.builtIn.count, 14)
    }

    func test_catalog_idsAreUnique() {
        XCTAssertEqual(Set(SmileGuideCatalog.builtIn.map(\.id)).count, 14)
    }

    func test_catalog_titlesAreUnique() {
        XCTAssertEqual(Set(SmileGuideCatalog.builtIn.map(\.title)).count, 14)
    }

    func test_catalog_coversEverySlot() {
        for slot in DaySlot.allCases {
            XCTAssertFalse(SmileGuideCatalog.builtIn(in: slot).isEmpty, "\(slot) 비어 있다")
        }
    }

    func test_everyGuide_lastsFiveSeconds_andIsBuiltIn() {
        for guide in SmileGuideCatalog.builtIn {
            XCTAssertEqual(guide.durationSeconds, 5, "\(guide.id)")
            XCTAssertTrue(guide.isBuiltIn, "\(guide.id)")
        }
    }

    func test_everyGuide_hasNonEmptyCopy() {
        for guide in SmileGuideCatalog.builtIn {
            XCTAssertFalse(guide.title.isEmpty, "\(guide.id) title")
            XCTAssertFalse(guide.instruction.isEmpty, "\(guide.id) instruction")
        }
    }

    /// 건강·미용 효과를 약속하는 표현(가이드라인 1.4.1)과 점수 개념이 없어야 한다.
    func test_copy_avoidsClaimAndScoreWording() {
        let banned = ["개선", "교정", "치료", "리프팅", "젊어", "점수", "행복해", "좋아집니다", "좋아져요", "예뻐"]
        for guide in SmileGuideCatalog.builtIn {
            let copy = "\(guide.title) \(guide.instruction)"
            for word in banned {
                XCTAssertFalse(copy.contains(word), "\(guide.id)에 금지 표현 '\(word)'이 있다")
            }
        }
    }

    /// 걷거나 운전하며 화면을 보도록 유도하지 않는다. 제목에도 적용한다.
    func test_copy_doesNotUrgeUseWhileMoving() {
        let banned = ["걷는", "걸으며", "운전", "이동 중", "횡단", "퇴근길", "출근길"]
        for guide in SmileGuideCatalog.builtIn {
            let copy = "\(guide.title) \(guide.instruction)"
            for word in banned {
                XCTAssertFalse(copy.contains(word), "\(guide.id)에 '\(word)'이 있다")
            }
        }
    }

    func test_guideForID_returnsMatchingGuide() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "evening-after-work").id, "evening-after-work")
    }

    func test_guideForID_fallsBackToDefault_whenUnknownOrNil() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "no-such-guide").id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "").id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.guide(id: nil).id, "anytime-soft")
    }

    func test_default_isAnytimeSoft_andUsesDefaultInstruction() {
        XCTAssertEqual(SmileGuideCatalog.default.id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.default.instruction, SmileGuideCatalog.defaultInstruction)
    }

    // MARK: - 옛 ID

    func test_legacyIDs_resolveToNewGuides() {
        XCTAssertEqual(SmileGuideCatalog.guide(id: "soft-smile").id, "anytime-soft")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "greeting-smile").id, "morning-greeting")
        XCTAssertEqual(SmileGuideCatalog.guide(id: "bright-smile").id, "anytime-pause")
    }

    func test_legacyAliases_allPointAtRealGuides() {
        for target in SmileGuideCatalog.legacyIDAliases.values {
            XCTAssertNotNil(SmileGuideCatalog.builtIn.first { $0.id == target }, target)
        }
    }

    // MARK: - DaySlot

    func test_daySlot_fromHour_neverReturnsAnytime() {
        for hour in 0...23 {
            XCTAssertNotEqual(DaySlot(hour: hour), .anytime, "\(hour)시")
        }
    }

    func test_daySlot_boundaries() {
        XCTAssertEqual(DaySlot(hour: 5), .morning)
        XCTAssertEqual(DaySlot(hour: 10), .morning)
        XCTAssertEqual(DaySlot(hour: 11), .afternoon)
        XCTAssertEqual(DaySlot(hour: 16), .afternoon)
        XCTAssertEqual(DaySlot(hour: 17), .evening)
        XCTAssertEqual(DaySlot(hour: 4), .evening)
    }

    func test_daySlot_sortIndexOrdersMorningFirstAnytimeLast() {
        let sorted = DaySlot.allCases.sorted { $0.sortIndex < $1.sortIndex }
        XCTAssertEqual(sorted, [.morning, .afternoon, .evening, .anytime])
    }
}
```

- [ ] **Step 3: 실행한다.** 이 시점에는 `notificationText`를 쓰던 곳이 깨진다. Task 4에서 고친다.

```bash
cd CoachingKit && swift test --filter SmileGuideTests 2>&1 | grep -E "error:|Executed"
```

---

### Task 4: notificationText 제거에 따른 호출부 정리

**Files:**

- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift`

- [ ] **Step 1: 알림 본문을 `instruction`으로 바꾼다**

`scheduleRollingWindow` 안의 content 구성을 바꾼다.

```swift
let content = UNMutableNotificationContent()
content.title = guide.title
content.body = guide.instruction
content.sound = .default
content.userInfo = ReminderNotificationPayload(reminderID: id, guideID: guide.id).userInfo
```

- [ ] **Step 2: 다른 사용처가 없는지 확인한다**

```bash
rg -n 'notificationText' SmileDay CoachingKit --glob '*.swift'
```

Expected: 결과 없음.

- [ ] **Step 3: 패키지 테스트를 돌린다**

```bash
cd CoachingKit && swift test 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```

---

### Task 5: CustomSmileCard 모델

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/CustomSmileCard.swift`
- Modify: `CoachingKit/Sources/CoachingKit/PersistenceSchema.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/CustomSmileCardTests.swift`

- [ ] **Step 1: 모델을 쓴다**

```swift
import Foundation
import SwiftData

/// 사용자가 직접 만든 상황 카드. 기본 카드는 코드 상수라 여기 들어오지 않는다.
@Model
public final class CustomSmileCard {
    @Attribute(.unique) public var id: String
    public var title: String
    /// nil이면 기본 안내 문구를 쓴다.
    public var instructionText: String?
    public var slotRawValue: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        title: String,
        instructionText: String? = nil,
        slot: DaySlot,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.instructionText = instructionText
        self.slotRawValue = slot.rawValue
        self.createdAt = createdAt
    }

    /// 알 수 없는 값은 `.anytime`으로 읽는다.
    public var slot: DaySlot {
        get { DaySlot(rawValue: slotRawValue) ?? .anytime }
        set { slotRawValue = newValue.rawValue }
    }

    public var guide: SmileGuide {
        SmileGuide(
            id: id,
            title: title,
            instruction: instructionText ?? SmileGuideCatalog.defaultInstruction,
            slot: slot,
            isBuiltIn: false
        )
    }
}
```

- [ ] **Step 2: 스키마에 넣는다**

```swift
public static let models: [any PersistentModel.Type] = [
    Baseline.self, CheckInSession.self, ReminderSetting.self, CareSession.self,
    SmileMoment.self, CustomSmileCard.self
]
```

- [ ] **Step 3: 테스트를 쓴다**

```swift
import XCTest
@testable import CoachingKit

final class CustomSmileCardTests: XCTestCase {
    func test_guide_usesTypedInstruction() {
        let card = CustomSmileCard(title: "엘리베이터에서 웃기", instructionText: "문이 닫히면 한 번 웃어보세요.", slot: .anytime)

        XCTAssertEqual(card.guide.instruction, "문이 닫히면 한 번 웃어보세요.")
        XCTAssertEqual(card.guide.title, "엘리베이터에서 웃기")
        XCTAssertFalse(card.guide.isBuiltIn)
    }

    func test_guide_fallsBackToDefaultInstruction_whenBlank() {
        let card = CustomSmileCard(title: "엘리베이터에서 웃기", instructionText: nil, slot: .anytime)

        XCTAssertEqual(card.guide.instruction, SmileGuideCatalog.defaultInstruction)
    }

    func test_guide_lastsFiveSeconds() {
        XCTAssertEqual(CustomSmileCard(title: "제목", slot: .morning).guide.durationSeconds, 5)
    }

    func test_slot_roundTrips() {
        for slot in DaySlot.allCases {
            XCTAssertEqual(CustomSmileCard(title: "제목", slot: slot).slot, slot)
        }
    }

    func test_slot_fallsBackToAnytime_whenRawValueUnknown() {
        let card = CustomSmileCard(title: "제목", slot: .morning)
        card.slotRawValue = "midnight"

        XCTAssertEqual(card.slot, .anytime)
    }

    func test_schema_containsCustomSmileCard_andKeepsLegacyModels() {
        let names = PersistenceSchema.models.map { String(describing: $0) }
        for expected in ["Baseline", "CheckInSession", "ReminderSetting", "CareSession", "SmileMoment", "CustomSmileCard"] {
            XCTAssertTrue(names.contains(expected), expected)
        }
    }
}
```

- [ ] **Step 4: 실행하고 커밋한다**

```bash
cd CoachingKit && swift test --filter 'CustomSmileCardTests|SmileGuideTests'
```

---

### Task 6: 숨긴 기본 카드 저장소

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/HiddenSmileGuideStore.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/HiddenSmileGuideStoreTests.swift`

- [ ] **Step 1: 프로토콜과 두 구현을 쓴다**

```swift
import Foundation

/// 목록에서 숨긴 기본 카드 ID. 기본 카드는 코드 상수라 삭제할 수 없고 숨기기만 한다.
public protocol HiddenSmileGuideStoring: AnyObject {
    var hiddenGuideIDs: Set<String> { get set }
}

public final class UserDefaultsHiddenSmileGuideStore: HiddenSmileGuideStoring {
    private static let key = "hiddenSmileGuideIDs"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hiddenGuideIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.key) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Self.key) }
    }
}

public final class InMemoryHiddenSmileGuideStore: HiddenSmileGuideStoring {
    public var hiddenGuideIDs: Set<String>

    public init(hiddenGuideIDs: Set<String> = []) {
        self.hiddenGuideIDs = hiddenGuideIDs
    }
}
```

- [ ] **Step 2: 테스트를 쓴다**

```swift
import XCTest
@testable import CoachingKit

final class HiddenSmileGuideStoreTests: XCTestCase {
    private let suite = "HiddenSmileGuideStoreTests"

    func test_inMemoryStore_startsEmpty() {
        XCTAssertTrue(InMemoryHiddenSmileGuideStore().hiddenGuideIDs.isEmpty)
    }

    func test_userDefaultsStore_roundTripsIDs() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = UserDefaultsHiddenSmileGuideStore(defaults: defaults)

        XCTAssertTrue(store.hiddenGuideIDs.isEmpty)
        store.hiddenGuideIDs = ["morning-coffee", "noon-before-call"]

        let reopened = UserDefaultsHiddenSmileGuideStore(defaults: defaults)
        XCTAssertEqual(reopened.hiddenGuideIDs, ["morning-coffee", "noon-before-call"])

        defaults.removePersistentDomain(forName: suite)
    }

    func test_userDefaultsStore_removingLeavesEmptySet() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let store = UserDefaultsHiddenSmileGuideStore(defaults: defaults)
        store.hiddenGuideIDs = ["morning-coffee"]

        store.hiddenGuideIDs = []

        XCTAssertTrue(UserDefaultsHiddenSmileGuideStore(defaults: defaults).hiddenGuideIDs.isEmpty)
        defaults.removePersistentDomain(forName: suite)
    }
}
```

- [ ] **Step 3: 실행한다**

```bash
cd CoachingKit && swift test --filter HiddenSmileGuideStoreTests
```

---

### Task 7: SmileGuideLibrary

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileGuideLibrary.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileGuideLibraryTests.swift`

- [ ] **Step 1: 라이브러리를 쓴다**

```swift
import Foundation
import SwiftData

public enum SmileGuideLibraryError: Error, Equatable {
    case blankTitle
}

/// 기본 카드와 사용자 카드를 합쳐 내놓는 단 한 곳.
public final class SmileGuideLibrary {
    private let modelContext: ModelContext
    private let hiddenStore: HiddenSmileGuideStoring

    public init(modelContext: ModelContext, hiddenStore: HiddenSmileGuideStoring) {
        self.modelContext = modelContext
        self.hiddenStore = hiddenStore
    }

    /// 목록에 보이는 카드. 시간대순, 같은 시간대에서는 기본 카드가 먼저, 내 카드는 만든 순.
    public func visibleGuides() throws -> [SmileGuide] {
        let hidden = hiddenStore.hiddenGuideIDs
        let builtIn = SmileGuideCatalog.builtIn.filter { !hidden.contains($0.id) }
        let custom = try customCards().map(\.guide)

        return DaySlot.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .flatMap { slot in
                builtIn.filter { $0.slot == slot } + custom.filter { $0.slot == slot }
            }
    }

    /// 숨기거나 지운 카드도 찾아준다 — 지난 기록과 예약된 알림이 이름을 잃지 않도록.
    /// 어디에도 없는 ID만 기본 카드로 떨어진다.
    public func guide(id: String?) -> SmileGuide {
        guard let id else { return SmileGuideCatalog.default }
        if let builtIn = SmileGuideCatalog.builtInGuide(id: id) { return builtIn }
        if let custom = try? customCard(id: id) { return custom.guide }
        return SmileGuideCatalog.default
    }

    public func hiddenBuiltInGuides() -> [SmileGuide] {
        let hidden = hiddenStore.hiddenGuideIDs
        return SmileGuideCatalog.builtIn.filter { hidden.contains($0.id) }
    }

    @discardableResult
    public func addCustom(title: String, instruction: String?, slot: DaySlot) throws -> SmileGuide {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw SmileGuideLibraryError.blankTitle }

        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let card = CustomSmileCard(
            title: trimmedTitle,
            instructionText: (trimmedInstruction?.isEmpty ?? true) ? nil : trimmedInstruction,
            slot: slot
        )
        modelContext.insert(card)
        try modelContext.save()
        return card.guide
    }

    public func removeCustom(id: String) throws {
        guard let card = try customCard(id: id) else { return }
        modelContext.delete(card)
        try modelContext.save()
    }

    public func hideBuiltIn(id: String) {
        guard SmileGuideCatalog.builtInGuide(id: id) != nil else { return }
        hiddenStore.hiddenGuideIDs.insert(id)
    }

    public func restoreBuiltIn(id: String) {
        hiddenStore.hiddenGuideIDs.remove(id)
    }

    private func customCards() throws -> [CustomSmileCard] {
        try modelContext.fetch(FetchDescriptor<CustomSmileCard>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func customCard(id: String) throws -> CustomSmileCard? {
        try modelContext.fetch(FetchDescriptor<CustomSmileCard>(predicate: #Predicate { $0.id == id })).first
    }
}
```

- [ ] **Step 2: 테스트를 쓴다**

```swift
import XCTest
import SwiftData
@testable import CoachingKit

final class SmileGuideLibraryTests: XCTestCase {
    private func makeLibrary() throws -> (SmileGuideLibrary, InMemoryHiddenSmileGuideStore) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let hidden = InMemoryHiddenSmileGuideStore()
        return (SmileGuideLibrary(modelContext: ModelContext(container), hiddenStore: hidden), hidden)
    }

    // MARK: - 목록

    func test_visibleGuides_startsWithEveryBuiltInCard() throws {
        let (library, _) = try makeLibrary()

        XCTAssertEqual(try library.visibleGuides().count, 14)
    }

    func test_visibleGuides_areOrderedBySlot() throws {
        let (library, _) = try makeLibrary()

        let slots = try library.visibleGuides().map(\.slot.sortIndex)

        XCTAssertEqual(slots, slots.sorted(), "아침 → 낮 → 저녁 → 언제든 순이어야 한다")
    }

    func test_visibleGuides_placeCustomCardAfterBuiltInsOfSameSlot() throws {
        let (library, _) = try makeLibrary()
        try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .morning)

        let morning = try library.visibleGuides().filter { $0.slot == .morning }

        XCTAssertEqual(morning.last?.title, "엘리베이터에서 웃기")
        XCTAssertTrue(morning.dropLast().allSatisfy(\.isBuiltIn))
    }

    // MARK: - 추가

    func test_addCustom_appearsInVisibleGuides() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertEqual(try library.visibleGuides().count, 15)
        XCTAssertEqual(library.guide(id: added.id).title, "엘리베이터에서 웃기")
    }

    func test_addCustom_withoutInstruction_usesDefaultInstruction() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertEqual(added.instruction, SmileGuideCatalog.defaultInstruction)
    }

    func test_addCustom_withBlankInstruction_usesDefaultInstruction() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: "   ", slot: .anytime)

        XCTAssertEqual(added.instruction, SmileGuideCatalog.defaultInstruction)
    }

    func test_addCustom_trimsTitle() throws {
        let (library, _) = try makeLibrary()

        let added = try library.addCustom(title: "  엘리베이터에서 웃기  ", instruction: nil, slot: .anytime)

        XCTAssertEqual(added.title, "엘리베이터에서 웃기")
    }

    func test_addCustom_rejectsBlankTitle() throws {
        let (library, _) = try makeLibrary()

        XCTAssertThrowsError(try library.addCustom(title: "   ", instruction: nil, slot: .anytime)) { error in
            XCTAssertEqual(error as? SmileGuideLibraryError, .blankTitle)
        }
        XCTAssertEqual(try library.visibleGuides().count, 14)
    }

    // MARK: - 삭제와 숨기기

    func test_removeCustom_dropsItFromList_butKeepsNameLookup() throws {
        let (library, _) = try makeLibrary()
        let added = try library.addCustom(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        try library.removeCustom(id: added.id)

        XCTAssertEqual(try library.visibleGuides().count, 14)
        XCTAssertEqual(library.guide(id: added.id).id, SmileGuideCatalog.default.id,
                       "완전히 사라진 카드는 기본 카드로 떨어진다")
    }

    func test_removeCustom_isNoOp_whenIDUnknown() throws {
        let (library, _) = try makeLibrary()

        XCTAssertNoThrow(try library.removeCustom(id: "no-such-card"))
        XCTAssertEqual(try library.visibleGuides().count, 14)
    }

    func test_hideBuiltIn_removesFromListButKeepsNameLookup() throws {
        let (library, _) = try makeLibrary()

        library.hideBuiltIn(id: "morning-coffee")

        XCTAssertEqual(try library.visibleGuides().count, 13)
        XCTAssertFalse(try library.visibleGuides().contains { $0.id == "morning-coffee" })
        XCTAssertEqual(library.guide(id: "morning-coffee").title, "첫 커피 마시며 숨 고르기",
                       "숨긴 카드도 이름은 찾아져야 한다")
    }

    func test_hiddenBuiltInGuides_listsWhatWasHidden() throws {
        let (library, _) = try makeLibrary()
        library.hideBuiltIn(id: "morning-coffee")
        library.hideBuiltIn(id: "noon-before-call")

        XCTAssertEqual(Set(library.hiddenBuiltInGuides().map(\.id)), ["morning-coffee", "noon-before-call"])
    }

    func test_restoreBuiltIn_bringsItBack() throws {
        let (library, _) = try makeLibrary()
        library.hideBuiltIn(id: "morning-coffee")

        library.restoreBuiltIn(id: "morning-coffee")

        XCTAssertEqual(try library.visibleGuides().count, 14)
        XCTAssertTrue(library.hiddenBuiltInGuides().isEmpty)
    }

    func test_hideBuiltIn_ignoresUnknownID() throws {
        let (library, hidden) = try makeLibrary()

        library.hideBuiltIn(id: "no-such-card")

        XCTAssertTrue(hidden.hiddenGuideIDs.isEmpty)
    }

    // MARK: - 조회

    func test_guideForID_resolvesLegacyIDs() throws {
        let (library, _) = try makeLibrary()

        XCTAssertEqual(library.guide(id: "soft-smile").id, "anytime-soft")
        XCTAssertEqual(library.guide(id: "greeting-smile").id, "morning-greeting")
        XCTAssertEqual(library.guide(id: "bright-smile").id, "anytime-pause")
    }

    func test_guideForID_fallsBackToDefault_whenNilOrUnknown() throws {
        let (library, _) = try makeLibrary()

        XCTAssertEqual(library.guide(id: nil).id, "anytime-soft")
        XCTAssertEqual(library.guide(id: "no-such-card").id, "anytime-soft")
    }
}
```

- [ ] **Step 3: 실행한다**

```bash
cd CoachingKit && swift test --filter SmileGuideLibraryTests
```

---

### Task 8: 알림에서 카드 역참조

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/ReminderRepository.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderRepositoryTests.swift`

- [ ] **Step 1: 조회를 추가한다**

`ReminderRepository`에 넣는다.

```swift
/// 이 카드를 쓰는 알림. guideID가 nil인 알림은 기본 카드를 쓰는 것으로 친다.
public func reminders(usingGuideID guideID: String) throws -> [ReminderSetting] {
    let isDefault = guideID == SmileGuideCatalog.default.id
    return try fetchAll().filter { reminder in
        if let stored = reminder.guideID { return SmileGuideCatalog.guide(id: stored).id == guideID }
        return isDefault
    }
}
```

- [ ] **Step 2: `ReminderSetting.guide`가 라이브러리를 모르는 점을 그대로 둔다**

`ReminderSetting.guide`는 기본 카탈로그만 본다. 사용자 카드까지 포함한 해석은 `SmileGuideLibrary.guide(id:)`가 한다. 알림 예약과 화면은 라이브러리를 거친다.

- [ ] **Step 3: 테스트를 더한다**

`ReminderRepositoryTests`의 "미소 가이드" 섹션 끝에 붙인다. 기존 테스트 중 `soft-smile`, `greeting-smile`, `bright-smile`을 쓰는 곳은 각각 `anytime-soft`, `morning-greeting`, `anytime-pause`로 바꾼다.

```swift
func test_remindersUsingGuideID_findsMatchingReminders() throws {
    let repository = ReminderRepository(modelContext: try makeInMemoryContext())
    try repository.add(hour: 9, minute: 0, guideID: "morning-greeting")
    try repository.add(hour: 13, minute: 0, guideID: "morning-greeting")
    try repository.add(hour: 18, minute: 0, guideID: "evening-after-work")

    let matches = try repository.reminders(usingGuideID: "morning-greeting")

    XCTAssertEqual(matches.map(\.hour), [9, 13])
}

/// guideID가 nil인 옛 알림은 기본 카드를 쓰는 것으로 친다.
func test_remindersUsingGuideID_countsLegacyNilAsDefault() throws {
    let repository = ReminderRepository(modelContext: try makeInMemoryContext())
    try repository.add(hour: 9, minute: 0)
    try repository.add(hour: 18, minute: 0, guideID: "evening-after-work")

    XCTAssertEqual(try repository.reminders(usingGuideID: SmileGuideCatalog.default.id).map(\.hour), [9])
}

func test_remindersUsingGuideID_matchesThroughLegacyAlias() throws {
    let repository = ReminderRepository(modelContext: try makeInMemoryContext())
    try repository.add(hour: 9, minute: 0, guideID: "greeting-smile")

    XCTAssertEqual(try repository.reminders(usingGuideID: "morning-greeting").count, 1)
}

func test_remindersUsingGuideID_returnsEmpty_whenNoneMatch() throws {
    let repository = ReminderRepository(modelContext: try makeInMemoryContext())
    try repository.add(hour: 9, minute: 0, guideID: "morning-greeting")

    XCTAssertTrue(try repository.reminders(usingGuideID: "evening-before-sleep").isEmpty)
}
```

- [ ] **Step 4: 실행한다**

```bash
cd CoachingKit && swift test --filter ReminderRepositoryTests
```

---

### Task 9: 카드 관리 ViewModel

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileLibraryViewModel.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileLibraryViewModelTests.swift`

- [ ] **Step 1: ViewModel을 쓴다**

```swift
import Foundation
import Observation

/// 카드를 지우기 전에 보여줄 영향 범위.
public struct GuideRemovalImpact: Equatable, Sendable {
    public let guide: SmileGuide
    /// 이 카드를 쓰는 알림의 시각. "09:00" 형식.
    public let affectedReminderTimes: [String]
    public let replacement: SmileGuide

    public var isInUse: Bool { !affectedReminderTimes.isEmpty }
}

/// 미소 카드 목록 관리 화면 상태.
@MainActor
@Observable
public final class SmileLibraryViewModel {
    public private(set) var guides: [SmileGuide] = []
    public private(set) var hiddenGuides: [SmileGuide] = []
    public private(set) var errorMessage: String?

    private let library: SmileGuideLibrary
    private let reminderRepository: ReminderRepository
    private let scheduler: ReminderScheduling

    public init(
        library: SmileGuideLibrary,
        reminderRepository: ReminderRepository,
        scheduler: ReminderScheduling
    ) {
        self.library = library
        self.reminderRepository = reminderRepository
        self.scheduler = scheduler
    }

    public func refresh() throws {
        guides = try library.visibleGuides()
        hiddenGuides = library.hiddenBuiltInGuides()
    }

    public func addCard(title: String, instruction: String?, slot: DaySlot) throws {
        do {
            try library.addCustom(title: title, instruction: instruction, slot: slot)
            errorMessage = nil
        } catch SmileGuideLibraryError.blankTitle {
            errorMessage = "상황 이름을 적어주세요."
            throw SmileGuideLibraryError.blankTitle
        }
        try refresh()
    }

    /// 지우기 전에 보여줄 내용. 화면이 이걸로 확인 문구를 만든다.
    public func removalImpact(for guide: SmileGuide) throws -> GuideRemovalImpact {
        let affected = try reminderRepository.reminders(usingGuideID: guide.id)
        return GuideRemovalImpact(
            guide: guide,
            affectedReminderTimes: affected.map { String(format: "%02d:%02d", $0.hour, $0.minute) },
            replacement: replacement(for: guide)
        )
    }

    /// 기본 카드는 숨기고 내 카드는 지운다. 그 카드를 쓰던 알림은 대체 카드로 바꿔 다시 예약한다.
    public func remove(_ guide: SmileGuide) async throws {
        let affected = try reminderRepository.reminders(usingGuideID: guide.id)
        let replacement = replacement(for: guide)

        for reminder in affected {
            try reminderRepository.updateGuide(reminder, guideID: replacement.id)
        }

        if guide.isBuiltIn {
            library.hideBuiltIn(id: guide.id)
        } else {
            try library.removeCustom(id: guide.id)
        }

        // 예약된 14일치가 사라진 카드의 문구를 들고 나가지 않도록 다시 채운다.
        for reminder in affected where reminder.isEnabled {
            await scheduler.scheduleRollingWindow(
                id: reminder.notificationID,
                hour: reminder.hour,
                minute: reminder.minute,
                guideID: replacement.id,
                days: reminderRollingWindowDays
            )
        }

        try refresh()
    }

    public func restore(_ guide: SmileGuide) throws {
        library.restoreBuiltIn(id: guide.id)
        try refresh()
    }

    /// 기본 카드를 지우면 같은 시간대의 다른 카드로, 없으면 전체 기본 카드로 넘긴다.
    private func replacement(for guide: SmileGuide) -> SmileGuide {
        let candidates = (try? library.visibleGuides()) ?? []
        if let sameSlot = candidates.first(where: { $0.slot == guide.slot && $0.id != guide.id }) {
            return sameSlot
        }
        if let any = candidates.first(where: { $0.id != guide.id }) {
            return any
        }
        return SmileGuideCatalog.default
    }
}
```

- [ ] **Step 2: 테스트를 쓴다**

```swift
import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class SmileLibraryViewModelTests: XCTestCase {
    private final class MockScheduler: ReminderScheduling {
        private(set) var scheduled: [(id: String, hour: Int, minute: Int, guideID: String, days: Int)] = []
        private(set) var cancelled: [String] = []
        var status: ReminderAuthorizationStatus = .authorized

        func requestAuthorization() async -> Bool { true }
        func currentAuthorizationStatus() async -> ReminderAuthorizationStatus { status }
        func scheduleRollingWindow(id: String, hour: Int, minute: Int, guideID: String, days: Int) async {
            scheduled.append((id, hour, minute, guideID, days))
        }
        func cancel(id: String) { cancelled.append(id) }
    }

    private func makeViewModel() throws -> (SmileLibraryViewModel, ReminderRepository, MockScheduler) {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        let reminders = ReminderRepository(modelContext: context)
        let scheduler = MockScheduler()
        let viewModel = SmileLibraryViewModel(
            library: SmileGuideLibrary(modelContext: context, hiddenStore: InMemoryHiddenSmileGuideStore()),
            reminderRepository: reminders,
            scheduler: scheduler
        )
        return (viewModel, reminders, scheduler)
    }

    func test_refresh_listsBuiltInCards() throws {
        let (viewModel, _, _) = try makeViewModel()

        try viewModel.refresh()

        XCTAssertEqual(viewModel.guides.count, 14)
        XCTAssertTrue(viewModel.hiddenGuides.isEmpty)
    }

    func test_addCard_appearsInList() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        try viewModel.addCard(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)

        XCTAssertEqual(viewModel.guides.count, 15)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_addCard_blankTitle_setsKoreanError() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        XCTAssertThrowsError(try viewModel.addCard(title: "  ", instruction: nil, slot: .anytime))

        XCTAssertEqual(viewModel.errorMessage, "상황 이름을 적어주세요.")
        XCTAssertEqual(viewModel.guides.count, 14)
    }

    // MARK: - 삭제 전 안내

    func test_removalImpact_listsAffectedReminderTimes() throws {
        let (viewModel, reminders, _) = try makeViewModel()
        try reminders.add(hour: 9, minute: 0, guideID: "morning-greeting")
        try reminders.add(hour: 13, minute: 30, guideID: "morning-greeting")
        try viewModel.refresh()

        let impact = try viewModel.removalImpact(for: SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertEqual(impact.affectedReminderTimes, ["09:00", "13:30"])
        XCTAssertTrue(impact.isInUse)
        XCTAssertNotEqual(impact.replacement.id, "morning-greeting")
    }

    func test_removalImpact_isNotInUse_whenNoReminderPointsAtIt() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        let impact = try viewModel.removalImpact(for: SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertFalse(impact.isInUse)
    }

    func test_removalImpact_replacementSharesSlot() throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        let impact = try viewModel.removalImpact(for: SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertEqual(impact.replacement.slot, .morning)
    }

    // MARK: - 삭제

    func test_remove_builtIn_hidesItAndKeepsNameLookup() async throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()

        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-coffee"))

        XCTAssertEqual(viewModel.guides.count, 13)
        XCTAssertEqual(viewModel.hiddenGuides.map(\.id), ["morning-coffee"])
    }

    func test_remove_custom_deletesIt() async throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()
        try viewModel.addCard(title: "엘리베이터에서 웃기", instruction: nil, slot: .anytime)
        let added = try XCTUnwrap(viewModel.guides.first { !$0.isBuiltIn })

        try await viewModel.remove(added)

        XCTAssertEqual(viewModel.guides.count, 14)
        XCTAssertTrue(viewModel.hiddenGuides.isEmpty)
    }

    func test_remove_reassignsAffectedRemindersAndReschedules() async throws {
        let (viewModel, reminders, scheduler) = try makeViewModel()
        try reminders.add(hour: 9, minute: 0, guideID: "morning-greeting")
        try viewModel.refresh()
        let target = SmileGuideCatalog.guide(id: "morning-greeting")
        let replacement = try viewModel.removalImpact(for: target).replacement

        try await viewModel.remove(target)

        let reminder = try XCTUnwrap(reminders.fetchAll().first)
        XCTAssertEqual(reminder.guideID, replacement.id)
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.guideID, replacement.id)
        XCTAssertEqual(scheduler.scheduled.first?.days, reminderRollingWindowDays)
    }

    func test_remove_doesNotRescheduleDisabledReminders() async throws {
        let (viewModel, reminders, scheduler) = try makeViewModel()
        let reminder = try reminders.add(hour: 9, minute: 0, guideID: "morning-greeting")
        try reminders.setEnabled(reminder, false)
        try viewModel.refresh()

        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-greeting"))

        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertNotEqual(reminder.guideID, "morning-greeting", "꺼져 있어도 카드는 바뀌어야 한다")
    }

    func test_restore_bringsHiddenCardBack() async throws {
        let (viewModel, _, _) = try makeViewModel()
        try viewModel.refresh()
        try await viewModel.remove(SmileGuideCatalog.guide(id: "morning-coffee"))

        try viewModel.restore(SmileGuideCatalog.guide(id: "morning-coffee"))

        XCTAssertEqual(viewModel.guides.count, 14)
        XCTAssertTrue(viewModel.hiddenGuides.isEmpty)
    }
}
```

- [ ] **Step 3: 실행한다**

```bash
cd CoachingKit && swift test --filter SmileLibraryViewModelTests
```

---

### Task 10: 홈과 온보딩 ViewModel 연결

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/SmileHomeViewModel.swift`
- Modify: `CoachingKit/Sources/CoachingKit/SmileOnboardingState.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileHomeViewModelTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileOnboardingStateTests.swift`

- [ ] **Step 1: `SmileHomeViewModel`이 라이브러리를 쓰게 한다**

`guides: [SmileGuide]` 저장 프로퍼티를 지우고 라이브러리 주입으로 바꾼다.

```swift
public private(set) var guides: [SmileGuide] = []
/// 지금 시간대에 어울리는 첫 카드. 홈이 기본 선택으로 쓴다.
public private(set) var suggestedGuide: SmileGuide?

private let library: SmileGuideLibrary
```

`init`에서 `guides: [SmileGuide] = SmileGuideCatalog.all` 인자를 지우고 `library: SmileGuideLibrary`를 받는다. `refresh()` 끝에 다음을 더한다.

```swift
guides = try library.visibleGuides()
let slot = DaySlot(hour: calendar.component(.hour, from: today))
suggestedGuide = guides.first { $0.slot == slot } ?? guides.first
```

`nextReminder`를 만들 때 `reminder.guide` 대신 `library.guide(id: reminder.guideID)`를 쓴다.

- [ ] **Step 2: 홈 테스트를 고친다**

`makeViewModel`에 라이브러리를 넣는다.

```swift
let library = SmileGuideLibrary(modelContext: context, hiddenStore: InMemoryHiddenSmileGuideStore())
let viewModel = SmileHomeViewModel(
    momentRepository: momentRepository,
    reminderRepository: reminderRepository,
    library: library,
    calendar: calendar,
    now: { now }
)
```

`test_guides_areTheThreeCatalogGuides`를 지우고 다음으로 바꾼다.

```swift
func test_refresh_guidesComeFromLibrary() throws {
    let (viewModel, _, _) = try makeViewModel(now: date(2026, 7, 28, 10))

    try viewModel.refresh()

    XCTAssertEqual(viewModel.guides.count, 14)
}

func test_refresh_suggestedGuideMatchesCurrentSlot() throws {
    let (viewModel, _, _) = try makeViewModel(now: date(2026, 7, 28, 9))
    try viewModel.refresh()
    XCTAssertEqual(viewModel.suggestedGuide?.slot, .morning)

    let (evening, _, _) = try makeViewModel(now: date(2026, 7, 28, 20))
    try evening.refresh()
    XCTAssertEqual(evening.suggestedGuide?.slot, .evening)
}
```

기존 테스트에서 쓰는 `soft-smile` / `greeting-smile` / `bright-smile`은 `anytime-soft` / `morning-greeting` / `evening-after-work`로 바꾼다. `test_refresh_nextReminder_legacyReminderShowsDefaultGuide`의 기대값은 `"anytime-soft"`로 바꾼다.

- [ ] **Step 3: 온보딩 권장값을 상황 카드로 바꾼다**

`SmileOnboardingViewModel.recommendedDrafts`를 바꾼다.

```swift
public static var recommendedDrafts: [ReminderDraft] {
    [
        ReminderDraft(hour: 9, minute: 0, guideID: "morning-greeting"),
        ReminderDraft(hour: 13, minute: 0, guideID: "noon-before-lunch"),
        ReminderDraft(hour: 18, minute: 0, guideID: "evening-after-work"),
    ]
}
```

`guides: [SmileGuide] = SmileGuideCatalog.all` 인자를 `library: SmileGuideLibrary`로 바꾸고, `guides`는 `try? library.visibleGuides() ?? SmileGuideCatalog.builtIn`으로 채운다. `ReminderDraft.guide`는 `SmileGuideCatalog.guide(id:)` 대신 주입된 라이브러리를 쓸 수 없으므로(값 타입) 그대로 두고, `confirm()`에서 `draft.guideID`를 그대로 저장한다.

- [ ] **Step 4: 온보딩 테스트를 고친다**

`test_recommendedDrafts_areThreeTimesWithDistinctGuides`의 기대값을 `["morning-greeting", "noon-before-lunch", "evening-after-work"]`로 바꾼다.
`test_guides_offerTheWholeCatalog`를 다음으로 바꾼다.

```swift
func test_guides_offerTheVisibleLibrary() throws {
    let (viewModel, _, _, _) = try makeViewModel()

    XCTAssertEqual(viewModel.guides.count, 14)
}
```

`test_confirm_*`에서 쓰는 guideID를 새 ID로 바꾼다.

- [ ] **Step 5: 패키지 전체를 돌린다**

```bash
cd CoachingKit && swift test 2>&1 | grep -E "error:|Executed [0-9]+ tests|All tests"
```

Expected: `Test Suite 'All tests' passed`.

---

### Task 11: 카드 선택 시트와 카드 추가 화면

**Files:**

- Create: `SmileDay/Views/Guides/SmileGuidePickerSheet.swift`
- Create: `SmileDay/Views/Guides/AddSmileCardView.swift`
- Modify: `SmileDay/Views/Theme.swift` (`GuidePickerRow` 삭제)

- [ ] **Step 1: `GuidePickerRow`를 지운다**

`Theme.swift` 끝의 `GuidePickerRow` 전체를 지운다. 카드가 14개 이상이라 가로 칩으로는 담을 수 없다.

- [ ] **Step 2: 선택 시트를 만든다**

`SmileGuidePickerSheet.swift`:

```swift
import SwiftUI
import CoachingKit

/// 상황 카드 하나를 고르는 시트. 홈, 설정의 알림 행, 온보딩이 모두 이 화면을 쓴다.
struct SmileGuidePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let guides: [SmileGuide]
    let selectedID: String
    let onSelect: (SmileGuide) -> Void
    let onAddCard: () -> Void

    private var slots: [DaySlot] {
        DaySlot.allCases
            .sorted { $0.sortIndex < $1.sortIndex }
            .filter { slot in guides.contains { $0.slot == slot } }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(slots, id: \.self) { slot in
                    Section(slot.displayName) {
                        ForEach(guides.filter { $0.slot == slot }) { guide in
                            Button {
                                onSelect(guide)
                                dismiss()
                            } label: {
                                GuideRow(guide: guide, isSelected: guide.id == selectedID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowBackground(Color.white)
                }

                Section {
                    Button {
                        onAddCard()
                    } label: {
                        Label("내 카드 추가", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SDColor.coralDeep)
                    }
                }
                .listRowBackground(Color.white)
            }
            .scrollContentBackground(.hidden)
            .background(SDColor.cream)
            .navigationTitle("어떤 상황에서 웃을까요?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .tint(SDColor.coralDeep)
    }
}

private struct GuideRow: View {
    let guide: SmileGuide
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(guide.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SDColor.ink)
                Text(guide.instruction)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SDColor.coralDeep)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
```

- [ ] **Step 3: 카드 추가 화면을 만든다**

`AddSmileCardView.swift`:

```swift
import SwiftUI
import CoachingKit

/// 내 상황 카드를 만드는 시트. 제목만 있으면 되고 안내 문구는 비워둘 수 있다.
struct AddSmileCardView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: SmileLibraryViewModel
    let onAdded: (SmileGuide) -> Void

    @State private var title = ""
    @State private var instruction = ""
    @State private var slot: DaySlot = .anytime

    var body: some View {
        NavigationStack {
            Form {
                Section("상황 이름") {
                    TextField("예) 엘리베이터에서 웃기", text: $title)
                }
                .listRowBackground(Color.white)

                Section {
                    TextField(SmileGuideCatalog.defaultInstruction, text: $instruction, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("안내 문구")
                } footer: {
                    Text("비워두면 기본 문구를 씁니다.")
                        .font(.caption)
                        .foregroundStyle(SDColor.muted)
                }
                .listRowBackground(Color.white)

                Section("시간대") {
                    Picker("시간대", selection: $slot) {
                        ForEach(DaySlot.allCases.sorted { $0.sortIndex < $1.sortIndex }, id: \.self) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.white)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(SDColor.alert)
                        .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SDColor.cream)
            .navigationTitle("카드 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(SDColor.coralDeep)
    }

    private func save() {
        do {
            try viewModel.addCard(title: title, instruction: instruction, slot: slot)
            if let added = viewModel.guides.last(where: { !$0.isBuiltIn }) {
                onAdded(added)
            }
            dismiss()
        } catch {
            // errorMessage가 화면에 표시된다.
        }
    }
}
```

- [ ] **Step 4: 빌드한다.** 이 시점에는 `GuidePickerRow`를 쓰던 세 화면이 깨진다. Task 12에서 고친다.

---

### Task 12: 홈·설정·온보딩 연결

**Files:**

- Modify: `SmileDay/Views/Home/SmileMVPHomeView.swift`
- Modify: `SmileDay/Views/Settings/SmileMVPSettingsView.swift`
- Modify: `SmileDay/Views/Onboarding/SmileMVPOnboardingView.swift`
- Modify: `SmileDay/Views/SharedStrings.swift`

- [ ] **Step 1: 문구를 더한다**

`SharedStrings`에 넣는다.

```swift
static let pickGuideAction = "상황 고르기"
static let addCardAction = "내 카드 추가"
static let myCardsTitle = "미소 카드"
static let hiddenCardsTitle = "숨긴 카드"
static let restoreCardAction = "되돌리기"
```

- [ ] **Step 2: 홈의 칩을 카드 이름 + 시트로 바꾼다**

`TodayCard`에서 `GuidePickerRow` 자리를 다음으로 바꾼다.

```swift
Button {
    onPickGuide()
} label: {
    HStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 2) {
            Text(selectedGuide.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SDColor.ink)
                .multilineTextAlignment(.leading)
            Text(selectedGuide.instruction)
                .font(.caption)
                .foregroundStyle(SDColor.muted)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
        }
        Spacer(minLength: 8)
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SDColor.muted)
    }
    .padding(12)
    .background(SDColor.shell.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
}
.buttonStyle(.plain)
.accessibilityHint(SharedStrings.pickGuideAction)
```

`SmileMVPHomeView`는 `selectedGuideID` 대신 `selectedGuide: SmileGuide?`를 들고, `viewModel.refresh()` 뒤에 아직 없으면 `viewModel.suggestedGuide`로 채운다. 라이브러리는 `SmileGuideLibrary(modelContext:hiddenStore: UserDefaultsHiddenSmileGuideStore())`로 만들어 `SmileHomeViewModel`에 넘긴다.

시트 두 개를 붙인다.

```swift
.sheet(isPresented: $isPickingGuide) {
    SmileGuidePickerSheet(
        guides: viewModel?.guides ?? [],
        selectedID: selectedGuide?.id ?? "",
        onSelect: { selectedGuide = $0 },
        onAddCard: { isPickingGuide = false; isAddingCard = true }
    )
}
.sheet(isPresented: $isAddingCard) {
    if let libraryViewModel {
        AddSmileCardView(viewModel: libraryViewModel, onAdded: { added in
            selectedGuide = added
            try? viewModel?.refresh()
        })
    }
}
```

- [ ] **Step 3: 설정의 알림 행을 시트로 바꾼다**

`ReminderRow`에서 `GuidePickerRow`를 지우고, 현재 카드 이름을 보여주는 버튼으로 바꾼다. 탭하면 `SmileGuidePickerSheet`가 열리고, 고르면 `viewModel.updateReminderGuide(reminder, guideID:)`를 부른다. "알림 추가" 섹션도 같은 방식으로 바꾼다.

- [ ] **Step 4: 설정에 "미소 카드" 섹션을 더한다**

```swift
Section(SharedStrings.myCardsTitle) {
    ForEach(libraryViewModel.guides) { guide in
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(guide.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SDColor.ink)
                Text(guide.slot.displayName)
                    .font(.caption)
                    .foregroundStyle(SDColor.muted)
            }
            Spacer()
            Button(guide.isBuiltIn ? "숨기기" : "지우기") {
                pendingRemoval = try? libraryViewModel.removalImpact(for: guide)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(SDColor.alert)
            .buttonStyle(.borderless)
        }
    }

    Button(SharedStrings.addCardAction) { isAddingCard = true }
        .font(.subheadline.weight(.semibold))
}
.listRowBackground(Color.white)

if !libraryViewModel.hiddenGuides.isEmpty {
    Section(SharedStrings.hiddenCardsTitle) {
        ForEach(libraryViewModel.hiddenGuides) { guide in
            HStack {
                Text(guide.title)
                    .font(.subheadline)
                    .foregroundStyle(SDColor.muted)
                Spacer()
                Button(SharedStrings.restoreCardAction) {
                    try? libraryViewModel.restore(guide)
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
    }
    .listRowBackground(Color.white)
}
```

삭제 확인은 `alert`로 붙인다.

```swift
.alert("이 카드를 지울까요?", isPresented: Binding(
    get: { pendingRemoval != nil },
    set: { if !$0 { pendingRemoval = nil } }
)) {
    Button("취소", role: .cancel) { pendingRemoval = nil }
    Button("지우기", role: .destructive) {
        guard let impact = pendingRemoval else { return }
        pendingRemoval = nil
        Task { try? await libraryViewModel.remove(impact.guide) }
    }
} message: {
    if let impact = pendingRemoval {
        if impact.isInUse {
            Text("이 카드를 쓰는 알림이 \(impact.affectedReminderTimes.count)개 있어요.\n\(impact.affectedReminderTimes.joined(separator: ", "))\n\n지우면 이 알림들은 '\(impact.replacement.title)'로 바뀝니다.")
        } else {
            Text("'\(impact.guide.title)'를 목록에서 지웁니다.")
        }
    }
}
```

- [ ] **Step 5: 온보딩의 칩을 시트로 바꾼다**

`ReminderDraftRow`에서 `GuidePickerRow`를 지우고, 카드 이름 버튼 + `SmileGuidePickerSheet`로 바꾼다. 고르면 `viewModel.updateGuide(draftID:guideID:)`를 부른다.

- [ ] **Step 6: 빌드한다**

```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

---

### Task 13: 전체 검증

- [ ] **Step 1: 패키지 전체**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit && swift test
```

Expected: `Test Suite 'All tests' passed`.

- [ ] **Step 2: 앱 빌드**

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: 스키마 호환**

`PersistenceSchemaMigrationTests`가 `CustomSmileCard`를 포함한 새 스키마로도 구버전 저장소를 여는지 확인한다. `legacySchema`는 그대로 두고 통과해야 한다.

```bash
cd CoachingKit && swift test --filter PersistenceSchemaMigrationTests
```

- [ ] **Step 4: 남은 옛 ID 확인**

```bash
rg -n 'soft-smile|greeting-smile|bright-smile' SmileDay CoachingKit --glob '*.swift'
```

Expected: `SmileGuide.swift`의 `legacyIDAliases`와 그 테스트에서만 나온다.

- [ ] **Step 5: 금지 문구**

```bash
rg -n '개선|교정|치료|리프팅|진짜 미소|억지 미소|어제보다|점수가|미소 크기|퇴근길|출근길' \
  SmileDay CoachingKit --glob '*.swift'
```

기존처럼 주석과 테스트의 금지어 목록에서만 나와야 한다.

- [ ] **Step 6: 정적 검사**

```bash
git diff --check
git status --short
```

---

### Task 14: 실기기 확인 (사람이 수행)

- [ ] 큰 글자 크기에서 카드 제목과 안내 문구가 잘리지 않는지
- [ ] VoiceOver로 카드 선택 시트를 훑을 수 있는지
- [ ] 카드를 추가하고 그 카드로 알림을 예약한 뒤 알림이 그 카드를 여는지
- [ ] 알림이 쓰는 카드를 지웠을 때 예약된 알림이 대체 카드 문구로 바뀌는지 (설정 앱 > 알림에서 확인하거나 시각을 1분 뒤로 바꿔 확인)
- [ ] 기본 카드를 숨겼다 되돌렸을 때 목록 순서가 유지되는지
