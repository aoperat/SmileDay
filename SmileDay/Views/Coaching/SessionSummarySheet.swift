import SwiftUI

struct SessionSummarySheet: View {
    let scoreDelta: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("오늘의 기록이 저장되었습니다")
                .font(.headline)

            Text(String(format: "기준선 대비 변화량: %.2f", scoreDelta))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("닫기") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    SessionSummarySheet(scoreDelta: 0.12)
}
