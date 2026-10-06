import XCTest
@testable import MinikPlus

final class MathM6ActivitySessionFactoryTests: XCTestCase {
    func testEveryEducationalIdentityBuildsDedicatedM6Session() {
        let factory = MathM6ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            towerModeSelector: { .answerTokens }, buildQuantityModeSelector: { .equalGroups }
        )
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m6), .m6Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testBothBuildQuantityAndTowerModesAreRoutable() {
        let groups = factory(tower: .count, quantity: .equalGroups)
        let fractions = factory(tower: .answerTokens, quantity: .fractionBar)
        guard case .buildQuantity(.equalGroups(_))? = groups.makeSession(for: .buildQuantity) else {
            return XCTFail("M6 must route equal-group construction.")
        }
        guard case .buildQuantity(.fractionBar(_))? = fractions.makeSession(for: .buildQuantity) else {
            return XCTFail("M6 must route fraction-bar construction.")
        }
        guard case .towerCount(_)? = groups.makeSession(for: .mathTower) else {
            return XCTFail("M6 must retain sensible Count Tower.")
        }
        guard case .towerTokens(_)? = fractions.makeSession(for: .mathTower) else {
            return XCTFail("M6 must route symbolic Answer Token Tower.")
        }
    }

    func testMixedExcludesInstructionAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM6MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM6MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM6MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM6MixedSession()
        for _ in 0..<30 { let old = mixed.currentActivity; mixed.advance(); XCTAssertNotEqual(old, mixed.currentActivity) }
    }

    func testRejectingFitGateMakesGeneratedSessionsUnavailable() {
        let factory = MathM6ActivitySessionFactory(
            configuration: .configuration(for: .minikMath), fitGate: .rejectingForTests,
            towerModeSelector: { .answerTokens }, buildQuantityModeSelector: { .equalGroups }
        )
        XCTAssertNil(factory.makeSession(for: .visualToAnswer))
        XCTAssertNil(factory.makeSession(for: .buildNumber))
        XCTAssertNil(factory.makeSession(for: .mathSoccer))
    }

    private func factory(tower: MathTowerConstructionMode, quantity: MathM6BuildQuantityMode) -> MathM6ActivitySessionFactory {
        MathM6ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            towerModeSelector: { tower }, buildQuantityModeSelector: { quantity }
        )
    }
}
