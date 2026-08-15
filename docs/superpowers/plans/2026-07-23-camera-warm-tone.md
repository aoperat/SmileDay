# 카메라 웜톤 오버레이 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 코칭 세션·기준선 촬영의 전면 카메라 프리뷰에 표시 전용 웜톤 오버레이를 얹는다.

**Architecture:** 재사용 가능한 `CameraWarmToneOverlay` 뷰 하나를 만들고, `ARFacePreviewRepresentable`과 `FaceGuideOverlay` 사이에 삽입한다. 일반 알파 합성만 사용 (blendMode는 Metal 카메라 레이어 위에서 보장 안 됨).

**Tech Stack:** SwiftUI.

**설계 문서:** `docs/superpowers/specs/2026-07-23-camera-warm-tone-design.md`

---

### Task 1: CameraWarmToneOverlay 추가 및 두 화면에 적용

**Files:**
- Create: `SmileDay/Views/CameraWarmToneOverlay.swift`
- Modify: `SmileDay/Views/Coaching/CoachingSessionView.swift:23-26`
- Modify: `SmileDay/Views/Onboarding/BaselineCaptureView.swift:17-20`

- [ ] **Step 1: 오버레이 뷰 생성**

```swift
// SmileDay/Views/CameraWarmToneOverlay.swift
import SwiftUI

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

- [ ] **Step 2: 두 화면에 삽입**

`CoachingSessionView.swift`와 `BaselineCaptureView.swift` 모두, `ARFacePreviewRepresentable(...).ignoresSafeArea()` 바로 다음 줄에:

```swift
            CameraWarmToneOverlay()
```

(`FaceGuideOverlay()` 앞.)

- [ ] **Step 3: 빌드 검증**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add SmileDay/Views/CameraWarmToneOverlay.swift SmileDay/Views/Coaching/CoachingSessionView.swift SmileDay/Views/Onboarding/BaselineCaptureView.swift
git commit -m "feat: add warm tone overlay to camera preview screens"
```

**후속**: 최종 톤(투명도 값)은 실기기에서 보고 조정한다. 시뮬레이터는 ARKit 얼굴 추적을 지원하지 않는다.
