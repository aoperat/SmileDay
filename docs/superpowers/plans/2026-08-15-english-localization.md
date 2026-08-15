# 영어 지원 1단계(배관) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한국어 앱의 동작을 한 글자도 바꾸지 않은 채, 문구 전체를 String Catalog로 옮기고 알림·저장·달력·포맷을 로케일 중립으로 만들어 영어 문구를 채워 넣을 자리를 완성한다.

**Architecture:** 사용자 문구는 앱 타깃의 `.xcstrings` 6개로 이동하고 코드는 Xcode가 생성한 `LocalizedStringResource` 심볼로만 참조한다. CoachingKit은 문구 대신 id·오류 케이스·검증 상태만 노출한다. 알림 본문은 `localizedUserNotificationString(forKey:)`로 배달 시점에 해석되고, 옛 빌드가 굳혀둔 알림은 `ReminderGroupSwap`을 쓰는 1회 마이그레이션이 갈아끼운다. 사용자 편집 알림 문구 저장소는 `text: String?` + 저장 키 v2로 바뀌며, 카탈로그 JSON을 파싱하는 CoachingKit 테스트가 금지어·누락·id 대응을 지킨다.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData, iOS 17+, Xcode 26.6 (String Catalog 심볼 생성 켜져 있음), XCTest, `swift test`(CoachingKit) + `xcodebuild`(앱).

**Spec:** `docs/superpowers/specs/2026-08-15-english-localization-design.md`

**범위:** 스펙 9절의 **0단계 + 1단계만.** 2단계(영어 문구 집필)와 7절(App Store·정책 페이지)은 코드 작업이 아니라 별도로 진행한다. 이 계획이 끝나면 한국어 앱은 오늘과 동일하게 동작하고(예외: 홈 화면 아이콘 이름), 영어 열은 한국어로 시딩된 `needsReview` 상태로 채워져 있다.

---

## 시작 전에 알아야 할 것

**미커밋 워킹트리.** 이 브랜치(`feature/live-smile-monitor`)에는 다른 작업의 미커밋 변경 17개 파일이 있다 — 앱 테스트 타깃 `SmileDayTests`, `ReminderGroupSwap` 추출, `SDFormat.duration/reminderInterval` 통합, `SDSystemSettings` 등. **스펙이 "없다"고 전제한 두 가지(앱 테스트 타깃, Applier 추출)가 이미 여기서 해결돼 있다.** Task 0이 이걸 먼저 커밋해서 영어화 작업과 분리한다.

**검증 명령.**
```bash
cd CoachingKit && swift test                       # 'Test Suite 'All tests' passed' 확인
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"
xcodebuild test -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -aE "error:|TEST (SUCCEEDED|FAILED)"
```
`grep -a`가 필수다 — xcodebuild 로그에 바이너리 바이트가 섞여 있다. `swift test` 마지막 줄 "0 tests in 0 suites passed"는 Swift Testing 러너 출력이지 실패가 아니다.

**Xcode GUI가 필요한 단계.** String Catalog 파일 생성과 키 추가, Vary by Plural, "Convert Strings to Symbols"는 Xcode 편집기 작업이다. 이 계획은 그 단계마다 결과 파일(`.xcstrings`는 JSON)의 기대 모양을 적어두어 GUI 없이 직접 편집해도 되게 했다. **`.xcstrings` 파일을 손으로 편집할 때는 `"version" : "1.1"`, `"sourceLanguage" : "en"`을 유지한다** — 심볼 생성은 1.1 포맷에서만 된다.

**커밋 메시지 규칙.** 이 저장소는 영어 소문자 접두사(`docs:`, `feat:`, `refactor:`, `test:`, `fix:`) + 한 줄 요약 + 본문에 "왜"를 쓴다. 매 커밋 끝에:
```
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

---

## 파일 지도

**새로 만드는 것**
| 파일 | 책임 |
|---|---|
| `SmileDay/Resources/Localizable.xcstrings` | 공용·알림·앱 이름·시작 실패·스플래시 문구 (기본 테이블) |
| `SmileDay/Resources/Home.xcstrings` | 홈·기록 화면 |
| `SmileDay/Resources/Onboarding.xcstrings` | 온보딩 |
| `SmileDay/Resources/Settings.xcstrings` | 설정·알림 문구 관리 |
| `SmileDay/Resources/Coaching.xcstrings` | 가이드·실시간 확인·세션 요약 |
| `SmileDay/Resources/InfoPlist.xcstrings` | `NSCameraUsageDescription`, `CFBundleDisplayName` |
| `CoachingKit/Sources/CoachingKit/ReminderMessageError.swift` | 알림 문구 편집 오류 케이스 |
| `CoachingKit/Sources/CoachingKit/ReminderScheduleError.swift` | 스케줄 저장 오류 케이스 |
| `CoachingKit/Sources/CoachingKit/ReminderMessageMigration.swift` | v1 → v2 승격 (동결 한국어 스냅샷 포함) |
| `CoachingKit/Sources/CoachingKit/LocalizedReminderBackfill.swift` | 옛 평문 알림 → 키 기반 1회 재예약 |
| `CoachingKit/Tests/CoachingKitTests/StringCatalogGuaranteeTests.swift` | 카탈로그 JSON 파싱 — 금지어·누락·id 대응·중복·불변식 |
| `CoachingKit/Tests/CoachingKitTests/ReminderMessageMigrationTests.swift` | 승격 규칙 |
| `CoachingKit/Tests/CoachingKitTests/LocalizedReminderBackfillTests.swift` | 1회 재예약 |
| `SmileDay/Services/ReminderMessageError+Message.swift` | 오류 케이스 → 문구 |
| `SmileDay/Services/ReminderScheduleError+Message.swift` | 오류 케이스 → 문구 |
| `SmileDay/Services/ReminderNotificationAction+Title.swift` | 버튼 문구 (CoachingKit에서 이동) |
| `SmileDay/Services/ReminderMessage+Resolved.swift` | `ReminderMessage` → 표시 문구 해석 |
| `SmileDay/Services/SmileCue+Text.swift` | `SmileCue.id` → 문구 |

**고치는 것 (핵심만)**
| 파일 | 변경 |
|---|---|
| `SmileDay.xcodeproj/project.pbxproj` | `developmentRegion = en`, `knownRegions += en`, `INFOPLIST_KEY_CFBundleDisplayName` 추가, 카메라 문구 영어로 |
| `SmileDay/SmileDayApp.swift:29` | `.environment(\.locale, ko_KR)` → `.environment(\.calendar, gregorianCurrent)` |
| `SmileDay/Views/SharedStrings.swift` | **삭제** |
| `SmileDay/Views/Theme.swift` | `SDFormat.koreanLocale` 삭제, `duration`/`reminderInterval` → `FormatStyle` |
| `CoachingKit/Sources/CoachingKit/SmileCue.swift` | `text` 제거 |
| `CoachingKit/Sources/CoachingKit/ReminderMessage.swift` | `text: String?`, 저장 키 v2, `resolve` 주입, 오류 enum |
| `CoachingKit/Sources/CoachingKit/ReminderNotificationAction.swift` | `title` 제거 |
| `CoachingKit/Sources/CoachingKit/SmileReminderScheduleViewModel.swift` | `errorMessage: String?` → `error: ReminderScheduleError?`, `invalidPatternMessage` → `isPatternValid` |
| `SmileDay/Services/UserNotificationReminderScheduler.swift` | title/body를 `localizedUserNotificationString` 키로 |
| `SmileDay/Views/RootView.swift` | `LocalizedReminderBackfill` 호출 추가 |
| `SmileDay/Views/Home/SmileHistoryView.swift` | 환경 캘린더, 요일 헤더 `id: \.offset`, `Text(x, format:)` |
| `SmileDay/Views/Home/SmileMVPHomeView.swift` | `Text(x, format:)`, 복수 심볼 |
| 그 외 뷰 전부 | 리터럴 → 심볼 |

---

## Task 0: 미커밋 워킹트리를 별도 커밋으로 정리

**Files:** 워킹트리의 변경 17개 + 미추적 파일 (영어화와 무관한 선행 작업)

- [ ] **Step 1: 무엇이 있는지 확인**

Run: `git status --short`
Expected: `M` 17개, `??`에 `CoachingKit/Sources/CoachingKit/ReminderGroupSwap.swift`, `SmileDayTests/`, `README.md`, `docs/marketing/2026-08-1*.md` 여러 개.

- [ ] **Step 2: 마케팅 문서는 이 커밋에서 제외 (별도 작업물)**

이 계획은 코드 작업만 다룬다. `docs/marketing/2026-08-14-*.md`, `docs/marketing/2026-08-15-*.md`, `README.md`는 건드리지 않고 그대로 미추적으로 둔다.

- [ ] **Step 3: 코드 변경만 스테이지**

```bash
git add AGENTS.md CLAUDE.md CLAUDE.ko.md \
  CoachingKit/Sources/CoachingKit/ \
  SmileDay.xcodeproj/project.pbxproj \
  SmileDay/ SmileDayTests/
git status --short | grep -v "^??"     # docs/marketing, README.md가 안 잡혀야 한다
```

- [ ] **Step 4: 두 테스트가 통과하는지 확인**

Run: `cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:"`
Expected: `Test Suite 'All tests' passed`

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git commit -F - <<'EOF'
refactor: extract ReminderGroupSwap, unify duration formatting, add app-target tests

The register → save → cancel-old ordering that guards against partial
rollback wiping live notifications lived twice — settings save and the
action backfill. One copy now, in ReminderGroupSwap.

SDFormat.duration/reminderInterval replace three hand-rolled formatters
that had drifted apart. SDSystemSettings.open replaces five copies of
the settings-URL dance.

SmileDayTests covers the app target's pure logic (identifiers, router,
SDFormat, Color tokens) — the first tests that run against SmileDay
itself rather than CoachingKit.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 1: 0단계 — `localizedUserNotificationString`이 String Catalog 키를 해석하는지 실측

스펙 9절 0단계. 이게 실패하면 Task 12–13을 재예약 설계로 되돌려야 하므로 **다른 어떤 코드 작업보다 먼저** 확정한다. 프로덕션 코드는 건드리지 않고, 실험용 임시 변경으로 확인한 뒤 되돌린다.

**Files:** 임시 — `SmileDay/Resources/Localizable.xcstrings` (생성 후 남김), `SmileDay/Services/AppDelegate.swift` (임시 수정 후 원복)

- [ ] **Step 1: 기본 String Catalog 파일 생성**

Xcode에서 `SmileDay` 그룹 우클릭 → New File → String Catalog → 이름 `Localizable`, 위치 `SmileDay/Resources/`(폴더 없으면 만든다). 또는 파일을 직접 만든다:

```bash
mkdir -p SmileDay/Resources
cat > SmileDay/Resources/Localizable.xcstrings <<'EOF'
{
  "sourceLanguage" : "en",
  "strings" : {
    "probeDeliveryTime" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "PROBE-EN" } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "탐침-KO" } }
      }
    }
  },
  "version" : "1.1"
}
EOF
```

직접 만든 경우 Xcode 프로젝트에 추가해야 한다: Xcode에서 `SmileDay` 그룹에 드래그 → "Copy items if needed" 끄기, 타깃 `SmileDay` 체크. 이 시점에 pbxproj의 `knownRegions`에 `en`이 자동으로 추가된다 — 안 됐으면 Task 2에서 한다.

- [ ] **Step 2: 앱 시작 시 즉시 로컬 알림을 하나 예약하는 임시 코드**

`SmileDay/Services/AppDelegate.swift`의 `application(_:didFinishLaunchingWithOptions:)` 끝에 임시로 추가:

```swift
        // TEMP PROBE — 제거 예정
        Task {
            let content = UNMutableNotificationContent()
            content.title = NSString.localizedUserNotificationString(forKey: "probeDeliveryTime", arguments: nil)
            content.body = "probe"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "probe", content: content, trigger: trigger)
            )
        }
```

