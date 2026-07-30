# 미소 빈도·반복 중심 시간창 리마인더 Implementation Plan

> 구현 전 대응 설계 `SmileDay/docs/superpowers/specs/2026-07-29-smile-frequency-window-reminders-design.md`를 전체 읽는다. 이 계획은 상황 카드 확장이 아니라, 현재 MVP를 시작·종료 시간과 반복 주기 중심으로 단순화한다.

**Goal:** 평소 잘 웃지 않는 사용자가 설정한 활동 시간 안에서 반복 알림을 받고, 짧은 문구와 5초 미소를 반복한 뒤 오늘과 최근 7일 횟수를 확인하게 한다.

**Architecture:** `CoachingKit`에 단일 반복 스케줄 모델·저장소, 시간 계산기, 비평가적 문구 카탈로그·순환 선택기, 빈도 중심 홈 집계를 둔다. 앱 타깃은 반복 `UNCalendarNotificationTrigger` 예약과 단순한 온보딩·홈·설정·실행 화면만 담당한다. 기존 개별 리마인더와 상황 카드 데이터는 호환을 위해 보존하지만 새 Root 흐름에서 분리한다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, UserNotifications, Observation, XCTest, iOS 17+.

---

### Task 0: 기준 상태와 목적 고정

**Files:**

- Verify: `AGENTS.md`
- Read: `SmileDay/docs/reports/2026-07-27-project-review.md`
- Read: `SmileDay/docs/superpowers/specs/2026-07-29-smile-frequency-window-reminders-design.md`

- [ ] `AGENTS.md`의 Product North Star를 구현 판단의 최상위 제품 기준으로 사용한다.
- [ ] 기존 작업 트리와 사용자 변경을 확인하고 겹치는 파일을 덮어쓰지 않는다.
- [ ] 최신 리뷰 이후 변경된 iOS 17 타깃은 현재 소스로 재확인한다.
- [ ] 아직 남은 `try! ModelContainer`와 실제 Metal `fatalError`는 제품 전환과 별도의 P0 안정성 선행 위험으로 기록한다.
- [ ] 기준 테스트와 빌드를 실행한다.

```bash
cd CoachingKit && swift test
cd ..
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected: `Test Suite 'All tests' passed`, `** BUILD SUCCEEDED **`.

---

### Task 1: 반복 스케줄 값 타입과 시간 계산

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileReminderPattern.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileReminderPatternTests.swift`

- [ ] `ReminderTime(hour:minute:)` 값을 추가하고 시·분 범위를 검증한다.
- [ ] `SmileReminderPattern`에 시작, 종료, `intervalMinutes`를 둔다.
- [ ] 허용 주기를 60·120·180·240분으로 제한한다.
- [ ] 시작 포함, 종료는 정확히 맞을 때만 포함하는 `occurrences()`를 구현한다.
- [ ] 시작≥종료와 자정 넘김을 명시적 오류로 반환한다.
- [ ] 기본 패턴을 09:00~21:00, 180분으로 둔다.

Tests:

- [ ] 09:00~21:00/180분 → 09, 12, 15, 18, 21시
- [ ] 종료가 주기와 맞지 않으면 마지막 초과 시각 제외
- [ ] 60·120·180·240분 경계
- [ ] 잘못된 시·분, 시작≥종료, 미지원 주기
- [ ] 결과 정렬과 중복 없음

```bash
cd CoachingKit && swift test --filter SmileReminderPatternTests
```

---

