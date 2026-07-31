import SwiftUI

/// 로컬 저장소를 열 수 없을 때 데이터 삭제나 강제 종료 대신 복구 안내를 보여준다.
struct AppStartupFailureView: View {
    var body: some View {
        ZStack {
            SDColor.cream.ignoresSafeArea()

            // 복구 방법을 알려주는 화면이라 큰 글씨에서 잘리면 안내 자체가 사라진다.
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(SDColor.sunDeep)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("앱을 시작하지 못했어요")
                            .font(.title2.bold())
                            .foregroundStyle(SDColor.ink)

                        Text("앱을 완전히 종료한 뒤 다시 열어주세요.\n계속되면 기기를 재시동해 주세요.")
                            .font(.body)
                            .foregroundStyle(SDColor.muted)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(28)
                .sdCard()
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(.light)
    }
}

/// 저장소는 열렸지만 화면 데이터를 읽지 못했을 때 쓰는 재시도 카드.
struct AppDataLoadFailureView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(SDColor.sunDeep)
                .accessibilityHidden(true)

            Text("앱 데이터를 불러오지 못했어요")
                .font(.headline)
                .foregroundStyle(SDColor.ink)

            Text("기존 기록은 그대로 있어요. 잠시 후 다시 시도해주세요.")
                .font(.subheadline)
                .foregroundStyle(SDColor.muted)
                .multilineTextAlignment(.center)

            Button("다시 시도", action: onRetry)
                .buttonStyle(SDInkButtonStyle())
        }
        .padding(24)
        .sdCard()
        .padding(.horizontal, 24)
    }
}
