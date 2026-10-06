import XCTest
@testable import MinikPlus

final class ContentContractsTests: XCTestCase {
    private let skill = SkillID(rawValue: "numbers.compare")
    private let stage = CurriculumStageID(rawValue: "M2")

    func testStudyCardRequiresAtLeastOneRepresentation() throws {
        XCTAssertNil(StudyCard(
            id: StudyCardID(rawValue: "study.empty"),
            representations: [],
            primarySkill: skill,
            curriculumStage: stage
        ))

        XCTAssertNotNil(StudyCard(
            id: StudyCardID(rawValue: "study.horse"),
            representations: [.imageAsset(AssetReference(rawValue: "horse"))],
            primarySkill: skill,
            curriculumStage: stage
        ))
    }

    func testStudyCardIsStudyContentWithoutValidationOrExpectedAnswer() throws {
        let card = try XCTUnwrap(StudyCard(
            id: StudyCardID(rawValue: "study.horse"),
            representations: [.imageAsset(AssetReference(rawValue: "horse"))],
            primarySkill: skill,
            curriculumStage: stage
        ))

        XCTAssertEqual(card.representations.count, 1)
    }

    func testEquivalenceSetRejectsFewerThanTwoRepresentations() {
        XCTAssertNil(EquivalenceSet(
            semanticValue: .integer(1),
            representations: [.imageAsset(AssetReference(rawValue: "one-dot"))]
        ))
    }

    func testEquivalenceSetAcceptsIdenticalPresentationInstances() throws {
        let semanticValue = SemanticValue.contentItem(
            ContentItemID(rawValue: "fruit.apple")
        )
        let image = Representation.imageAsset(AssetReference(rawValue: "apple"))
        let set = try XCTUnwrap(EquivalenceSet(
            semanticValue: semanticValue,
            representations: [image, image]
        ))

        XCTAssertEqual(set.semanticValue, semanticValue)
        XCTAssertEqual(set.representations, [image, image])
    }

    func testEquivalenceSetRepresentsOneHalfInSeveralForms() throws {
        let oneHalf = try XCTUnwrap(Rational(numerator: 1, denominator: 2))
        let representations: [Representation] = [
            mathExpression("1/2", structure: "fraction.one-half"),
            mathExpression("0.5", structure: "decimal.one-half"),
            mathExpression("50%", structure: "percent.one-half")
        ]
        let set = try XCTUnwrap(EquivalenceSet(
            semanticValue: .rational(oneHalf),
            representations: representations
        ))

        XCTAssertEqual(set.semanticValue, .rational(oneHalf))
        XCTAssertEqual(set.representations, representations)
    }

    func testComparableItemCarriesExactValueWithoutParsingRepresentation() throws {
        let sevenHalves = try XCTUnwrap(Rational(numerator: 7, denominator: 2))
        let item = ComparableItem(
            id: ComparableItemID(rawValue: "seven-halves"),
            representation: mathExpression("3 + 1/2", structure: "mixed-number.seven-halves"),
            comparisonValue: .rational(sevenHalves)
        )
        let set = try XCTUnwrap(ComparableSet(items: [item]))

        XCTAssertEqual(set.items.first?.comparisonValue, .rational(sevenHalves))
    }

    func testBuildChallengeUsesRepresentedTokensWithStableIDs() throws {
        let token = BuildToken(
            id: BuildTokenID(rawValue: "token.h"),
            representation: learningText("H")
        )
        let challenge = try makeBuildChallenge(tokens: [token], expected: [token.id])

        XCTAssertEqual(challenge.availableTokens.first?.id, BuildTokenID(rawValue: "token.h"))
        XCTAssertEqual(challenge.availableTokens.first?.representation, learningText("H"))
    }

    func testBuildChallengePreservesExpectedTokenOrder() throws {
        let seven = BuildToken(id: BuildTokenID(rawValue: "token.7"), representation: learningText("7"))
        let plus = BuildToken(id: BuildTokenID(rawValue: "token.plus"), representation: learningText("+"))
        let five = BuildToken(id: BuildTokenID(rawValue: "token.5"), representation: learningText("5"))
        let expected = [seven.id, plus.id, five.id]
        let challenge = try makeBuildChallenge(tokens: [five, seven, plus], expected: expected)

        XCTAssertEqual(challenge.expectedTokenSequence, expected)
    }

