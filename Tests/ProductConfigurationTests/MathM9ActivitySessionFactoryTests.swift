import XCTest
@testable import MinikPlus

final class MathM9ActivitySessionFactoryTests: XCTestCase {
    func testEveryEducationalIdentityBuildsDedicatedM9Session() {
        let factory = MathM9ActivitySessionFactory(configuration: .configuration(for: .minikMath))
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m9), .m9Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testMixedContainsOnlyGradedModesAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM9MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM9MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM9MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM9MixedSession()
        for _ in 0..<30 {
            let previous = mixed.currentActivity
            mixed.advance()
            XCTAssertNotEqual(previous, mixed.currentActivity)
        }
    }

    func testRejectingFitGateDoesNotGenerateSessions() {
        let factory = MathM9ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            fitGate: .rejectingForTests
        )
        XCTAssertNil(factory.makeSession(for: .visualToAnswer))
        XCTAssertNil(factory.makeSession(for: .buildNumber))
        XCTAssertNil(factory.makeSession(for: .mathSoccer))
    }
}
