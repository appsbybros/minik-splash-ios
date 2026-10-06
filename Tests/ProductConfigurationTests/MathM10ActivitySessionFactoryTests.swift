import XCTest
@testable import MinikPlus

final class MathM10ActivitySessionFactoryTests: XCTestCase {
    func testEveryEducationalIdentityBuildsDedicatedM10Session() {
        let factory = MathM10ActivitySessionFactory(configuration: .configuration(for: .minikMath))
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m10), .m10Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testMixedExcludesInstructionAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM10MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM10MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM10MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM10MixedSession()
        for _ in 0..<30 {
            let previous = mixed.currentActivity
            mixed.advance()
            XCTAssertNotEqual(previous, mixed.currentActivity)
        }
    }

    func testRejectingFitGateDoesNotGenerateSessions() {
        let factory = MathM10ActivitySessionFactory(
            configuration: .configuration(for: .minikMath), fitGate: .rejectingForTests)
        XCTAssertNil(factory.makeSession(for: .visualToAnswer))
        XCTAssertNil(factory.makeSession(for: .buildNumber))
        XCTAssertNil(factory.makeSession(for: .mathSoccer))
    }
}
