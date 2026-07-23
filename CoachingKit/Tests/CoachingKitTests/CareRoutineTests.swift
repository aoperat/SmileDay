import XCTest
@testable import CoachingKit

final class CareRoutineTests: XCTestCase {
    func test_catalog_everyStepHasNonEmptySystemImage() {
        for routine in CareRoutine.catalog {
            for step in routine.steps {
                XCTAssertFalse(
                    step.systemImage.isEmpty,
                    "\(routine.id) step '\(step.title)' is missing a systemImage"
                )
            }
        }
    }
}