    func testBuildChallengeDefaultsToSubmitSequenceValidation() throws {
        let token = BuildToken(
            id: BuildTokenID(rawValue: "token.default"),
            representation: learningText("A")
        )
        let challenge = try makeBuildChallenge(tokens: [token], expected: [token.id])

        XCTAssertEqual(challenge.validationMode, .submitSequence)
    }

    func testBuildChallengeCanUseImmediatePrefixValidation() throws {
        let token = BuildToken(
            id: BuildTokenID(rawValue: "token.immediate"),
            representation: learningText("A")
        )
        let challenge = try makeBuildChallenge(
            tokens: [token],
            expected: [token.id],
            validationMode: .immediatePrefix
        )

        XCTAssertEqual(challenge.validationMode, .immediatePrefix)
    }

    func testBuildChallengeRejectsRepeatedTokenInstanceID() throws {
        let token = BuildToken(
            id: BuildTokenID(rawValue: "token.p1"),
            representation: learningText("P")
        )
        let prompt = try XCTUnwrap(Prompt(representations: [
            mathExpression("P P", structure: "letters.double-p")
        ]))
        let difficulty = try XCTUnwrap(Difficulty(0.4))

        XCTAssertNil(BuildChallenge(
            id: ChallengeID(rawValue: "build.repeated-token"),
            prompt: prompt,
            availableTokens: [token],
            expectedTokenSequence: [token.id, token.id],
            primarySkill: skill,
            curriculumStage: stage,
            difficulty: difficulty
        ))
    }

    func testBuildChallengeAcceptsDistinctTokenIDsWithSameRepresentation() throws {
        let first = BuildToken(
            id: BuildTokenID(rawValue: "token.p1"),
            representation: learningText("P")
        )
        let second = BuildToken(
            id: BuildTokenID(rawValue: "token.p2"),
            representation: learningText("P")
        )
        let challenge = try makeBuildChallenge(
            tokens: [first, second],
            expected: [first.id, second.id]
        )

        XCTAssertEqual(first.representation, second.representation)
        XCTAssertEqual(challenge.expectedTokenSequence, [first.id, second.id])
    }

    func testSoccerRoundRejectsTargetForMissingBall() throws {
        let challenge = try makeChallenge(id: "soccer.question.1", expectedValue: 13)
        let target = SoccerChallengeTarget(
            challenge: challenge,
            intendedBallID: SoccerBallID(rawValue: "ball.missing")
        )

        XCTAssertNil(SoccerRound(
            id: SoccerRoundID(rawValue: "round.invalid"),
            answerBalls: [answerBall(id: "ball.13", value: 13)],
            challengeTargets: [target]
        ))
    }

    func testSoccerRoundSupportsDistinctBallsAndSequentialChallenges() throws {
        let firstChallenge = try makeChallenge(id: "soccer.question.1", expectedValue: 13)
        let secondChallenge = try makeChallenge(id: "soccer.question.2", expectedValue: 14)
        let firstBall = answerBall(id: "ball.13", value: 13)
        let secondBall = answerBall(id: "ball.14", value: 14)
        let targets = [
            SoccerChallengeTarget(challenge: firstChallenge, intendedBallID: firstBall.id),
            SoccerChallengeTarget(challenge: secondChallenge, intendedBallID: secondBall.id)
        ]
        let round = try XCTUnwrap(SoccerRound(
            id: SoccerRoundID(rawValue: "round.valid"),
            answerBalls: [firstBall, secondBall],
            challengeTargets: targets
        ))

        XCTAssertEqual(round.answerBalls.count, 2)
        XCTAssertEqual(round.challengeTargets.map(\.challenge.id), [firstChallenge.id, secondChallenge.id])
        XCTAssertEqual(round.challengeTargets.map(\.intendedBallID), [firstBall.id, secondBall.id])
    }

