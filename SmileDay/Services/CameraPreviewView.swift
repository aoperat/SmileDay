import MetalKit
import CoreImage
import ARKit

/// ARFrame 원본을 보정 없이 그리는 카메라 프리뷰.
/// 세션 프레임이 도착할 때만 수동으로 draw해 카메라 페이스에 동기화한다.
final class CameraPreviewView: MTKView {
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
        // 전면 카메라 세로 화면: 90도 회전만. 미러링·색보정 없이 원본 그대로.
        image = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)
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
