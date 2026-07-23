import SwiftUI

struct ARFacePreviewRepresentable: UIViewRepresentable {
    let session: ARKitFaceTrackingSession

    func makeUIView(context: Context) -> FilteredCameraPreviewView {
        session.previewView
    }

    func updateUIView(_ uiView: FilteredCameraPreviewView, context: Context) {}
}