### Task 2: 단일 스케줄 SwiftData 모델과 저장소

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileReminderSchedule.swift`
- Create: `CoachingKit/Sources/CoachingKit/SmileReminderScheduleRepository.swift`
- Modify: `CoachingKit/Sources/CoachingKit/PersistenceSchema.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileReminderScheduleRepositoryTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/PersistenceSchemaMigrationTests.swift`

- [ ] 설계의 optional 없는 필드와 안정적인 `notificationGroupID`를 구현한다.
- [ ] `fetchCurrent`, `save(pattern:isEnabled:)`, `setEnabled` API를 구현한다.
- [ ] 저장 레코드가 없으면 기본 패턴을 값으로 제공하되 사용자가 확정하기 전에는 저장하지 않는다.
- [ ] 중복 레코드는 최신값을 읽고 자동 삭제하지 않는다.
- [ ] `PersistenceSchema.models`에 새 모델을 추가하고 기존 모델은 모두 유지한다.
- [ ] 구 스키마 파일을 새 스키마로 여는 마이그레이션 테스트를 갱신한다.

```bash
cd CoachingKit
swift test --filter SmileReminderScheduleRepositoryTests
swift test --filter PersistenceSchemaMigrationTests
```

---

### Task 3: 기존 개별 알림의 제안 변환

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/LegacyReminderPatternAdapter.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/LegacyReminderPatternAdapterTests.swift`

- [ ] 활성 `ReminderSetting`을 시각순으로 정렬한다.
- [ ] 시각이 정확한 등차수열이고 간격이 허용 주기일 때만 패턴 제안값을 만든다.
- [ ] 한 개, 불규칙 간격, 중복 시각, 미지원 간격은 자동 변환하지 않는다.
- [ ] 변환은 제안만 하고 기존 레코드와 pending notification을 변경하지 않는다.
- [ ] 새 스케줄 저장·예약 성공 후에만 레거시 알림 취소를 허용하는 결과 타입을 둔다.

```bash
cd CoachingKit && swift test --filter LegacyReminderPatternAdapterTests
```

---

### Task 4: 반복 알림 스케줄러 API

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/ReminderScheduling.swift`
- Modify: `SmileDay/Services/UserNotificationReminderScheduler.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SettingsViewModelTests.swift` or replace with new schedule ViewModel tests

- [ ] `scheduleDailyPattern(groupID:times:)`와 `cancelGroup(id:)` 경계를 추가한다.
- [ ] 각 시각에 date component의 hour/minute만 갖는 `repeats: true` 요청을 만든다.
- [ ] identifier를 `groupID-hour-minute` 형식으로 결정적으로 생성한다.
- [ ] 설정 변경 전 기존 group 요청을 모두 취소한다.
- [ ] 알림 title/body는 상황·시간대와 무관한 초대형 문구로 고정한다.
- [ ] payload는 가이드 ID에 의존하지 않는 새 schedule payload를 지원한다.
- [ ] 기존 `scheduleRollingWindow`는 레거시 취소·마이그레이션 동안만 유지한 뒤 호출부가 0인지 확인한다.
- [ ] `reminderRollingWindowDays`와 앱 활성화 때마다 14일치를 다시 채우는 의존을 새 흐름에서 제거한다.

Verification:

```bash
rg -n 'scheduleRollingWindow|reminderRollingWindowDays' CoachingKit SmileDay --glob '*.swift'
```

새 Root 호출 경로에는 결과가 없어야 한다.

---

### Task 5: 비평가적 미소 문구 카탈로그와 순환

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileCue.swift`
- Create: `CoachingKit/Sources/CoachingKit/SmileCueCursorStore.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileCueTests.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileCueSelectorTests.swift`

- [ ] 설계의 기본 문구를 ID가 안정적인 값 타입 카탈로그로 만든다.
- [ ] 사용자에게 카테고리나 아침·낮·저녁 레이블을 노출하지 않는다.
- [ ] 직전 문구를 바로 반복하지 않는 순환 선택기를 구현한다.
- [ ] UserDefaults와 InMemory cursor store를 둔다.
- [ ] 모든 문구가 비어 있지 않고 건강·외모 효과나 평가 표현이 없는지 테스트한다.
- [ ] `사랑받`, `예뻐`, `인상 개선`, `교정`, `치료`, `더 크게`, `잘 웃` 같은 부담·평가 패턴을 테스트한다.
- [ ] 좋은 기억이 떠오르지 않는 상태를 허용하는 문구가 카탈로그에 포함됐는지 테스트한다.

```bash
cd CoachingKit
swift test --filter SmileCueTests
swift test --filter SmileCueSelectorTests
```

---

