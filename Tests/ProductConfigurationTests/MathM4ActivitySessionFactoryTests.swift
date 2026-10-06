import XCTest
@testable import MinikPlus

final class MathM4ActivitySessionFactoryTests: XCTestCase {
    func testEveryEducationalIdentityBuildsDedicatedM4Session() {
        let factory = MathM4ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            towerModeSelector: { .answerTokens }
        )
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m4), .m4Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testBothTowerModesAreProductionRoutable() throws {
        let countFactory = MathM4ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            towerModeSelector: { .count }
        )
        let tokenFactory = MathM4ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            towerModeSelector: { .answerTokens }
        )
        guard case .towerCount(let count)? = countFactory.makeSession(for: .mathTower) else {
            return XCTFail("Small M4 results must support Count Tower.")
        }
        XCTAssertTrue(count.rounds.allSatisfy { $0.target <= 20 && $0.mathLevelID == .m4 })
        guard case .towerTokens(let tokens)? = tokenFactory.makeSession(for: .mathTower) else {
            return XCTFail("Large M4 results must support Answer Token Tower.")
        }
        XCTAssertTrue(tokens.challenges.allSatisfy { $0.curriculumStage == MathCurriculumLevelID.m4.curriculumStageID })
    }

    func testMixedExcludesInstructionAndPingPongAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM4MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM4MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM4MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM4MixedSession()
        for _ in 0..<30 {
            let previous = mixed.currentActivity
            mixed.advance()
            XCTAssertNotEqual(previous, mixed.currentActivity)
        }
    }

    func testRejectingFitGateMakesGeneratedSessionsUnavailable() {
        let factory = MathM4ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            fitGate: .rejectingForTests,
            towerModeSelector: { .answerTokens }
        )
        XCTAssertNil(factory.makeSession(for: .visualToAnswer))
        XCTAssertNil(factory.makeSession(for: .buildNumber))
        XCTAssertNil(factory.makeSession(for: .mathSoccer))
    }
}
