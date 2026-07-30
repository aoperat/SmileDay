# SmileDay 프로젝트 전체점검 보고서

- 작성일: 2026-07-30
- 기준 브랜치/커밋: `main` / `d1a8f87`
- 기준 상태: 위 커밋 이후의 대규모 미커밋·미추적 리팩터링을 포함한 현재 작업 트리
- 점검 범위: 제품 핵심 루프, 앱·패키지 구조, SwiftData 호환성, 알림, 선택형 실시간 모드, 개인정보·심사 준비, 사용자 문구, 자동 테스트, 앱 빌드
- 이전 전체점검: `2026-07-27-project-review.md`

## 1. 결론

현재 구현은 “반복 알림 → 짧은 문구 → 5초 미소 → 완료 저장 → 오늘·최근 7일 횟수”라는 제품 중심축에 잘 수렴했다. 2026-07-27 점검의 최소 iOS 버전 불일치, SwiftData 시작 강제 종료, Metal 프리뷰 강제 종료, 과거 점수·외모 개선 기능 잔존 문제는 현재 작업 트리에서 해소됐다.

점검에서 확인한 코드 위험은 같은 날 수정했다. `PrivacyInfo.xcprivacy` 추가, 알림 예약 실패 전파·부분 등록 롤백·기존 알림 보존, 실시간 모드 실패 시 idle timer 즉시 복원, 저장소 읽기 실패 재시도 UI가 현재 작업 트리에 반영됐다.

패키지 로직은 수정 후 165개 XCTest가 모두 통과했고, 개인정보 매니페스트 lint와 현재 앱 Swift 소스 파서 검사를 통과했다. 남은 출시 전 검증 공백은 다음 두 가지다.

1. 앱 전체 `xcodebuild`는 점검 환경의 SwiftPM 샌드박스와 CoreSimulatorService 제한으로 패키지 해석 단계에서 중단되어 컴파일 성공 여부가 미판정이다.
2. 반복 알림과 TrueDepth 실시간 모드는 실기기 검증 기록이 아직 없다.

현재 출시 전 권장 순서는 권한 제한이 없는 환경의 앱 빌드 → 반복 알림 실기기 QA → TrueDepth 실기기 QA → Archive 개인정보 매니페스트 포함 확인이다.

## 2. 검증 결과

### 2-1. CoachingKit 전체 테스트

실행 명령:

```bash
cd CoachingKit
CLANG_MODULE_CACHE_PATH=/private/tmp/smileday-review-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/smileday-review-clang-cache \
swift test --disable-sandbox
```

결과:

- `Test Suite 'All tests' passed`
- 165 tests, 0 failures
- Swift Testing runner의 마지막 `0 tests in 0 suites passed`는 XCTest 결과와 별개다.
- CoreData 알림 등록 경고가 반복됐지만 테스트 실패는 없었다.

### 2-2. 앱 소스 정적 검증

실행 결과:

- `xcrun swiftc -frontend -parse`로 현재 `SmileDay/**/*.swift` 전체 파서 검사 통과
- `git diff --check` 통과
- 앱 아이콘 JSON 파싱 통과
- light/dark/tinted 아이콘 모두 1024×1024, alpha 없음
- 앱·패키지 Swift 소스에서 `fatalError`, `try!`, 금지 사용자 문구(`리프팅`, `젊어진다`, `교정한다`, `치료`) 없음

파서 검사는 타입 검사나 링크 검사를 대체하지 않는다.

### 2-3. 앱 빌드

실행 명령:

```bash
CFFIXED_USER_HOME=/private/tmp/smileday-review-user \
CLANG_MODULE_CACHE_PATH=/private/tmp/smileday-review-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/smileday-review-clang-cache \
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/smileday-review-derived-data \
  -clonedSourcePackagesDirPath /private/tmp/smileday-review-packages \
  CODE_SIGNING_ALLOWED=NO build
```

결과: **환경 제한으로 미판정**

