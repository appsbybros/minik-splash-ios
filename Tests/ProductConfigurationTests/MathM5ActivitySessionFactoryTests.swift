import XCTest
@testable import MinikPlus

final class MathM5ActivitySessionFactoryTests: XCTestCase {
    func testEveryEducationalIdentityBuildsDedicatedM5Session() {
        let factory = MathM5ActivitySessionFactory(
            configuration: .configuration(for: .minikMath), towerModeSelector: { .answerTokens }
        )
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m5), .m5Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testBothTowerModesAreProductionRoutable() {
        let count = MathM5ActivitySessionFactory(
            configuration: .configuration(for: .minikMath), towerModeSelector: { .count }
        )
        let tokens = MathM5ActivitySessionFactory(
            configuration: .configuration(for: .minikMath), towerModeSelector: { .answerTokens }
        )
        guard case .towerCount(let countSession)? = count.makeSession(for: .mathTower) else {
            return XCTFail("Small results must support Count Tower.")
        }
        XCTAssertTrue(countSession.rounds.allSatisfy { $0.target <= 20 && $0.mathLevelID == .m5 })
        guard case .towerTokens(let tokenSession)? = tokens.makeSession(for: .mathTower) else {
            return XCTFail("Large results must support Answer Token Tower.")
        }
        XCTAssertTrue(tokenSession.challenges.allSatisfy { $0.curriculumStage == MathCurriculumLevelID.m5.curriculumStageID })
    }

    func testMixedExcludesInstructionAndPingPongAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM5MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM5MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM5MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM5MixedSession()
        for _ in 0..<30 { let old = mixed.currentActivity; mixed.advance(); XCTAssertNotEqual(old, mixed.currentActivity) }
    }

    func testRejectingFitGateMakesGeneratedSessionsUnavailable() {
        let factory = MathM5ActivitySessionFactory(
            configuration: .configuration(for: .minikMath), fitGate: .rejectingForTests,
            towerModeSelector: { .answerTokens }
        )
        XCTAssertNil(factory.makeSession(for: .visualToAnswer))
        XCTAssertNil(factory.makeSession(for: .buildNumber))
        XCTAssertNil(factory.makeSession(for: .mathSoccer))
    }
}
