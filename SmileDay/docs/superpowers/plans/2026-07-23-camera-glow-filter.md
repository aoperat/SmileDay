# 카메라 글로우 필터 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ARSCNView 기반 카메라 프리뷰를 CIFilter 체인(웜톤·글로우·비네트)을 적용한 커스텀 Metal 렌더링으로 교체한다.

**Architecture:** `ARKitFaceTrackingSession`이 `ARSession`을 직접 소유하고, blendshape 추출을 `ARSessionDelegate`로 옮긴다. 프레임은 `FaceBeautyFilter`로 보정 후 `FilteredCameraPreviewView`(MTKView)에 그린다. 1단계 웜톤 오버레이는 필터 체인으로 흡수되어 삭제한다.

**Tech Stack:** ARKit, Metal(MetalKit), Core Image, SwiftUI.

**설계 문서:** `SmileDay/docs/superpowers/specs/2026-07-23-camera-glow-filter-design.md`

---

### Task 1: FaceBeautyFilter + FilteredCameraPreviewView 생성

**Files:**
- Create: `SmileDay/Services/FaceBeautyFilter.swift`
- Create: `SmileDay/Services/FilteredCameraPreviewView.swift`

- [ ] **Step 1: 필터 체인 작성**

```swift
// SmileDay/Services/FaceBeautyFilter.swift
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo

/// 전면 카메라 프레임에 웜톤·글로우·비네트를 적용하는 표시 전용 보정 체인.
/// 측정은 TrueDepth 데이터 기반이라 이 보정의 영향을 받지 않는다.
enum FaceBeautyFilter {
    static func apply(to pixelBuffer: CVPixelBuffer) -> CIImage {
        // 전면 카메라 세로 화면: 회전 + 셀피 미러링 (기존 ARSCNView 프리뷰와 동일한 방향)
        let base = CIImage(cvPixelBuffer: pixelBuffer).oriented(.leftMirrored)

        // 1) 웜톤: 기준 색온도를 살짝 올려 따뜻하게
        let warm = CIFilter.temperatureAndTint()
        warm.inputImage = base
        warm.neutral = CIVector(x: 6500, y: 0)
        warm.targetNeutral = CIVector(x: 7150, y: 0)
        var image = warm.outputImage ?? base

        // 2) 밝기·채도 미세 보정
        let controls = CIFilter.colorControls()
        controls.inputImage = image
        controls.brightness = 0.015
        controls.saturation = 1.05
        controls.contrast = 1.0
        image = controls.outputImage ?? image

        // 3) 소프트 글로우: 1/4로 줄여 블러 → 감쇠 → 스크린 블렌드 (다운스케일로 60fps 확보)
        let downscale = CGAffineTransform(scaleX: 0.25, y: 0.25)
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = image.transformed(by: downscale).clampedToExtent()
        blur.radius = 6
        let blurred = blur.outputImage?
            .cropped(to: image.extent.applying(downscale))
            .transformed(by: CGAffineTransform(scaleX: 4, y: 4))

        if let blurred {
            let dim = CIFilter.colorMatrix()
            dim.inputImage = blurred
            dim.rVector = CIVector(x: 0.24, y: 0, z: 0, w: 0)
            dim.gVector = CIVector(x: 0, y: 0.24, z: 0, w: 0)
            dim.bVector = CIVector(x: 0, y: 0, z: 0.24, w: 0)

            let screen = CIFilter.screenBlendMode()
            screen.inputImage = dim.outputImage
            screen.backgroundImage = image
            image = screen.outputImage?.cropped(to: image.extent) ?? image
        }

        // 4) 은은한 비네트: 가장자리를 살짝 어둡게 해 얼굴로 시선 집중
        let vignette = CIFilter.vignette()
        vignette.inputImage = image
        vignette.intensity = 0.35
        vignette.radius = 1.6
        return vignette.outputImage ?? image
    }
}
```

- [ ] **Step 2: Metal 프리뷰 뷰 작성**

