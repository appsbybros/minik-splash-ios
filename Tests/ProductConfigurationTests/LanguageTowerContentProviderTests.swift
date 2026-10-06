import XCTest
@testable import MinikPlus

final class LanguageTowerContentProviderTests: XCTestCase {
    func testRealEnglishAndHebrewItemsCreateValidOrderedTokenRounds() throws {
        for language in [LanguageIdentifier.english, .hebrew] {
            let round = try XCTUnwrap(provider().round(
                for: request(),
                learnedLanguage: language
            ))
            let content = round.content
            let sourceItem = try XCTUnwrap(
                LanguageWordLevelContent.wordsLevelA.items.first {
                    $0.id == content.contentItemID
                }
            )

            XCTAssertFalse(content.contentItemID.rawValue.isEmpty)
            XCTAssertFalse(content.targetText.text.isEmpty)
            XCTAssertEqual(
                content.targetText.direction,
                language == .hebrew ? .rightToLeft : .leftToRight
            )
            XCTAssertEqual(
                content.expectedTokenSequence.map(\.text).joined(),
                content.targetText.text.filter { !$0.isWhitespace }
            )
            XCTAssertEqual(
                content.image,
                sourceItem.isImageReady ? sourceItem.imageAssetReference : nil
            )
            XCTAssertEqual(round.blocks.count, content.expectedTokenSequence.count)
            XCTAssertEqual(Set(round.blocks.map(\.id)).count, round.blocks.count)
            XCTAssertTrue(round.blocks.allSatisfy {
                $0.contentItemID == content.contentItemID
            })
        }
    }

    func testFirstLetterStartsAsLockedBaseLikeAndroid() throws {
        let round = try makePlayableRound()
        let session = try XCTUnwrap(TowerSession(orderedTokenRound: round))

        XCTAssertEqual(session.acceptedTokens, [round.content.expectedTokenSequence[0]])
        XCTAssertEqual(session.acceptedBlockIDs.count, 1)
        XCTAssertEqual(session.orderedProgressCount, 1)
        XCTAssertFalse(session.availableOrderedBlocks.contains {
            $0.id == session.acceptedBlockIDs[0]
        })
    }

