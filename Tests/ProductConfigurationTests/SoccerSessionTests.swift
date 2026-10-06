import XCTest
@testable import MinikPlus

final class SoccerSessionTests: XCTestCase {
    func testInitialStateStartsOnFirstTargetWithNoResultAndZeroScore() throws {
        let round = try makeRound(values: [1, 2])
        let session = SoccerSession(round: round)

        XCTAssertEqual(session.currentTargetIndex, 0)
        XCTAssertEqual(session.currentTarget, round.challengeTargets[0])
        XCTAssertEqual(session.targetCount, 2)
        XCTAssertNil(session.selectedBallID)
        XCTAssertNil(session.educationalIsCorrect)
        XCTAssertNil(session.gameOutcome)
        XCTAssertEqual(session.childScore, 0)
        XCTAssertEqual(session.keeperScore, 0)
        XCTAssertFalse(session.isComplete)
    }

    func testUnknownBallIsIgnoredAndValidSelectionLocksSelection() throws {
        let round = try makeRound(values: [1, 2])
        var session = SoccerSession(round: round)
        let firstBallID = round.answerBalls[0].id
        let secondBallID = round.answerBalls[1].id

        session.selectBall(SoccerBallID(rawValue: "missing"))
        session.selectBall(firstBallID)
        session.selectBall(secondBallID)

        XCTAssertEqual(session.selectedBallID, firstBallID)
    }

    func testIntendedAndOtherValidBallsSetEducationalCorrectness() throws {
        let round = try makeRound(values: [1, 2])
        let intendedID = round.challengeTargets[0].intendedBallID
        let otherID = try XCTUnwrap(round.answerBalls.first { $0.id != intendedID }?.id)
        var correctSession = SoccerSession(round: round)
        var incorrectSession = SoccerSession(round: round)

        correctSession.selectBall(intendedID)
        incorrectSession.selectBall(otherID)

        XCTAssertEqual(correctSession.educationalIsCorrect, true)
        XCTAssertEqual(incorrectSession.educationalIsCorrect, false)
    }

    func testShotRequiresSelectionAndCannotResolveTwice() throws {
        let round = try makeRound(values: [1, 2])
        var session = SoccerSession(round: round)
        let intendedID = round.challengeTargets[0].intendedBallID

        session.resolveShot(outcome: .goal)

        XCTAssertNil(session.gameOutcome)

        session.selectBall(intendedID)
        session.resolveShot(outcome: .miss)
        session.resolveShot(outcome: .goal)

        XCTAssertEqual(session.gameOutcome, .miss)
        XCTAssertEqual(session.childScore, 0)
        XCTAssertEqual(session.keeperScore, 0)
    }

    func testScoringRules() throws {
        let cases: [(Bool, GameOutcome, Int, Int)] = [
            (true, .goal, 1, 0),
            (true, .miss, 0, 0),
            (true, .saved, 0, 0),
            (false, .goal, 0, 0),
            (false, .miss, 0, 1),
            (false, .saved, 0, 1)
        ]

        for (isCorrect, outcome, childScore, keeperScore) in cases {
            let session = try resolvedSession(isCorrect: isCorrect, outcome: outcome)
            XCTAssertEqual(session.childScore, childScore)
            XCTAssertEqual(session.keeperScore, keeperScore)
        }
    }

    func testEducationalCorrectnessDoesNotChangeWhenShotResolves() throws {
        let round = try makeRound(values: [1, 2])
        var session = SoccerSession(round: round)
        let intendedID = round.challengeTargets[0].intendedBallID
        session.selectBall(intendedID)

        session.resolveShot(outcome: .saved)

        XCTAssertEqual(session.educationalIsCorrect, true)
        XCTAssertEqual(session.gameOutcome, .saved)
    }

