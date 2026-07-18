#if DEBUG
import Foundation
import CoachingKit

/// 시뮬레이터에는 AR 얼굴 추적이 없어 기준선 캡처를 통과할 수 없다.
/// `-seedDemoData` 런치 인자로 기준선과 지난 체크인들을 심어 UI 확인용 상태를 만든다.
enum DemoSeeder {
    static func seedIfNeeded(repository: SessionRepository) throws {
        guard try repository.fetchLatestBaseline() == nil else { return }

        let calendar = Calendar.current
        let now = Date()
        try repository.saveBaseline(
            FaceMeasurement(mouthCornerLeft: 0.3, mouthCornerRight: 0.3, browTension: 0.2),
            capturedAt: calendar.date(byAdding: .weekOfYear, value: -3, to: now) ?? now
        )

        let deltasByDaysAgo: [Int: Double] = [1: 0.2, 2: 0.15, 3: 0.3, 4: 0.1, 5: 0.25, 7: 0.1, 9: 0.3, 11: 0.2]
        for (daysAgo, delta) in deltasByDaysAgo {
            guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)),
                  let noon = calendar.date(byAdding: .hour, value: 12, to: day) else { continue }
            try repository.saveCheckIn(
                measurement: FaceMeasurement(
                    mouthCornerLeft: 0.3 + delta,
                    mouthCornerRight: 0.3 + delta,
                    browTension: 0.2 + delta
                ),
                date: noon,
                lightingQuality: 1.0,
                deviceAngleOK: true,
                scoreDelta: delta
            )
        }
    }
}
#endif
