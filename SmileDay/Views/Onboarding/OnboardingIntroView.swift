import SwiftUI

struct OnboardingIntroView: View {
    let onStart: () -> Void
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            IntroPage(
                systemImage: "face.smiling",
                title: "스마일데이",
                message: "무표정일 때의 얼굴 긴장 습관을 인지하고\n매일의 표정 습관을 기록하는 앱입니다."
            )
            .tag(0)

            IntroPage(
                systemImage: "lock.shield",
                title: "데이터는 기기에만 저장됩니다",
                message: "카메라로 측정한 얼굴 데이터는 이 기기에만 저장되며 외부로 전송되지 않습니다.\n\n이 앱은 의학적 효과를 보장하지 않습니다. 심한 비대칭이나 안면마비가 의심되면 전문의 상담을 권장합니다."
            )
            .tag(1)

            VStack(spacing: 32) {
                IntroPage(
                    systemImage: "camera.viewfinder",
                    title: "기준선 촬영 준비",
                    message: "밝은 곳에서 정면을 바라보고\n무표정으로 촬영해주세요.\n\n시작하면 카메라 권한을 요청합니다."
                )

                Button("시작하기") {
                    onStart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

private struct IntroPage: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text(title)
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    OnboardingIntroView(onStart: {})
}
