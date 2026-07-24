import SwiftUI

struct ARFacePreviewRepresentable: UIViewRepresentable {
    let session: ARKitFaceTrackingSession

    func makeUIView(context: Context) -> CameraPreviewView {
        session.previewView
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}
}
