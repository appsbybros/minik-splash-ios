import XCTest
@testable import MinikPlus

final class MultipleChoiceSessionTests: XCTestCase {
    func testEmptyChallengeArrayCannotInitializeSession() {
        XCTAssertNil(MultipleChoiceSession(challenges: []))
    }

    func testSessionStartsOnFirstChallenge() throws {
        let challenges = try makeChallenges(count: 2)
        let session = try XCTUnwrap(MultipleChoiceSession(challenges: challenges))

        XCTAssertEqual(session.currentChallengeIndex, 0)
        XCTAssertEqual(session.currentChallenge, challenges[0])
        XCTAssertNil(session.selectedChoiceID)
        XCTAssertNil(session.answerResult)
        XCTAssertFalse(session.isComplete)
    }

    func testCorrectChoiceIsRecognized() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))
        let correctChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(2) })

        session.selectChoice(correctChoice.id)

        XCTAssertEqual(session.selectedChoiceID, correctChoice.id)
        XCTAssertEqual(session.answerResult, .correct)
    }

    func testWrongChoiceIsRecognized() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))
        let wrongChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(3) })

        session.selectChoice(wrongChoice.id)

        XCTAssertEqual(session.selectedChoiceID, wrongChoice.id)
        XCTAssertEqual(session.answerResult, .incorrect)
    }

    func testExactIdentityRecognizesMatchingContentItem() throws {
        let contentID = ContentItemID(rawValue: "language.alphabet.en.a")
        let challenge = try makeContentIdentityChallenge(expectedContentID: contentID)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))

        session.selectChoice(challenge.choices[0].id)

        XCTAssertEqual(session.answerResult, .correct)
    }

    func testExactIdentityRejectsDifferentContentItem() throws {
        let expectedID = ContentItemID(rawValue: "language.alphabet.en.a")
        let challenge = try makeContentIdentityChallenge(expectedContentID: expectedID)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))

        session.selectChoice(challenge.choices[1].id)

        XCTAssertEqual(session.answerResult, .incorrect)
    }

    func testQuestionCannotBeAnsweredTwice() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))
        let correctChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(2) })
        let wrongChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(3) })

        session.selectChoice(wrongChoice.id)
        session.selectChoice(correctChoice.id)

        XCTAssertEqual(session.selectedChoiceID, wrongChoice.id)
        XCTAssertEqual(session.answerResult, .incorrect)
    }

    func testCannotAdvanceBeforeAnswering() throws {
        let challenges = try makeChallenges(count: 2)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: challenges))

        session.nextChallenge()

        XCTAssertEqual(session.currentChallengeIndex, 0)
        XCTAssertEqual(session.currentChallenge, challenges[0])
        XCTAssertFalse(session.isComplete)
    }

    func testAdvancesAfterAnswerAndClearsQuestionState() throws {
        let challenges = try makeChallenges(count: 2)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: challenges))
        let choice = try XCTUnwrap(challenges[0].choices.first)
        session.selectChoice(choice.id)

        session.nextChallenge()

        XCTAssertEqual(session.currentChallengeIndex, 1)
        XCTAssertEqual(session.currentChallenge, challenges[1])
        XCTAssertNil(session.selectedChoiceID)
        XCTAssertNil(session.answerResult)
        XCTAssertFalse(session.isComplete)
    }

    func testFinalAnsweredChallengeCompletesWithoutMoving() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))
        let choice = try XCTUnwrap(challenge.choices.first)
        session.selectChoice(choice.id)

        session.nextChallenge()

        XCTAssertEqual(session.currentChallengeIndex, 0)
        XCTAssertEqual(session.currentChallenge, challenge)
        XCTAssertTrue(session.isComplete)
    }

    func testPostCompletionActionsAreSafe() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))
        let initialChoice = try XCTUnwrap(challenge.choices.first)
        let otherChoice = try XCTUnwrap(challenge.choices.last)
        session.selectChoice(initialChoice.id)
        session.nextChallenge()
        let result = session.answerResult

        session.selectChoice(otherChoice.id)
        session.nextChallenge()

        XCTAssertEqual(session.currentChallengeIndex, 0)
        XCTAssertEqual(session.selectedChoiceID, initialChoice.id)
        XCTAssertEqual(session.answerResult, result)
        XCTAssertTrue(session.isComplete)
    }

    func testDefaultManualPolicyRemainsSourceCompatible() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        let session = try XCTUnwrap(MultipleChoiceSession(challenges: [challenge]))

        XCTAssertEqual(session.progressionPolicy, .manual)
        XCTAssertFalse(session.canAdvanceManually)
        XCTAssertNil(session.pendingAction)
    }

    func testPracticePolicyWrongSelectionCanResetForRetry() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try makePracticeSession(challenges: [challenge])
        let wrongChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(3) })

        session.selectChoice(wrongChoice.id)

        XCTAssertEqual(session.selectedChoiceID, wrongChoice.id)
        XCTAssertEqual(session.answerResult, .incorrect)
        XCTAssertTrue(session.hasIncorrectAttempt)
        XCTAssertFalse(session.canSelectChoices)
        XCTAssertTrue(session.canAdvanceManually)
        XCTAssertEqual(
            session.pendingAction,
            .resetAfterIncorrect(challengeID: challenge.id)
        )

        session.resetTransientIncorrectAttempt(for: challenge.id)

        XCTAssertNil(session.selectedChoiceID)
        XCTAssertNil(session.answerResult)
        XCTAssertTrue(session.hasIncorrectAttempt)
        XCTAssertTrue(session.canSelectChoices)
        XCTAssertTrue(session.canAdvanceManually)
        XCTAssertNil(session.pendingAction)
    }

    func testPracticePolicyRetryCanSucceedOnSameChallenge() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try makePracticeSession(challenges: [challenge])
        let wrongChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(3) })
        let correctChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(2) })

        session.selectChoice(wrongChoice.id)
        session.resetTransientIncorrectAttempt(for: challenge.id)
        session.selectChoice(correctChoice.id)

        XCTAssertEqual(session.selectedChoiceID, correctChoice.id)
        XCTAssertEqual(session.answerResult, .correct)
        XCTAssertTrue(session.hasIncorrectAttempt)
        XCTAssertFalse(session.canAdvanceManually)
        XCTAssertEqual(
            session.pendingAction,
            .advanceAfterCorrect(challengeID: challenge.id)
        )
    }

    func testPracticePolicySkipAfterWrongAdvancesExactlyOnce() throws {
        let challenges = try makeChallenges(count: 2)
        var session = try makePracticeSession(challenges: challenges)
        let wrongChoice = try XCTUnwrap(challenges[0].choices.first { $0.semanticValue == .integer(2) })
        let firstChallengeID = challenges[0].id

        session.selectChoice(wrongChoice.id)
        session.resetTransientIncorrectAttempt(for: firstChallengeID)
        session.nextChallenge()
        session.nextChallenge()

        XCTAssertEqual(session.currentChallengeIndex, 1)
        XCTAssertEqual(session.currentChallenge, challenges[1])
        XCTAssertNil(session.selectedChoiceID)
        XCTAssertNil(session.answerResult)
        XCTAssertFalse(session.hasIncorrectAttempt)
        XCTAssertFalse(session.isComplete)
    }

    func testPracticePolicyFinalCorrectAnswerCanCompleteWithoutManualNext() throws {
        let challenge = try makeChallenge(id: "question.1", correctValue: 2)
        var session = try makePracticeSession(challenges: [challenge])
        let correctChoice = try XCTUnwrap(challenge.choices.first { $0.semanticValue == .integer(2) })

        session.selectChoice(correctChoice.id)
        let didComplete = session.advanceIfCurrentChallengeMatches(challenge.id)

        XCTAssertTrue(didComplete)
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.answerResult, .correct)
    }

    func testPracticePolicyIgnoresStaleResetAndDuplicateAdvanceCalls() throws {
        let challenges = try makeChallenges(count: 2)
        var session = try makePracticeSession(challenges: challenges)
        let wrongChoice = try XCTUnwrap(challenges[0].choices.first { $0.semanticValue == .integer(2) })
        let correctChoice = try XCTUnwrap(challenges[1].choices.first { $0.semanticValue == .integer(2) })
        let staleChallengeID = challenges[0].id
        let currentChallengeID = challenges[1].id

        session.selectChoice(wrongChoice.id)
        session.nextChallenge()
        session.resetTransientIncorrectAttempt(for: staleChallengeID)

        XCTAssertEqual(session.currentChallengeIndex, 1)
        XCTAssertNil(session.selectedChoiceID)
        XCTAssertNil(session.answerResult)

        session.selectChoice(correctChoice.id)
        let firstAdvance = session.advanceIfCurrentChallengeMatches(currentChallengeID)
        let duplicateAdvance = session.advanceIfCurrentChallengeMatches(currentChallengeID)

        XCTAssertTrue(firstAdvance)
        XCTAssertFalse(duplicateAdvance)
        XCTAssertTrue(session.isComplete)
    }

    private func makeChallenges(count: Int) throws -> [Challenge] {
        try (0 ..< count).map { index in
            try makeChallenge(id: "question.\(index)", correctValue: index + 1)
        }
    }

    private func makePracticeSession(challenges: [Challenge]) throws -> MultipleChoiceSession {
        try XCTUnwrap(
            MultipleChoiceSession(
                challenges: challenges,
                progressionPolicy: .retryUntilCorrect
            )
        )
    }

    private func makeChallenge(id: String, correctValue: Int) throws -> Challenge {
        let prompt = try XCTUnwrap(Prompt(representations: [
            .learningText(LearningTextRepresentation(
                text: "Prompt \(id)",
                language: nil,
                direction: nil
            ))
        ]))
        let difficulty = try XCTUnwrap(Difficulty(0.5))
        let choices = [correctValue, correctValue + 1].enumerated().map { index, value in
            Choice(
                id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                representation: .learningText(LearningTextRepresentation(
                    text: "Option \(index)",
                    language: nil,
                    direction: nil
                )),
                semanticValue: .integer(value)
            )
        }

        return Challenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            choices: choices,
            interaction: .singleChoice,
            validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.integer(correctValue)),
            primarySkill: SkillID(rawValue: "skill.example"),
            secondarySkills: [],
            curriculumStage: CurriculumStageID(rawValue: "stage.example"),
            difficulty: difficulty
        )
    }

    private func makeContentIdentityChallenge(
        expectedContentID: ContentItemID
    ) throws -> Challenge {
        let prompt = try XCTUnwrap(Prompt(representations: [
            .learningText(LearningTextRepresentation(
                text: "A a",
                language: .english,
                direction: .leftToRight
            ))
        ]))
        let difficulty = try XCTUnwrap(Difficulty(0.5))
        let otherContentID = ContentItemID(rawValue: "language.alphabet.en.b")
        let choices = [expectedContentID, otherContentID].enumerated().map { index, contentID in
            Choice(
                id: ChoiceID(rawValue: "identity.choice.\(index)"),
                representation: .learningText(LearningTextRepresentation(
                    text: "Word \(index)",
                    language: .english,
                    direction: .leftToRight
                )),
                semanticValue: .contentItem(contentID)
            )
        }

        return Challenge(
            id: ChallengeID(rawValue: "identity.challenge"),
            prompt: prompt,
            choices: choices,
            interaction: .singleChoice,
            validationRule: .exactIdentity,
            expectedAnswer: .semanticValue(.contentItem(expectedContentID)),
            primarySkill: LanguageSkillIDs.alphabetRecognition,
            secondarySkills: [],
            curriculumStage: LanguageCurriculumStageIDs.alphabet,
            difficulty: difficulty
        )
    }
}
