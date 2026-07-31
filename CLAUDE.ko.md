# CLAUDE.md (한국어)

이 파일은 Claude Code(claude.ai/code)가 이 저장소에서 작업할 때 참고하는 안내 문서입니다.

## 명령어

```bash
# CoachingKit 테스트 전체 실행 (순수 Swift, macOS에서 실행 — 시뮬레이터 불필요)
cd CoachingKit && swift test

# 특정 테스트 클래스만 실행
cd CoachingKit && swift test --filter SmileMomentRepositoryTests

# iOS 앱 빌드 (SwiftUI 뷰 / 앱 타겟 코드의 컴파일 확인)
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -sdk iphonesimulator build
```

린트 설정은 없습니다. SwiftUI 뷰에는 자동화된 테스트가 없으므로, 뷰 레이어 변경에 대한 검증은 `xcodebuild` 성공 여부로 판단합니다.

참고: 테스트는 XCTest 기반이라 `swift test` 출력의 마지막 줄은 Swift Testing 러너가 남기는 "0 tests in 0 suites passed"인데, 이는 실패가 아닙니다. 출력에서 `Test Suite 'All tests' passed`를 확인하세요.

## 아키텍처

SmileDay는 일상에서 잘 웃지 않는 사람이 미소 짓는 횟수를 늘리도록 돕는 한국어 iOS 앱입니다(iOS 17+, SwiftUI + SwiftData). 모든 데이터는 기기 내에만 저장되며 서버는 없습니다.

제품의 우선순위이자 유일하게 기록을 남기는 핵심 루프는 다음과 같습니다:

```
반복 알림 → 비평가적 문구 → 5초 미소 → 완료 시각 저장 → 오늘과 최근 7일 횟수 확인
```

이 루프는 카메라를 쓰지 않습니다. 카메라 권한은 온보딩 단계가 아니며, 미소 완료에 필요하지도 않습니다.

선택형 부가 모드로 "실시간 미소 확인"이 하나 있고, 홈의 보조 카드에서만 들어갑니다. 사용자가 명시적으로 실행하는 동안 TrueDepth 카메라가 세션 시작 시 편한 표정 대비 입꼬리 계수가 얼마나 올라왔는지를 0–100 실시간 신호로 보여줍니다. 경계는 분명합니다:

- 카메라 화면은 기본으로 꺼져 있고, 토글로 그 세션에만 켭니다. 켜면 돌고 있는 `ARSession`을 `ARSCNView`로 그립니다. `ARFrame.capturedImage`는 분당 1회 스냅샷을 찍을 때만 읽습니다 — 프레임마다 읽지 않고, 프리뷰 자체도 이를 읽지 않습니다.
- 1분에 1장 사진을 집고, 끝나면 세션 타임라인과 미소 비율을 보여줍니다. 전부 메모리에만 있고 요약 화면을 닫으면 사라집니다.
- 저장도 전송도 하지 않습니다 — 사진·영상·blend shape·단계·타임라인·측정 시간이 SwiftData·UserDefaults·파일 시스템·네트워크로 나가지 않습니다. 촬영·내보내기·공유 경로가 없습니다.
- 완료 횟수에 더해지지 않습니다. 실시간 확인을 켠 것과 미소를 완료한 것은 다른 행동입니다.
- 점수는 판정이 아니라 센서 값입니다. 외모·감정·Duchenne 여부·좌우 대칭을 평가하지 않습니다.

코드베이스는 두 개의 레이어로 나뉩니다:

- **`CoachingKit/`** — 플랫폼과 무관한 모든 것을 담은 로컬 Swift 패키지입니다: SwiftData `@Model` 클래스, `ModelContext`를 감싸는 리포지토리(`SmileMomentRepository`, `SmileReminderScheduleRepository`, `LegacyReminderRepository`), `@Observable` 뷰 모델(`SmileHomeViewModel`, `SmileGuideViewModel`, `SmileReminderScheduleViewModel`, `SmileOnboardingViewModel`), 값 타입(`SmileCue`, `SmileGuide`, `SmileReminderPattern`, `ReminderNotificationPayload`). 이 패키지는 macOS도 타겟으로 하여 시뮬레이터 없이 Mac에서 `swift test`가 실행되도록 합니다. **새로운 로직은 앱 타겟이 아니라 이곳에 테스트와 함께 추가해야 합니다.**
- **`SmileDay/`** — 앱 타겟입니다: SwiftUI 뷰(`Views/`)와 플랫폼 서비스(`Services/`). CoachingKit 프로토콜 두 개를 구현합니다: `UserNotificationReminderScheduler`의 `ReminderScheduling`, 그리고 선택형 실시간 모드의 ARKit/AVFoundation 경계인 `ARKitLiveSmileMonitor`의 `LiveSmileMonitoring`. 뷰는 뷰 모델을 생성하고 이 구체 서비스를 주입하며, 테스트에서는 페이크를 주입합니다.

영속성은 두 층으로 나뉘고, 둘 다 `PersistenceSchema`에 등록됩니다:

- 활성: `SmileMoment`(완료한 미소 하나), `SmileReminderSchedule`(단일 반복 스케줄).
- 호환 전용, 화면에서 읽지 않음: `Baseline`, `CheckInSession`, `CareSession`, `ReminderSetting`, `CustomSmileCard`. 기존 사용자의 저장소가 계속 열리도록 남겨둔 것입니다. **버전드 마이그레이션 설계 없이 삭제하거나 저장 프로퍼티를 바꾸지 마세요.**

앱 흐름: 스플래시 → 최초 1회 알림 시간대 온보딩 → `SmileMVPHomeView`(오늘 횟수, 다음 알림, 최근 7일) → 미소 가이드 전체 화면 → 설정에서 반복 스케줄 편집. 스케줄은 `UserNotificationReminderScheduler`로 매일 반복 알림으로 등록되며, 알림 탭은 `AppDelegate` → `NotificationRouter`(environment object로 주입)를 거쳐 수동 실행과 같은 가이드를 엽니다. 레거시 경로 두 가지는 의도적으로 남겨둡니다: `cancel(id:)`는 옛 빌드가 만든 identifier를 그대로 재구성해 지우고, `ReminderNotificationPayload`는 옛 `bucket`/`promptText` payload도 계속 파싱합니다.

## 컨벤션

- 모든 사용자 대상 문구는 한국어이며, 앱은 날짜/차트 축도 한국어로 표시되도록 `Locale(identifier: "ko_KR")`을 고정합니다. 공용 문자열은 `Views/SharedStrings.swift`에 있습니다.
- 건강 관련 표현은 제한됩니다(App Store 가이드라인 1.4.1): "리프팅", "젊어진다", "교정한다", "치료" 같은 문구는 절대 사용하지 마세요. 대신 습관 인식 프레이밍을 사용하세요("표정 습관을 기록한다").
- 등급이나 연속 기록 실패 표현을 쓰지 않습니다. 0회인 날은 실패가 아니라 그냥 쉬어간 날입니다. 사용자에게 보이는 가이드 문구는 `SmileCueCatalog`에 있습니다.
- "점수"라는 이름으로 보여주는 유일한 값은 실시간 모드의 센서 신호이며, 저장하거나 세션 간에 비교하거나 좋고 나쁨으로 표현하지 않습니다.
- `SmileGuideCatalog.default.id`(`"anytime-soft"`)는 저장되는 값입니다 — `SmileMoment.guideID`와 이미 기기에 예약된 알림 payload에 들어 있습니다. 바꾸지 마세요.
- 디자인 스펙은 `docs/superpowers/specs/`에, 구현 계획은 `docs/superpowers/plans/`(날짜별 마크다운 파일)에 있습니다. 기능을 확장하기 전에 관련 스펙을 먼저 확인하세요.