- CoreSimulatorService 연결 실패
- SwiftPM 패키지 해석 중 `sandbox-exec: sandbox_apply: Operation not permitted`
- 앱 소스 컴파일 전에 종료되어 성공·실패를 판정할 수 없음

권한 제한이 없는 Xcode 환경에서 같은 프로젝트·스킴의 generic simulator build를 다시 실행해야 한다.

## 3. 해소된 이전 위험

### iOS 17 지원 범위

- `CoachingKit/Package.swift`: `.iOS(.v17)`
- Xcode Debug/Release: `IPHONEOS_DEPLOYMENT_TARGET = 17.0`

2026-07-27의 `26.5` 불일치는 해소됐다.

### 앱 시작 강제 종료

`SmileDayApp`은 `ModelContainer` 생성을 `Result`로 보관하고 실패 시 `AppStartupFailureView`를 표시한다. 저장소를 자동 삭제하거나 빈 저장소로 대체하지 않고, `try!`도 없다.

### 과거 Metal 프리뷰 강제 종료

`CameraPreviewView`와 과거 얼굴 측정 파이프라인은 삭제됐다. 선택형 실시간 모드는 `ARSession`과 필요할 때만 생성되는 `ARSCNView`를 사용하며 Metal 생성 `fatalError` 경로가 없다.

### 제품 중심축과 데이터 최소화

- 핵심 5초 완료 흐름은 카메라를 사용하지 않는다.
- 새로 쓰는 SwiftData 모델은 `SmileMoment`와 `SmileReminderSchedule`뿐이다.
- 과거 모델 5개는 기존 저장소 호환을 위해서만 스키마에 남고 UI가 읽지 않는다.
- 실시간 모드 ViewModel에는 저장소가 없고, 앱 서비스는 `ARFrame.capturedImage`를 읽지 않는다.
- 전체 blend-shape 사전 대신 좌우 입꼬리 계수·카메라 방향 오프셋·밝기만 메모리로 전달한다.
- 실시간 모드 사용은 `SmileMoment`에 기록되지 않는다.
- 프리뷰는 기본 꺼짐이며 사용자가 직접 켤 때만 `ARSCNView`가 생성된다.

## 4. 발견 사항

### 해결 — Required Reason API 개인정보 매니페스트

근거:

- `UserDefaultsSmileOnboardingStore`
- `UserDefaultsSmileCueCursorStore`
- `UserDefaultsLiveSmileNudgeSettingsStore`
- 앱 타깃의 `PrivacyInfo.xcprivacy`

Apple은 Required Reason API 사용 이유를 개인정보 매니페스트에 선언하지 않은 앱을 App Store Connect에서 허용하지 않는다. 현재 매니페스트는 앱 전용 `UserDefaults` 읽기·쓰기에 해당하는 `NSPrivacyAccessedAPICategoryUserDefaults`와 승인 사유 `CA92.1`을 선언한다.

반영 내용:

1. `NSPrivacyTracking = false`
2. `NSPrivacyCollectedDataTypes` 빈 배열
3. `NSPrivacyAccessedAPITypes`에 UserDefaults / `CA92.1`
4. `plutil -lint` 통과

남은 확인은 Archive 후 생성된 앱 번들에 매니페스트가 포함됐는지 보는 것이다.

Apple 참고 문서:

- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/documentation/foundation/userdefaults
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files

### 해결 — 알림 예약 실패 전파와 기존 알림 보존

근거:

- `ReminderScheduling.scheduleDailyPattern`은 `async throws`다.
- `UserNotificationReminderScheduler`는 중간 실패 시 이번 호출에서 추가한 identifier를 제거하고 오류를 전달한다.
- `SmileReminderScheduleViewModel.save`는 새 UUID 그룹을 전부 등록한 뒤 SwiftData에 저장하고, 그 다음에만 이전 그룹과 레거시 알림을 취소한다.

추가된 회귀 검증:

- 예약 실패 시 이전 SwiftData 스케줄 유지
- 예약 실패 시 이전 group·레거시 알림 미취소
- 새 group 등록 → 이전 group 취소 → 레거시 취소 순서
- 온보딩 예약 실패 시 완료 flag와 스케줄 미저장
- 새 예약 group ID의 SwiftData 교체