- [ ] **Step 3: 실기기 또는 시뮬레이터에서 확인 (한국어 → 영어 전환)**

1. 기기 언어 한국어 상태로 앱 실행 → 알림 권한 허용 → 앱을 백그라운드로 → 60초 뒤 알림 제목이 **"탐침-KO"**인지 확인.
2. **앱을 재실행하지 않고** 설정 → 일반 → 언어 및 지역 → iPhone 언어를 English로 변경 (기기 재시작이 안 되는 시뮬레이터라면 설정 → 앱 → SmileDay → 언어를 English로).
3. 앱을 다시 실행해 알림을 다시 예약(예약은 언제 하든 상관없다 — 핵심은 **예약 이후** 언어를 바꾸는 것). 백그라운드 → 60초 뒤 언어를 English로 바꾼 뒤 → 알림 제목이 **"PROBE-EN"**인지 확인.

정확한 실험 순서: 한국어 상태에서 예약 → 60초 안에 언어를 영어로 전환 → 알림 도착 시 제목 확인. **"PROBE-EN"이면 통과.**

Expected: 예약 시점 언어와 무관하게 **표시 시점 언어**로 제목이 나온다.

- [ ] **Step 4: 결과를 스펙에 기록**

통과했으면 스펙 11절의 첫 항목을 "실측 통과 (날짜)"로 바꾼다:

```bash
sed -i '' 's/^- \*\*0단계가 최우선\*\*: `localizedUserNotificationString(forKey:)` × String Catalog 실기기 확인 (9절)\./- ~~0단계~~ `localizedUserNotificationString(forKey:)` × String Catalog — 실측 통과 (2026-08-15, Task 1). 예약 후 언어를 바꿔도 표시 시점 언어로 나왔다./' docs/superpowers/specs/2026-08-15-english-localization-design.md
```

**실패했으면 여기서 멈추고 보고한다.** Task 12–13이 재설계 대상이 된다.

- [ ] **Step 5: 임시 코드 제거, 카탈로그의 probe 키 제거**

`AppDelegate.swift`의 TEMP PROBE 블록을 지운다. `Localizable.xcstrings`에서 `probeDeliveryTime` 항목을 지운다(빈 `"strings" : {}`로 남긴다).

```bash
git diff SmileDay/Services/AppDelegate.swift    # 빈 출력이어야 한다
```

- [ ] **Step 6: 커밋 (카탈로그 파일 + 스펙 기록)**

```bash
git add SmileDay/Resources/Localizable.xcstrings SmileDay.xcodeproj/project.pbxproj docs/superpowers/specs/2026-08-15-english-localization-design.md
git commit -F - <<'EOF'
feat: add the base String Catalog and confirm delivery-time localization

localizedUserNotificationString(forKey:) resolved a catalog key in the
language active at delivery, not at scheduling — measured on device by
scheduling in Korean and switching to English before it fired. This is
the premise the whole notification design rests on, so it went first.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 2: 프로젝트 언어 설정 — developmentRegion, knownRegions, Info.plist 키

**Files:**
- Modify: `SmileDay.xcodeproj/project.pbxproj`
- Create: `SmileDay/Resources/InfoPlist.xcstrings`

- [ ] **Step 1: pbxproj 수정**

```bash
sed -i '' 's/developmentRegion = ko;/developmentRegion = en;/' SmileDay.xcodeproj/project.pbxproj
grep -n "developmentRegion" SmileDay.xcodeproj/project.pbxproj
```
Expected: `developmentRegion = en;`

`knownRegions` 블록을 확인해 `en`이 없으면 추가:
```bash
grep -A4 "knownRegions" SmileDay.xcodeproj/project.pbxproj
```
`en,` `ko,` `Base,` 세 줄이 있어야 한다. `en`이 없으면 `ko,` 앞에 `				en,` 줄을 넣는다.

- [ ] **Step 2: 카메라 문구를 영어로 교체하고 CFBundleDisplayName 추가**

두 빌드 구성(Debug/Release) 모두. 스펙 4.4절 — **빌드 세팅은 지우지 않는다**, 값만 영어로 바꾼다. 영어 문구는 2단계에서 다듬되 지금은 deck 톤으로 임시 확정한다.

```bash
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("SmileDay.xcodeproj/project.pbxproj")
s = p.read_text()
old = 'INFOPLIST_KEY_NSCameraUsageDescription = "실시간 미소 신호를 보여주기 위해 전면 카메라를 사용합니다. 카메라 화면은 사용자가 켤 때만 표시하며, 사진과 영상을 저장하거나 전송하지 않습니다.";'
new = ('INFOPLIST_KEY_CFBundleDisplayName = SmileDay;\n'
       '\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "The front camera reads how your mouth corners move, to show a live smile signal. The camera view appears only when you turn it on. No photos or video are saved or sent.";')
