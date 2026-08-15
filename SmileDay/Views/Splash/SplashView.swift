import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            SDColor.primaryGradient
                .ignoresSafeArea()

            // 주조색이 노랑이라 크림색 글자는 대비가 1.5:1도 안 나온다. 앱 아이콘과 같은
            // 조합(노랑 바탕 + 진한 글자)으로 맞춘다.
            VStack(spacing: 20) {
                SmileArc(depth: 0.4)
                    .stroke(SDColor.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 96, height: 48)

                Text(.splashTitle)
                    .font(.title.bold())
                    .foregroundStyle(SDColor.ink)

                Text(.splashTagline)
                    .font(.subheadline)
                    .foregroundStyle(SDColor.ink.opacity(0.75))
            }
        }
    }
}

#Preview {
    SplashView()
}