### 해결 — 실시간 모드 실패 시 자동 잠금 상태 복원

근거:

- 시작 시 `UIApplication.shared.isIdleTimerDisabled = true`
- 권한 거부·미지원 기기·세션 실패는 ViewModel 내부에서 monitor를 중지하고 `.failed`로 전환
- 화면은 state가 `.failed`로 바뀌는 즉시 프리뷰를 끄고 `restoreIdleTimer()`를 호출한다.

SwiftUI 생명주기는 자동 테스트가 없으므로 권한 거부·미지원 기기·세션 실패 각각을 실기기에서 확인해야 한다.

### P1 — 앱 전체 컴파일과 실기기 검증 공백

패키지 로직은 통과했지만 SwiftUI·ARKit·UserNotifications 연결부는 자동 테스트 대상이 아니다. 현재 환경에서는 `xcodebuild`도 소스 컴파일 전 중단됐다.

필수 외부 검증:

- generic iOS Simulator build 성공
- iOS 17 이상 실기기에서 반복 알림 등록·변경·비활성화·딥링크
- TrueDepth 기기에서 권한 허용·거부, 얼굴 이탈, 어두움, 방향, 프리뷰 토글, 백그라운드, 전화/인터럽트, 종료 후 비영속성
- App Privacy Report로 카메라 접근 시간과 네트워크 접속 없음 확인
- 앱 재실행 후 실시간 레벨·보정값·사용 시간 미보존 확인

### 해결 — 읽기 오류 재시도 UI

`RootView`, 홈, 설정은 저장소 읽기 오류를 더 이상 정상 빈 상태로 처리하지 않는다. 공통 한국어 오류 카드가 기존 기록은 유지된다고 안내하고 재시도 동작을 제공한다.

## 5. 양호한 점

- 활성 로직과 플랫폼 경계가 `CoachingKit` / 앱 타깃으로 잘 분리됐다.
- 기존 7개 SwiftData 모델이 모두 등록되어 있고, 과거 스키마 재개방 테스트가 있다.
- 5초 완료는 시작 전·중도 취소·중복 시작·지연 tick을 포함해 저장 정확히 한 번을 테스트한다.
- 알림 payload는 현재 형식과 과거 `bucket`/`promptText` 형식을 모두 파싱한다.
- 실시간 신호는 보정, smoothing, publish 제한, hysteresis, 품질 우선순위, nudge pause를 결정적 테스트로 고정한다.
- TrueDepth 미지원 기기는 실시간 모드만 제한되고 핵심 앱 흐름은 유지된다.
- 사용자 문구는 한국어이며 외모·감정·치료 평가를 피한다.
- 카메라 사용 설명은 프리뷰 표시와 저장·전송 부재를 구분한다.
- 앱 아이콘의 세 appearance 파일이 규격과 alpha 조건을 만족한다.

## 6. 출시 전 권장 순서

1. 권한 제한이 없는 환경에서 iOS Simulator build
2. Archive 번들에 `PrivacyInfo.xcprivacy` 포함 확인
3. 반복 알림 실기기 QA와 결과 보고서 작성
4. TrueDepth 실기기 QA와 결과 보고서 작성
5. App Privacy Report 및 App Store Connect 개인정보 응답 최종 대조
6. 대규모 현재 작업 트리를 의도별 커밋으로 정리한 뒤 최종 회귀 실행

## 7. 다음 점검 시 갱신 규칙

- 이 문서는 2026-07-30 현재 작업 트리의 스냅샷이다.
- 위 P0/P1에 영향을 주는 코드 변경 후 테스트·빌드·실기기 결과를 다시 확인한다.
- 프로젝트 전체를 다시 점검했다면 이 문서를 갱신하거나 더 최신 날짜의 보고서로 대체한다.
- 새 보고서를 만들면 루트 `AGENTS.md`의 최신 전체점검 링크도 함께 갱신한다.
