import SwiftUI

struct StreakDotsView: View {
    let days: [Bool]
    let streak: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, done in
                    Circle()
                        .fill(done ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            if streak > 0 {
                Text("연속 \(streak)일 기록 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    StreakDotsView(days: [false, true, true, false, true], streak: 1)
}
