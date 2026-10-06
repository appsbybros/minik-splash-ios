import XCTest
@testable import MinikPlus

final class LanguageSoccerContentProviderTests: XCTestCase {
    func testRealEnglishAndHebrewContentCreatesValidOrderedTokenRounds() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let round = try XCTUnwrap(provider().round(
                for: request(),
                learnedLanguage: language
            ))
            let content = try orderedContent(in: round)

            XCTAssertFalse(content.contentItemID.rawValue.isEmpty)
            XCTAssertFalse(content.targetText.text.isEmpty)
            XCTAssertFalse(content.expectedTokenSequence.isEmpty)
            XCTAssertEqual(
                content.expectedTokenSequence.map(\.text).joined(),
                content.targetText.text.filter { !$0.isWhitespace }
            )
            XCTAssertNotNil(content.image)
            XCTAssertEqual(round.answerBalls.count, content.expectedTokenSequence.count)
            XCTAssertEqual(Set(round.answerBalls.map(\.id)).count, round.answerBalls.count)
            XCTAssertTrue(round.answerBalls.allSatisfy {
                $0.semanticValue == .contentItem(content.contentItemID)
            })
            XCTAssertTrue(round.answerBalls.allSatisfy { ball in
                guard case .learningText(let representation) = ball.representation else {
                    return false
                }
                return !representation.text.isEmpty
                    && ball.orderedTokenDisplayText == representation.text
            })
        }
    }

    func testExpectedTokensReconstructLearnedWordWithoutWhitespace() throws {
        let item = try item(where: { item in
            LanguageWordContentProvider.learnedText(
                for: item,
                language: .english
            )?.text.contains(where: { $0.isWhitespace }) == true
        })
        let round = try makeRound(language: .english, item: item)
        let content = try orderedContent(in: round)

        XCTAssertEqual(
            content.expectedTokenSequence.map(\.text).joined(),
            content.targetText.text.filter { !$0.isWhitespace }
        )
        XCTAssertTrue(content.expectedTokenSequence.allSatisfy {
            !$0.text.contains(where: { $0.isWhitespace })
        })
    }

    func testCorrectNextTokenAdvancesConsumesAndBuildsEvenWhenShotIsSaved() throws {
        var session = SoccerSession(round: try makePlayableRound())
        let ball = try correctBall(in: session)

        session.selectBall(ball.id)
        session.resolveShot(outcome: .saved)

        XCTAssertEqual(session.educationalIsCorrect, true)
        XCTAssertEqual(session.currentTargetIndex, 1)
        XCTAssertEqual(session.builtTokens, [try XCTUnwrap(ball.orderedToken)])
        XCTAssertTrue(session.consumedBallIDs.contains(ball.id))
        XCTAssertFalse(session.availableBalls.contains(where: { $0.id == ball.id }))
        XCTAssertEqual(session.childScore, 0)
        XCTAssertEqual(session.keeperScore, 0)
    }

    func testWrongTokenDoesNotAdvanceOrConsumeAndRemainsAvailableAfterGoal() throws {
        var session = SoccerSession(round: try makePlayableRound())
        let ball = try wrongBall(in: session)

        session.selectBall(ball.id)
        session.resolveShot(outcome: .goal)

        XCTAssertEqual(session.educationalIsCorrect, false)
        XCTAssertEqual(session.currentTargetIndex, 0)
        XCTAssertTrue(session.builtTokens.isEmpty)
        XCTAssertFalse(session.consumedBallIDs.contains(ball.id))
        XCTAssertEqual(session.childScore, 0)
        XCTAssertEqual(session.keeperScore, 0)

        session.prepareNextKick()

        XCTAssertNil(session.selectedBallID)
        XCTAssertTrue(session.availableBalls.contains(where: { $0.id == ball.id }))
    }

    func testCancellingUnresolvedShotDoesNotScoreAdvanceOrConsume() throws {
        var session = SoccerSession(round: try makePlayableRound())
        let ball = try correctBall(in: session)

        session.selectBall(ball.id)
        session.cancelUnresolvedShot()

        XCTAssertNil(session.selectedBallID)
        XCTAssertNil(session.educationalIsCorrect)
        XCTAssertNil(session.gameOutcome)
        XCTAssertEqual(session.currentTargetIndex, 0)
        XCTAssertEqual(session.childScore, 0)
        XCTAssertEqual(session.keeperScore, 0)
        XCTAssertTrue(session.consumedBallIDs.isEmpty)
    }

    func testOrderedTokenScoreMatrixMatchesAndroid() throws {
        let cases: [(Bool, GameOutcome, Int, Int)] = [
            (true, .goal, 1, 0),
            (true, .miss, 0, 0),
            (true, .saved, 0, 0),
            (false, .goal, 0, 0),
            (false, .miss, 0, 1),
            (false, .saved, 0, 1)
        ]

        for (isCorrect, outcome, childScore, keeperScore) in cases {
            var session = SoccerSession(round: try makePlayableRound())
            let ball = try (isCorrect ? correctBall(in: session) : wrongBall(in: session))
            session.selectBall(ball.id)
            session.resolveShot(outcome: outcome)

            XCTAssertEqual(session.childScore, childScore, "correct=\(isCorrect), outcome=\(outcome)")
            XCTAssertEqual(session.keeperScore, keeperScore, "correct=\(isCorrect), outcome=\(outcome)")
            XCTAssertEqual(session.currentTargetIndex, isCorrect ? 1 : 0)
        }
    }

    func testDuplicateLettersUseDistinctIDsAndEquivalentInstanceCanSatisfyNextToken() throws {
        let item = try itemWithDuplicateCharacters(language: .english)
        let round = try makeRound(language: .english, item: item)
        let content = try orderedContent(in: round)
        let duplicateToken = try duplicateValue(in: content.expectedTokenSequence)
        let duplicateIndex = try XCTUnwrap(
            content.expectedTokenSequence.firstIndex(of: duplicateToken)
        )
        var session = SoccerSession(round: round)

        for expected in content.expectedTokenSequence.prefix(duplicateIndex) {
            let ball = try XCTUnwrap(session.availableBalls.first {
                $0.orderedToken == expected
            })
            session.selectBall(ball.id)
            session.resolveShot(outcome: .miss)
            session.prepareNextKick()
        }

        let equivalentBalls = session.availableBalls.filter {
            $0.orderedToken == duplicateToken
        }
        XCTAssertGreaterThanOrEqual(equivalentBalls.count, 2)
        XCTAssertEqual(Set(equivalentBalls.map(\.id)).count, equivalentBalls.count)

        let interchangeableBall = try XCTUnwrap(equivalentBalls.last)
        session.selectBall(interchangeableBall.id)
        session.resolveShot(outcome: .goal)

        XCTAssertEqual(session.educationalIsCorrect, true)
        XCTAssertEqual(session.currentTargetIndex, duplicateIndex + 1)
        XCTAssertTrue(session.consumedBallIDs.contains(interchangeableBall.id))
    }

    func testCompletionOccursOnlyAfterFinalExpectedToken() throws {
        let round = try makePlayableRound()
        let content = try orderedContent(in: round)
        var session = SoccerSession(round: round)

        for (index, expected) in content.expectedTokenSequence.enumerated() {
            let ball = try XCTUnwrap(session.availableBalls.first {
                $0.orderedToken == expected
            })
            session.selectBall(ball.id)
            session.resolveShot(outcome: index.isMultiple(of: 2) ? .goal : .saved)

            XCTAssertEqual(session.isComplete, index == content.expectedTokenSequence.count - 1)
            if !session.isComplete {
                session.prepareNextKick()
            }
        }

        XCTAssertEqual(session.builtTokens, content.expectedTokenSequence)
        XCTAssertEqual(session.currentTargetIndex, content.expectedTokenSequence.count)
    }

    func testLanguageDirectionAndPronunciationMetadataArePreserved() throws {
        let englishRound = try makeRound(
            language: .english,
            item: try item(where: { !$0.englishText.isEmpty })
        )
        let hebrewItem = try item(where: { $0.hebrewSpeechText != nil })
        let hebrewRound = try makeRound(language: .hebrew, item: hebrewItem)
        let english = try orderedContent(in: englishRound)
        let hebrew = try orderedContent(in: hebrewRound)

        XCTAssertEqual(english.targetText.language, .english)
        XCTAssertEqual(english.targetText.direction, .leftToRight)
        XCTAssertEqual(english.speechCue.language, .english)
        XCTAssertEqual(english.speechCue.text, english.targetText.text)

        XCTAssertEqual(hebrew.targetText.language, .hebrew)
        XCTAssertEqual(hebrew.targetText.direction, .rightToLeft)
        XCTAssertEqual(hebrew.targetText.speechText, hebrewItem.hebrewSpeechText)
        XCTAssertEqual(hebrew.speechCue.language, .hebrew)
        XCTAssertEqual(hebrew.speechCue.text, hebrewItem.hebrewSpeechText)
        XCTAssertTrue(hebrew.expectedTokenSequence.allSatisfy {
            $0.language == .hebrew && $0.direction == .rightToLeft
        })
    }

    func testBuiltDisplayTextRestoresWhitespaceWhenFollowingTokenIsAccepted() throws {
        let item = try item { $0.stableKey == "food_ice_cream" }
        let round = try makeRound(language: .english, item: item)
        let content = try orderedContent(in: round)
        var session = SoccerSession(round: round)

        XCTAssertEqual(content.targetText.text, "Ice cream")
        XCTAssertEqual(session.builtDisplayText, "")

        for expected in content.expectedTokenSequence.prefix(3) {
            try accept(expected, in: &session)
            session.prepareNextKick()
        }
        XCTAssertEqual(session.builtDisplayText, "Ice")

        try accept(content.expectedTokenSequence[3], in: &session)
        XCTAssertEqual(session.builtDisplayText, "Ice c")
        XCTAssertFalse(session.availableBalls.contains(where: {
            $0.orderedToken?.text.contains(where: { $0.isWhitespace }) == true
        }))
    }

    func testKickedLetterSpeechUsesLearnPronunciationIncludingHebrewFinalForms() throws {
        let finalForms = [
            "ך": "כ' סופית",
            "ם": "מ' סופית",
            "ן": "נ' סופית",
            "ף": "פ' סופית",
            "ץ": "צ' סופית"
        ]

        for (letter, pronunciation) in finalForms {
            XCTAssertEqual(
                LanguageLearnContentProvider.pronunciationText(
                    forLetter: letter,
                    language: .hebrew
                ),
                pronunciation
            )

            let item = try item { item in
                LanguageWordContentProvider.learnedText(
                    for: item,
                    language: .hebrew
                )?.text.contains(letter) == true
            }
            let round = try makeRound(language: .hebrew, item: item)
            var session = SoccerSession(round: round)
            let ball = try XCTUnwrap(session.availableBalls.first {
                $0.orderedToken?.text == letter
            })

            session.selectBall(ball.id)

            XCTAssertEqual(
                session.selectedOrderedTokenSpeechCue,
                LearningSpeechUtterance(text: pronunciation, language: .hebrew)
            )
        }
    }

    func testAutomaticPreparationClearsAttemptAndPreservesRetryRules() throws {
        var correctSession = SoccerSession(round: try makePlayableRound())
        let correct = try correctBall(in: correctSession)
        correctSession.selectBall(correct.id)
        correctSession.resolveShot(outcome: .saved)
        correctSession.prepareNextKick()

        XCTAssertNil(correctSession.selectedBallID)
        XCTAssertNil(correctSession.educationalIsCorrect)
        XCTAssertNil(correctSession.gameOutcome)
        XCTAssertEqual(correctSession.currentTargetIndex, 1)
        XCTAssertFalse(correctSession.availableBalls.contains(where: { $0.id == correct.id }))

        var wrongSession = SoccerSession(round: try makePlayableRound())
        let wrong = try wrongBall(in: wrongSession)
        wrongSession.selectBall(wrong.id)
        wrongSession.resolveShot(outcome: .saved)
        wrongSession.prepareNextKick()

        XCTAssertNil(wrongSession.selectedBallID)
        XCTAssertNil(wrongSession.educationalIsCorrect)
        XCTAssertNil(wrongSession.gameOutcome)
        XCTAssertEqual(wrongSession.currentTargetIndex, 0)
        XCTAssertTrue(wrongSession.availableBalls.contains(where: { $0.id == wrong.id }))
    }

    func testPracticeAdvancesToFreshRoundResetsScoreAndExposesNewSpeechCue() throws {
        let rounds = Array(provider().rounds(
            for: request(),
            learnedLanguage: .english
        ).prefix(3))
        var practice = try XCTUnwrap(LanguageSoccerPracticeSession(rounds: rounds))
        let firstContentID = practice.currentContentItemID

        XCTAssertFalse(practice.currentSpeechCue.text.isEmpty)
        XCTAssertEqual(
            practice.currentSpeechCue,
            practice.currentSession.orderedTokenContent?.speechCue
        )

        try completeCurrentRound(in: &practice)
        XCTAssertGreaterThan(practice.currentSession.childScore, 0)
        XCTAssertTrue(practice.advanceToNextRound())

        XCTAssertNotEqual(practice.currentContentItemID, firstContentID)
        XCTAssertFalse(practice.currentSpeechCue.text.isEmpty)
        XCTAssertEqual(
            practice.currentSpeechCue,
            practice.currentSession.orderedTokenContent?.speechCue
        )
        XCTAssertEqual(practice.currentSession.childScore, 0)
        XCTAssertEqual(practice.currentSession.keeperScore, 0)
        XCTAssertEqual(practice.roundNumber, 2)
        XCTAssertFalse(practice.currentSession.isComplete)
    }

    func testPracticeUsesEveryPoolItemThenContinuesWithoutImmediateRepeat() throws {
        let rounds = Array(provider().rounds(
            for: request(),
            learnedLanguage: .english
        ).prefix(3))
        var practice = try XCTUnwrap(LanguageSoccerPracticeSession(rounds: rounds))
        var contentIDs = [practice.currentContentItemID]

        var observedBoundary: LanguageSoccerPoolBoundary?
        for _ in 0 ..< practice.poolSize + 1 {
            try completeCurrentRound(in: &practice)
            XCTAssertTrue(practice.advanceToNextRound())
            if let boundary = practice.lastAdvanceBoundary {
                observedBoundary = boundary
            }
            contentIDs.append(practice.currentContentItemID)
        }

        XCTAssertEqual(Set(contentIDs.prefix(practice.poolSize)).count, practice.poolSize)
        for (previous, next) in zip(contentIDs, contentIDs.dropFirst()) {
            XCTAssertNotEqual(previous, next)
        }
        XCTAssertEqual(observedBoundary?.activity, .soccer)
        XCTAssertEqual(observedBoundary?.evaluatedLevel, .a)
        XCTAssertEqual(observedBoundary?.items.count, practice.poolSize)
    }

    func testProductPolicyAndFactoryAvailability() {
        let plus = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnly = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikMath)
        )

        XCTAssertNotNil(plus.makeSoccerSession(for: .english))
        XCTAssertNotNil(plus.makeSoccerSession(for: .hebrew))
        XCTAssertNotNil(englishOnly.makeSoccerSession(for: .english))
        XCTAssertNil(englishOnly.makeSoccerSession(for: .hebrew))
        XCTAssertNil(math.makeSoccerSession(for: .english))
    }

    func testSoccerIsPresentOnlyInProductionLanguageGamesSection() throws {
        let sections = ActivityCatalog.languageSections(
            for: .configuration(for: .minikPlus)
        )
        let games = try XCTUnwrap(sections.first { $0.id == "games" })

        XCTAssertTrue(games.activities.contains(.soccer))
        XCTAssertFalse(sections
            .filter { $0.id != "games" }
            .contains(where: { $0.activities.contains(.soccer) }))
    }

    private func provider(
        configuration: ProductConfiguration = .configuration(for: .minikPlus)
    ) -> LanguageSoccerContentProvider {
        LanguageSoccerContentProvider(configuration: configuration)
    }

    private func request() -> ChallengeRequest {
        ChallengeRequest(
            activityType: .soccer,
            curriculumStage: LanguageCurriculumStageIDs.wordsLevelA,
            primarySkill: LanguageSkillIDs.wordConstruction,
            difficulty: Difficulty(0.5)!,
            interaction: .orderedTokens,
            countRequirement: nil
        )
    }

    private func makeRound(
        language: LanguageIdentifier,
        item: LanguageWordCatalogItem
    ) throws -> SoccerRound {
        try XCTUnwrap(provider().round(
            for: request(),
            learnedLanguage: language,
            item: item
        ))
    }

    private func makePlayableRound() throws -> SoccerRound {
        let item = try item(where: { item in
            guard let text = LanguageWordContentProvider.learnedText(
                for: item,
                language: .english
            ) else {
                return false
            }
            let tokens = text.text.filter { !$0.isWhitespace }.map(String.init)
            return Set(tokens).count >= 2
        })
        return try makeRound(language: .english, item: item)
    }

    private func orderedContent(in round: SoccerRound) throws -> SoccerOrderedTokenContent {
        guard case .orderedTokens(let content) = round.mechanic else {
            throw TestError.expectedOrderedTokenRound
        }
        return content
    }

    private func correctBall(in session: SoccerSession) throws -> SoccerAnswerBall {
        try XCTUnwrap(session.availableBalls.first {
            $0.orderedToken == session.currentExpectedToken
        })
    }

    private func wrongBall(in session: SoccerSession) throws -> SoccerAnswerBall {
        try XCTUnwrap(session.availableBalls.first {
            $0.orderedToken != session.currentExpectedToken
        })
    }

    private func accept(
        _ expected: LearningTextRepresentation,
        in session: inout SoccerSession
    ) throws {
        let ball = try XCTUnwrap(session.availableBalls.first {
            $0.orderedToken == expected
        })
        session.selectBall(ball.id)
        session.resolveShot(outcome: .goal)
    }

    private func completeCurrentRound(
        in practice: inout LanguageSoccerPracticeSession
    ) throws {
        while !practice.currentSession.isComplete {
            let expected = try XCTUnwrap(practice.currentSession.currentExpectedToken)
            let ball = try XCTUnwrap(practice.currentSession.availableBalls.first {
                $0.orderedToken == expected
            })
            practice.selectBall(ball.id)
            practice.resolveShot(outcome: .goal)
            if !practice.currentSession.isComplete {
                practice.prepareNextKick()
            }
        }
    }

    private func item(
        where predicate: (LanguageWordCatalogItem) -> Bool
    ) throws -> LanguageWordCatalogItem {
        try XCTUnwrap(LanguageWordLevelContent.wordsLevelA.items.first(where: predicate))
    }

    private func itemWithDuplicateCharacters(
        language: LanguageIdentifier
    ) throws -> LanguageWordCatalogItem {
        try item { item in
            guard let text = LanguageWordContentProvider.learnedText(
                for: item,
                language: language
            ) else {
                return false
            }
            let tokens = text.text.filter { !$0.isWhitespace }.map(String.init)
            return Set(tokens).count < tokens.count
        }
    }

    private func duplicateValue(
        in tokens: [LearningTextRepresentation]
    ) throws -> LearningTextRepresentation {
        let groups = Dictionary(grouping: tokens, by: { $0 })
        return try XCTUnwrap(groups.first(where: { $0.value.count > 1 })?.key)
    }

    private enum TestError: Error {
        case expectedOrderedTokenRound
    }
}
