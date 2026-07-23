import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            SDColor.primaryGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                SmileArc(depth: 0.4)
                    .stroke(SDColor.cream, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 96, height: 48)

                Text("스마일데이")
                    .font(.title.bold())
                    .foregroundStyle(SDColor.cream)

                Text("웃다보면 다 좋아질거야")
                    .font(.subheadline)
                    .foregroundStyle(SDColor.cream.opacity(0.9))
            }
        }
    }
}

#Preview {
    SplashView()
}
