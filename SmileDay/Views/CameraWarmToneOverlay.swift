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
