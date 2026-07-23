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

    func test_catalog_everyRoutineHasNonEmptyPurpose() {
        for routine in CareRoutine.catalog {
            XCTAssertFalse(
                routine.purpose.isEmpty,
                "\(routine.id) is missing a purpose description"
            )
        }
    }
}