    func testNextRequiresShotThenAdvancesClearsAttemptAndPreservesScore() throws {
        let round = try makeRound(values: [1, 2])
        var session = SoccerSession(round: round)
        let intendedID = round.challengeTargets[0].intendedBallID
        session.selectBall(intendedID)

        session.nextTarget()

        XCTAssertEqual(session.currentTargetIndex, 0)

        session.resolveShot(outcome: .goal)
        session.nextTarget()

        XCTAssertEqual(session.currentTargetIndex, 1)
        XCTAssertNil(session.selectedBallID)
        XCTAssertNil(session.educationalIsCorrect)
        XCTAssertNil(session.gameOutcome)
        XCTAssertEqual(session.childScore, 1)
        XCTAssertEqual(session.keeperScore, 0)
    }

    func testFinalNextCompletesAndPostCompletionActionsAreSafe() throws {
        let round = try makeRound(values: [1])
        var session = SoccerSession(round: round)
        let ballID = round.answerBalls[0].id
        session.selectBall(ballID)
        session.resolveShot(outcome: .goal)
        session.nextTarget()
        let childScore = session.childScore

        session.selectBall(ballID)
        session.resolveShot(outcome: .goal)
        session.nextTarget()

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.currentTargetIndex, 0)
        XCTAssertEqual(session.childScore, childScore)
        XCTAssertEqual(session.keeperScore, 0)
    }

    func testOrderedKickPreparationDoesNotChangeAnswerChoiceFlow() throws {
        let round = try makeRound(values: [1, 2])
        var session = SoccerSession(round: round)
        let intendedID = round.challengeTargets[0].intendedBallID
        session.selectBall(intendedID)
        session.resolveShot(outcome: .goal)

        session.prepareNextKick()

        XCTAssertEqual(session.currentTargetIndex, 0)
        XCTAssertEqual(session.selectedBallID, intendedID)
        XCTAssertEqual(session.educationalIsCorrect, true)
        XCTAssertEqual(session.gameOutcome, .goal)
        XCTAssertEqual(session.childScore, 1)

        session.nextTarget()

        XCTAssertEqual(session.currentTargetIndex, 1)
        XCTAssertNil(session.selectedBallID)
        XCTAssertNil(session.educationalIsCorrect)
        XCTAssertNil(session.gameOutcome)
        XCTAssertEqual(session.childScore, 1)
    }

    private func resolvedSession(
        isCorrect: Bool,
        outcome: GameOutcome
    ) throws -> SoccerSession {
        let round = try makeRound(values: [1, 2])
        let intendedID = round.challengeTargets[0].intendedBallID
        let selectedID: SoccerBallID
        if isCorrect {
            selectedID = intendedID
        } else {
            selectedID = try XCTUnwrap(round.answerBalls.first { $0.id != intendedID }?.id)
        }

        var session = SoccerSession(round: round)
        session.selectBall(selectedID)
        session.resolveShot(outcome: outcome)
        return session
    }

    private func makeRound(values: [Int]) throws -> SoccerRound {
        let difficulty = try XCTUnwrap(Difficulty(0.5))
        let balls = values.enumerated().map { index, value in
            SoccerAnswerBall(
                id: SoccerBallID(rawValue: "ball.\(index)"),
                representation: representation("Ball \(index)"),
                semanticValue: .integer(value)
            )
        }
        let targets = try balls.enumerated().map { index, ball in
            let prompt = try XCTUnwrap(Prompt(representations: [representation("Prompt \(index)")]))
            let challenge = Challenge(
                id: ChallengeID(rawValue: "challenge.\(index)"),
                prompt: prompt,
                choices: [],
                interaction: .singleChoice,
                validationRule: .numericEquivalence,
                expectedAnswer: .semanticValue(ball.semanticValue),
                primarySkill: SkillID(rawValue: "skill.soccer"),
                secondarySkills: [],
                curriculumStage: CurriculumStageID(rawValue: "stage.soccer"),
                difficulty: difficulty
            )
            return SoccerChallengeTarget(challenge: challenge, intendedBallID: ball.id)
        }

        return try XCTUnwrap(SoccerRound(
            id: SoccerRoundID(rawValue: "round.fixture"),
            answerBalls: balls,
            challengeTargets: targets
        ))
    }

    private func representation(_ text: String) -> Representation {
        .learningText(LearningTextRepresentation(
            text: text,
            language: nil,
            direction: nil
        ))
    }
}
