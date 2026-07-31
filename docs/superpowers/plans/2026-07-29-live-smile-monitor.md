# 프리뷰 없는 실시간 미소 확인 모드 Implementation Plan

> 구현 전 대응 설계 `docs/superpowers/specs/2026-07-29-live-smile-monitor-design.md`와 현재 제품 설계 `docs/superpowers/specs/2026-07-29-smile-frequency-window-reminders-design.md`를 전체 읽는다.

**Goal:** 사용자가 iPhone을 세워둔 동안 카메라 프리뷰 없이 현재 미소 점수와 즉각적인 상태 피드백을 확인하게 한다.

**Architecture:** `CoachingKit`에는 최소 샘플 타입, ARKit 경계 프로토콜, 순수 점수 계산, 보정·smoothing·품질 상태를 가진 ViewModel을 둔다. 앱 타깃은 TrueDepth ARSession, 카메라 권한, 프리뷰 없는 SwiftUI 화면, idle timer 생명주기만 담당한다. 측정값과 점수는 저장하지 않는다.

**Tech Stack:** Swift 5.10, SwiftUI, Observation, ARKit, AVFoundation, XCTest, iOS 17+.

---

### Task 0: 현재 정리 작업과 기준 상태 확인

**Files:**

- Read: `AGENTS.md`
- Read: `SmileDay/AGENTS.md`
- Read: `CoachingKit/AGENTS.md`
- Read: `docs/superpowers/specs/2026-07-29-live-smile-monitor-design.md`
- Read: `docs/superpowers/plans/2026-07-29-dead-code-cleanup.md`

- [ ] 작업 트리에서 레거시 측정 파일 삭제와 새 빈도 중심 파일 추가가 진행 중인지 확인한다.
- [ ] `FaceMeasurement`, `ScoreCalculator`, `CoachingViewModel`, `CameraPreviewView`를 복원하지 않는다.
- [ ] 기존 사용자 변경과 죽은 코드 정리 변경을 보존한다.
- [ ] 기준 패키지 테스트와 앱 빌드 결과를 기록한다.

```bash
cd /Users/ijonghwan/Documents/WorkSpaces/smileDay/SmileDay
git status --short

cd CoachingKit && swift test

cd ..
xcodebuild -project SmileDay.xcodeproj -scheme SmileDay \
  -destination 'generic/platform=iOS Simulator' \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 CODE_SIGNING_ALLOWED=NO build
```

---

### Task 1: 제품 지침을 선택형 실시간 모드와 정합화

**Files:**

- Modify: `AGENTS.md`
- Modify: `SmileDay/AGENTS.md`
- Modify: `SmileDay/Views/AGENTS.md`
- Modify: `SmileDay/Views/Coaching/AGENTS.md`
- Modify: `SmileDay/Services/AGENTS.md`
- Modify: `CoachingKit/Sources/CoachingKit/AGENTS.md`

- [ ] 핵심 알림 → 5초 미소 → 완료 루프가 제품 우선순위임을 유지한다.
- [ ] 카메라가 필수 온보딩이나 기본 완료 흐름으로 돌아가지 않게 명시한다.
- [ ] 선택형 실시간 모드에서는 외모·감정 평가 없이 입꼬리 센서 신호만 표시할 수 있다고 명시한다.
- [ ] 프리뷰·사진·영상·점수 저장 금지를 지침에 추가한다.
- [ ] 과거 문서의 카메라 없는 shipping UI 설명을 현재 선택형 구조에 맞게 갱신한다.

---

### Task 2: 실시간 샘플과 모니터링 경계 정의

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/LiveSmileSample.swift`
- Create: `CoachingKit/Sources/CoachingKit/LiveSmileMonitoring.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/LiveSmileSampleTests.swift`

- [ ] `LiveSmileSample`에 좌우 mouth smile, pitch, yaw, optional ambient intensity만 둔다.
- [ ] 전체 blend shape dictionary나 raw frame을 패키지로 넘기지 않는다.
- [ ] 추적·미추적·권한·미지원·세션 오류를 표현하는 `LiveSmileMonitorEvent`를 정의한다.
- [ ] `LiveSmileMonitoring`에 `onEvent`, `start`, `stop`만 둔다.
- [ ] 중복 시작·종료 계약을 문서화한다.
- [ ] 타입이 `Equatable`, `Sendable` 요구를 충족하는지 테스트한다.

```bash
cd CoachingKit && swift test --filter LiveSmileSampleTests
```

---

### Task 3: 점수 계산과 품질 판정 구현

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/LiveSmileScoreEvaluator.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/LiveSmileScoreEvaluatorTests.swift`