assert s.count(old) == 2, s.count(old)
s = s.replace(old, new)
p.write_text(s)
print("ok")
PY
grep -n "INFOPLIST_KEY_CFBundleDisplayName\|INFOPLIST_KEY_NSCameraUsageDescription" SmileDay.xcodeproj/project.pbxproj
```
Expected: 각각 2줄(Debug/Release).

- [ ] **Step 3: InfoPlist.xcstrings 생성 (한국어 값을 담는다)**

```bash
cat > SmileDay/Resources/InfoPlist.xcstrings <<'EOF'
{
  "sourceLanguage" : "en",
  "strings" : {
    "CFBundleDisplayName" : {
      "extractionState" : "extracted_with_value",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "SmileDay" } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "스마일데이" } }
      }
    },
    "NSCameraUsageDescription" : {
      "extractionState" : "extracted_with_value",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "The front camera reads how your mouth corners move, to show a live smile signal. The camera view appears only when you turn it on. No photos or video are saved or sent." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "실시간 미소 신호를 보여주기 위해 전면 카메라를 사용합니다. 카메라 화면은 사용자가 켤 때만 표시하며, 사진과 영상을 저장하거나 전송하지 않습니다." } }
      }
    }
  },
  "version" : "1.1"
}
EOF
```
Xcode에서 이 파일을 `SmileDay` 타깃에 추가한다(드래그, Copy items 끄기).

- [ ] **Step 4: 빌드하고 산출물의 Info.plist를 확인**

```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator -derivedDataPath /tmp/sd-build build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"
APP=$(find /tmp/sd-build -name "SmileDay.app" -path "*iphonesimulator*" | head -1)
plutil -p "$APP/Info.plist" | grep -E "CFBundleDisplayName|NSCameraUsageDescription"
ls "$APP"/*.lproj
plutil -p "$APP/ko.lproj/InfoPlist.strings" 2>/dev/null || strings "$APP/ko.lproj/InfoPlist.strings" | head
```
Expected: `Info.plist`에 두 키가 **존재**(영어 값), `en.lproj/`·`ko.lproj/`가 있고 `ko.lproj/InfoPlist.strings`에 한국어 값.

- [ ] **Step 5: 시뮬레이터에서 앱 이름 확인 (한국어 → 스마일데이, 영어 → SmileDay)**

시뮬레이터 언어 한국어로 설치 → 홈 화면 아이콘 이름 "스마일데이". 영어로 바꾸면 "SmileDay". (스펙 4.4절 A안 — 한국어 사용자의 아이콘 이름이 바뀌는 것은 의도다.)

- [ ] **Step 6: 커밋**

```bash
git add SmileDay.xcodeproj/project.pbxproj SmileDay/Resources/InfoPlist.xcstrings
git commit -F - <<'EOF'
feat: make English the development region; localize Info.plist strings

CFBundleDevelopmentRegion is the fallback language, not a label. Devices
whose preferred-language list contains neither ko nor en now get English
instead of Korean.

The camera purpose string stays in build settings — this project has no
Info.plist file, so the build setting is the only thing that creates the
key. InfoPlist.xcstrings only overrides values. Deleting the setting would
drop the key entirely: ITMS-90683 on upload, and ARSession kills the app.

CFBundleDisplayName is new. The icon read "SmileDay" for everyone
(PRODUCT_NAME) while notifications said "스마일데이". Korean now says
스마일데이 in both places; English says SmileDay in both.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 3: 카탈로그 보증 테스트 골격 — JSON 파서와 첫 검사

문구를 옮기기 **전에** 검사를 세운다. 이후 Task마다 이 테스트가 이동을 감시한다. 스펙 4.5절.

**Files:**
- Create: `CoachingKit/Tests/CoachingKitTests/StringCatalogGuaranteeTests.swift`

- [ ] **Step 1: 실패하는 테스트 — 카탈로그 파일이 열리고 파싱된다**

```swift
import XCTest
@testable import CoachingKit

/// 앱 타깃의 String Catalog(JSON)를 상대 경로로 읽어 문구 보증을 검사한다.
///
/// 앱 타깃에는 문구 테스트가 없고 CoachingKit에서는 문구가 사라졌다. 금지어·누락·id 대응 같은
/// 보증이 그 사이에서 증발하지 않게 여기서 파일을 직접 읽는다 — 번들 리소스가 아니라 파일이므로
/// SwiftPM이 카탈로그를 컴파일하지 못하는 제약(스펙 4.3절)을 타지 않는다.
final class StringCatalogGuaranteeTests: XCTestCase {
    struct Catalog {
        let name: String
        /// key → (lang → value)
        let strings: [String: [String: String]]
    }

    private static let catalogNames = ["Localizable", "Home", "Onboarding", "Settings", "Coaching"]

    private static var resourcesDirectory: URL {
        // CoachingKit/Tests/CoachingKitTests/이파일.swift → 저장소 루트/SmileDay/Resources
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CoachingKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // CoachingKit
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("SmileDay/Resources")
    }

    private static func loadCatalog(_ name: String) throws -> Catalog {
        let url = resourcesDirectory.appendingPathComponent("\(name).xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any], "\(name): not a JSON object")
        let strings = try XCTUnwrap(root["strings"] as? [String: Any], "\(name): no 'strings'")
        var out: [String: [String: String]] = [:]
        for (key, entry) in strings {
            let locs = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            var perLang: [String: String] = [:]
            for (lang, loc) in locs {
                if let unit = (loc as? [String: Any])?["stringUnit"] as? [String: Any],
                   let value = unit["value"] as? String {
                    perLang[lang] = value
                } else if let variations = (loc as? [String: Any])?["variations"] as? [String: Any],
                          let plural = variations["plural"] as? [String: Any] {
                    // 복수형은 카테고리별 값을 이어 붙여 검사한다 (금지어·누락 검사용)
                    let joined = plural.values.compactMap {
                        (($0 as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String
                    }.joined(separator: " | ")
                    perLang[lang] = joined
                }
            }
            out[key] = perLang
        }
        return Catalog(name: name, strings: out)
    }

    private static func loadAll() throws -> [Catalog] {
        try catalogNames.map(loadCatalog)
    }

    func test_allCatalogsExistAndParse() throws {
        let catalogs = try Self.loadAll()
        XCTAssertEqual(catalogs.count, Self.catalogNames.count)
    }
}
```

- [ ] **Step 2: 실행해서 실패 확인 (Home 등 아직 없음)**

Run: `cd CoachingKit && swift test --filter StringCatalogGuaranteeTests 2>&1 | grep -E "error|failed|passed" | head`
Expected: `test_allCatalogsExistAndParse` 실패 — `Home.xcstrings` 파일 없음.

- [ ] **Step 3: 나머지 카탈로그 파일 4개를 빈 상태로 생성하고 프로젝트에 추가**

```bash
for n in Home Onboarding Settings Coaching; do
cat > SmileDay/Resources/$n.xcstrings <<'EOF'
{
  "sourceLanguage" : "en",
  "strings" : {

  },
  "version" : "1.1"
}
EOF
done
ls SmileDay/Resources/
```
Xcode에서 4개 파일을 `SmileDay` 타깃에 추가한다.

- [ ] **Step 4: 통과 확인**

Run: `cd CoachingKit && swift test --filter StringCatalogGuaranteeTests 2>&1 | grep -E "error|failed|passed" | head`
Expected: `passed`

- [ ] **Step 5: 커밋**

```bash
git add SmileDay/Resources/*.xcstrings SmileDay.xcodeproj/project.pbxproj CoachingKit/Tests/CoachingKitTests/StringCatalogGuaranteeTests.swift
git commit -F - <<'EOF'
test: parse the app's String Catalogs from CoachingKit tests

The catalogs are JSON on disk. Reading them by relative path from the
package tests sidesteps SwiftPM's inability to compile .xcstrings, and
gives the copy guarantees (banned words, missing values, id parity) a
place to live once the strings leave CoachingKit.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 4: 카탈로그 보증 — 금지어(한/영)·누락·상태 검사 추가

**Files:**
- Modify: `CoachingKit/Tests/CoachingKitTests/StringCatalogGuaranteeTests.swift`

- [ ] **Step 1: 검사 4개 추가**

파일 끝(클래스 안)에 추가:

```swift
    // MARK: - 보증

    /// 한국어 금지어. 기존 SmileCueTests·ReminderMessageTests의 목록을 합쳤다.
    private static let bannedKorean = ["사랑받", "예뻐", "인상 개선", "교정", "치료", "더 크게", "잘 웃", "리프팅", "젊어진"]
    /// 영어 금지어. 스펙 2절 — 영어권 심사(1.4.1)에서 직접 걸리는 말.
    private static let bannedEnglish = [
        "lift", "tone", "firm", "anti-aging", "rejuvenat", "wrinkle", "therap",
        "treatment", "cure", "heal", "depression", "anxiety", "mood disorder", "clinical",
    ]

    func test_koreanValues_avoidBannedWording() throws {
        for catalog in try Self.loadAll() {
            for (key, langs) in catalog.strings {
                guard let ko = langs["ko"] else { continue }
                for word in Self.bannedKorean {
                    XCTAssertFalse(ko.contains(word), "\(catalog.name).\(key) ko contains banned '\(word)'")
                }
            }
        }
    }

    func test_englishValues_avoidBannedWording() throws {
        for catalog in try Self.loadAll() {
            for (key, langs) in catalog.strings {
                guard let en = langs["en"]?.lowercased() else { continue }
                for word in Self.bannedEnglish {
                    // 단어 경계를 대충 본다 — "lift"가 "uplifting"에 걸리면 그것도 잡는 게 맞다.
                    XCTAssertFalse(en.contains(word), "\(catalog.name).\(key) en contains banned '\(word)'")
                }
            }
        }
    }

    func test_everyKey_hasNonEmptyKoreanAndEnglish() throws {
        for catalog in try Self.loadAll() {
            for (key, langs) in catalog.strings {
                let ko = langs["ko"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let en = langs["en"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                XCTAssertFalse(ko.isEmpty, "\(catalog.name).\(key): ko is empty")
                XCTAssertFalse(en.isEmpty, "\(catalog.name).\(key): en is empty")
            }
        }
    }

    /// 제품 불변식 — 큐 중 하나는 "떠올릴 게 없어도 괜찮다"고 말해야 한다.
    /// SmileCueTests.test_catalog_allowsHavingNothingPositiveToRecall 을 여기로 옮겼다.
    func test_cues_allowHavingNothingPositiveToRecall() throws {
        let coaching = try Self.loadCatalog("Coaching")
        let koValues = coaching.strings.values.compactMap { $0["ko"] }
        XCTAssertTrue(
            koValues.contains { $0.contains("떠오르는 장면이 없어도 괜찮아요") },
            "Coaching catalog lost the 'nothing needed' cue"
        )
    }
```

- [ ] **Step 2: 실행 — 불변식 검사가 실패해야 한다 (큐가 아직 안 옮겨짐)**

Run: `cd CoachingKit && swift test --filter StringCatalogGuaranteeTests 2>&1 | grep -E "error|failed|passed" | head`
Expected: `test_cues_allowHavingNothingPositiveToRecall` 실패, 나머지 3개는 통과(빈 카탈로그라 검사할 것이 없음).

이 실패는 Task 6에서 큐를 옮기면 통과한다. 지금은 **실패 상태로 커밋한다** — 이동을 감시하는 것이 목적이다.

- [ ] **Step 3: 커밋**

```bash
git add CoachingKit/Tests/CoachingKitTests/StringCatalogGuaranteeTests.swift
git commit -F - <<'EOF'
test: guard the catalogs — banned wording in both languages, no empty values

The 'nothing needed' cue invariant fails on purpose until Task 6 moves the
cues in; it is here to make sure the move does not lose it.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 5: `SmileDayApp` — 로케일 고정 해제, 환경 캘린더 주입

**Files:**
- Modify: `SmileDay/SmileDayApp.swift:29`

- [ ] **Step 1: 현재 코드 확인**

Run: `sed -n '20,40p' SmileDay/SmileDayApp.swift`
Expected: `.environment(\.locale, Locale(identifier: "ko_KR"))` 한 줄이 보인다.

- [ ] **Step 2: 로케일 고정을 캘린더 주입으로 교체**

`.environment(\.locale, Locale(identifier: "ko_KR"))` 를 다음으로 바꾼다:

```swift
                .environment(\.calendar, Self.displayCalendar)
```

그리고 `SmileDayApp` 구조체 안에 추가:

```swift
    /// 화면이 날짜를 계산하고 그릴 때 함께 쓰는 캘린더.
    ///
    /// 체계는 그레고리력으로 고정한다 — 기록은 그레고리력 날짜이고, `.current`를 그대로 쓰면
    /// 불기·연호 기기에서 격자와 헤더가 다른 달을 가리킨다. 요일 시작과 이름은 로케일에서
    /// 온다(locale을 대입하면 firstWeekday도 따라온다 — 실측).
    private static var displayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        return calendar
    }
```

- [ ] **Step 3: 빌드**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add SmileDay/SmileDayApp.swift
git commit -F - <<'EOF'
feat: follow the device language; inject one Gregorian calendar for display

The ko_KR pin overrode the device for every user. In its place the app
hands views a Gregorian calendar with the current locale — Gregorian so
Thai/Japanese calendar settings can't split grid from header, current
locale so first-weekday and symbols follow the region.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 6: `SmileCue`에서 문구를 걷어내고 Coaching 카탈로그로

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/SmileCue.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileCueTests.swift`
- Modify: `SmileDay/Resources/Coaching.xcstrings`
- Create: `SmileDay/Services/SmileCue+Text.swift`
- Modify: `SmileDay/Views/Coaching/SmileGuideView.swift:67`
- Modify: `CoachingKit/Tests/CoachingKitTests/StringCatalogGuaranteeTests.swift`

- [ ] **Step 1: 실패하는 테스트 — 카탈로그에 모든 cue id의 키가 있어야 한다**

`StringCatalogGuaranteeTests.swift`에 추가:

```swift
    /// id는 CoachingKit, 문구는 앱 카탈로그로 갈라졌다. 큐를 추가하며 한쪽만 손대면 가이드
    /// 화면에 키 문자열이 뜬다 — 그 어긋남을 여기서 잡는다.
    func test_everySmileCue_hasACatalogEntry() throws {
        let coaching = try Self.loadCatalog("Coaching")
        for cue in SmileCueCatalog.all {
            let key = "smileCue.\(cue.id)"
            XCTAssertNotNil(coaching.strings[key], "Coaching catalog missing '\(key)'")
        }
    }
```

Run: `cd CoachingKit && swift test --filter StringCatalogGuaranteeTests/test_everySmileCue_hasACatalogEntry 2>&1 | grep -E "failed|passed"`
Expected: 실패 (키 없음).

- [ ] **Step 2: Coaching 카탈로그에 큐 8개 추가**

`SmileDay/Resources/Coaching.xcstrings`의 `"strings"`를 다음으로 채운다. **`en` 값은 deck(`docs/english-copy-deck.md`)의 제안 문구를 넣고 상태를 `needs_review`로** — 스펙 9절 1단계 시딩 규칙.

```json
  "strings" : {
    "smileCue.cared-for" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "What face would you want someone who loves you to see?" } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "나를 아끼는 사람에게 어떤 표정을 보여주고 싶나요?" } }
      }
    },
    "smileCue.welcome" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Picture running into someone you're glad to see." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "반가운 사람을 만났을 때의 표정을 떠올려보세요." } }
      }
    },
    "smileCue.self-kindness" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Send today's you something warm." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "오늘의 나에게 따뜻한 표정을 보내볼까요?" } }
      }
    },
    "smileCue.gratitude" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Think of someone you're grateful for." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "고마운 사람을 떠올리며 가볍게 미소 지어보세요." } }
      }
    },
    "smileCue.greeting" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Like you're greeting someone you like." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "기분 좋은 인사를 건네듯 표정을 지어보세요." } }
      }
    },
    "smileCue.enough" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "It doesn't have to be big. Easy is enough." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요." } }
      }
    },
    "smileCue.nothing-needed" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Nothing has to come to mind. Just let your face loosen." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "떠오르는 장면이 없어도 괜찮아요. 잠깐 얼굴의 힘만 빼보세요." } }
      }
    },
    "smileCue.gentle-invitation" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "If you're up for it, let the corners lift a little." } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "지금 괜찮다면 입꼬리를 살짝 올려볼까요?" } }
      }
    }
  },
```

**주의 — 영어 금지어 검사와의 충돌.** `"let the corners lift a little"`의 `lift`는 Task 4의 `bannedEnglish`에 걸린다. 이건 deck의 실제 제안이고 맥락(입꼬리를 올린다)은 무해하지만, 검사는 단순 부분 문자열이다. **2단계 집필에서 정할 문제이므로 지금은 `en` 값을 `"If you're up for it, let the corners rise a little."`로 바꿔 넣는다** (`lift` → `rise`). deck에도 그 이유를 한 줄 남긴다(Task 6 Step 7).

- [ ] **Step 3: 카탈로그 검사 통과 확인 (id 대응·불변식)**

Run: `cd CoachingKit && swift test --filter StringCatalogGuaranteeTests 2>&1 | grep -E "failed|passed"`
Expected: 전부 `passed` — `test_everySmileCue_hasACatalogEntry`, `test_cues_allowHavingNothingPositiveToRecall` 포함.

- [ ] **Step 4: `SmileCue`에서 `text` 제거**

`CoachingKit/Sources/CoachingKit/SmileCue.swift` 전체를 다음으로:

```swift
import Foundation

/// 미소 가이드 화면의 안내 문구 하나를 가리키는 식별자.
///
/// 문구 자체는 앱 타깃의 `Coaching.xcstrings`에 있다(`smileCue.<id>`). 패키지는 어떤 큐가
/// 있고 어떤 순서로 도는지만 안다 — `SmileCueCursorStore`가 이 id로 순환 위치를 저장하므로
/// **id와 배열 순서는 바꾸지 않는다.**
public struct SmileCue: Identifiable, Equatable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public enum SmileCueCatalog {
    public static let all: [SmileCue] = [
        SmileCue(id: "cared-for"),
        SmileCue(id: "welcome"),
        SmileCue(id: "self-kindness"),
        SmileCue(id: "gratitude"),
        SmileCue(id: "greeting"),
        SmileCue(id: "enough"),
        SmileCue(id: "nothing-needed"),
        SmileCue(id: "gentle-invitation"),
    ]
}
```

- [ ] **Step 5: `SmileCueTests`에서 문구 검사를 제거 (카탈로그 검사로 이전됨)**

`CoachingKit/Tests/CoachingKitTests/SmileCueTests.swift`의 첫 두 테스트를 다음으로 교체:

```swift
    func test_catalog_isNonEmptyAndUnique() {
        XCTAssertFalse(SmileCueCatalog.all.isEmpty)
        XCTAssertEqual(Set(SmileCueCatalog.all.map(\.id)).count, SmileCueCatalog.all.count)
    }
    // 금지어·공백·"떠올릴 게 없어도 괜찮다" 불변식은 StringCatalogGuaranteeTests로 옮겼다 —
    // 문구가 앱 카탈로그로 갔기 때문이다.
```

`test_catalog_allowsHavingNothingPositiveToRecall`은 삭제한다.

Run: `cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:"`
Expected: `Test Suite 'All tests' passed`

- [ ] **Step 6: 앱 타깃 — `SmileCue` → 문구 해석 확장, 호출부 교체**

`SmileDay/Services/SmileCue+Text.swift` 생성:

```swift
import Foundation
import CoachingKit

extension SmileCue {
    /// 가이드 화면에 보이는 문구. 키는 `Coaching.xcstrings`의 `smileCue.<id>`.
    ///
    /// 심볼(`.Coaching.smileCue…`)이 아니라 키 문자열로 조회한다 — id가 데이터라 심볼을 정적으로
    /// 고를 수 없다. 대응 키가 있다는 보증은 `StringCatalogGuaranteeTests`가 진다.
    var text: String {
        String(localized: String.LocalizationValue("smileCue.\(id)"), table: "Coaching")
    }
}
```

`SmileGuideView.swift:67`의 `Text(cue.text)`는 그대로 둔다 — 확장이 같은 이름을 제공한다.

- [ ] **Step 7: deck에 `lift` 회피 메모**

`docs/english-copy-deck.md`의 `smileCue.gentle-invitation` 행 아래에 한 줄:

```
> `lift`는 심사 위험어 목록에 있어 자동 검사에 걸린다. 카탈로그에는 `let the corners rise a little`로 시딩했다 — 2단계에서 최종 표현을 정한다.
```

- [ ] **Step 8: 빌드**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/SmileCue.swift CoachingKit/Tests/CoachingKitTests/SmileCueTests.swift CoachingKit/Tests/CoachingKitTests/StringCatalogGuaranteeTests.swift SmileDay/Resources/Coaching.xcstrings SmileDay/Services/SmileCue+Text.swift SmileDay.xcodeproj/project.pbxproj docs/english-copy-deck.md
git commit -F - <<'EOF'
refactor: move smile cue copy into the Coaching catalog; SmileCue keeps only its id

The ids and their order are unchanged — SmileCueCursorStore persists a
position keyed on them. The banned-word and 'nothing needed' guarantees
moved into the catalog test so the move could not lose them.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 7: `ReminderNotificationAction` 버튼 문구를 앱 타깃으로

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/ReminderNotificationAction.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderNotificationActionTests.swift`
- Create: `SmileDay/Services/ReminderNotificationAction+Title.swift`
- Modify: `SmileDay/Resources/Localizable.xcstrings`
- Modify: `SmileDay/Services/AppDelegate.swift:73-80`

- [ ] **Step 1: 카탈로그에 버튼 문구 2개 추가**

`Localizable.xcstrings`의 `"strings"`에:

```json
    "reminderAction.smile-recorded" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "I smiled" } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "웃었어요" } }
      }
    },
    "reminderAction.open-guide" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Open guide" } },
        "ko" : { "stringUnit" : { "state" : "translated", "value" : "가이드 열기" } }
      }
    },
```

- [ ] **Step 2: 앱 타깃 확장**

`SmileDay/Services/ReminderNotificationAction+Title.swift`:

```swift
import Foundation
import CoachingKit

extension ReminderNotificationAction {
    /// 잠금화면 버튼 문구. 키는 `reminderAction.<rawValue>` — rawValue가 곧 호환 계약이므로
    /// 키도 같이 고정이다.
    ///
    /// `localizedUserNotificationString`으로 만들어 **표시 시점** 언어를 따른다. 카테고리는 앱
    /// 실행마다 다시 등록되지만, 이렇게 두면 등록 시점 언어와도 무관해진다.
    var title: String {
        NSString.localizedUserNotificationString(forKey: "reminderAction.\(rawValue)", arguments: nil)
    }
}
```

- [ ] **Step 3: CoachingKit에서 `title` 제거**

`ReminderNotificationAction.swift`에서 `title` 프로퍼티(주석 포함 `:17-23`)를 삭제하고, 타입 주석의 "실제 `UNNotificationCategory`는 앱 타깃이 만든다. 패키지는 식별자와 문구만 갖는다."를 "패키지는 식별자만 갖는다. 문구는 앱 타깃(`Localizable.xcstrings`의 `reminderAction.<rawValue>`)에 있다."로 바꾼다.

- [ ] **Step 4: 테스트 정리**

`ReminderNotificationActionTests.swift`에서 `test_titles_areKoreanAndNonEmpty`, `test_titles_avoidBannedWording`를 삭제한다(카탈로그 검사가 대신한다). 나머지(rawValue 고정, opensApp)는 그대로.

Run: `cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:"`
Expected: `passed`

- [ ] **Step 5: `AppDelegate`는 이미 `action.title`을 쓴다 — 빌드로 확인**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **` (확장이 같은 이름을 제공)

- [ ] **Step 6: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderNotificationAction.swift CoachingKit/Tests/CoachingKitTests/ReminderNotificationActionTests.swift SmileDay/Services/ReminderNotificationAction+Title.swift SmileDay/Resources/Localizable.xcstrings SmileDay.xcodeproj/project.pbxproj
git commit -F - <<'EOF'
refactor: notification button titles move to the app target, resolved at display time

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 8: 오류 문구를 오류 케이스로 — `ReminderMessageError`, `ReminderScheduleError`, `isPatternValid`

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/ReminderMessageError.swift`
- Create: `CoachingKit/Sources/CoachingKit/ReminderScheduleError.swift`
- Modify: `CoachingKit/Sources/CoachingKit/ReminderMessage.swift` (뷰모델 부분)
- Modify: `CoachingKit/Sources/CoachingKit/SmileReminderScheduleViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderMessageTests.swift:49,52,55`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileReminderScheduleViewModelTests.swift:195`
- Create: `SmileDay/Services/ReminderMessageError+Message.swift`, `SmileDay/Services/ReminderScheduleError+Message.swift`
- Modify: `SmileDay/Resources/Settings.xcstrings`, `Onboarding.xcstrings`
- Modify: 뷰 호출부 `ReminderMessageManagementView:75,99,107`, `SmileMVPSettingsView:59-64`, `SmileMVPOnboardingView:134-140`

- [ ] **Step 1: 실패하는 테스트 — 뷰모델이 문구가 아니라 케이스를 노출한다**

`ReminderMessageTests.swift`의 `:49, :52, :55` 세 단언을 다음으로 바꾼다:

```swift
        XCTAssertEqual(viewModel.error, .empty)
        // ...
        XCTAssertEqual(viewModel.error, .duplicate)
        // ...
        XCTAssertEqual(viewModel.error, .lastRemaining)
```

`SmileReminderScheduleViewModelTests.swift:195`:
```swift
        XCTAssertEqual(viewModel.error, .schedulingFailed)
```

Run: `cd CoachingKit && swift test 2>&1 | grep -E "error:" | head -5`
Expected: 컴파일 에러 — `error`, `.empty` 없음.

- [ ] **Step 2: 오류 타입 정의**

`CoachingKit/Sources/CoachingKit/ReminderMessageError.swift`:
```swift
import Foundation

/// 알림 문구 편집이 거부된 이유. 문구는 앱 타깃이 붙인다.
public enum ReminderMessageError: Equatable, Sendable {
    case empty
    case tooLong(limit: Int)
    case duplicate
    /// 마지막 한 개는 지울 수 없다.
    case lastRemaining
}
```

`CoachingKit/Sources/CoachingKit/ReminderScheduleError.swift`:
```swift
import Foundation

/// 알림 일정 저장이 실패한 이유. 문구는 앱 타깃이 붙인다.
public enum ReminderScheduleError: Equatable, Sendable {
    /// 새 알림을 등록하지 못했다. 기존 알림은 그대로다.
    case schedulingFailed
    /// 일정을 저장하지 못했다.
    case persistenceFailed
}
```

- [ ] **Step 3: `ReminderMessageViewModel` 수정**

`ReminderMessage.swift`의 뷰모델에서:
- `public private(set) var errorMessage: String?` → `public private(set) var error: ReminderMessageError?`
- `remove(id:)`의 `errorMessage = "알림 메시지는 한 개 이상 남겨주세요."` → `error = .lastRemaining`
- `validated`의 세 곳: `"메시지를 입력해주세요."` → `error = .empty`; `"메시지는 100자 이내로…"` → `error = .tooLong(limit: 100)`; `"같은 메시지가 이미 있어요."` → `error = .duplicate`
- `errorMessage = nil` 전부 → `error = nil`
- `clearError()`는 `error = nil`

- [ ] **Step 4: `SmileReminderScheduleViewModel` 수정**

- `:9` `invalidPatternMessage` 삭제. 대신 추가:
```swift
    /// 시작·종료가 같은 시각이면 만들 수 없는 창이다. 화면이 안내 문구를 띄울지 판단하는 값.
    public var isPatternValid: Bool { pattern != nil }
```
- `:21` `errorMessage: String?` → `error: ReminderScheduleError?`
- `:210-213`의 `guard let pattern else { errorMessage = …; return false }` → `guard let pattern else { return false }` (유효성은 화면이 `isPatternValid`로 본다)
- `:242` → `error = .schedulingFailed`
- `:259` → `error = .persistenceFailed`
- `errorMessage = nil` 전부 → `error = nil`

Run: `cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:"`
Expected: `passed`

- [ ] **Step 5: 카탈로그에 오류·검증 문구 추가**

`Settings.xcstrings`:
```json
    "messageError.empty" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "메시지를 입력해주세요." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "메시지를 입력해주세요." } } } },
    "messageError.tooLong" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "메시지는 %lld자 이내로 입력해주세요." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "메시지는 %lld자 이내로 입력해주세요." } } } },
    "messageError.duplicate" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "같은 메시지가 이미 있어요." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "같은 메시지가 이미 있어요." } } } },
    "messageError.lastRemaining" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "알림 메시지는 한 개 이상 남겨주세요." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "알림 메시지는 한 개 이상 남겨주세요." } } } },
    "scheduleError.schedulingFailed" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "알림을 등록하지 못했어요. 기존 알림은 그대로 유지했어요." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "알림을 등록하지 못했어요. 기존 알림은 그대로 유지했어요." } } } },
    "scheduleError.persistenceFailed" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "알림 설정을 저장하지 못했어요. 다시 시도해주세요." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "알림 설정을 저장하지 못했어요. 다시 시도해주세요." } } } },
    "invalidPattern" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "시작 시간과 종료 시간을 다르게 정해주세요." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "시작 시간과 종료 시간을 다르게 정해주세요." } } } },
```
(`en`에 한국어를 그대로 넣는 것이 1단계 시딩 규칙이다. `messageError.tooLong`의 `%lld`는 인자 하나.)

`invalidPattern`은 온보딩과 설정 둘 다 쓰므로 **`Localizable.xcstrings`(기본 테이블)**에 넣는다. 위 블록에서 그 항목만 옮긴다.

- [ ] **Step 6: 앱 타깃 확장 두 개**

`SmileDay/Services/ReminderMessageError+Message.swift`:
```swift
import Foundation
import CoachingKit

extension ReminderMessageError {
    var message: String {
        switch self {
        case .empty: String(localized: .Settings.messageErrorEmpty)
        case .tooLong(let limit): String(localized: .Settings.messageErrorTooLong(limit))
        case .duplicate: String(localized: .Settings.messageErrorDuplicate)
        case .lastRemaining: String(localized: .Settings.messageErrorLastRemaining)
        }
    }
}
```

`SmileDay/Services/ReminderScheduleError+Message.swift`:
```swift
import Foundation
import CoachingKit

extension ReminderScheduleError {
    var message: String {
        switch self {
        case .schedulingFailed: String(localized: .Settings.scheduleErrorSchedulingFailed)
        case .persistenceFailed: String(localized: .Settings.scheduleErrorPersistenceFailed)
        }
    }
}
```

**심볼 이름 확인.** 위는 "`messageError.tooLong` → `.Settings.messageErrorTooLong(_:)`" 변환 규칙을 가정한 것이다(점 제거 + camelCase, 인자 있으면 함수). 이 규칙은 커뮤니티 출처라 **첫 빌드에서 자동완성으로 실제 생성 이름을 확인하고 맞춘다.** 이름이 다르면 이 파일과 이후 Task의 심볼 참조를 실제 이름으로 통일하고 이 계획서에 한 줄 기록한다.

- [ ] **Step 7: 뷰 호출부 교체**

`ReminderMessageManagementView.swift`:
- `:75` `validationMessage: { viewModel.errorMessage }` → `validationMessage: { viewModel.error?.message }`
- `:99` `viewModel.errorMessage != nil` → `viewModel.error != nil`
- `:107` `Text(viewModel.errorMessage ?? "")` → `Text(viewModel.error?.message ?? "")`

`SmileMVPSettingsView.swift`:
- `:59-60` `if let errorMessage = viewModel.errorMessage { Text(errorMessage)` → `if let error = viewModel.error { Text(error.message)`
- `:64` `Text(SmileReminderScheduleViewModel.invalidPatternMessage)` → `Text(.invalidPattern)` (조건은 이미 `!viewModel.isPatternValid`류일 것 — 없으면 `if !viewModel.isPatternValid`로 감싼다)

`SmileMVPOnboardingView.swift`:
- `:134-135` 같은 패턴 → `if let error = viewModel.error { Text(error.message)`
- `:140` → `Text(.invalidPattern)`

- [ ] **Step 8: 빌드 (심볼 생성 확인)**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`. 에러가 나면 생성 심볼 이름을 확인 — Xcode에서 `.Settings.` 뒤에 자동완성.

- [ ] **Step 9: 커밋**

```bash
git add CoachingKit/Sources/CoachingKit/ReminderMessageError.swift CoachingKit/Sources/CoachingKit/ReminderScheduleError.swift CoachingKit/Sources/CoachingKit/ReminderMessage.swift CoachingKit/Sources/CoachingKit/SmileReminderScheduleViewModel.swift CoachingKit/Tests/ SmileDay/Services/ReminderMessageError+Message.swift SmileDay/Services/ReminderScheduleError+Message.swift SmileDay/Resources/ SmileDay/Views/ SmileDay.xcodeproj/project.pbxproj
git commit -F - <<'EOF'
refactor: view models expose error cases and a validity flag, not sentences

invalidPatternMessage was never an error — two screens rendered it
directly whenever the window was degenerate. It is now isPatternValid
and the sentence lives with the views.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 9: `ReminderMessage.text`를 옵셔널로 + 저장 키 v2 + `resolve` 주입

스펙 5.2절. **알림 재예약(Task 12)보다 먼저 완성돼야 한다.**

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/ReminderMessage.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/ReminderMessageTests.swift`, `ReminderMessageApplyTests.swift`
- Modify: `SmileDay/Resources/Localizable.xcstrings`
- Create: `SmileDay/Services/ReminderMessage+Resolved.swift`

- [ ] **Step 1: 실패하는 테스트 — 기본 문구는 `text == nil`, 저장 키는 v2, resolve로 중복 검사**

`ReminderMessageTests.swift`에 추가:

```swift
    func test_defaults_haveNoInlineText() {
        for message in ReminderMessageCatalog.defaults {
            XCTAssertNil(message.text, "\(message.id) should resolve from the catalog, not carry text")
        }
    }

    func test_store_writesV2AndLeavesV1Untouched() throws {
        let suite = "ReminderMessageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // 옛 빌드가 남긴 v1
        let v1 = try JSONEncoder().encode([
            ReminderMessage(id: "gentle-five-seconds", text: "지금 괜찮다면 5초만 편안하게 미소 지어보세요."),
            ReminderMessage(id: "custom-1", text: "내가 쓴 문구"),
        ])
        defaults.set(v1, forKey: "reminderMessages.v1")

        let store = UserDefaultsReminderMessageStore(defaults: defaults)
        let messages = store.messages
        XCTAssertNil(messages[0].text, "untouched default is promoted")
        XCTAssertEqual(messages[1].text, "내가 쓴 문구")

        store.messages = messages
        XCTAssertNotNil(defaults.data(forKey: "reminderMessages.v2"))
        XCTAssertEqual(defaults.data(forKey: "reminderMessages.v1"), v1, "v1 must never be rewritten")
    }

    func test_duplicateCheck_usesResolvedText() {
        // 해석기가 "gentle-five-seconds"를 "A"로 푼다고 하자. 사용자가 "A"를 새로 추가하면 중복이다.
        let store = InMemoryReminderMessageStore(messages: [ReminderMessage(id: "gentle-five-seconds")])
        let viewModel = ReminderMessageViewModel(store: store) { $0.text ?? ($0.id == "gentle-five-seconds" ? "A" : $0.id) }
        XCTAssertFalse(viewModel.add(text: "A"))
        XCTAssertEqual(viewModel.error, .duplicate)
    }

    func test_update_toResolvedDefault_clearsTextBackToNil() {
        let store = InMemoryReminderMessageStore(messages: [ReminderMessage(id: "gentle-five-seconds")])
        let viewModel = ReminderMessageViewModel(store: store) { $0.text ?? "A" }
        XCTAssertTrue(viewModel.update(id: "gentle-five-seconds", text: "A"))
        XCTAssertNil(viewModel.messages[0].text, "saving the default unchanged must not freeze it")
        XCTAssertTrue(viewModel.update(id: "gentle-five-seconds", text: "B"))
        XCTAssertEqual(viewModel.messages[0].text, "B")
    }
```

기존 테스트 중 `text`를 `String`으로 가정하는 곳(`:12`의 `Set(messages.map(\.text))`, `:31`, `:51`)은 다음 단계에서 고친다.

Run: `cd CoachingKit && swift test --filter ReminderMessageTests 2>&1 | grep -E "error:" | head -5`
Expected: 컴파일 에러 (`text` non-optional, `resolve` 인자 없음).

- [ ] **Step 2: `ReminderMessage` 모델과 카탈로그**

`ReminderMessage.swift` 상단을 다음으로:

```swift
import Foundation
import Observation

public struct ReminderMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    /// nil이면 기본 문구 — 표시·예약 시점에 id로 카탈로그에서 해석한다.
    /// 값이 있으면 사용자가 직접 쓴 문구이고, 언어가 바뀌어도 번역하지 않는다.
    public var text: String?

    public init(id: String = UUID().uuidString, text: String? = nil) {
        self.id = id
        self.text = text
    }
}

public enum ReminderMessageCatalog {
    /// 기본 문구의 id. 문구 자체는 앱 타깃 `Localizable.xcstrings`의 `reminderMessage.<id>`.
    /// **id는 기기에 예약된 알림이 키로 들고 있는 호환 계약이다 — 바꾸지 않는다.**
    public static let defaults: [ReminderMessage] = [
        "gentle-five-seconds", "release-shoulders", "warm-greeting", "comfortable-is-enough",
        "remember-gratitude", "relax-expression", "kind-to-self", "bright-as-comfortable",
    ].map { ReminderMessage(id: $0) }
}
```

- [ ] **Step 3: 저장소 — v2 키, v1 읽기 + 승격**

`UserDefaultsReminderMessageStore`를 다음으로:

```swift
public final class UserDefaultsReminderMessageStore: ReminderMessageStoring {
    /// v1은 `text`가 항상 있던 시절의 데이터다. **읽기만 하고 절대 쓰지 않는다** — 옛 빌드가
    /// 다시 켜져도(백업 복원, TestFlight 병행) 자기 데이터를 온전히 본다.
    private static let legacyKey = "reminderMessages.v1"
    private static let key = "reminderMessages.v2"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var messages: [ReminderMessage] {
        get {
            if let data = defaults.data(forKey: Self.key),
               let decoded = try? decoder.decode([ReminderMessage].self, from: data),
               !decoded.isEmpty {
                return decoded
            }
            if let data = defaults.data(forKey: Self.legacyKey),
               let decoded = try? decoder.decode([ReminderMessage].self, from: data),
               !decoded.isEmpty {
                // 플래그로 막지 않는다 — v2가 없을 때마다 다시 승격한다. 백업 복원으로 v1만
                // 되살아나도 다음 읽기에서 그대로 맞춰진다.
                return ReminderMessageMigration.promoteUntouchedDefaults(decoded)
            }
            return ReminderMessageCatalog.defaults
        }
        set {
            let value = newValue.isEmpty ? ReminderMessageCatalog.defaults : newValue
            guard let data = try? encoder.encode(value) else { return }
            defaults.set(data, forKey: Self.key)
        }
    }
}
```

- [ ] **Step 4: 승격 함수 — 동결된 한국어 스냅샷**

`CoachingKit/Sources/CoachingKit/ReminderMessageMigration.swift` 생성:

```swift
import Foundation

/// v1 저장 데이터를 v2 모양으로 옮긴다.
///
/// 1.x는 기본 문구를 텍스트로 저장했다. 사용자가 한 항목만 고쳐도 기본 8개가 통째로 그 시점
/// 언어로 굳는 구조였다. 여기서는 **1.x가 실제로 출하한 한국어 원문**과 정확히 같은 항목만
/// "손대지 않은 기본값"으로 보고 `text = nil`로 되돌린다.
///
/// 비교값은 아래 상수다. **카탈로그를 조회하면 안 된다** — 카탈로그는 현재 언어로 해석되므로
/// 영어 기기에서는 영어가 나와 영원히 불일치하고, 그 사용자만 한국어 알림에 갇힌다.
/// 마이그레이션 데이터는 역사적 사실이지 지역화 대상이 아니다.
public enum ReminderMessageMigration {
    /// 1.x 빌드의 `ReminderMessageCatalog.defaults` 원문. 절대 수정하지 않는다.
    static let legacyKoreanDefaults: [String: String] = [
        "gentle-five-seconds": "지금 괜찮다면 5초만 편안하게 미소 지어보세요.",
        "release-shoulders": "잠깐 어깨 힘을 빼고 입꼬리를 살짝 올려볼까요?",
        "warm-greeting": "반가운 사람에게 인사하듯 가볍게 미소 지어보세요.",
        "comfortable-is-enough": "크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요.",
        "remember-gratitude": "고마운 사람을 떠올리며 잠깐 미소 지어볼까요?",
        "relax-expression": "화면에서 눈을 떼고 얼굴의 힘을 가볍게 풀어볼까요?",
        "kind-to-self": "오늘의 나에게 따뜻한 표정을 보내볼까요?",
        "bright-as-comfortable": "지금 잠깐, 편한 만큼 밝게 웃어볼까요?",
    ]

    /// 멱등이다 — 이미 nil인 항목은 그대로, 사용자 문구는 그대로.
    public static func promoteUntouchedDefaults(_ messages: [ReminderMessage]) -> [ReminderMessage] {
        messages.map { message in
            guard let text = message.text,
                  legacyKoreanDefaults[message.id] == text else { return message }
            return ReminderMessage(id: message.id, text: nil)
        }
    }
}
```

- [ ] **Step 5: 뷰모델 — `resolve` 주입, 해석 텍스트로 중복·되돌림**

`ReminderMessageViewModel`:

```swift
@MainActor
@Observable
public final class ReminderMessageViewModel {
    public private(set) var messages: [ReminderMessage]
    public private(set) var error: ReminderMessageError?

    private let store: ReminderMessageStoring
    /// 항목을 화면 문구로 푼다. 앱은 카탈로그를, 테스트는 항등 함수를 넘긴다 —
    /// 이 패키지는 카탈로그를 읽을 수 없어서(스펙 4.3절) 해석을 밖에서 받는다.
    private let resolve: (ReminderMessage) -> String

    public init(store: ReminderMessageStoring, resolve: @escaping (ReminderMessage) -> String) {
        self.store = store
        self.resolve = resolve
        messages = store.messages
    }

    @discardableResult
    public func add(text: String) -> Bool {
        guard let text = validated(text) else { return false }
        messages.append(ReminderMessage(text: text))
        persist()
        return true
    }

    @discardableResult
    public func update(id: String, text: String) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == id }),
              let text = validated(text, excludingID: id) else {
            return false
        }
        // 기본 문구를 열어보고 그대로 저장하면 굳지 않는다 — 해석값과 같으면 nil로 되돌린다.
        let asDefault = ReminderMessage(id: id, text: nil)
        let isCatalogDefault = ReminderMessageCatalog.defaults.contains { $0.id == id }
        if isCatalogDefault, resolve(asDefault) == text {
            messages[index].text = nil
        } else {
            messages[index].text = text
        }
        persist()
        return true
    }

    // remove / move / clearError 는 그대로 (errorMessage → error 만 Task 8에서 바뀜)

    private func validated(_ rawText: String, excludingID: String? = nil) -> String? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { error = .empty; return nil }
        guard text.count <= 100 else { error = .tooLong(limit: 100); return nil }
        guard !messages.contains(where: { $0.id != excludingID && resolve($0) == text }) else {
            error = .duplicate; return nil
        }
        error = nil
        return text
    }
    // persist 그대로
}
```

`InMemoryReminderMessageStore`는 그대로.

- [ ] **Step 6: 기존 테스트의 `text` 가정 정리**

`ReminderMessageTests.swift`:
- `:12` `XCTAssertEqual(Set(messages.map(\.text)).count, messages.count)` → `XCTAssertEqual(Set(messages.map(\.id)).count, messages.count)`
- `:14-20` 금지어 검사 삭제(카탈로그 검사로 이전)
- 뷰모델을 만드는 모든 곳에 `resolve: { $0.text ?? $0.id }` 추가 (항등 — 기본 문구는 id로 대표)
- `:31` `viewModel.messages[2].text` → 그대로(사용자 추가 문구는 text 있음)
- `:51` `add(text: only.text)` → `add(text: only.text ?? only.id)`

`ReminderMessageApplyTests.swift`의 뷰모델 생성부도 `resolve` 추가. `scheduledMessages.last == ["바꾼 문구"]` 류의 단언은 scheduler fake가 `messages.map(\.text)`를 모으는 방식이면 `[String?]`로 바뀐다 — fake를 `compactMap`으로 고치거나 단언을 `["바꾼 문구"]`와 비교 가능한 형태로 맞춘다.

Run: `cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:|failed"`
Expected: `passed`

- [ ] **Step 7: 카탈로그에 기본 알림 문구 8개 + 중복 검사 테스트**

`Localizable.xcstrings`에 (deck의 영어 제안, `needs_review`):

```json
    "reminderMessage.gentle-five-seconds" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Five easy seconds, if now works." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "지금 괜찮다면 5초만 편안하게 미소 지어보세요." } } } },
    "reminderMessage.release-shoulders" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Drop your shoulders. Let the corners rise." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "잠깐 어깨 힘을 빼고 입꼬리를 살짝 올려볼까요?" } } } },
    "reminderMessage.warm-greeting" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Like you just spotted a friend." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "반가운 사람에게 인사하듯 가볍게 미소 지어보세요." } } } },
    "reminderMessage.comfortable-is-enough" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Doesn't have to be big. Easy is plenty." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "크게 웃지 않아도 괜찮아요. 편안한 미소면 충분해요." } } } },
    "reminderMessage.remember-gratitude" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Someone you're grateful for — picture them." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "고마운 사람을 떠올리며 잠깐 미소 지어볼까요?" } } } },
    "reminderMessage.relax-expression" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Look away from the screen. Let your face go." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "화면에서 눈을 떼고 얼굴의 힘을 가볍게 풀어볼까요?" } } } },
    "reminderMessage.kind-to-self" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "Something warm, for today's you." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "오늘의 나에게 따뜻한 표정을 보내볼까요?" } } } },
    "reminderMessage.bright-as-comfortable" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "needs_review", "value" : "As bright as feels easy. Just for a second." } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "지금 잠깐, 편한 만큼 밝게 웃어볼까요?" } } } },
    "notificationAppName" : { "extractionState" : "manual", "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "SmileDay" } },
      "ko" : { "stringUnit" : { "state" : "translated", "value" : "스마일데이" } } } },
```
(deck의 `Let the corners lift.` → `rise.` — Task 6과 같은 이유.)

`StringCatalogGuaranteeTests.swift`에 추가:

```swift
    func test_everyDefaultReminderMessage_hasACatalogEntry_andEnglishIsDistinct_andShort() throws {
        let base = try Self.loadCatalog("Localizable")
        var english: [String] = []
        for message in ReminderMessageCatalog.defaults {
            let key = "reminderMessage.\(message.id)"
            let langs = try XCTUnwrap(base.strings[key], "Localizable missing '\(key)'")
            let en = try XCTUnwrap(langs["en"])
            XCTAssertLessThanOrEqual(en.count, 100, "\(key) en exceeds the 100-char edit limit")
            english.append(en)
        }
        XCTAssertEqual(Set(english).count, english.count, "default reminder messages must resolve to distinct English — duplicate check depends on it")
    }

    /// 마이그레이션 스냅샷은 1.x 원문 그대로여야 하고, 카탈로그의 ko 값과도 같아야 한다.
    /// (한국어 문구를 안 바꾼다는 2절 원칙의 기계 검사이기도 하다.)
    func test_legacyKoreanSnapshot_matchesCatalogKorean() throws {
        let base = try Self.loadCatalog("Localizable")
        for (id, legacy) in ReminderMessageMigration.legacyKoreanDefaults {
            XCTAssertEqual(base.strings["reminderMessage.\(id)"]?["ko"], legacy, id)
        }
    }
```

Run: `cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:|failed"`
Expected: `passed`

- [ ] **Step 8: 앱 타깃 해석기**

`SmileDay/Services/ReminderMessage+Resolved.swift`:
```swift
import Foundation
import CoachingKit

extension ReminderMessage {
    /// 화면에 보이는 문구. 사용자가 쓴 것이면 그대로, 기본값이면 카탈로그에서 현재 언어로.
    var resolvedText: String {
        // 키를 먼저 String으로 합친다. 보간 리터럴을 LocalizationValue에 직접 넘기면 보간이
        // 포맷 인자로 잡혀 "reminderMessage.%@"를 찾는다 (Task 6에서 실측·수정한 함정).
        if let text { return text }
        let key = "reminderMessage." + id
        return String(localized: String.LocalizationValue(key))
    }
}
```

`ReminderMessageManagementView`와 `SmileMVPSettingsView`에서 `ReminderMessageViewModel(store:)`를 만드는 곳에 `resolve: { $0.resolvedText }`를 넘기고, 목록에서 `message.text`를 그리는 곳은 `message.resolvedText`로 바꾼다. 에디터를 여는 `:26` `text: message.text` → `text: message.resolvedText`.

- [ ] **Step 9: 빌드 후 커밋**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`

```bash
git add CoachingKit/ SmileDay/ SmileDay.xcodeproj/project.pbxproj
git commit -F - <<'EOF'
feat: reminder messages carry text only when the user wrote it

Defaults are now id-only and resolve from the catalog at display and
delivery time. Storage moves to reminderMessages.v2; v1 is read once for
promotion and never rewritten, so an older build restored from backup
still sees intact data — its getter swallows decode failures and would
have silently replaced user-written messages with defaults.

Promotion compares against a frozen snapshot of the Korean strings 1.x
shipped, never the catalog. The catalog is localized: on an English
device it would return English, nothing would match, and the users this
work exists for would keep Korean notifications forever.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 10: 알림 예약 — 제목·본문을 배달 시점 해석 키로

**Files:**
- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift:47-48`

- [ ] **Step 1: 교체**

`:47-48`을 다음으로:

```swift
            // 제목·기본 본문은 키로 넣어 **표시 시점** 언어를 따른다(스펙 5.1절). 사용자가
            // 직접 쓴 문구는 평문 그대로 — 그 사람의 문장이라 번역하지 않는다.
            // 이 키들은 기기에 예약된 알림이 들고 남는 호환 계약이다. 카탈로그에서 지우거나
            // 이름을 바꾸면 잠금화면에 날 키가 뜬다.
            content.title = NSString.localizedUserNotificationString(forKey: "notificationAppName", arguments: nil)
            let message = availableMessages[index % availableMessages.count]
            content.body = message.text
                ?? NSString.localizedUserNotificationString(forKey: "reminderMessage.\(message.id)", arguments: nil)
```

- [ ] **Step 2: 빌드 + 시뮬레이터에서 알림 하나 확인**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`
Expected: `** BUILD SUCCEEDED **`

시뮬레이터(한국어)에서 설정 → 알림 켜기 → 시각을 1~2분 뒤로 → 알림 도착 시 제목 "스마일데이", 본문이 기본 문구 한국어인지 확인.

- [ ] **Step 3: 커밋**

```bash
git add SmileDay/Services/UserNotificationReminderScheduler.swift
git commit -F - <<'EOF'
feat: schedule notification title/body as delivery-time keys

Repeating notifications freeze their content when scheduled. With keys,
iOS resolves the language when it shows the banner — switching device
language changes the next reminder with no re-schedule.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 11: 1회 마이그레이션 — 옛 평문 알림을 키 기반으로 (`LocalizedReminderBackfill`)

`ReminderActionBackfill`의 형제. **승격(Task 9)이 store 읽기에서 자동으로 먼저 돌므로** 순서 제약이 충족된다.

**Files:**
- Create: `CoachingKit/Sources/CoachingKit/LocalizedReminderBackfill.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/LocalizedReminderBackfillTests.swift`
- Modify: `SmileDay/Views/RootView.swift:60-63`

- [ ] **Step 1: 실패하는 테스트**

`ReminderActionBackfillTests.swift`의 구조를 그대로 본떠 `LocalizedReminderBackfillTests.swift`를 만든다. 핵심 케이스 4개:

```swift
import XCTest
import SwiftData
@testable import CoachingKit

@MainActor
final class LocalizedReminderBackfillTests: XCTestCase {
    private final class MemoryStore: LocalizedReminderBackfillStoring {
        var hasBackfilledLocalizedReminders = false
    }

    // ReminderActionBackfillTests 의 makeSubject/FakeScheduler 를 그대로 복사해 쓴다.
    // (SmileReminderScheduleRepository는 in-memory ModelContainer로 만든다 — 그 파일 참고.)

    func test_runsOnce_withNewGroup_thenCancelsOld() async throws {
        let (backfill, scheduler, repo, store) = try makeSubject(enabled: true)
        let before = try XCTUnwrap(try repo.fetchCurrent()?.notificationGroupID)
        let ran = await backfill.runIfNeeded()
        XCTAssertTrue(ran)
        XCTAssertEqual(scheduler.scheduledGroups.count, 1)
        XCTAssertNotEqual(scheduler.scheduledGroups.first, before, "must register a NEW group first")
        XCTAssertEqual(scheduler.cancelledGroups, [before], "old group cancelled last")
        XCTAssertTrue(store.hasBackfilledLocalizedReminders)
    }

    func test_secondRun_doesNothing() async throws {
        let (backfill, scheduler, _, _) = try makeSubject(enabled: true)
        await backfill.runIfNeeded()
        let again = await backfill.runIfNeeded()
        XCTAssertFalse(again)
        XCTAssertEqual(scheduler.scheduledGroups.count, 1)
    }

    func test_whenDisabledOrNoSchedule_marksDoneWithoutScheduling() async throws {
        let (backfill, scheduler, _, store) = try makeSubject(enabled: false)
        let ran = await backfill.runIfNeeded()
        XCTAssertFalse(ran)
        XCTAssertTrue(scheduler.scheduledGroups.isEmpty)
        XCTAssertTrue(store.hasBackfilledLocalizedReminders, "nothing to migrate — don't retry forever")
    }

    func test_schedulingFailure_leavesFlagUnset_andOldGroupIntact() async throws {
        let (backfill, scheduler, repo, store) = try makeSubject(enabled: true)
        scheduler.failNextSchedule = true
        let before = try repo.fetchCurrent()?.notificationGroupID
        let ran = await backfill.runIfNeeded()
        XCTAssertFalse(ran)
        XCTAssertFalse(store.hasBackfilledLocalizedReminders)
        XCTAssertTrue(scheduler.cancelledGroups.isEmpty)
        XCTAssertEqual(try repo.fetchCurrent()?.notificationGroupID, before)
    }
}
```

Run: `cd CoachingKit && swift test --filter LocalizedReminderBackfillTests 2>&1 | grep -E "error:" | head -3`
Expected: 컴파일 에러 (타입 없음).

- [ ] **Step 2: 구현 — `ReminderActionBackfill`을 복사해 이름·플래그·주석만 바꾼다**

`CoachingKit/Sources/CoachingKit/LocalizedReminderBackfill.swift`:

```swift
import Foundation

public protocol LocalizedReminderBackfillStoring: AnyObject {
    var hasBackfilledLocalizedReminders: Bool { get set }
}

public final class UserDefaultsLocalizedReminderBackfillStore: LocalizedReminderBackfillStoring {
    private let defaults: UserDefaults
    private let key = "hasBackfilledLocalizedReminders"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public var hasBackfilledLocalizedReminders: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }
}

/// 옛 빌드가 평문 한국어로 굳혀둔 반복 알림을, 배달 시점에 해석되는 키 기반 알림으로 한 번 갈아끼운다.
///
/// 이 빌드부터 알림 제목·기본 본문은 `localizedUserNotificationString` 키다(스펙 5.1절). 그런데
/// 이미 기기에 예약된 알림은 예약 당시의 평문을 들고 있어 언어를 바꿔도 그대로다. 설정을 다시
/// 저장하기 전까지 영어 기기에 한국어 알림이 계속 온다 — 그래서 업데이트 뒤 한 번 재예약한다.
///
/// `ReminderActionBackfill`과 같은 규칙: 새 그룹 먼저, 저장, 옛 그룹은 마지막. 실패하면 표시를
/// 안 남겨 다음 실행에서 다시 시도한다. 승격(`ReminderMessageMigration`)은 `messageStore.messages`를
/// 읽는 순간 자동으로 먼저 도므로 여기서 따로 부르지 않는다.
@MainActor
public struct LocalizedReminderBackfill {
    private let scheduleRepository: SmileReminderScheduleRepository
    private let scheduler: ReminderScheduling
    private let messageStore: ReminderMessageStoring
    private let store: LocalizedReminderBackfillStoring
    private let groupIDFactory: () -> String

    public init(
        scheduleRepository: SmileReminderScheduleRepository,
        scheduler: ReminderScheduling,
        messageStore: ReminderMessageStoring = UserDefaultsReminderMessageStore(),
        store: LocalizedReminderBackfillStoring = UserDefaultsLocalizedReminderBackfillStore(),
        groupIDFactory: @escaping () -> String = { UUID().uuidString }
    ) {
        self.scheduleRepository = scheduleRepository
        self.scheduler = scheduler
        self.messageStore = messageStore
        self.store = store
        self.groupIDFactory = groupIDFactory
    }

    @discardableResult
    public func runIfNeeded() async -> Bool {
        guard !store.hasBackfilledLocalizedReminders else { return false }
        guard let schedule = try? scheduleRepository.fetchCurrent() else { return false }
        guard schedule.isEnabled, let pattern = schedule.pattern else {
            store.hasBackfilledLocalizedReminders = true
            return false
        }
        do {
            try await ReminderGroupSwap(
                scheduleRepository: scheduleRepository,
                scheduler: scheduler,
                groupIDFactory: groupIDFactory
            ).run(
                pattern: pattern,
                messages: messageStore.messages,
                previousGroupID: schedule.notificationGroupID
            )
        } catch {
            return false
        }
        store.hasBackfilledLocalizedReminders = true
        return true
    }
}
```

Run: `cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:|failed"`
Expected: `passed`

- [ ] **Step 3: `RootView`에서 호출**

`RootView.swift:60-63`의 `ReminderActionBackfill(...).runIfNeeded()` 바로 뒤에:

```swift
        // 옛 빌드가 평문으로 굳혀둔 알림을 배달 시점 해석 키로 한 번 바꾼다. 위와 같은 규칙.
        await LocalizedReminderBackfill(
            scheduleRepository: SmileReminderScheduleRepository(modelContext: modelContext),
            scheduler: UserNotificationReminderScheduler()
        ).runIfNeeded()
```

- [ ] **Step 4: 빌드 후 커밋**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build 2>&1 | grep -aE "error:|BUILD (SUCCEEDED|FAILED)"`

```bash
git add CoachingKit/Sources/CoachingKit/LocalizedReminderBackfill.swift CoachingKit/Tests/CoachingKitTests/LocalizedReminderBackfillTests.swift SmileDay/Views/RootView.swift
git commit -F - <<'EOF'
feat: one-time re-schedule so pre-existing notifications pick up delivery-time keys

Modelled on ReminderActionBackfill: new group first, save, cancel old
last; no flag on failure so the next launch retries. Users who only tap
"웃었어요" from the lock screen never render RootView and keep their
plain-text Korean reminders until the next foreground launch — which is
exactly what they had, so not a regression.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 12: `SharedStrings` 84개 → `Localizable`/화면별 카탈로그, 호출부를 심볼로

가장 큰 기계적 작업. **한 번에 다 하지 말고 파일 단위로 나눠 커밋한다.** 여기서는 절차를 정확히 정의하고, 하위 Task 12a–12e로 화면을 나눈다.

**공통 절차 (모든 하위 Task 동일)**

1. 대상 화면이 쓰는 `SharedStrings.*` 키와 인라인 리터럴을 열거한다.
2. 카탈로그(화면 테이블 또는 `Localizable`)에 키를 추가한다 — `ko`에 원문 그대로, `en`에 한국어 그대로 + `needs_review` (deck에 제안이 있는 것은 deck 문구 + `needs_review`).
3. **키 이름 = 기존 `SharedStrings` 프로퍼티 이름 그대로**(예: `todayCountTitle`). 인라인 리터럴은 화면 접두 없이 의미 이름(예: `historyNavigationTitle`).
4. 호출부: `SharedStrings.foo` → `.foo`(기본 테이블) 또는 `.Home.foo`(화면 테이블). `Text("리터럴")` → `Text(.foo)`. `String`이 필요한 자리(`accessibilityLabel`, `Button("…")`도 `LocalizedStringResource`를 받으므로 그대로 심볼)는 `String(localized: .foo)`.
5. 빌드 → 카탈로그 검사 테스트 → **한국어 이전 diff 검사**(아래) → 커밋.

**한국어 이전 diff 검사** (스펙 10절). 이 계획 착수 시점의 리터럴 목록을 한 번 뽑아두고, 카탈로그의 `ko` 값 전체와 비교한다:

```bash
# 한 번만 — Task 0 커밋 직후 기준
git show HEAD:SmileDay/Views/SharedStrings.swift | grep -o '"[^"]*[가-힣][^"]*"' | tr -d '"' | sort -u > /tmp/ko-before.txt
git ls-files 'SmileDay/Views/*.swift' | grep -v SharedStrings | xargs grep -oh '"[^"]*[가-힣][^"]*"' | tr -d '"' | sort -u >> /tmp/ko-before.txt
sort -u /tmp/ko-before.txt -o /tmp/ko-before.txt
wc -l /tmp/ko-before.txt

# 매 하위 Task 끝에
for f in SmileDay/Resources/{Localizable,Home,Onboarding,Settings,Coaching}.xcstrings; do
  jq -r '.strings | to_entries[] | .value.localizations.ko | (.stringUnit.value // (.variations.plural | to_entries[]? | .value.stringUnit.value))' "$f"
done | sort -u > /tmp/ko-after.txt
comm -23 /tmp/ko-before.txt /tmp/ko-after.txt     # 아직 안 옮긴 것 (줄어들어야 한다)
comm -13 /tmp/ko-before.txt /tmp/ko-after.txt     # 원문에 없던 한국어 (오타·변형 — 항상 빈 출력)
```
`Localizable`에 먼저 들어간 `invalidPattern` 등은 원문 목록에 있으니 문제없다. 복수형 변형은 원문이 `"\(count)번"` 같은 보간이라 `%lld번` 꼴로 달라진다 — 그 항목만 예외로 눈으로 본다.

### Task 12a: `Localizable` — 공용 문구 (알림 안내, 권한, 정책, 시작 실패, 스플래시)

**Files:** `SharedStrings.swift`의 `smileNowAction` … `disableRemindersCancelAction`(`:6-67`), `AppStartupFailureView.swift`, `SplashView.swift`, `Theme.swift:120`, `Localizable.xcstrings`, 그 호출부

- [ ] Step 1: 위 절차 1–4. `privacyPolicyURLString`·`supportURLString`은 **문구가 아니다** — `SDLinks` 같은 `enum`으로 옮겨 앱 타깃 상수로 남긴다(예: `SmileDay/Services/SDLinks.swift`).
- [ ] Step 2: 빌드, 카탈로그 검사, diff.
- [ ] Step 3: 커밋 `refactor: move shared reminder/permission/legal copy into Localizable`

### Task 12b: `Coaching` — 실시간 확인·세션 요약·가이드

**Files:** `SharedStrings.swift:69-143`, `LiveSmileMonitorView.swift`, `LiveSmileSessionSummaryView.swift`, `SmileGuideView.swift`, `Coaching.xcstrings`

- [ ] Step 1: 절차 1–4. `liveMonitorIntroPoints` 배열은 **키 5개로 쪼갠다** (`liveMonitorIntroCamera`, `liveMonitorIntroPreview`, `liveMonitorIntroGraph`, `liveMonitorIntroNoStorage`, `liveMonitorIntroBattery`) 그리고 호출부:
  ```swift
  private let introPoints: [LocalizedStringResource] = [
      .Coaching.liveMonitorIntroCamera, .Coaching.liveMonitorIntroPreview,
      .Coaching.liveMonitorIntroGraph, .Coaching.liveMonitorIntroNoStorage,
      .Coaching.liveMonitorIntroBattery,
  ]
  // ...
  ForEach(Array(introPoints.enumerated()), id: \.offset) { _, point in Text(point) ... }
  ```
- [ ] Step 2: `liveMonitorNudgeTitle = "Smile!"`는 한국어에도 영문이었다. `ko`·`en` 둘 다 `"Smile!"`로 넣는다(변경 없음).
- [ ] Step 3: `LiveSmileSessionSummaryView:95, 103`의 퍼센트 → `Text(value, format: .percent.precision(.fractionLength(0)))`. `:103`은 `Text("\(String(localized: .Coaching.liveSummaryLegendUnknown)) \(summary.unknownRatio.formatted(.percent.precision(.fractionLength(0))))")` 처럼 두 조각을 조립하되 보간 리터럴이 카탈로그로 추출되지 않게 `Text(verbatim:)`을 쓴다.
- [ ] Step 4: `LiveSmileMonitorView:343` `"\(count)단계 중 \(filled)단계"` → 키 `liveMonitorLevelSteps` 값 `%lld단계 중 %lld단계`(복수 아님), 심볼 함수로.
- [ ] Step 5: 빌드, 검사, diff, 커밋 `refactor: move coaching/live-monitor copy into the Coaching catalog`

### Task 12c: `Home` — 홈·기록

**Files:** `SmileMVPHomeView.swift`, `SmileHistoryView.swift`, `Home.xcstrings`

- [ ] Step 1: 절차 1–4. 복수형 대상(스펙 6.4절): `todaySmileCount`(`%lld번`), `todaySmileCountAccessibility`(`오늘 미소 %lld번`), `recentTotalCount`(`총 %lld번`), `monthSmileCount`, `activeDayCount`(`%lld일`), `historyDayCount`, `historyDayAccessibility`. 카탈로그에 넣을 때 **Vary by Plural** — JSON으로는:
  ```json
  "todaySmileCount" : { "extractionState" : "manual", "localizations" : {
    "ko" : { "variations" : { "plural" : { "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld번" } } } } },
    "en" : { "variations" : { "plural" : {
      "one"   : { "stringUnit" : { "state" : "needs_review", "value" : "%lld번" } },
      "other" : { "stringUnit" : { "state" : "needs_review", "value" : "%lld번" } } } } } } },
  ```
- [ ] Step 2: 날짜 8곳(스펙 6.1절) `Text(x.formatted(.dateTime.locale(SDFormat.koreanLocale)...))` → `Text(x, format: .dateTime...)` (locale 제거). 접근성 라벨의 날짜는 `x.formatted(.dateTime...)` (환경을 못 타므로 `@Environment(\.calendar)`/`.locale`을 명시적으로 넣는다: `.dateTime.month().day().calendar(calendar).locale(locale)`).
- [ ] Step 3: `SmileHistoryView:14-20`의 자체 캘린더 → `@Environment(\.calendar) private var calendar`. `:108` 요일 헤더:
  ```swift
  private var weekdayHeaders: [String] {
      let symbols = calendar.veryShortWeekdaySymbols
      let shift = calendar.firstWeekday - 1
      return Array(symbols[shift...] + symbols[..<shift])
  }
  // ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, symbol in Text(symbol) ... }
  ```
  `:158` → `(calendar.component(.weekday, from: firstDate) - calendar.firstWeekday + 7) % 7`.
- [ ] Step 4: `Theme.swift:126` `SDFormat.koreanLocale` 삭제. `SDFormatTests`(앱 테스트)에서 참조하면 같이 정리.
- [ ] Step 5: 빌드, 검사, diff, 커밋 `refactor: home/history copy into the Home catalog; calendar follows the environment`

### Task 12d: `Onboarding`

**Files:** `SmileMVPOnboardingView.swift`, `Onboarding.xcstrings`, `Theme.swift`(`reminderInterval`)

- [ ] Step 1: 절차 1–4. `:258` `"하루 \(count)번 알려드려요"` 복수형. `:279`/`SDFormat.reminderInterval(minutes:)` → `Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))` + "마다"는 키 `reminderEvery`(`%@마다`)에 포맷 결과를 인자로. 한국어에서 "30분마다"/"3시간마다"가 그대로 나오는지 확인한다 — 안 나오면 `.units` 대신 `Measurement`로 조정.
- [ ] Step 2: 빌드, 검사, diff, 커밋 `refactor: onboarding copy into the Onboarding catalog`

### Task 12e: `Settings`

**Files:** `SmileMVPSettingsView.swift`, `ReminderMessageManagementView.swift`, `Settings.xcstrings`, `Theme.swift`(`duration`)

- [ ] Step 1: 절차 1–4. `:94` `"\(count)개"` 복수형. `SDFormat.duration(seconds:)` → `Duration.seconds(s).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))` — 한국어 결과가 "3분 20초"인지 확인. `LiveSmileSessionSummaryView`도 이 함수를 쓰므로 한 번에 바뀐다.
- [ ] Step 2: 빌드, 검사, diff, 커밋 `refactor: settings copy into the Settings catalog; durations via FormatStyle`

### Task 12f: `SharedStrings.swift` 삭제

- [ ] Step 1: `grep -rn "SharedStrings" SmileDay/ SmileDayTests/` → 빈 출력 확인.
- [ ] Step 2: `git rm SmileDay/Views/SharedStrings.swift`. 빌드. `comm -23 /tmp/ko-before.txt /tmp/ko-after.txt`가 URL 2개와 보간 항목만 남기는지 확인.
- [ ] Step 3: 커밋 `refactor: remove SharedStrings — the catalogs are the source of copy now`

---

## Task 13: 카탈로그 상태 게이트 스크립트 + CLAUDE.md 갱신

**Files:**
- Create: `scripts/check-catalogs.sh`
- Modify: `CLAUDE.md`

- [ ] **Step 1: 게이트 스크립트**

```bash
mkdir -p scripts
cat > scripts/check-catalogs.sh <<'EOF'
#!/usr/bin/env bash
# String Catalog 게이트. 2단계 종료 조건: en/ko 값이 비었거나 needs_review/new 인 항목이 0개.
# 1단계에서는 needs_review 가 많은 것이 정상이다 — 개수만 보고한다.
set -euo pipefail
cd "$(dirname "$0")/.."
total=0; review=0; empty=0
for f in SmileDay/Resources/{Localizable,Home,Onboarding,Settings,Coaching}.xcstrings; do
  t=$(jq '.strings | length' "$f")
  r=$(jq '[.strings[] | .localizations[]? | (.stringUnit.state // (.variations.plural[]?.stringUnit.state)) | select(. == "needs_review" or . == "new")] | length' "$f")
  e=$(jq '[.strings | to_entries[] | select((.value.localizations.en // null) == null or (.value.localizations.ko // null) == null)] | length' "$f")
  echo "$(basename "$f"): keys=$t needs_review=$r missing_lang=$e"
  total=$((total+t)); review=$((review+r)); empty=$((empty+e))
done
echo "TOTAL keys=$total needs_review=$review missing_lang=$empty"
[ "$empty" -eq 0 ] || { echo "FAIL: keys missing a language"; exit 1; }
if [ "${STRICT:-0}" = "1" ] && [ "$review" -ne 0 ]; then echo "FAIL: needs_review remaining"; exit 1; fi
EOF
chmod +x scripts/check-catalogs.sh
./scripts/check-catalogs.sh
```
Expected: `missing_lang=0`, `needs_review`는 100+ (정상). `STRICT=1`이 2단계 게이트.

- [ ] **Step 2: CLAUDE.md에 로컬라이제이션 절 추가**

"Conventions" 절의 첫 항목("All user-facing copy is Korean; the app pins `Locale(identifier: "ko_KR")`…")을 다음으로 교체:

```markdown
- User-facing copy lives in String Catalogs under `SmileDay/Resources/` (`Localizable` + one per screen: `Home`, `Onboarding`, `Settings`, `Coaching`, plus `InfoPlist`). Source language is **English** (`developmentRegion = en` — it is the fallback for devices we don't translate for); Korean is the `ko` column. Code references copy only through the Xcode-generated `LocalizedStringResource` symbols (`Text(.todayCountTitle)`, `.Home.…`); never write a key literal. CoachingKit holds no user-facing strings — SwiftPM cannot compile `.xcstrings`, so `String(localized:)` there silently returns the key. `StringCatalogGuaranteeTests` parses the catalogs from disk and enforces banned wording (ko + en), no missing values, and id ↔ key parity for cues and default reminder messages. `scripts/check-catalogs.sh` reports `needs_review` counts; `STRICT=1` is the release gate.
- Notification title/body are scheduled as `localizedUserNotificationString` keys and resolve in the device language at delivery. `reminderMessage.<id>` / `notificationAppName` / `reminderAction.<rawValue>` keys are therefore a compatibility contract with notifications already on devices — do not rename or delete them.
- Do not add `NSCameraUsageDescription` or `CFBundleDisplayName` to `InfoPlist.xcstrings` without keeping the `INFOPLIST_KEY_*` build setting: this project generates its Info.plist and the catalog only overrides values for keys that already exist.
```

- [ ] **Step 3: 커밋**

```bash
git add scripts/check-catalogs.sh CLAUDE.md
git commit -F - <<'EOF'
docs: catalog gate script; CLAUDE.md describes the localization layout and its contracts

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
```

---

## Task 14: 1단계 최종 검증

**Files:** 없음 (검증만)

- [x] **Step 1: 자동 검증 전부**

```bash
cd CoachingKit && swift test 2>&1 | grep -E "Test Suite 'All tests'|error:|failed"; cd ..
xcodebuild test -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -aE "error:|TEST (SUCCEEDED|FAILED)"
./scripts/check-catalogs.sh
grep -rn "SDFormat.koreanLocale\|SharedStrings\.\|ko_KR" SmileDay/ CoachingKit/Sources/ || echo "clean"
```
Expected: 두 테스트 통과, `missing_lang=0`, 마지막 grep `clean`.

- [x] **Step 2: CoachingKit에 표시용 String 반환 public API가 없는지 (스펙 10절)**

```bash
python3 - <<'PY'
import re, pathlib
lit=re.compile(r'"(?:[^"\\]|\\.)*"'); han=re.compile(r'[가-힣]')
hits=[]
for p in pathlib.Path('CoachingKit/Sources').rglob('*.swift'):
    s=re.sub(r'/\*.*?\*/','',p.read_text(),flags=re.S)
    for i,l in enumerate(s.split('\n'),1):
        code=l.split('//')[0]
        for m in lit.finditer(code):
            if han.search(m.group()): hits.append(f"{p}:{i}: {m.group()}")
