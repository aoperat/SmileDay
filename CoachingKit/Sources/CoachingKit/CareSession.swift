import Foundation
import SwiftData

/// 케어 루틴 1회 완료 기록.
@Model
public final class CareSession {
    public var date: Date
    public var routineID: String

    public init(date: Date, routineID: String) {
        self.date = date
        self.routineID = routineID
    }
}
