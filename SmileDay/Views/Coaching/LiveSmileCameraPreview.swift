import ARKit
import SceneKit
import SwiftUI

/// 사용자가 직접 켰을 때만 나타나는 카메라 화면.
///
/// 이미 돌고 있는 세션을 그대로 그리기만 한다. 프레임을 따로 읽지 않고,
/// 저장하거나 내보내는 경로도 없다. 끄면 뷰 자체가 사라져 렌더링 비용도 사라진다.
struct LiveSmileCameraPreview: UIViewRepresentable {
    let session: ARSession
    /// 프리뷰 뷰가 세션 delegate를 가져가더라도 샘플 전달이 끊기지 않게 되돌린다.
    let onAttached: () -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.isUserInteractionEnabled = false
        view.automaticallyUpdatesLighting = true
        view.rendersContinuously = true
        // 얼굴 메시나 3D 오버레이를 그리지 않는다. 카메라 배경만 보여준다.
        view.scene = SCNScene()
        attach(session, to: view)
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        guard view.session !== session else { return }
        attach(session, to: view)
    }

    private func attach(_ session: ARSession, to view: ARSCNView) {
        view.session = session
        onAttached()
    }
}
