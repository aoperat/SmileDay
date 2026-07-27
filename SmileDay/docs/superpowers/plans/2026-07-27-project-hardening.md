# 프로젝트 안정성 정리 Implementation Plan

> **For agentic workers:** 각 Task를 순서대로 수행하고 체크박스로 진행 상태를 기록한다. 구현 전 대응 설계 문서 `SmileDay/docs/superpowers/specs/2026-07-27-project-hardening-design.md`를 읽는다.

**Goal:** iOS 지원 버전 불일치, SwiftData/Metal 강제 종료 경로, 정책상 혼동 가능한 `.lift` 명칭과 TrueDepth 검증 공백을 정리한다.

**Architecture:** 핵심 도메인 명칭과 호환성 테스트는 `CoachingKit`에서 처리한다. 앱 타깃은 시작 실패 상태와 플랫폼 렌더러 실패를 한국어 UI로 표현한다. SwiftData 초기화 실패 시 자동 삭제나 새 저장소 대체를 하지 않는다.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, ARKit, MetalKit, XCTest, Xcode 26.5.

---

## 사전 확인

- [ ] 현재 변경을 덮어쓰지 않도록 작업 트리 확인

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git status --short
git diff -- SmileDay.xcodeproj/project.pbxproj \
  SmileDay/SmileDayApp.swift \
  SmileDay/Services/CameraPreviewView.swift \
  SmileDay/Services/ARKitFaceTrackingSession.swift \
  CoachingKit/Sources/CoachingKit/CareRoutine.swift
```

- [ ] 기준 검증 실행 및 결과 기록

```bash
cd CoachingKit && swift test
cd ..
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

샌드박스나 CoreSimulatorService 제한으로 실행할 수 없다면 코드 실패로 기록하지 말고 환경 제한과 명령을 결과에 남긴다.

---

### Task 1: 최소 지원 버전을 iOS 17.0으로 통일

**Files:**
- Modify: `SmileDay.xcodeproj/project.pbxproj`
- Verify: `CoachingKit/Package.swift`

- [ ] `project.pbxproj`의 Debug/Release 프로젝트 설정에 있는 `IPHONEOS_DEPLOYMENT_TARGET = 26.5;`를 모두 `17.0`으로 변경한다.
- [ ] 앱 타깃의 Debug/Release가 프로젝트 값을 상속하는지 `xcodebuild -showBuildSettings`로 확인한다.
- [ ] 패키지의 `.iOS(.v17)` 선언은 변경하지 않는다.

```bash
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -showBuildSettings | rg 'IPHONEOS_DEPLOYMENT_TARGET'
```

**Expected:** 앱 빌드 설정이 `IPHONEOS_DEPLOYMENT_TARGET = 17.0` 하나로 수렴한다.

- [ ] iOS 17에서 사용할 수 없는 API가 있는지 generic simulator build로 확인한다.

---

### Task 2: SwiftData 초기화 강제 종료 제거

**Files:**
- Modify: `SmileDay/SmileDayApp.swift`
- Create: `SmileDay/Views/AppStartupFailureView.swift`
- Modify: `SmileDay.xcodeproj/project.pbxproj` (프로젝트가 폴더 동기화 그룹이 아닐 경우 파일 참조 추가)

- [ ] `ModelContainer` 생성과 실패 UI를 분리할 수 있도록 작은 부트스트랩 상태를 정의한다.

권장 형태:

```swift
enum AppModelContainerBootstrap {
    case ready(ModelContainer)
    case failed

    static func make() -> Self {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema)
        do {
            return .ready(try ModelContainer(for: schema, configurations: [configuration]))
        } catch {
            assertionFailure("ModelContainer initialization failed: \(error)")
            return .failed
        }
    }
}
```

오류의 상세 경로나 내부 데이터베이스 정보는 사용자 문구에 노출하지 않는다. Release에서도 진단이 필요하면 `Logger`의 privacy 기본값을 사용한다.

- [ ] 성공 시 기존 `RootView`, `ko_KR` locale, `NotificationRouter`, `.modelContainer` 주입을 그대로 유지한다.
- [ ] 실패 시 `AppStartupFailureView`를 표시한다.

오류 화면 요구사항:

- 제목: “앱 데이터를 불러오지 못했어요”
- 설명: 앱을 완전히 종료한 뒤 다시 열도록 안내
- 기존 데이터 삭제나 재설치를 첫 해결책으로 안내하지 않음
- VoiceOver 읽기 순서와 Dynamic Type 대응

- [ ] 앱 시작 파일에서 `try! ModelContainer`가 사라졌는지 확인한다.

```bash
rg -n 'try!.*ModelContainer|fatalError' SmileDay/SmileDayApp.swift SmileDay/Views/AppStartupFailureView.swift
```

- [ ] 시뮬레이터 빌드 후 정상 시작 경로를 확인한다.
- [ ] DEBUG 전용 실패 주입 지점을 둘 경우 launch argument로만 제공하고 Release 빌드에서는 컴파일 제외한다.

---

### Task 3: Metal 프리뷰 실패를 복구 가능한 상태로 전환

**Files:**
- Modify: `SmileDay/Services/CameraPreviewView.swift`
- Modify: `SmileDay/Services/ARKitFaceTrackingSession.swift`
- Modify: `SmileDay/Services/ARFacePreviewRepresentable.swift`
- Modify: `SmileDay/Views/Onboarding/BaselineCaptureView.swift`
- Modify: `SmileDay/Views/Coaching/CoachingSessionView.swift`
- Modify: `SmileDay/Views/SharedStrings.swift`

- [ ] `CameraPreviewView` 생성자를 failable 또는 throwing factory로 바꿔 Metal device/command queue 실패를 호출자가 처리하게 한다.
- [ ] `FaceTrackingError`를 `LocalizedError`로 만들고 아래 경우를 구분한다.

```swift
enum FaceTrackingError: LocalizedError {
    case unsupportedDevice
    case previewUnavailable
    case sessionFailed
}
```

- [ ] `ARKitFaceTrackingSession`은 `CameraPreviewView?` 렌더러와 항상 표시 가능한 `UIView` 프리뷰 컨테이너를 분리한다.
- [ ] Metal 렌더러가 없으면 검은 대체 뷰를 제공하고 `start()`에서 `.previewUnavailable`을 `onError`로 전달한다.
- [ ] `ARFacePreviewRepresentable`의 반환 타입을 일반 `UIView`로 조정한다.
- [ ] AR 프레임 업데이트는 렌더러가 있을 때만 수행한다.
- [ ] 두 카메라 화면에서 `session.onError`가 ViewModel 생성 중 덮어써지지 않는지 확인한다. 필요하면 `FaceTrackingSession` 프로토콜의 단일 콜백 소유권을 ViewModel에 두고 ViewModel이 표시용 오류 상태를 노출하도록 `CoachingKit` 테스트와 함께 확장한다.
- [ ] 공통 한국어 문구를 `SharedStrings`에 추가하고 오류 발생 시 측정/저장 버튼을 비활성화한다.

권장 문구:

- TrueDepth 미지원: “이 기기에서는 얼굴 측정을 사용할 수 없어요.”
- 프리뷰 초기화 실패: “카메라 화면을 준비하지 못했어요. 앱을 다시 열어주세요.”
- AR 세션 실패: “얼굴 측정이 중단됐어요. 잠시 후 다시 시도해주세요.”

- [ ] `CameraPreviewView`의 Metal 생성 경로에 `fatalError`가 없는지 확인한다. `@available(*, unavailable)` coder initializer는 예외로 기록한다.

```bash
rg -n 'fatalError' SmileDay/Services
```

- [ ] 시뮬레이터에서 unsupported-device 경로가 종료되지 않고 오류 UI를 표시하는지 확인한다.

---

### Task 4: `CareCategory.lift`를 호환 가능한 명칭으로 변경

**Files:**
- Modify: `CoachingKit/Sources/CoachingKit/CareRoutine.swift`
- Modify: `CoachingKit/Sources/CoachingKit/InsightEngine.swift`
- Modify: `CoachingKit/Sources/CoachingKit/CareViewModel.swift`
- Modify: `SmileDay/Views/Care/CareView.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/CareRoutineTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/CareViewModelTests.swift`
- Modify: `CoachingKit/Tests/CoachingKitTests/InsightEngineTests.swift`