```swift
// SmileDay/Services/FilteredCameraPreviewView.swift
import MetalKit
import CoreImage
import ARKit

/// ARFrame을 FaceBeautyFilter로 보정해 그리는 카메라 프리뷰.
/// 세션 프레임이 도착할 때만 수동으로 draw해 카메라 페이스에 동기화한다.
final class FilteredCameraPreviewView: MTKView {
    private let commandQueue: MTLCommandQueue
    private let ciContext: CIContext
    private var image: CIImage?

    init() {
        guard let metalDevice = MTLCreateSystemDefaultDevice(),
              let queue = metalDevice.makeCommandQueue() else {
            fatalError("Metal을 사용할 수 없는 기기입니다")
        }
        commandQueue = queue
        ciContext = CIContext(mtlDevice: metalDevice, options: [.cacheIntermediates: false])
        super.init(frame: .zero, device: metalDevice)
        framebufferOnly = false
        isPaused = true
        enableSetNeedsDisplay = false
        backgroundColor = .black
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(with frame: ARFrame) {
        image = FaceBeautyFilter.apply(to: frame.capturedImage)
        draw()
    }

    override func draw(_ rect: CGRect) {
        guard let image,
              let drawable = currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let target = drawableSize
        guard target.width > 0, target.height > 0, !image.extent.isEmpty else { return }

        // aspect-fill: 짧은 변을 채우도록 확대 후 중앙 크롭
        let scale = max(target.width / image.extent.width, target.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let originX = scaled.extent.midX - target.width / 2
        let originY = scaled.extent.midY - target.height / 2
        let centered = scaled.transformed(by: CGAffineTransform(translationX: -originX, y: -originY))

        ciContext.render(
            centered,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: CGRect(origin: .zero, size: target),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add SmileDay/Services/FaceBeautyFilter.swift SmileDay/Services/FilteredCameraPreviewView.swift
git commit -m "feat: add beauty filter chain and Metal camera preview"
```

---

### Task 2: ARKitFaceTrackingSession 교체 + 오버레이 정리

**Files:**
- Modify: `SmileDay/Services/ARKitFaceTrackingSession.swift` (ARSCNView → ARSession + FilteredCameraPreviewView)
- Modify: `SmileDay/Services/ARFacePreviewRepresentable.swift` (반환 타입 교체)
- Modify: `SmileDay/Views/Coaching/CoachingSessionView.swift` (`CameraWarmToneOverlay()` 제거)
- Modify: `SmileDay/Views/Onboarding/BaselineCaptureView.swift` (`CameraWarmToneOverlay()` 제거)
- Delete: `SmileDay/Views/CameraWarmToneOverlay.swift`

- [ ] **Step 1: ARKitFaceTrackingSession 재작성**

blendshape 추출·각도 판정 로직은 그대로 두고, 델리게이트만 `ARSCNViewDelegate` → `ARSessionDelegate.session(_:didUpdate anchors:)`로 옮긴다. `session(_:didUpdate frame:)`에서 조명 추정과 프리뷰 갱신을 함께 처리한다. ARSession delegate 큐는 기본값(메인 직렬 큐)이므로 기존의 `DispatchQueue.main.async` 래핑은 제거한다.

