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
