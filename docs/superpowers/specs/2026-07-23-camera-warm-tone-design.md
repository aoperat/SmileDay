# 카메라 웜톤 오버레이 설계

**상태**: 승인됨
**작성일**: 2026-07-23
**프로젝트**: SmileDay (Xcode + SwiftUI)

## 1. 배경과 목표

코칭 세션과 기준선 촬영은 사용자가 전면 카메라 속 자기 얼굴을 한참 응시하는 화면이다. 전면 카메라 원본은 조명·화각 특성상 실제보다 차갑고 어둡게 보이는 경향이 있고, 이 불편함은 매일 쓰는 앱의 리텐션에 영향을 준다. 앱의 Morning Glow 톤(크림/코랄)에 맞는 따뜻하고 부드러운 화면 보정을 표시 전용으로 추가한다.

**원칙**:
- **표시 전용 보정**: 점수는 TrueDepth 기반 ARKit blendshape에서 나오므로 화면 보정은 측정에 영향이 없다. 사진 저장도 없어 순수 라이브 프리뷰 문제다.
- **"살짝"이 적정선**: 피부 리터칭·얼굴형 보정 같은 강한 인물 보정은 "있는 그대로의 표정을 관찰한다"는 앱 정체성과 충돌하므로 하지 않는다. 이번 단계는 톤·조명 느낌 보정까지만.
- 필터 선택 UI는 두지 않는다. 잘 조율된 기본 룩 하나만 제공한다.

## 2. 단계적 접근

- **1단계 (이번 작업)**: `ARSCNView` 위에 따뜻한 톤의 반투명 오버레이를 얹는다. 저비용으로 분위기를 확인한다.
- **2단계 (보류)**: 1단계가 부족하면 `ARSession` 프레임을 CIFilter로 직접 처리(커스텀 렌더링)해 밝기/웜톤/약한 피부 소프트닝까지 적용한다. 렌더링 파이프라인 교체라 별도 설계로 다룬다.

## 3. 기술 결정

SwiftUI의 `blendMode`(softLight 등)는 SwiftUI 렌더 트리 안에서만 동작하고, `UIViewRepresentable`로 감싼 Metal 기반 카메라 레이어(`ARSCNView`)와의 블렌딩은 보장되지 않는다. 따라서 어떤 환경에서도 확실하게 동작하는 **일반 알파 합성**만 사용한다:

- **웜 워시**: 살구빛(`SDColor.apricot`)~코랄을 위→아래로 아주 옅게 깔아 색온도를 올린다.
- **크림 비네트**: 가장자리를 크림톤으로 살짝 감싸 조명이 부드럽게 도는 느낌을 주고 시선을 중앙(얼굴)으로 모은다.

투명도 값은 코드 상수로 두고, 실기기에서 보며 조정한다 (시뮬레이터는 ARKit 얼굴 추적을 지원하지 않아 실기기 확인 필수).

## 4. 컴포넌트 설계 (SmileDay 타겟)

```swift
// SmileDay/Views/CameraWarmToneOverlay.swift
/// 전면 카메라 프리뷰 위에 얹는 웜톤 보정 레이어. 표시 전용이라 측정에는 영향이 없다.
struct CameraWarmToneOverlay: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SDColor.apricot.opacity(0.10), SDColor.coral.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [.clear, SDColor.cream.opacity(0.22)],
                center: .center,
                startRadius: 180,
                endRadius: 560
            )
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
```

**적용 지점** (둘 다 동일 패턴):
- `CoachingSessionView`: `ARFacePreviewRepresentable` 바로 다음, `FaceGuideOverlay` 앞에 삽입
- `BaselineCaptureView`: 동일

코칭과 기준선 촬영에 같은 룩을 적용해 두 화면의 인상이 일치하도록 한다.

## 5. 검증

UI 전용 변경이라 유닛 테스트는 없다. `xcodebuild` 빌드 성공을 확인하고, 최종 톤 조정은 사용자가 실기기에서 보고 피드백한다.

## 6. 이번 설계에 포함하지 않는 것

- CIFilter 기반 커스텀 렌더링과 피부 소프트닝 (2단계로 보류)
- 필터 선택 UI, 보정 강도 설정
- 히스토리/기록 화면 등 카메라 외 화면의 톤 변경