- [ ] 좌우 `mouthSmile` 평균을 계산한다.
- [ ] 세션 neutral 평균을 빼고 음수는 0으로 고정한다.
- [ ] 초기 표시 span `0.45`로 0–100에 정규화한다.
- [ ] 입력과 결과를 유효 범위로 clamp한다.
- [ ] 좌우 차이를 점수 감점에 사용하지 않는다.
- [ ] 미간, 눈가, 턱, 감정 추론 값을 사용하지 않는다.
- [ ] pitch/yaw ±15° 판정을 순수 함수로 둔다.
- [ ] optional ambient intensity가 임계값 아래일 때만 어두움으로 판정한다.

Tests:

- [ ] neutral과 같은 값 → 0
- [ ] neutral보다 낮은 값 → 0
- [ ] relative `0.225` → 약 50
- [ ] relative `0.45` 이상 → 100
- [ ] 좌우 비대칭이어도 평균만 반영
- [ ] 비정상 음수·1 초과 입력 clamp
- [ ] 각도 ±15° 경계
- [ ] 조명값 nil은 어두움으로 단정하지 않음

```bash
cd CoachingKit && swift test --filter LiveSmileScoreEvaluatorTests
```

---

### Task 4: 보정·smoothing·피드백 ViewModel 구현

**Files:**

- Create: `CoachingKit/Sources/CoachingKit/LiveSmileMonitorViewModel.swift`
- Create: `CoachingKit/Tests/CoachingKitTests/LiveSmileMonitorViewModelTests.swift`

- [ ] 상태를 `idle`, `requestingPermission`, `calibrating`, `monitoring`, `qualityIssue`, `failed`로 모델링한다.
- [ ] 유효 샘플 2초분으로 neutral 평균을 계산한다.
- [ ] 테스트가 실제 시간에 의존하지 않도록 `now: () -> Date` 또는 유효 샘플 개수를 주입한다.
- [ ] 얼굴 이탈·각도·조명 상태가 점수보다 우선하게 한다.
- [ ] 지수 이동 평균 `alpha = 0.2`를 적용한다.
- [ ] UI 게시 빈도를 초당 최대 10회로 제한한다.
- [ ] 0–24, 25–49, 50–74, 75–100 피드백 단계에 hysteresis를 적용한다.
- [ ] `recalibrate()`가 기존 neutral과 smoothing 상태를 비운다.
- [ ] `stop()`이 점수·보정값·callback을 해제한다.
- [ ] 어떤 종료 경로에서도 저장소를 호출하지 않는다.

Tests:

- [ ] 유효 프레임 부족 시 보정 유지
- [ ] 얼굴 이탈 프레임은 보정에서 제외
- [ ] 보정 완료 후 점수 게시
- [ ] 급격한 입력에도 smoothing 적용
- [ ] 품질 문제 중 마지막 점수 숨김 또는 고정
- [ ] 경계 근처에서 피드백 문구 왕복 방지
- [ ] 다시 보정 후 이전 neutral 미사용
- [ ] stop 후 뒤늦은 event 무시

```bash
cd CoachingKit && swift test --filter LiveSmileMonitorViewModelTests
```

---

### Task 5: 프리뷰 없는 ARKit 서비스 구현

**Files:**

- Create: `SmileDay/Services/ARKitLiveSmileMonitor.swift`
- Modify: `SmileDay.xcodeproj/project.pbxproj`