    func testSoccerRoundRejectsDuplicateBallSemanticValues() throws {
        let firstBall = answerBall(id: "ball.13.first", value: 13)
        let secondBall = answerBall(id: "ball.13.second", value: 13)
        let firstChallenge = try makeChallenge(id: "soccer.question.1", expectedValue: 13)
        let secondChallenge = try makeChallenge(id: "soccer.question.2", expectedValue: 13)

        XCTAssertNil(SoccerRound(
            id: SoccerRoundID(rawValue: "round.duplicate-values"),
            answerBalls: [firstBall, secondBall],
            challengeTargets: [
                SoccerChallengeTarget(challenge: firstChallenge, intendedBallID: firstBall.id),
                SoccerChallengeTarget(challenge: secondChallenge, intendedBallID: secondBall.id)
            ]
        ))
    }

    func testSoccerRoundRejectsRepeatedTargetAndUntargetedBall() throws {
        let firstBall = answerBall(id: "ball.13", value: 13)
        let secondBall = answerBall(id: "ball.14", value: 14)
        let firstChallenge = try makeChallenge(id: "soccer.question.1", expectedValue: 13)
        let secondChallenge = try makeChallenge(id: "soccer.question.2", expectedValue: 13)

        XCTAssertNil(SoccerRound(
            id: SoccerRoundID(rawValue: "round.repeated-target"),
            answerBalls: [firstBall, secondBall],
            challengeTargets: [
                SoccerChallengeTarget(challenge: firstChallenge, intendedBallID: firstBall.id),
                SoccerChallengeTarget(challenge: secondChallenge, intendedBallID: firstBall.id)
            ]
        ))
    }

    func testSoccerRoundRejectsSemanticMismatchWithIntendedBall() throws {
        let ball = answerBall(id: "ball.14", value: 14)
        let challenge = try makeChallenge(id: "soccer.question.1", expectedValue: 13)

        XCTAssertNil(SoccerRound(
            id: SoccerRoundID(rawValue: "round.semantic-mismatch"),
            answerBalls: [ball],
            challengeTargets: [
                SoccerChallengeTarget(challenge: challenge, intendedBallID: ball.id)
            ]
        ))
    }

    func testSoccerAnswerBallCarriesRepresentationAndSemanticValue() {
        let ball = answerBall(id: "ball.13", value: 13)

        XCTAssertEqual(ball.representation, mathExpression("13", structure: "integer.13"))
        XCTAssertEqual(ball.semanticValue, .integer(13))
    }

    func testGameOutcomeIsIndependentFromEducationalCorrectness() throws {
        let attempt = try makeAttempt(isCorrect: true)
        let outcome = GameOutcome.saved

        XCTAssertTrue(attempt.isCorrect)
        XCTAssertEqual(outcome, .saved)
    }

    func testAttemptResultRecordsLearningFieldsWithoutGameOutcome() throws {
        let difficulty = try XCTUnwrap(Difficulty(0.6))
        let attempt = try XCTUnwrap(AttemptResult(
            challengeID: ChallengeID(rawValue: "attempt.challenge"),
            activityType: .soccer,
            primarySkill: skill,
            curriculumStage: stage,
            difficulty: difficulty,
            isCorrect: false,
            attemptNumber: 2,
            responseDuration: .seconds(3)
        ))

        XCTAssertEqual(attempt.primarySkill, skill)
        XCTAssertEqual(attempt.curriculumStage, stage)
        XCTAssertEqual(attempt.difficulty, difficulty)
        XCTAssertFalse(attempt.isCorrect)
    }

    func testActivityTypeAndInteractionAreDistinctConcepts() {
        let activity: ActivityType = .multipleChoice
        let interaction: Interaction = .singleChoice

        XCTAssertEqual(activity.rawValue, "multipleChoice")
        XCTAssertEqual(interaction.rawValue, "singleChoice")
    }

