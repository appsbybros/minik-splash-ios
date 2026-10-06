import XCTest
@testable import MinikPlus

final class MathM7ActivitySessionFactoryTests: XCTestCase {
    func testEveryEducationalIdentityBuildsDedicatedM7Session() {
        let factory = MathM7ActivitySessionFactory(configuration: .configuration(for: .minikMath))
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m7), .m7Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testMixedContainsOnlyGradedModesAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM7MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM7MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM7MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM7MixedSession()
        for _ in 0..<30 { let old = mixed.currentActivity; mixed.advance(); XCTAssertNotEqual(old, mixed.currentActivity) }
    }

    func testRejectingFitGateDoesNotLoopOrReturnGeneratedActivities() {
        let factory = MathM7ActivitySessionFactory(configuration: .configuration(for: .minikMath), fitGate: .rejectingForTests)
        XCTAssertNil(factory.makeSession(for: .visualToAnswer))
        XCTAssertNil(factory.makeSession(for: .buildNumber))
        XCTAssertNil(factory.makeSession(for: .mathSoccer))
    }
}