- [ ] `ARFaceTrackingConfiguration.isSupported`를 시작 전에 확인한다.
- [ ] 카메라 권한 상태를 AVFoundation으로 확인하고 필요할 때만 요청한다.
- [ ] `ARSessionDelegate`에서 첫 tracked `ARFaceAnchor`만 사용한다.
- [ ] `.mouthSmileLeft`, `.mouthSmileRight`만 읽는다.
- [ ] 얼굴 transform에서 pitch/yaw를 계산한다.
- [ ] 최신 ambient intensity를 샘플에 결합한다.
- [ ] `ARFrame.capturedImage`를 읽지 않는다.
- [ ] `MTKView`, Metal, CoreImage, preview `UIView`를 만들지 않는다.
- [ ] 미추적, 세션 중단, 실패, 권한 거부, 미지원 이벤트를 패키지 타입으로 전달한다.
- [ ] `start()` 중복 실행을 막고 `stop()`에서 `session.pause()`와 callback 정리를 수행한다.

Static verification:

```bash
rg -n 'capturedImage|MTKView|MetalKit|CoreImage|UIViewRepresentable|ARSCNView|ARView' \
  SmileDay/Services/ARKitLiveSmileMonitor.swift \
  SmileDay/Views/Coaching/LiveSmileMonitorView.swift
```

Expected: 결과 없음.

---

### Task 6: 카메라 권한 설명과 앱 설정 추가

**Files:**

- Modify: `SmileDay.xcodeproj/project.pbxproj`
- Modify: `SmileDay/Views/SharedStrings.swift`

- [ ] Debug/Release에 `NSCameraUsageDescription`을 추가한다.
- [ ] 문구가 프리뷰 없음과 실시간 처리 목적을 정확히 설명하게 한다.

권장 문구:

> 실시간 미소 신호를 보여주기 위해 전면 카메라를 사용합니다. 사진과 영상은 표시하거나 저장하지 않습니다.

- [ ] 권한 거부 상태에서 시스템 설정으로 이동하는 공통 버튼 문구를 재사용한다.
- [ ] 기존 알림·5초 미소 기능은 카메라 권한을 요청하지 않는지 확인한다.

---

### Task 7: 실시간 모니터 화면 구현

**Files:**

- Create: `SmileDay/Views/Coaching/LiveSmileMonitorView.swift`
- Modify: `SmileDay/Views/Theme.swift` only if an active visual token is needed

- [ ] 프리뷰용 view나 빈 검은 카메라 사각형을 만들지 않는다.
- [ ] 큰 점수, `현재 미소 점수` 레이블, 연속형 게이지, 피드백 문구를 표시한다.
- [ ] `카메라 사용 중 · 영상과 점수는 저장하지 않아요`를 항상 볼 수 있게 한다.
- [ ] idle·권한·미지원·오류·얼굴 이탈·각도·조명·보정·정상 상태를 각각 표시한다.
- [ ] `다시 보정`과 `종료` 행동을 제공한다.
- [ ] 시작 전에 장시간 사용 시 배터리 소모 안내를 표시한다.
- [ ] 측정 중 idle timer를 비활성화하고 모든 종료 경로에서 이전 값으로 복원한다.
- [ ] scene inactive/background에서 즉시 stop하고 복귀 시 재시작 버튼을 표시한다.
- [ ] 점수 숫자를 VoiceOver live region에서 제외하고 상태 변화만 알린다.
- [ ] Reduce Motion에서 게이지의 큰 보간 애니메이션을 생략한다.

---

### Task 8: 홈에 선택형 진입 추가

**Files:**

- Modify: `SmileDay/Views/Home/SmileMVPHomeView.swift`
- Modify: `SmileDay/Views/SharedStrings.swift`

- [ ] 기본 `지금 한 번 웃기` CTA의 위치와 강조를 유지한다.
- [ ] 보조 카드 또는 버튼 `실시간 미소 확인`을 추가한다.
- [ ] 보조 설명에 프리뷰·저장 없음이 드러나게 한다.
- [ ] full-screen cover로 모니터 화면을 연다.
- [ ] 알림 딥링크는 기존 5초 미소 화면으로 계속 연결한다.
- [ ] TrueDepth 미지원 여부 때문에 홈의 기존 기능을 숨기거나 막지 않는다.

---

### Task 9: 정책·프라이버시 정적 감사

- [ ] 사용자 문구가 외모, 인상, 감정, 치료 효과를 평가하지 않는지 확인한다.
- [ ] `잘 웃었다`, `못 웃었다`, `예뻐졌다`, `인상 개선`처럼 점수를 가치 판단으로 읽게 하는 문구를 제거한다.
- [ ] 사진·영상·점수 저장 코드가 없는지 확인한다.
- [ ] 네트워크 프레임워크나 업로드 경로가 추가되지 않았는지 확인한다.
- [ ] 화면 프리뷰 구현이 없는지 확인한다.