    func testCorrectNextBlockAdvancesOnceConsumesAndProvidesSpeechCue() throws {
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: makePlayableRound()))
        let expected = try XCTUnwrap(session.currentExpectedToken)
        let block = try XCTUnwrap(session.availableOrderedBlocks.first {
            $0.orderedToken == expected
        })
        let previousProgress = session.orderedProgressCount

        XCTAssertEqual(session.placeOrderedBlock(block.id), .correct)

        XCTAssertEqual(session.orderedProgressCount, previousProgress + 1)
        XCTAssertTrue(session.acceptedBlockIDs.contains(block.id))
        XCTAssertFalse(session.availableOrderedBlocks.contains { $0.id == block.id })
        XCTAssertEqual(session.lastAcceptedBlockSpeechCue?.text, expected.speechText ?? expected.text)
        XCTAssertEqual(session.lastAcceptedBlockSpeechCue?.language, expected.language)
    }

    func testWrongOrLaterBlockDoesNotAdvanceAndRemainsAvailable() throws {
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: makePlayableRound()))
        let wrong = try XCTUnwrap(session.availableOrderedBlocks.first {
            $0.orderedToken != session.currentExpectedToken
        })
        let previousProgress = session.orderedProgressCount

        XCTAssertEqual(session.placeOrderedBlock(wrong.id), .incorrect)
        XCTAssertEqual(session.orderedProgressCount, previousProgress)
        XCTAssertTrue(session.availableOrderedBlocks.contains { $0.id == wrong.id })

        session.clearOrderedPlacementFeedback()

        XCTAssertNil(session.answerResult)
        XCTAssertTrue(session.availableOrderedBlocks.contains { $0.id == wrong.id })
    }

    func testDuplicateLettersHaveDistinctIDsAndEquivalentBlockCanSatisfyExpectedValue() throws {
        let item = try itemWithDuplicateCharacters(language: .english)
        let round = try makeRound(language: .english, item: item)
        let duplicate = try duplicateValue(in: round.content.expectedTokenSequence)
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: round))
        let physicalDuplicates = round.blocks.filter {
            $0.orderedToken == duplicate
        }

        XCTAssertGreaterThanOrEqual(physicalDuplicates.count, 2)
        XCTAssertEqual(Set(physicalDuplicates.map(\.id)).count, physicalDuplicates.count)

        while session.currentExpectedToken != duplicate {
            try acceptNext(in: &session)
            session.clearOrderedPlacementFeedback()
        }

        let equivalentBlocks = session.availableOrderedBlocks.filter {
            $0.orderedToken == duplicate
        }
        let interchangeable = try XCTUnwrap(equivalentBlocks.last)
        XCTAssertEqual(session.placeOrderedBlock(interchangeable.id), .correct)
        XCTAssertTrue(session.acceptedBlockIDs.contains(interchangeable.id))
    }

    func testConsumingOneDuplicateLeavesTheOtherPhysicalCopyAvailable() throws {
        let item = try itemWithDuplicateCharactersAfterBase(language: .english)
        let round = try makeRound(language: .english, item: item)
        let duplicate = try duplicateValue(
            in: Array(round.content.expectedTokenSequence.dropFirst())
        )
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: round))

        while session.currentExpectedToken != duplicate {
            try acceptNext(in: &session)
            session.clearOrderedPlacementFeedback()
        }

        let copies = session.availableOrderedBlocks.filter {
            $0.orderedToken == duplicate
        }
        XCTAssertGreaterThanOrEqual(copies.count, 2)
        XCTAssertEqual(session.placeOrderedBlock(copies[0].id), .correct)
        XCTAssertFalse(session.availableOrderedBlocks.contains { $0.id == copies[0].id })
        XCTAssertTrue(session.availableOrderedBlocks.contains { $0.id == copies[1].id })
    }

    func testLockedBaseCannotBeConsumedAgain() throws {
        let round = try makePlayableRound()
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: round))
        let baseID = try XCTUnwrap(session.acceptedBlockIDs.first)
        let acceptedBefore = session.acceptedBlockIDs

        XCTAssertNil(session.placeOrderedBlock(baseID))
        XCTAssertEqual(session.acceptedBlockIDs, acceptedBefore)
        XCTAssertEqual(session.orderedProgressCount, 1)
    }

    func testAcceptedStackPreservesSemanticBottomUpOrder() throws {
        let round = try makePlayableRound()
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: round))

        try acceptNext(in: &session)
        session.clearOrderedPlacementFeedback()
        if !session.isComplete {
            try acceptNext(in: &session)
        }

        XCTAssertEqual(
            session.acceptedOrderedBlocks.map(\.orderedToken),
            Array(round.content.expectedTokenSequence.prefix(session.orderedProgressCount))
        )
    }

    func testCompletionOccursOnlyAfterFinalRequiredBlock() throws {
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: makePlayableRound()))

        while session.orderedProgressCount < session.orderedTargetCount - 1 {
            try acceptNext(in: &session)
            XCTAssertFalse(session.isComplete)
            session.clearOrderedPlacementFeedback()
        }

        try acceptNext(in: &session)

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(
            session.acceptedTokens,
            try XCTUnwrap(session.orderedTokenContent?.expectedTokenSequence)
        )
    }

    func testWhitespaceIsNotDraggableAndProgressiveDisplayPreservesIt() throws {
        let item = try item { $0.stableKey == "food_ice_cream" }
        let round = try makeRound(language: .english, item: item)
        var session = try XCTUnwrap(TowerSession(orderedTokenRound: round))

        XCTAssertEqual(round.content.contentItemID, item.id)
        XCTAssertEqual(round.content.targetText.text, "ICE CREAM")
        XCTAssertTrue(round.blocks.allSatisfy {
            !$0.orderedToken.text.contains(where: { $0.isWhitespace })
        })
        XCTAssertEqual(session.builtDisplayText, "I")

        try acceptNext(in: &session)
        session.clearOrderedPlacementFeedback()
        try acceptNext(in: &session)
        session.clearOrderedPlacementFeedback()
        XCTAssertEqual(session.builtDisplayText, "ICE ")

        try acceptNext(in: &session)
        XCTAssertEqual(session.builtDisplayText, "ICE C")
    }

    func testDirectionTargetSpeechAndHebrewFinalFormPronunciationArePreserved() throws {
        let finalForms = [
            "ך": "כ' סופית",
            "ם": "מ' סופית",
            "ן": "נ' סופית",
            "ף": "פ' סופית",
            "ץ": "צ' סופית"
        ]

        for (letter, pronunciation) in finalForms {
            let item = try item { item in
                guard let text = LanguageWordContentProvider.learnedText(
                    for: item,
                    language: .hebrew
                )?.text else {
                    return false
                }
                return text.contains(letter)
                    && (3 ... 10).contains(text.filter { !$0.isWhitespace }.count)
            }
            let round = try makeRound(language: .hebrew, item: item)
            let token = try XCTUnwrap(round.content.expectedTokenSequence.first {
                $0.text == letter
            })

            XCTAssertEqual(round.content.targetText.direction, .rightToLeft)
            XCTAssertEqual(round.content.speechCue.language, .hebrew)
            XCTAssertFalse(round.content.speechCue.text.isEmpty)
            XCTAssertEqual(token.speechText, pronunciation)
            XCTAssertEqual(
                token.speechText,
                LanguageLearnContentProvider.pronunciationText(
                    forLetter: letter,
                    language: .hebrew
                )
            )
        }
    }

    func testPracticeReplacesCompletedRoundResetsStateAndCyclesWithoutImmediateRepeat() throws {
        let rounds = Array(provider().rounds(
            for: request(),
            learnedLanguage: .english
        ).prefix(3))
        var practice = try XCTUnwrap(LanguageTowerPracticeSession(rounds: rounds))
        var contentIDs = [practice.currentContentItemID]

        for _ in 0 ..< practice.poolSize + 1 {
            try completeCurrentRound(in: &practice)
            XCTAssertTrue(practice.currentSession.isComplete)
            XCTAssertTrue(practice.advanceToNextRound())
            XCTAssertEqual(practice.currentSession.orderedProgressCount, 1)
            XCTAssertNil(practice.currentSession.answerResult)
            XCTAssertFalse(practice.currentSpeechCue.text.isEmpty)
            XCTAssertEqual(
                practice.currentSpeechCue,
                try XCTUnwrap(practice.currentSession.orderedTokenContent?.speechCue)
            )
            contentIDs.append(practice.currentContentItemID)
        }

        XCTAssertEqual(Set(contentIDs.prefix(practice.poolSize)).count, practice.poolSize)
        for (previous, next) in zip(contentIDs, contentIDs.dropFirst()) {
            XCTAssertNotEqual(previous, next)
        }
        XCTAssertEqual(practice.lastAdvanceBoundary?.activity, .tower)
        XCTAssertEqual(practice.lastAdvanceBoundary?.items.count, practice.poolSize)
    }

    func testCompletionEmitsExactlyOnceAndNextWordGetsFreshIdentity() throws {
        let rounds = Array(provider().rounds(
            for: request(),
            learnedLanguage: .english
        ).prefix(2))
        var practice = try XCTUnwrap(LanguageTowerPracticeSession(rounds: rounds))
        let firstPresentationID = practice.presentationID
        try completeCurrentRound(in: &practice)

        let completion = try XCTUnwrap(practice.takeCompletion())
        XCTAssertEqual(completion.id, firstPresentationID)
        XCTAssertEqual(completion.contentItemID, practice.currentContentItemID)
        XCTAssertNil(practice.takeCompletion())

        XCTAssertTrue(practice.advanceToNextRound(
            expectedPresentationID: firstPresentationID
        ))
        XCTAssertNotEqual(practice.presentationID, firstPresentationID)
        XCTAssertEqual(practice.currentSession.orderedProgressCount, 1)
        XCTAssertEqual(practice.currentSession.acceptedBlockIDs.count, 1)
        XCTAssertNil(practice.currentSession.answerResult)
        XCTAssertFalse(practice.currentSession.isComplete)
    }

    func testStaleTransitionCannotAdvanceALaterWord() throws {
        let rounds = Array(provider().rounds(
            for: request(),
            learnedLanguage: .english
        ).prefix(2))
        var practice = try XCTUnwrap(LanguageTowerPracticeSession(rounds: rounds))
        let stalePresentationID = practice.presentationID
        try completeCurrentRound(in: &practice)
        XCTAssertTrue(practice.advanceToNextRound(
            expectedPresentationID: stalePresentationID
        ))
        let currentPresentationID = practice.presentationID
        try completeCurrentRound(in: &practice)

        XCTAssertFalse(practice.advanceToNextRound(
            expectedPresentationID: stalePresentationID
        ))
        XCTAssertEqual(practice.presentationID, currentPresentationID)
        XCTAssertTrue(practice.currentSession.isComplete)
    }

    func testTowerCompletionRewardIsFixedTwoPointsAndIdempotent() throws {
        let suiteName = "LanguageTowerContentProviderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = LocalRewardRepository(
            userDefaults: defaults,
            storageKey: "tower.rewards"
        )
        let service = LocalRewardService(repository: repository)
        let event = try XCTUnwrap(ActivityEvent(
            sessionID: ActivitySessionID(),
            context: ActivityEventContext(
                product: .minikPlus,
                activityID: ProgressActivityID(rawValue: "language.tower"),
                skillID: LanguageSkillIDs.wordConstruction
            ),
            kind: .completed,
            occurredAt: Date()
        ))
        let reward = try XCTUnwrap(LanguageTowerRewardMapper.rewardEvent(for: event))

        XCTAssertNotNil(try service.process(reward, policy: .androidTowerReference))
        XCTAssertNil(try service.process(reward, policy: .androidTowerReference))
        let state = try repository.loadLedger().state(
            for: RewardScope(ownerID: .localDefault, product: .minikPlus)
        )
        XCTAssertEqual(state.points, 2)
        XCTAssertEqual(state.currentStreak, 0)
        XCTAssertEqual(state.bestStreak, 0)
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

        XCTAssertNotNil(plus.makeTowerPracticeSession(for: .english))
        XCTAssertNotNil(plus.makeTowerPracticeSession(for: .hebrew))
        XCTAssertNotNil(englishOnly.makeTowerPracticeSession(for: .english))
        XCTAssertNil(englishOnly.makeTowerPracticeSession(for: .hebrew))
        XCTAssertNil(math.makeTowerPracticeSession(for: .english))
    }

    func testTowerAppearsOnlyInLanguageGamesSectionWithoutRequiringItToBeLast() throws {
        let sections = ActivityCatalog.languageSections(
            for: .configuration(for: .minikPlus)
        )
        let games = try XCTUnwrap(sections.first { $0.id == "games" })

        XCTAssertTrue(games.activities.contains(.tower))
        XCTAssertFalse(sections
            .filter { $0.id != "games" }
            .contains(where: { $0.activities.contains(.tower) }))
    }

    private func provider(
        configuration: ProductConfiguration = .configuration(for: .minikPlus)
    ) -> LanguageTowerContentProvider {
        LanguageTowerContentProvider(configuration: configuration)
    }

    private func request() -> ChallengeRequest {
        ChallengeRequest(
            activityType: .tower,
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
    ) throws -> TowerOrderedTokenRound {
        try XCTUnwrap(provider().round(
            for: request(),
            learnedLanguage: language,
            item: item
        ))
    }

    private func makePlayableRound() throws -> TowerOrderedTokenRound {
        let item = try item { item in
            guard let text = LanguageWordContentProvider.learnedText(
                for: item,
                language: .english
            ) else {
                return false
            }
            let tokens = text.text.filter { !$0.isWhitespace }.map(String.init)
            return (3 ... 10).contains(tokens.count) && Set(tokens).count >= 2
        }
        return try makeRound(language: .english, item: item)
    }

    private func acceptNext(in session: inout TowerSession) throws {
        let expected = try XCTUnwrap(session.currentExpectedToken)
        let block = try XCTUnwrap(session.availableOrderedBlocks.first {
            $0.orderedToken == expected
        })
        XCTAssertEqual(session.placeOrderedBlock(block.id), .correct)
    }

    private func completeCurrentRound(
        in practice: inout LanguageTowerPracticeSession
    ) throws {
        while !practice.currentSession.isComplete {
            let expected = try XCTUnwrap(practice.currentSession.currentExpectedToken)
            let block = try XCTUnwrap(practice.currentSession.availableOrderedBlocks.first {
                $0.orderedToken == expected
            })
            XCTAssertEqual(practice.placeBlock(block.id), .correct)
            if !practice.currentSession.isComplete {
                practice.clearPlacementFeedback()
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
            let tokens = text.text.uppercased().filter { !$0.isWhitespace }.map(String.init)
            return (3 ... 10).contains(tokens.count) && Set(tokens).count < tokens.count
        }
    }

    private func itemWithDuplicateCharactersAfterBase(
        language: LanguageIdentifier
    ) throws -> LanguageWordCatalogItem {
        try item { item in
            guard let text = LanguageWordContentProvider.learnedText(
                for: item,
                language: language
            ) else {
                return false
            }
            let tokens = text.text.uppercased().filter { !$0.isWhitespace }.map(String.init)
            let remainingTokens = Array(tokens.dropFirst())
            return (3 ... 10).contains(tokens.count)
                && Set(remainingTokens).count < remainingTokens.count
        }
    }

    private func duplicateValue(
        in tokens: [LearningTextRepresentation]
    ) throws -> LearningTextRepresentation {
        let groups = Dictionary(grouping: tokens, by: { $0 })
        return try XCTUnwrap(groups.first(where: { $0.value.count > 1 })?.key)
    }
}
