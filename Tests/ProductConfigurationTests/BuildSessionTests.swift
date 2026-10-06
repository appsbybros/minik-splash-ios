import XCTest
@testable import MinikPlus

final class BuildSessionTests: XCTestCase {
    func testEmptyInitializationFails() {
        XCTAssertNil(BuildSession(challenges: []))
    }

    func testSelectionPreservesOrderAndRejectsDuplicateTokenInstance() throws {
        let challenge = try makeChallenge(id: "build.1")
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        let first = challenge.availableTokens[0].id
        let second = challenge.availableTokens[1].id

        session.selectToken(second)
        session.selectToken(first)
        session.selectToken(second)

        XCTAssertEqual(session.selectedTokenIDs, [second, first])
    }

    func testUndoRemovesOnlyLastSelectedToken() throws {
        let challenge = try makeChallenge(id: "build.1")
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        let first = challenge.availableTokens[0].id
        let second = challenge.availableTokens[1].id
        session.selectToken(first)
        session.selectToken(second)

        session.undoLastToken()

        XCTAssertEqual(session.selectedTokenIDs, [first])
    }

    func testTokenPresentationOrderIsCompleteScrambledAndStablePerRound() throws {
        let firstChallenge = try makeChallenge(id: "build.1")
        let secondChallenge = try makeChallenge(id: "build.2")
        var session = try XCTUnwrap(BuildSession(challenges: [firstChallenge, secondChallenge]))
        let firstOrder = session.tokenPresentationOrder
        let firstAvailableIDs = firstChallenge.availableTokens.map(\.id)

        XCTAssertEqual(Set(firstOrder), Set(firstAvailableIDs))
        XCTAssertEqual(firstOrder.count, firstAvailableIDs.count)
        XCTAssertNotEqual(firstOrder, firstChallenge.expectedTokenSequence)

        session.selectToken(firstChallenge.expectedTokenSequence[0])
        session.undoLastToken()
        for tokenID in firstChallenge.expectedTokenSequence {
            session.selectToken(tokenID)
        }
        session.submit()

        XCTAssertEqual(session.tokenPresentationOrder, firstOrder)

        session.nextChallenge()

        let secondAvailableIDs = secondChallenge.availableTokens.map(\.id)
        XCTAssertEqual(Set(session.tokenPresentationOrder), Set(secondAvailableIDs))
        XCTAssertEqual(session.tokenPresentationOrder.count, secondAvailableIDs.count)
        XCTAssertNotEqual(session.tokenPresentationOrder, secondChallenge.expectedTokenSequence)
    }

    func testSubmitIsBlockedUntilRequiredTokenCountIsSelected() throws {
        let challenge = try makeChallenge(id: "build.1")
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        session.selectToken(challenge.availableTokens[0].id)

        session.submit()

        XCTAssertNil(session.answerResult)
    }

    func testCorrectAndWrongOrderedSequencesAreDetected() throws {
        let challenge = try makeChallenge(id: "build.1")
        var correctSession = try XCTUnwrap(BuildSession(challenges: [challenge]))
        var wrongSession = try XCTUnwrap(BuildSession(challenges: [challenge]))

        for tokenID in challenge.expectedTokenSequence {
            correctSession.selectToken(tokenID)
        }
        for tokenID in challenge.expectedTokenSequence.reversed() {
            wrongSession.selectToken(tokenID)
        }
        correctSession.submit()
        wrongSession.submit()

        XCTAssertEqual(correctSession.answerResult, .correct)
        XCTAssertEqual(wrongSession.answerResult, .incorrect)
    }

    func testEquivalentDuplicateTokenInstancesAreInterchangeable() throws {
        let firstP = token(id: "word.token.p1", text: "p")
        let secondP = token(id: "word.token.p2", text: "p")
        let tokens = [
            token(id: "word.token.a", text: "A"),
            firstP,
            secondP,
            token(id: "word.token.l", text: "l")
        ]
        let challenge = try makeChallenge(id: "word", tokens: tokens)
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        for tokenID in [tokens[0].id, secondP.id, firstP.id, tokens[3].id] {
            session.selectToken(tokenID)
        }
        session.submit()

        XCTAssertEqual(session.answerResult, .correct)
    }

    func testImmediatePrefixAcceptsCorrectNextVisibleRepresentation() throws {
        let challenge = try makeChallenge(
            id: "immediate.correct",
            validationMode: .immediatePrefix
        )
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        session.selectToken(challenge.expectedTokenSequence[0])

        XCTAssertEqual(session.selectedTokenIDs, [challenge.expectedTokenSequence[0]])
        XCTAssertEqual(session.lastSelectionResult, .correct)
        XCTAssertNil(session.answerResult)
    }