```bash
rg -n '잘 웃|못 웃|예뻐|젊어진|교정|치료|인상 개선|리프팅' \
  SmileDay CoachingKit --glob '*.swift'

rg -n 'capturedImage|UIImage|CIImage|MTKView|ARSCNView|URLSession|upload|payload' \
  SmileDay/Services/ARKitLiveSmileMonitor.swift \
  SmileDay/Views/Coaching/LiveSmileMonitorView.swift \
  CoachingKit/Sources/CoachingKit/LiveSmile*.swift
```

검출된 `payload`는 알림 payload와 혼동하지 않고 대상 파일 안의 실제 측정 저장 여부만 판정한다.

---

### Task 10: 자동 검증

- [ ] 관련 테스트:

```bash
cd CoachingKit
swift test --filter LiveSmileSampleTests
swift test --filter LiveSmileScoreEvaluatorTests
swift test --filter LiveSmileMonitorViewModelTests
```

- [ ] 패키지 전체 테스트:

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

- [ ] diff 검증:

```bash
git diff --check
git status --short
git diff --stat
```

---

### Task 11: TrueDepth 실기기 QA

**Required:** iOS 17 이상, Face ID/TrueDepth 지원 iPhone.

- [ ] 첫 진입 전 카메라 사용·프리뷰 없음·미저장 설명 표시
- [ ] 권한 허용 → 보정 → 실시간 점수
- [ ] 권한 거부 → 앱 종료 없이 설정 안내
- [ ] 설정 앱에서 재허용 후 정상 시작
- [ ] TrueDepth 미지원 기기에서 기존 앱 기능 정상 사용
- [ ] 편한 표정 2초 보정과 다시 보정
- [ ] 입꼬리 움직임 증가에 따라 점수가 부드럽게 상승
- [ ] 표정을 풀면 점수가 부드럽게 하락
- [ ] 좌우 비대칭을 실패로 표시하지 않음
- [ ] 얼굴 이탈 → 점수보다 위치 안내 우선
- [ ] ±15° 바깥 → 정면 안내 우선
- [ ] 어두운 환경 → 조명 안내 우선
- [ ] 프리뷰와 얼굴 이미지가 화면 어디에도 없음
- [ ] iOS 초록색 카메라 표시가 측정 중에만 나타남
- [ ] 홈·알림·5초 미소 흐름에서는 카메라가 켜지지 않음
- [ ] 화면 자동 잠금이 측정 중에만 비활성화됨
- [ ] background/전화 수신/화면 닫기에서 카메라 즉시 종료
- [ ] 15분 사용 시 발열·배터리·프레임 안정성 기록
- [ ] 종료·재실행 후 점수와 보정값이 남지 않음
- [ ] SwiftData와 UserDefaults에 측정값이 추가되지 않음
- [ ] VoiceOver가 점수를 프레임마다 반복 낭독하지 않음

결과는 `docs/reports/YYYY-MM-DD-live-smile-monitor-device-verification.md`에 기기, iOS, 빌드/커밋, 항목별 PASS/FAIL과 발열 체감만 기록한다. 얼굴 이미지, raw blend shape, 점수 시계열은 저장하지 않는다.

---

## 완료 체크리스트

- [ ] 대응 Design Spec의 완료 기준을 모두 충족함
- [ ] 기존 빈도 중심 핵심 루프가 카메라 없이 계속 동작함
- [ ] 카메라 프리뷰·사진·영상·측정값 저장 코드 없음
- [ ] 0–100 점수와 품질 우선 피드백이 실기기에서 안정적으로 동작함
- [ ] 닫기·백그라운드에서 ARSession과 idle timer가 정리됨
- [ ] 관련 테스트와 전체 패키지 테스트 통과
- [ ] iOS 17 앱 빌드 통과
- [ ] TrueDepth 실기기 QA 기록 완료
- [ ] 사용자 기존 변경을 덮어쓰지 않음
- [ ] `git diff --check` 통과