    func testChallengeRequestExpressesSingleChoiceRequest() throws {
        let difficulty = try XCTUnwrap(Difficulty(0.3))
        let choiceCount = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 4))
        let request = ChallengeRequest(
            activityType: .multipleChoice,
            curriculumStage: stage,
            primarySkill: skill,
            difficulty: difficulty,
            interaction: .singleChoice,
            countRequirement: choiceCount
        )

        XCTAssertEqual(request.interaction, .singleChoice)
        XCTAssertEqual(request.countRequirement, choiceCount)
    }

    func testChallengeRequestExpressesGenericItemCount() throws {
        let difficulty = try XCTUnwrap(Difficulty(0.5))
        let itemCount = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 6))
        let request = ChallengeRequest(
            activityType: .soccer,
            curriculumStage: stage,
            primarySkill: skill,
            difficulty: difficulty,
            interaction: .singleChoice,
            countRequirement: itemCount
        )

        XCTAssertEqual(request.countRequirement?.kind, .items)
        XCTAssertEqual(request.countRequirement?.count, 6)
    }

    func testStudyOnlyProviderDoesNotRequireChallengeCapability() throws {
        let difficulty = try XCTUnwrap(Difficulty(0.2))
        let request = ChallengeRequest(
            activityType: .learn,
            curriculumStage: stage,
            primarySkill: skill,
            difficulty: difficulty,
            interaction: nil,
            countRequirement: nil
        )
        let provider: any StudyContentProviding = StudyOnlyProvider()

        XCTAssertEqual(provider.studyCards(for: request), [])
    }

    func testWordCardsFactoryReturnsNilForUnsupportedCategory() {
        let factory = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikPlus)
        )

        XCTAssertNil(factory.makeWordCardsSession(
            for: .english,
            categoryID: LanguageWordCategoryID(rawValue: "unsupported.test.category")
        ))
    }

    private func learningText(_ text: String) -> Representation {
        .learningText(LearningTextRepresentation(
            text: text,
            language: .english,
            direction: .leftToRight
        ))
    }

    private func mathExpression(_ expression: String, structure: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(
            expression: expression,
            structureID: RepresentationStructureID(rawValue: structure)
        ))
    }

    private func makeBuildChallenge(
        tokens: [BuildToken],
        expected: [BuildTokenID],
        validationMode: BuildValidationMode = .submitSequence
    ) throws -> BuildChallenge {
        let prompt = try XCTUnwrap(Prompt(representations: [
            mathExpression("7 + 5", structure: "addition.7-plus-5")
        ]))
        let difficulty = try XCTUnwrap(Difficulty(0.4))
        return try XCTUnwrap(BuildChallenge(
            id: ChallengeID(rawValue: "build.challenge"),
            prompt: prompt,
            availableTokens: tokens,
            expectedTokenSequence: expected,
            primarySkill: skill,
            curriculumStage: stage,
            difficulty: difficulty,
            validationMode: validationMode
        ))
    }

    private func makeChallenge(id: String, expectedValue: Int) throws -> Challenge {
        let prompt = try XCTUnwrap(Prompt(representations: [
            mathExpression("8 + 5", structure: "addition.8-plus-5")
        ]))
        let difficulty = try XCTUnwrap(Difficulty(0.4))
        return Challenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            choices: [],
            interaction: .numericInput,
            validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.integer(expectedValue)),
            primarySkill: skill,
            secondarySkills: [],
            curriculumStage: stage,
            difficulty: difficulty
        )
    }

    private func answerBall(id: String, value: Int) -> SoccerAnswerBall {
        SoccerAnswerBall(
            id: SoccerBallID(rawValue: id),
            representation: mathExpression("\(value)", structure: "integer.\(value)"),
            semanticValue: .integer(value)
        )
    }

    private func makeAttempt(isCorrect: Bool) throws -> AttemptResult {
        let difficulty = try XCTUnwrap(Difficulty(0.4))
        return try XCTUnwrap(AttemptResult(
            challengeID: ChallengeID(rawValue: "attempt.challenge"),
            activityType: .soccer,
            primarySkill: skill,
            curriculumStage: stage,
            difficulty: difficulty,
            isCorrect: isCorrect,
            attemptNumber: 1
        ))
    }

    private struct StudyOnlyProvider: StudyContentProviding {
        func studyCards(for request: ChallengeRequest) -> [StudyCard] {
            []
        }
    }
}