### Task 6: 반복 스케줄 ViewModel

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/SmileReminderScheduleViewModel.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/SmileReminderScheduleViewModelTests.swift`

- [ ] 편집 상태를 시작 시각, 종료 시각, 반복 주기, 활성 상태로 제한한다.
- [ ] 계산된 하루 알림 횟수와 시각 목록을 노출한다.
- [ ] 저장 성공 후 반복 알림을 재예약한다.
- [ ] 예약 실패 시 저장 상태와 UI 오류가 어긋나지 않도록 결과를 명시한다.
- [ ] 권한 거부여도 패턴 저장과 수동 미소 사용을 허용한다.
- [ ] 새 패턴 저장·예약 성공 후 레거시 pending notification을 취소한다.
- [ ] 다음 알림 계산을 같은 `occurrences()` 결과에서 파생해 화면과 실제 예약이 어긋나지 않게 한다.

Tests:

- [ ] 기본값과 편집
- [ ] 유효하지 않은 범위 저장 차단
- [ ] 켜기·끄기와 재예약
- [ ] 권한 허용·거부
- [ ] 저장 실패·예약 실패
- [ ] 자정 전후 다음 알림
- [ ] 레거시 변환 성공·보류

---

### Task 7: 온보딩을 시작·종료·반복 설정으로 교체

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/SmileOnboardingState.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileOnboardingStateTests.swift`
- Modify: `SmileDay/Views/Onboarding/SmileMVPOnboardingView.swift`

- [ ] 목적 문구를 “평소 잘 웃지 않는 나를 위해, 하루에 몇 번 잠깐 웃어보는 시간을 만들어요.”로 바꾼다.
- [ ] `ReminderDraft` 배열과 개별 추가·삭제를 제거한다.
- [ ] 상황 카드 목록·선택을 제거한다.
- [ ] 시작·종료 DatePicker와 1·2·3·4시간 주기 Picker를 제공한다.
- [ ] “하루 N번 알려드려요” 미리보기를 표시한다.
- [ ] 사용자가 확정한 뒤 알림 권한을 요청한다.
- [ ] 저장과 예약이 모두 성공한 뒤에만 onboarding 완료 flag를 기록한다.
- [ ] 권한 거부 시에도 앱 진입과 수동 미소를 허용한다.

---

### Task 8: 홈을 빈도와 반복 중심으로 단순화

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/SmileHomeViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileHomeViewModelTests.swift`
- Modify: `SmileDay/Views/Home/SmileMVPHomeView.swift`
- Modify: `SmileDay/Views/SharedStrings.swift`

- [ ] `SmileGuideLibrary`, `guides`, `suggestedGuide`, `DaySlot` 의존을 제거한다.
- [ ] 다음 알림은 단일 패턴의 occurrence 계산 결과로 구한다.
- [ ] 최근 7일 총 완료 횟수를 집계한다.
- [ ] “오늘 미소 N번”과 “지금 한 번 웃기”를 최상단에 유지한다.
- [ ] “이번 주 N일”을 “최근 7일 N번”으로 교체한다.
- [ ] 날짜별 횟수 도트는 유지한다.
- [ ] 상황 선택 줄, 카드 picker, 내 카드 추가 흐름을 홈에서 제거한다.
- [ ] 알림 딥링크와 수동 진입 모두 다음 순환 문구를 가진 동일 실행 화면을 연다.

```bash
rg -n 'DaySlot|suggestedGuide|SmileGuidePickerSheet|AddSmileCardView' \
  SmileDay/Views/Home CoachingKit/Sources/CoachingKit/SmileHomeViewModel.swift
