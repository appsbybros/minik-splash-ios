import XCTest
@testable import MinikPlus

final class MathM8ActivitySessionFactoryTests: XCTestCase {
    func testEveryEducationalIdentityBuildsDedicatedM8Session() {
        let factory = MathM8ActivitySessionFactory(configuration: .configuration(for: .minikMath))
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m8), .m8Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testMixedContainsOnlyGradedModesAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM8MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM8MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM8MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM8MixedSession()
        for _ in 0..<30 {
            let previous = mixed.currentActivity
            mixed.advance()
            XCTAssertNotEqual(previous, mixed.currentActivity)
        }
    }

    func testRejectingFitGateDoesNotGenerateSessions() {
        let factory = MathM8ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            fitGate: .rejectingForTests
        )
        XCTAssertNil(factory.makeSession(for: .visualToAnswer))
        XCTAssertNil(factory.makeSession(for: .buildNumber))
        XCTAssertNil(factory.makeSession(for: .mathSoccer))
    }
}
