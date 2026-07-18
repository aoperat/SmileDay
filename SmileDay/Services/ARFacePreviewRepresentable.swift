import SwiftUI
import ARKit

struct ARFacePreviewRepresentable: UIViewRepresentable {
    let session: ARKitFaceTrackingSession

    func makeUIView(context: Context) -> ARSCNView {
        session.previewView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}
