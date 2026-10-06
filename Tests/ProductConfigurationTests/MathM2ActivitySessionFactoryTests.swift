import XCTest
@testable import MinikPlus

final class MathM2ActivitySessionFactoryTests: XCTestCase {
    private var factory: MathM2ActivitySessionFactory {
        MathM2ActivitySessionFactory(
            configuration: ProductConfiguration.configuration(for: .minikMath)
        )
    }

    func testEveryEducationalM2IdentityBuildsDedicatedProductionSession() {
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m2), .m2Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testMixedIncludesOnlyGradedEducationalModesAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM2MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM2MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM2MixedSession.eligibleActivities.contains(.pingPong))
        var session = MathM2MixedSession()
        for _ in 0..<30 {
            let previous = session.currentActivity
            session.advance()
            XCTAssertNotEqual(session.currentActivity, previous)
        }
    }

    func testM2CountSessionsCarryM2MetadataAndExtraTokens() throws {
        for activity in [MathProductionActivityID.buildQuantity, .mathTower] {
            let produced = try XCTUnwrap(factory.makeSession(for: activity))
            let session: MathCountConstructionSession
            switch produced {
            case .buildQuantity(let value), .tower(let value): session = value
            default: return XCTFail("Expected count construction for \(activity).")
            }
            for round in session.rounds {
                XCTAssertEqual(round.mathLevelID, .m2)
                XCTAssertGreaterThan(round.availableTokenIDs.count, round.target)
            }
        }
    }

    func testRejectingFitGateProducesUnavailableSessionsInsteadOfUnboundedGeneration() {
        let rejectingFactory = MathM2ActivitySessionFactory(
            configuration: ProductConfiguration.configuration(for: .minikMath),
            fitGate: .rejectingForTests
        )
        XCTAssertNil(rejectingFactory.makeSession(for: .visualToAnswer))
        XCTAssertNil(rejectingFactory.makeSession(for: .buildNumber))
        XCTAssertNil(rejectingFactory.makeSession(for: .mathSoccer))
    }
}