- [ ] 먼저 raw value 호환성 테스트를 추가한다.

```swift
func test_mouthCornerCategory_preservesLegacyRawValue() {
    XCTAssertEqual(CareCategory.mouthCorner.rawValue, "lift")
    XCTAssertEqual(CareCategory(rawValue: "lift"), .mouthCorner)
}
```

- [ ] `case lift`를 `case mouthCorner = "lift"`로 변경한다.
- [ ] 의미적 참조 `.lift`를 `.mouthCorner`로 바꾼다.
- [ ] 카탈로그 루틴 ID와 `videoFileName`은 기존 리소스 호환을 위해 유지한다.
- [ ] 사용자 표시명 “입꼬리”와 기존 카피가 변하지 않는지 테스트한다.
- [ ] 금지된 사용자 노출 표현을 전체 검사한다.

```bash
rg -n '리프팅|젊어진다|교정한다|치료' SmileDay CoachingKit \
  --glob '*.swift' --glob '*.md'
rg -n '\\.lift\\b|case lift\\b' SmileDay CoachingKit --glob '*.swift'
```

첫 번째 검색은 과거 계획 문서의 변경 전 예시가 잡힐 수 있으므로, 앱 소스의 사용자 노출 문자열을 우선 판정한다.

- [ ] 관련 테스트 실행

```bash
cd CoachingKit
swift test --filter CareRoutineTests
swift test --filter CareViewModelTests
swift test --filter InsightEngineTests
```

---

### Task 5: 자동 검증과 회귀 점검

- [ ] CoachingKit 전체 테스트

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay/CoachingKit
swift test
```

**Expected:** `Test Suite 'All tests' passed`.

- [ ] iOS 17 최소 타깃 앱 빌드

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

**Expected:** `** BUILD SUCCEEDED **`.

- [ ] 강제 종료 경로와 이전 이름 재검색

```bash
rg -n 'try!.*ModelContainer|\\.lift\\b|case lift\\b' SmileDay CoachingKit --glob '*.swift'
rg -n 'fatalError' SmileDay --glob '*.swift'
```

남는 `fatalError`는 `@available(*, unavailable)` coder initializer처럼 실제 실행 불가능한 경로인지 각각 설명한다.

- [ ] `git diff --check`와 변경 범위 확인

```bash
git diff --check
git status --short
git diff --stat
```

---

### Task 6: TrueDepth 실기기 검증

**Required device:** iOS 17 이상, Face ID/TrueDepth 지원 iPhone.

- [ ] 신규 설치 후 카메라 권한 허용 → 기준선 저장
- [ ] 카메라 권한 거부 → 앱 종료 없이 복구 안내 표시
- [ ] 얼굴 미검출/프레임 이탈 → 저장 버튼 비활성 상태 확인
- [ ] 어두운 환경 → 조명 경고 표시
- [ ] 좌우/상하 15° 초과 → 정면 안내 표시
- [ ] 안정화 1초 전후 기준선 저장 버튼 상태 확인
- [ ] 체크인 완료 → 점수, payload, 인사이트 저장 확인
- [ ] 측정 중 백그라운드 진입 후 복귀 → 세션 상태와 프리뷰 확인
- [ ] 로컬 알림 탭 → 코칭 탭 딥링크 및 질문 표시
- [ ] 앱 재실행 → 기존 기준선과 기록 유지

결과는 `SmileDay/docs/reports/YYYY-MM-DD-truedepth-device-verification.md`에 기기 모델, iOS 버전, 빌드/커밋, 항목별 PASS/FAIL만 기록한다. 실제 얼굴 이미지, 개인 측정 원시값, 화면 녹화는 저장소에 추가하지 않는다.

---

## 완료 기준

- [ ] Design Spec의 Acceptance Criteria가 모두 충족됨
- [ ] 기존 사용자 데이터 삭제나 SwiftData 스키마 변경 없음
- [ ] 자동 테스트·시뮬레이터 빌드 결과 기록
- [ ] TrueDepth 실기기 체크리스트 결과 기록
- [ ] 기존 미커밋 변경과 이번 변경이 최종 diff에서 구분됨

