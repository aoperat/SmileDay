import Foundation
import CoachingKit

extension ReminderScheduleError {
    var message: String {
        switch self {
        case .schedulingFailed: String(localized: .Settings.scheduleErrorSchedulingFailed)
        case .persistenceFailed: String(localized: .Settings.scheduleErrorPersistenceFailed)
        }
    }
}
