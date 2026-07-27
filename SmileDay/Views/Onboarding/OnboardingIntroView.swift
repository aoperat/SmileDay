import SwiftUI

struct OnboardingIntroView: View {
    let onStart: () -> Void
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            IntroPage(
                systemImage: "face.smiling",
                title: "스마일데이",
                message: "하루에 한 번, 잠시 멈춰 미소 짓는 시간을 만들어요.\n\n잘 웃었는지 평가하지 않아요. 오늘 잠시 웃어본 것과 나를 웃게 한 순간만 기록해요."
            )
            .tag(0)

            IntroPage(
                systemImage: "lock.shield",
                title: "사진은 저장하지 않아요",
                message: "카메라는 얼굴이 잘 잡혔는지 확인하는 데만 써요. 사진과 영상은 어디에도 저장하지 않습니다.\n\n기분과 한 줄 기록도 이 기기 안에만 남고 외부로 전송되지 않아요."
            )
            .tag(1)

            VStack(spacing: 32) {
                IntroPage(
                    systemImage: "camera.viewfinder",
                    title: "처음 한 번만 설정할게요",
                    message: "카메라가 평소 내 표정을 알아볼 수 있게\n밝은 곳에서 편안한 표정으로 한 번만 찍어요.\n\n시작하면 카메라 권한을 요청합니다."
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
