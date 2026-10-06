import XCTest
@testable import MinikPlus

final class MathM3ActivitySessionFactoryTests: XCTestCase {
    private var factory: MathM3ActivitySessionFactory {
        MathM3ActivitySessionFactory(configuration: .configuration(for: .minikMath))
    }

    func testEveryEducationalIdentityBuildsDedicatedM3Session() {
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m3), .m3Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testBuildMathPreservesTypedMissingValuePromptsAcrossAllSixChallenges() throws {
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m3), .m3Production)
        let activitySession = try XCTUnwrap(factory.makeSession(for: .buildMath))
        guard case .buildMath(var session) = activitySession else {
            return XCTFail("Production M3 Build must use the equation-building session.")
        }
        // An independent oracle for the deterministic six-challenge production sequence.
        // UUIDs and the shuffled token tray are deliberately not part of the oracle.
        let expected: [(left: Int, operation: MathOperation, right: Int, result: Int,
                        missing: MathMissingPosition, skill: SkillID)] = [
            (2, .addition, 5, 7, .rightOperand, MathSkillIDs.missingAddend),
            (12, .subtraction, 7, 5, .rightOperand, MathSkillIDs.missingAddend),
            (7, .addition, 5, 12, .result, MathSkillIDs.addition),
            (6, .addition, 4, 10, .result, MathSkillIDs.equivalentValues),
            (7, .addition, 5, 12, .rightOperand, MathSkillIDs.missingAddend),
            (18, .subtraction, 9, 9, .rightOperand, MathSkillIDs.missingAddend)
        ]
        XCTAssertEqual(session.challengeCount, expected.count)
        for (challenge, fixture) in zip(session.challenges, expected) {
            XCTAssertEqual(challenge.curriculumStage, MathCurriculumLevelID.m3.curriculumStageID)
            XCTAssertEqual(challenge.primarySkill, fixture.skill)
            XCTAssertEqual(challenge.validationMode, .submitSequence)
            XCTAssertEqual(challenge.prompt.representations.count, 1)
            guard case .math(.missingValueExpression(let prompt)) = try XCTUnwrap(challenge.prompt.representations.first) else {
                return XCTFail("Production M3 Build must retain its typed missing-value prompt.")
            }
            XCTAssertEqual(prompt.operation, fixture.operation)
            XCTAssertEqual(prompt.missingPosition, fixture.missing)
            XCTAssertEqual(prompt.left, .integer(fixture.left))
            XCTAssertEqual(prompt.right, fixture.missing == .rightOperand ? nil : .integer(fixture.right))
            XCTAssertEqual(prompt.result, fixture.missing == .result ? nil : .integer(fixture.result))

            let pieces = try challenge.expectedTokenSequence.map { tokenID -> String in
                let token = try XCTUnwrap(challenge.availableTokens.first { $0.id == tokenID })
                guard case .mathExpression(let expression) = token.representation else {
                    throw M3BuildFixtureError.unexpectedTokenRepresentation
                }
                return expression.expression
            }
            XCTAssertEqual(pieces, [String(fixture.left), fixture.operation.symbol, String(fixture.right), "=", String(fixture.result)])
            XCTAssertEqual(challenge.availableTokens.count, 6)
            XCTAssertEqual(Set(challenge.availableTokens.map(\.id)).count, 6)
            for tokenID in challenge.expectedTokenSequence { session.selectToken(tokenID) }
            XCTAssertNil(session.answerResult)
            session.submit()
            XCTAssertEqual(session.answerResult, .correct)
            session.nextChallenge()
        }
        XCTAssertTrue(session.isComplete)
    }

    func testMixedExcludesInstructionAndGameModesAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM3MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM3MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM3MixedSession.eligibleActivities.contains(.pingPong))
        var mixed = MathM3MixedSession()
        for _ in 0..<30 {
            let previous = mixed.currentActivity
            mixed.advance()
            XCTAssertNotEqual(previous, mixed.currentActivity)
        }
    }

    func testTowerUsesCountConstructionRatherThanPrototypeSorting() throws {
        let session = try XCTUnwrap(factory.makeSession(for: .mathTower))
        guard case .tower(let tower) = session else {
            return XCTFail("M3 Tower must use the confirmed count-construction contract.")
        }
        for round in tower.rounds {
            XCTAssertEqual(round.mathLevelID, .m3)
            XCTAssertGreaterThan(round.availableTokenIDs.count, round.target)
        }
    }

    func testRejectingFitGateMakesGeneratedSessionsUnavailable() {
        let rejecting = MathM3ActivitySessionFactory(
            configuration: .configuration(for: .minikMath),
            fitGate: .rejectingForTests
        )
        XCTAssertNil(rejecting.makeSession(for: .visualToAnswer))
        XCTAssertNil(rejecting.makeSession(for: .buildNumber))
        XCTAssertNil(rejecting.makeSession(for: .mathSoccer))
    }
}

private enum M3BuildFixtureError: Error {
    case unexpectedTokenRepresentation
}