```

Expected: 새 홈 경로에서 결과 없음.

---

### Task 9: 실행 화면에 생각 문구 적용

**Files:**

- Modify: `CoachingKit/Sources/CoachingKit/SmileGuideViewModel.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/SmileGuideViewModelTests.swift`
- Modify: `SmileDay/Views/Coaching/SmileGuideView.swift`
- Modify: `SmileDay/Views/SharedStrings.swift`

- [ ] 화면 진입 시 `SmileCueSelector`에서 문구 하나를 받는다.
- [ ] 문구 아래에 중립적 신체 안내를 보조 문구로 표시한다.
- [ ] 기존 5초 타이머와 자기 보고 완료를 유지한다.
- [ ] 중도 닫기 미기록, start 연타 방지, 완료 정확히 한 번 저장을 회귀 테스트한다.
- [ ] 완료 문구를 “오늘 한 번 더 웃어봤어요.”로 바꾼다.
- [ ] 문구 ID 저장은 빈도 지표에 필요하지 않으므로 이번 작업에서 `SmileMoment` 스키마를 확장하지 않는다.

---

### Task 10: 설정 화면 단순화

**Files:**

- Modify: `SmileDay/Views/Settings/SmileMVPSettingsView.swift`
- Modify: `SmileDay/Views/RootView.swift`
- Disconnect: `SmileDay/Views/Guides/SmileGuidePickerSheet.swift`
- Disconnect: `SmileDay/Views/Guides/AddSmileCardView.swift`

- [ ] 개별 알림 목록 CRUD를 단일 패턴 편집으로 교체한다.
- [ ] 미소 카드 관리, 숨김, 복구 섹션을 제거한다.
- [ ] 활성 토글과 시작·종료·주기, 예상 시각만 표시한다.
- [ ] 알림 권한과 온디바이스 저장 설명을 유지한다.
- [ ] 앱 활성화 시 rolling window 재예약 코드를 제거한다. repeating request는 설정 변경 때만 갱신한다.
- [ ] 상황 카드 파일은 이번 Task에서 삭제하지 않고 Root에서 도달하지 않게 한다.

---

### Task 11: 레거시 연결 해제와 정적 목적 감사

**Files:**

- Modify as needed: `SmileDay/Views/**/*.swift`
- Do not delete legacy persistence models in this Task

- [ ] 새 Root 흐름에서 `DaySlot`, `CustomSmileCard`, `HiddenSmileGuideStoring`, `SmileGuideLibrary` 호출부가 없는지 확인한다.
- [ ] 새 Root 흐름에서 개별 `ReminderSetting` CRUD가 없는지 확인한다.
- [ ] 카메라·기준선·점수·케어·Pro 화면은 계속 도달 불가능한지 확인한다.
- [ ] 사용자 문구에 금지 표현과 목적 이탈 문구가 없는지 검색한다.

```bash
rg -n '아침|낮|저녁|상황 카드|카드 추가|점수|기준선|교정|치료|리프팅|인상 개선' \
  SmileDay/Views/Onboarding/SmileMVPOnboardingView.swift \
  SmileDay/Views/Home/SmileMVPHomeView.swift \
  SmileDay/Views/Coaching/SmileGuideView.swift \
  SmileDay/Views/Settings/SmileMVPSettingsView.swift
```

검출된 문자열은 시간 선택기의 시스템 표기와 실제 목적 이탈 문구를 구분해 판정한다.

---

### Task 12: 전체 자동 검증

- [ ] `CoachingKit` 전체 테스트:

```bash
cd CoachingKit && swift test
```

Expected: `Test Suite 'All tests' passed`.

- [ ] 앱 빌드:

```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] 정적 검사:

```bash
git diff --check
git status --short
git diff --stat
```

- [ ] 새 스키마로 기존 저장소를 열어 `ReminderSetting`, `SmileMoment`, `CustomSmileCard` 데이터가 유지되는지 확인한다.

---

### Task 13: 실기기 반복 알림 QA

**Required:** iOS 17 이상 iPhone. TrueDepth는 필요하지 않다.

- [ ] 신규 설치에서 09:00~21:00/3시간 기본값이 하루 5회로 표시됨
- [ ] 시작·종료·주기 변경 후 pending request 시각 일치
- [ ] 앱을 종료해도 일일 repeating notification이 도착함
- [ ] 날짜가 바뀐 다음 날에도 재실행 없이 알림이 반복됨
- [ ] 알림 허용·거부·설정 앱에서 재허용
- [ ] 알림 끄기 후 해당 group pending request가 모두 제거됨
- [ ] 알림 탭 → 순환 문구 → 5초 → 완료 1개
- [ ] 수동 진입 → 순환 문구 → 완료 1개
- [ ] 중도 닫기 → 기록 없음
- [ ] 오늘 횟수와 최근 7일 총 횟수 즉시 갱신
- [ ] 큰 글자와 VoiceOver에서 시간 설정·문구·타이머 사용 가능
- [ ] 알림 문구가 운전·보행 중 화면 사용을 유도하지 않음

