import SwiftUI

struct FaceGuideOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width * 0.62
            let height = width * 1.35

            Ellipse()
                .stroke(style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: width, height: height)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)
        }
        .allowsHitTesting(false)
    }
}