```swift
// SmileDay/Services/ARKitFaceTrackingSession.swift
import ARKit
import CoachingKit

enum FaceTrackingError: Error {
    case unsupportedDevice
}

final class ARKitFaceTrackingSession: NSObject, FaceTrackingSession {
    var onUpdate: ((FaceMeasurement) -> Void)?
    var onError: ((Error) -> Void)?
    var onLightingUpdate: ((Double) -> Void)?
    var onTrackingQualityUpdate: ((Bool) -> Void)?

    let previewView = FilteredCameraPreviewView()
    private let session = ARSession()
    private var isRunning = false

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        guard !isRunning else { return }
        guard ARFaceTrackingConfiguration.isSupported else {
            onError?(FaceTrackingError.unsupportedDevice)
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }

    func stop() {
        session.pause()
        isRunning = false
    }
}

extension ARKitFaceTrackingSession: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let faceAnchor = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        // 트래킹이 유실된 프레임(손으로 가림/프레임 이탈)은 마지막 정상값을 덮어쓰지 않도록 무시한다.
        guard faceAnchor.isTracked else { return }
        let blendShapes = faceAnchor.blendShapes

        let mouthCornerLeft = blendShapes[.mouthSmileLeft]?.doubleValue ?? 0
        let mouthCornerRight = blendShapes[.mouthSmileRight]?.doubleValue ?? 0
        let browDownLeft = blendShapes[.browDownLeft]?.doubleValue ?? 0
        let browDownRight = blendShapes[.browDownRight]?.doubleValue ?? 0
        let browInnerUp = blendShapes[.browInnerUp]?.doubleValue ?? 0
        let browTension = (browDownLeft + browDownRight + browInnerUp) / 3

        let measurement = FaceMeasurement(
            mouthCornerLeft: mouthCornerLeft,
            mouthCornerRight: mouthCornerRight,
            browTension: browTension
        )

        let angleOK = Self.isAngleWithinTolerance(transform: faceAnchor.transform)

        onUpdate?(measurement)
        onTrackingQualityUpdate?(angleOK)
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        previewView.update(with: frame)
        if let intensity = frame.lightEstimate?.ambientIntensity {
            onLightingUpdate?(Double(intensity))
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        onError?(error)
    }

    /// 얼굴 world-space transform에서 pitch(x축)/yaw(y축) 각도를 도 단위로 구해 허용 범위를 판정한다.
    /// 쿼터니언 성분 순서는 simd_quatf.vector == (x, y, z, w).
    private static func isAngleWithinTolerance(transform: simd_float4x4) -> Bool {
        let q = simd_quatf(transform)
        let x = Double(q.vector.x)
        let y = Double(q.vector.y)
        let z = Double(q.vector.z)
        let w = Double(q.vector.w)

        // pitch: x축 회전 (atan2), yaw: y축 회전 (asin). 정면 응시 시 항등 쿼터니언 → 0도.
        let pitchRadians = atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y))
        let sinYaw = max(-1, min(1, 2 * (w * y - z * x)))
        let yawRadians = asin(sinYaw)

        let pitchDegrees = pitchRadians * 180 / .pi
        let yawDegrees = yawRadians * 180 / .pi

        return AngleEvaluator.isWithinTolerance(pitchDegrees: pitchDegrees, yawDegrees: yawDegrees)
    }
}
```

- [ ] **Step 2: ARFacePreviewRepresentable 반환 타입 교체**

```swift
// SmileDay/Services/ARFacePreviewRepresentable.swift
import SwiftUI

struct ARFacePreviewRepresentable: UIViewRepresentable {
    let session: ARKitFaceTrackingSession

    func makeUIView(context: Context) -> FilteredCameraPreviewView {
        session.previewView
    }

    func updateUIView(_ uiView: FilteredCameraPreviewView, context: Context) {}
}
```

- [ ] **Step 3: 웜톤 오버레이 제거**

`CoachingSessionView.swift`와 `BaselineCaptureView.swift`에서 `CameraWarmToneOverlay()` 줄을 제거하고, `SmileDay/Views/CameraWarmToneOverlay.swift` 파일을 삭제한다.

- [ ] **Step 4: Commit**

```bash
git add -A SmileDay/Services SmileDay/Views
git commit -m "feat: render camera preview through beauty filter pipeline"
```

---

### Task 3: 빌드·테스트 검증

- [ ] **Step 1: 앱 타겟 빌드**

Run: `xcodebuild -project SmileDay.xcodeproj -scheme SmileDay -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: CoachingKit 테스트 (변경 없음 확인)**

Run: `cd CoachingKit && swift test`
Expected: PASS — 전부 통과 (CoachingKit은 이번 작업에서 미변경).

**후속 (실기기 확인 필수)**: 시뮬레이터는 ARKit 얼굴 추적 미지원. 실기기에서 (1) 방향/셀피 미러링이 기존과 동일한지, (2) 실시간 게이지·조명 배너가 동작하는지, (3) 발열·프레임 드랍이 없는지 확인하고 필터 강도를 조정한다.