결과는 `SmileDay/docs/reports/YYYY-MM-DD-smile-frequency-window-device-verification.md`에 기기, iOS, 빌드/커밋, PASS/FAIL만 기록한다.

---

### Task 14: 7일 사용자 검증 게이트

- [ ] 평소 잘 웃지 않는 사용자 5~10명이 최소 7일 사용한다.
- [ ] 알림 전후로 “웃는 것을 떠올린 횟수가 늘었는가”를 인터뷰한다.
- [ ] 기본 3시간 주기와 하루 예상 횟수의 부담을 확인한다.
- [ ] 생각 문구가 도움이 됐는지, 감정 강요처럼 느껴졌는지 확인한다.
- [ ] 홈에서 오늘 횟수와 최근 7일 횟수가 행동 반복을 이해시키는지 확인한다.
- [ ] 다음 기능은 반복적으로 확인된 문제만 별도 spec↔plan으로 올린다.
  - 요일별 시간창
  - 문구 끄기·즐겨찾기
  - 알림 건너뛰기와 방해 금지
  - Apple Watch 또는 위젯
- [ ] 얼굴 점수, 기준선, AR 분석, 상황 카드 확장은 사용자 검증 없이 복구하지 않는다.

---

## 실행 기록 (2026-07-29)

구현 완료:

- 단일 `SmileReminderSchedule` SwiftData 모델과 저장소
- 09:00~21:00, 1·2·3·4시간 반복 시간 계산
- 시각별 매일 반복 `UNCalendarNotificationTrigger`
- 비평가적 문구 8개와 재실행 후 이어지는 순환 선택
- 온보딩·홈·미소 실행·설정을 빈도·반복 중심 흐름으로 전환
- 아침·낮·저녁 상황 카드와 개별 알림 CRUD를 새 Root 흐름에서 제거
- 오늘 횟수, 최근 7일 총 횟수, 다음 알림 표시
- 기존 개별 알림 사용자는 새 시간창을 직접 확인하도록 온보딩 재진입
- 새 스케줄 저장 성공 뒤에만 기존 pending 알림 취소
- 시작 화면의 낮은 글자 대비와 효과 암시 문구 수정

검증:

- `CoachingKit` 전체 389개 테스트가 통과했다.
- 핵심 화면과 서비스 파일의 Swift parser 검사를 통과했다.
- `SDPaletteTests` 8개가 `ink`/`muted` 본문을 흰 카드와 크림 배경 모두 4.5:1 이상으로 고정하고 코랄 아이콘 대비도 확인한다.
- 시작 화면의 기존 크림 글씨/코랄 배경 조합은 약 3:1 미만이어서, 크림 배경의 `ink`(11.04:1)와 `muted`(4.68:1)로 교체했다.
- 앱 `xcodebuild`는 소스 컴파일 전에 실행 환경의 `sandbox-exec: sandbox_apply: Operation not permitted`로 패키지 해석이 중단되어 미판정이다.

계획과 달라진 점:

- 불규칙한 기존 개별 알림을 자동 추정하지 않는다. 새 스케줄이 없는 기존 사용자는 설정 온보딩을 다시 보고 직접 확정한다.
- 새 반복 알림 payload는 데이터 호환을 위해 기존 `ReminderNotificationPayload`에 기본 guide ID를 싣는다. 새 화면은 이 ID를 상황 선택에 사용하지 않고 문구 순환만 시작한다.

남은 외부 검증:

- 권한 제한이 없는 Xcode 환경에서 앱 빌드
- iOS 17 이상 실기기에서 매일 반복 알림, 권한 변경, 앱 종료 상태 딥링크 확인
- 5~10명의 7일 사용성 검증