print("\n".join(hits) or "no Korean string literals outside comments")
PY
```
Expected: `ReminderMessageMigration.swift`의 스냅샷 8줄만 남는다(의도 — 마이그레이션 데이터).

- [x] **Step 3: 시뮬레이터 수동 검증 — 한국어**

한국어 시뮬레이터로 전 화면 훑기: 온보딩(신규 설치) → 홈 → 가이드 → 기록(월간 달력, 요일 헤더 일~토, 오늘 선택) → 설정 → 알림 문구 관리(기본 문구 열고 저장 → 목록에서 여전히 기본으로 보이는지) → 실시간 확인 인트로 → 세션 요약. **모든 문구가 오늘과 동일**해야 한다. 홈 화면 아이콘 이름 "스마일데이".

- [ ] **Step 4: 시뮬레이터 수동 검증 — 영어 + 영국 지역**

언어 English, 지역 United Kingdom: 기록 화면 요일 헤더가 **M T W T F S S 7칸 전부** 그려지고 날짜가 어긋나지 않는지, 24시간제로 알림 시각이 표시되는지, 카메라 권한 대화상자가 영어인지, 알림 제목이 "SmileDay"인지. 한국어가 보이는 것은 정상(1단계 시딩) — 다만 **키 문자열**(예: `todayCountTitle`)이 보이면 오타이므로 고친다.

- [ ] **Step 5: 시뮬레이터 수동 검증 — 접근성**

`.accessibility5` 크기 + 영어 + iPhone SE 시뮬레이터: 홈·기록 통계 카드가 세로로 넘치지 않는지. 넘치면 해당 `HStack`을 `ViewThatFits`로 감싼다(1단계 범위 안).

- [ ] **Step 6: 업그레이드 경로 검증**

Task 0 커밋 시점 빌드를 시뮬레이터에 설치 → 알림 켜고 문구 하나 편집 → 이 브랜치 빌드로 덮어 설치 → 앱 실행 → 설정 → 알림 문구 관리: 편집한 문구는 그대로, 나머지는 기본. **여기까지는 v2가 아직 없다** — 읽기 경로는 승격만 하고 쓰지 않는다. 문구 하나를 더 편집(또는 순서 변경)한 뒤 `xcrun simctl spawn booted defaults read <bundle-id> reminderMessages.v1`이 **바이트 그대로** 있고 `reminderMessages.v2`가 새로 생겼는지. 다음 알림이 도착하는지.

- [x] **Step 7: 스펙 상태 갱신 + 커밋**

스펙 상단 상태를 "승인됨 — **1단계 구현 완료 (날짜)**"로. 미확인 항목 11절에 심볼 이름 변환 실측 결과를 기록.

```bash
git add docs/superpowers/specs/2026-08-15-english-localization-design.md
git commit -m "docs: mark English support phase 1 (plumbing) complete

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## 다음 단계 (이 계획 밖)

- **2단계 — 영어 문구 집필.** `./scripts/check-catalogs.sh`의 `needs_review` 큐를 deck의 톤 규칙으로 비운다. `STRICT=1`이 통과하면 끝. deck에 없는 약 160개(실시간 확인 상세, 오류·복구, 설정, 권한 안내, 접근성 라벨, 데이터 저장 위치)가 대상.
- **App Store 영어 페이지·정책 페이지** (스펙 7절) — 코드 밖.
