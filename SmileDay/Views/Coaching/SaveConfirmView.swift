import SwiftUI

struct SaveConfirmView: View {
    let todayScore: Int
    let yesterdayScore: Int?
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("오늘의 기록이 저장되었습니다")
                .font(.headline)

            HStack(spacing: 12) {
                if let yesterdayScore {
                    Text("어제 \(signed(yesterdayScore))°")
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                }
                Text("오늘 \(signed(todayScore))°")
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
            }
            .font(.title3)

            Button("확인") {
                onConfirm()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

#Preview {
    SaveConfirmView(todayScore: 3, yesterdayScore: 1, onConfirm: {})
}
