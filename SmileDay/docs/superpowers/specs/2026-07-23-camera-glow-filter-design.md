# 카메라 글로우 필터 (2단계 커스텀 렌더링) 설계

**상태**: 승인됨
**작성일**: 2026-07-23
**프로젝트**: SmileDay (Xcode + SwiftUI)

## 1. 배경과 목표

1단계 웜톤 오버레이([[2026-07-23-camera-warm-tone-design]])는 단순 알파 합성이라 표현력에 한계가 있다. 사용자가 "조금 더 예뻐 보이는" 화면을 원하므로, 카메라 프레임 자체를 CIFilter 체인으로 보정하는 2단계 커스텀 렌더링으로 확장한다.

**범위 결정** (사용자 승인):
- **포함**: 소프트 글로우(피부가 부드럽고 화사해 보이는 효과) + 웜톤 + 미세 밝기/채도 + 은은한 비네트
- **보류**: 주파수 분리 기반 피부 스무딩 — 글로우 결과를 실기기로 보고 추가 여부 결정
- **제외**: 볼륨·리프팅 등 얼굴 형태 변형 — 입꼬리 리프트를 코칭하는 앱에서 화면이 미리 올려 보여주면 피드백 루프가 가짜가 된다. 정체성 충돌로 하지 않는다.

측정은 TrueDepth 기반 ARKit blendshape에서 나오므로 화면 보정은 점수에 영향이 없다.

## 2. 아키텍처 변경

**현재**: `ARKitFaceTrackingSession`이 `ARSCNView`를 소유. ARSCNView가 카메라 배경을 내부에서 직접 그려 필터 개입이 불가능. blendshape은 `ARSCNViewDelegate.renderer(_:didUpdate:for:)`에서 추출.

**변경**: `ARSCNView`를 버리고 `ARSession`을 직접 소유한다.

- **트래킹**: blendshape 추출을 `ARSessionDelegate.session(_:didUpdate anchors:)`로 이동 (동일한 `ARFaceAnchor` 데이터, `isTracked` 가드와 각도 판정 로직 유지). ARSession delegate 큐는 기본값(메인)을 사용.
- **렌더링**: `session(_:didUpdate frame:)`에서 받은 `ARFrame.capturedImage`를 필터 체인으로 보정해 `MTKView`에 직접 그린다. 조명 추정도 같은 콜백에서 유지.
- `FaceTrackingSession` 프로토콜(CoachingKit)은 변경 없음 — `previewView`는 프로토콜 밖 앱 내부 사항.

## 3. 컴포넌트 (SmileDay 타겟)

```
ARKitFaceTrackingSession (수정)
 ├─ ARSession 직접 소유, ARSessionDelegate로 트래킹·조명·프레임 처리
 └─ previewView: FilteredCameraPreviewView

FilteredCameraPreviewView (신규, MTKView 서브클래스)
 ├─ isPaused = true, 프레임 도착 시에만 수동 draw (세션 페이스에 동기화)
 ├─ CIContext(mtlDevice:)로 drawable 텍스처에 직접 렌더
 └─ aspect-fill 스케일링 + 중앙 크롭

FaceBeautyFilter (신규, enum 네임스페이스)
 └─ apply(to: CVPixelBuffer) -> CIImage — 보정 체인 전체
```

**필터 체인 순서**:
1. **방향 보정**: `oriented(.leftMirrored)` — 전면 카메라 세로 화면 + 셀피 미러링 (기존 ARSCNView 프리뷰와 동일한 방향)
2. **웜톤**: `CITemperatureAndTint` (6500 → 7150) — 1단계 오버레이의 웜 워시를 대체
3. **밝기·채도**: `CIColorControls` (brightness +0.015, saturation 1.05)
4. **소프트 글로우**: 1/4 다운스케일 → 가우시안 블러(r=6) → 업스케일 → RGB 0.24 감쇠 → 스크린 블렌드. 다운스케일로 실시간(60fps) 성능을 확보한다.
5. **비네트**: `CIVignette` (intensity 0.35, radius 1.6) — 가장자리를 살짝 어둡게 해 얼굴로 시선 집중

강도 값은 상수로 두고 실기기에서 보며 조정한다.

## 4. 1단계 오버레이 정리

`CameraWarmToneOverlay`는 웜톤이 필터 체인으로 흡수되므로 두 화면에서 제거하고 파일을 삭제한다. 이중 보정을 피한다.

## 5. 검증

- 렌더링·필터는 앱 타겟 UI 코드라 유닛 테스트 없음. `xcodebuild` 빌드 성공 확인.
- CoachingKit은 변경 없음 — 기존 테스트가 그대로 통과해야 한다.
- **실기기 확인 필수** (시뮬레이터는 ARKit 얼굴 추적 미지원): 방향/미러링이 기존과 같은지, 트래킹(실시간 게이지)과 조명 배너가 여전히 동작하는지, 발열·프레임 드랍이 없는지.

## 6. 이번 설계에 포함하지 않는 것

- 주파수 분리 피부 스무딩 (실기기 확인 후 별도 결정)
- 얼굴 형태 변형 (볼륨·리프팅) — 앱 정체성과 충돌, 영구 제외 권고
- 필터 선택 UI·강도 설정