    func testImmediatePrefixAcceptsEquivalentDuplicatePhysicalToken() throws {
        let firstP = token(id: "immediate.token.p1", text: "P")
        let secondP = token(id: "immediate.token.p2", text: "P")
        let finalToken = token(id: "immediate.token.l", text: "L")
        let challenge = try makeChallenge(
            id: "immediate.duplicates",
            tokens: [firstP, secondP, finalToken],
            validationMode: .immediatePrefix
        )
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        session.selectToken(secondP.id)

        XCTAssertEqual(session.selectedTokenIDs, [secondP.id])
        XCTAssertEqual(session.lastSelectionResult, .correct)
    }

    func testImmediatePrefixWrongTokenIsNotConsumedAndProgressDoesNotAdvance() throws {
        let challenge = try makeChallenge(
            id: "immediate.wrong",
            validationMode: .immediatePrefix
        )
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        let wrongTokenID = challenge.expectedTokenSequence[1]

        session.selectToken(wrongTokenID)

        XCTAssertEqual(session.selectedTokenIDs, [])
        XCTAssertEqual(session.lastSelectionResult, .incorrect)
        XCTAssertNil(session.answerResult)

        session.selectToken(challenge.expectedTokenSequence[0])

        XCTAssertEqual(session.selectedTokenIDs, [challenge.expectedTokenSequence[0]])
        XCTAssertEqual(session.lastSelectionResult, .correct)
    }

    func testImmediatePrefixWrongSelectionAllowsExplicitNext() throws {
        let first = try makeChallenge(
            id: "immediate.skip.first",
            validationMode: .immediatePrefix
        )
        let second = try makeChallenge(
            id: "immediate.skip.second",
            validationMode: .immediatePrefix
        )
        var session = try XCTUnwrap(BuildSession(challenges: [first, second]))

        session.selectToken(first.expectedTokenSequence[1])
        session.nextChallenge()

        XCTAssertEqual(session.currentChallengeIndex, 1)
        XCTAssertEqual(session.selectedTokenIDs, [])
        XCTAssertNil(session.lastSelectionResult)
        XCTAssertNil(session.answerResult)
    }

    func testImmediatePrefixFinalCorrectTokenSucceedsWithoutSubmit() throws {
        let challenge = try makeChallenge(
            id: "immediate.complete",
            validationMode: .immediatePrefix
        )
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        challenge.expectedTokenSequence.forEach { session.selectToken($0) }

        XCTAssertEqual(session.answerResult, .correct)
        XCTAssertEqual(session.selectedTokenIDs.count, challenge.expectedTokenSequence.count)
    }

    func testLanguageBuiltDisplayRestoresWhitespaceWithoutDraggableSpaceTokens() throws {
        let target = LearningTextRepresentation(
            text: "ICE CREAM",
            language: .english,
            direction: .leftToRight
        )
        let tokens = target.text.filter { !$0.isWhitespace }.enumerated().map { index, character in
            BuildToken(
                id: BuildTokenID(rawValue: "ice-cream.token.\(index)"),
                representation: .learningText(LearningTextRepresentation(
                    text: String(character),
                    language: target.language,
                    direction: target.direction
                ))
            )
        }
        let content = try XCTUnwrap(LanguageWordBuildContent(
            contentItemID: ContentItemID(rawValue: "language.words.ice_cream"),
            targetText: target
        ))
        let challenge = try makeChallenge(
            id: "ice-cream",
            tokens: tokens,
            validationMode: .immediatePrefix,
            languageWordContent: content
        )
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        XCTAssertEqual(session.builtDisplayText, "")
        XCTAssertTrue(challenge.availableTokens.allSatisfy { token in
            guard case .learningText(let text) = token.representation else { return false }
            return !text.text.contains(where: { $0.isWhitespace })
        })

        challenge.expectedTokenSequence.prefix(3).forEach { session.selectToken($0) }
        XCTAssertEqual(session.builtDisplayText, "ICE")

        session.selectToken(challenge.expectedTokenSequence[3])
        XCTAssertEqual(session.builtDisplayText, "ICE C")
    }

    func testImmediatePrefixDoesNotAllowUndoOrSubmitControlsToChangeState() throws {
        let challenge = try makeChallenge(
            id: "immediate.controls",
            validationMode: .immediatePrefix
        )
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        session.selectToken(challenge.expectedTokenSequence[0])
        let selectedIDs = session.selectedTokenIDs

        session.undoLastToken()
        session.submit()

        XCTAssertEqual(session.selectedTokenIDs, selectedIDs)
        XCTAssertNil(session.answerResult)
    }

