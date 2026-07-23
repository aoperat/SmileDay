import Foundation
import SwiftData

@Model
public final class Baseline {
    public var capturedAt: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double
    public var lightingQuality: Double = 1.0
    public var deviceAngleOK: Bool = true

    public init(
        capturedAt: Date,
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        lightingQuality: Double,
        deviceAngleOK: Bool
    ) {
        self.capturedAt = capturedAt
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.lightingQuality = lightingQuality
        self.deviceAngleOK = deviceAngleOK
    }

    public var measurement: FaceMeasurement {
        FaceMeasurement(mouthCornerLeft: mouthCornerLeft, mouthCornerRight: mouthCornerRight, browTension: browTension)
    }
}

public extension Baseline {
    /// 이 이상 경과하면 재설정을 권장한다.
    static let recommendResetThresholdWeeks = 4

    /// 촬영 후 경과한 완전한 주 수.
    func ageWeeks(now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(calendar.dateComponents([.weekOfYear], from: capturedAt, to: now).weekOfYear ?? 0, 0)
    }

    /// 재설정을 권장할 시점이 됐는지.
    func isOverdueForReset(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        ageWeeks(now: now, calendar: calendar) >= Self.recommendResetThresholdWeeks
    }
}
