import Foundation
import CoachingKit

extension ReminderMessageError {
    var message: String {
        switch self {
        case .empty: String(localized: .Settings.messageErrorEmpty)
        case .tooLong(let limit): String(localized: .Settings.messageErrorTooLong(limit))
        case .duplicate: String(localized: .Settings.messageErrorDuplicate)
        case .lastRemaining: String(localized: .Settings.messageErrorLastRemaining)
        }
    }
}