    func testDifferentRepresentationOrderRemainsIncorrect() throws {
        let tokens = [
            token(id: "word.token.a", text: "A"),
            token(id: "word.token.p", text: "p"),
            token(id: "word.token.l", text: "l")
        ]
        let challenge = try makeChallenge(id: "word", tokens: tokens)
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))

        for tokenID in [tokens[1].id, tokens[0].id, tokens[2].id] {
            session.selectToken(tokenID)
        }
        session.submit()

        XCTAssertEqual(session.answerResult, .incorrect)
    }

    func testPresentationIsNotVisiblySolvedWhenDifferentRepresentationsExist() throws {
        let firstP = token(id: "word.token.p1", text: "p")
        let secondP = token(id: "word.token.p2", text: "p")
        let tokens = [
            token(id: "word.token.a", text: "A"),
            firstP,
            secondP,
            token(id: "word.token.l", text: "l")
        ]
        let challenge = try makeChallenge(id: "word", tokens: tokens)
        let session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        let tokensByID = Dictionary(uniqueKeysWithValues: tokens.map { ($0.id, $0) })
        let presented = session.tokenPresentationOrder.compactMap {
            tokensByID[$0]?.representation
        }
        let expected = challenge.expectedTokenSequence.compactMap {
            tokensByID[$0]?.representation
        }

        XCTAssertEqual(Set(session.tokenPresentationOrder), Set(tokens.map(\.id)))
        XCTAssertNotEqual(presented, expected)
    }

    func testAnswerLocksEditingAndNextAdvancesWithClearedState() throws {
        let firstChallenge = try makeChallenge(id: "build.1")
        let secondChallenge = try makeChallenge(id: "build.2")
        let challenges = [firstChallenge, secondChallenge]
        var session = try XCTUnwrap(BuildSession(challenges: challenges))
        for tokenID in challenges[0].expectedTokenSequence {
            session.selectToken(tokenID)
        }
        session.submit()
        let submittedIDs = session.selectedTokenIDs

        session.undoLastToken()
        session.selectToken(challenges[0].availableTokens[0].id)

        XCTAssertEqual(session.selectedTokenIDs, submittedIDs)
        XCTAssertEqual(session.answerResult, .correct)

        session.nextChallenge()

        XCTAssertEqual(session.currentChallengeIndex, 1)
        XCTAssertEqual(session.currentChallenge, challenges[1])
        XCTAssertEqual(session.selectedTokenIDs, [])
        XCTAssertNil(session.answerResult)
    }

    func testFinalNextCompletesAndPostCompletionActionsAreSafe() throws {
        let challenge = try makeChallenge(id: "build.1")
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        for tokenID in challenge.expectedTokenSequence {
            session.selectToken(tokenID)
        }
        session.submit()
        session.nextChallenge()
        let submittedIDs = session.selectedTokenIDs
        let result = session.answerResult

        session.undoLastToken()
        session.selectToken(challenge.availableTokens[0].id)
        session.submit()
        session.nextChallenge()

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.currentChallengeIndex, 0)
        XCTAssertEqual(session.selectedTokenIDs, submittedIDs)
        XCTAssertEqual(session.answerResult, result)
    }

    private func makeChallenge(
        id: String,
        validationMode: BuildValidationMode = .submitSequence
    ) throws -> BuildChallenge {
        let first = token(id: "\(id).token.1", text: "A")
        let second = token(id: "\(id).token.2", text: "B")
        let prompt = try XCTUnwrap(Prompt(representations: [representation("Prompt")]))
        let difficulty = try XCTUnwrap(Difficulty(0.5))

        return try XCTUnwrap(BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: [first, second],
            expectedTokenSequence: [first.id, second.id],
            primarySkill: SkillID(rawValue: "skill.build"),
            curriculumStage: CurriculumStageID(rawValue: "stage.build"),
            difficulty: difficulty,
            validationMode: validationMode
        ))
    }

    private func makeChallenge(
        id: String,
        tokens: [BuildToken],
        validationMode: BuildValidationMode = .submitSequence,
        languageWordContent: LanguageWordBuildContent? = nil
    ) throws -> BuildChallenge {
        let prompt = try XCTUnwrap(Prompt(representations: [representation("Prompt")]))
        let difficulty = try XCTUnwrap(Difficulty(0.5))

        return try XCTUnwrap(BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: tokens,
            expectedTokenSequence: tokens.map(\.id),
            primarySkill: SkillID(rawValue: "skill.build"),
            curriculumStage: CurriculumStageID(rawValue: "stage.build"),
            difficulty: difficulty,
            validationMode: validationMode,
            languageWordContent: languageWordContent
        ))
    }

    private func token(id: String, text: String) -> BuildToken {
        BuildToken(
            id: BuildTokenID(rawValue: id),
            representation: representation(text)
        )
    }

    private func representation(_ text: String) -> Representation {
        .learningText(LearningTextRepresentation(
            text: text,
            language: nil,
            direction: nil
        ))
    }
}
