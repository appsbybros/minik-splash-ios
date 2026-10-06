import Foundation
import XCTest
@testable import MinikPlus

final class LanguageBuildParityTests: XCTestCase {
    func testReference06HebrewHostArrowClueAndArPrefix() throws {
        let challenge = try arrowChallenge()
        let clue = LanguageWordBuildClue.make(for: challenge, interfaceLocale: .hebrew)
        XCTAssertEqual(clue.text?.text, "\u{05D7}\u{05E5}")
        XCTAssertEqual(clue.text?.language, .hebrew)
        XCTAssertNil(clue.image)
        var session = try XCTUnwrap(BuildSession(challenges: [challenge]))
        session.selectToken(challenge.availableTokens[0].id)
        // The second physical r is also valid for the first r position.
        session.selectToken(challenge.availableTokens[2].id)
        XCTAssertEqual(session.builtDisplayText, "Ar")
        XCTAssertEqual(session.selectedTokenIDs.count, 2)
        XCTAssertEqual(session.tokenPresentationOrder.count, 5)
        XCTAssertEqual(challenge.prompt.learningSpeechCue?.language, .english)
        XCTAssertEqual(challenge.prompt.learningSpeechCue?.text, "Arrow")
    }

    func testPlusCluePolicySeparatesHostTextImagesAndLearnedSpeech() throws {
        let challenge = try arrowChallenge()
        let same = LanguageWordBuildClue.make(for: challenge, interfaceLocale: .english)
        XCTAssertNil(same.text)
        XCTAssertNil(same.image)
        let french = LanguageWordBuildClue.make(for: challenge, interfaceLocale: .french)
        XCTAssertEqual(french.text?.text, "Arrow") // Exact WordItemLoader fallback, not French TTS.
        XCTAssertNotNil(french.image)
        XCTAssertEqual(challenge.languageWordContent?.targetText.language, .english)
        XCTAssertEqual(challenge.prompt.learningSpeechCue?.text, "Arrow")
    }

    func testWrongLetterKeepsPoolAndPrefixAndSkipRemainsAfterAnotherCorrectLetter() throws {
        let challenge = try arrowChallenge()
        var session = try XCTUnwrap(BuildSession(challenges: [challenge, challenge]))
        let board = session.tokenPresentationOrder
        session.selectToken(challenge.availableTokens[0].id)
        session.selectToken(challenge.availableTokens[4].id)
        XCTAssertEqual(session.lastSelectionResult, .incorrect)
        XCTAssertEqual(session.builtDisplayText, "A")
        XCTAssertEqual(session.tokenPresentationOrder, board)
        XCTAssertTrue(session.hasIncorrectAttempt)
        session.selectToken(challenge.availableTokens[1].id)
        XCTAssertEqual(session.builtDisplayText, "Ar")
        XCTAssertTrue(session.hasIncorrectAttempt)
        session.nextChallenge()
        XCTAssertEqual(session.currentChallengeIndex, 1)
        XCTAssertFalse(session.hasIncorrectAttempt)
        XCTAssertEqual(session.builtDisplayText, "")
    }

    func testCompletedBuildScoresOnceAndRejectedLettersDoNotSpendPointsOrEraseDisplayedStreak() throws {
        let store = Store()
        let service = LanguageWordPracticeRewardService(repository: store)
        let sessionID = ActivitySessionID()
        let scope = RewardScope(ownerID: .localDefault, product: .minikPlus)
        for _ in 0..<3 {
            let completion = LanguageWordCompletion(id: UUID(), contentItemID: ContentItemID(rawValue: "word"), hadIncorrectLetter: false)
            try service.processCompletion(completion, sessionID: sessionID, product: .minikPlus, occurredAt: .distantPast)
            try service.processCompletion(completion, sessionID: sessionID, product: .minikPlus, occurredAt: .distantPast)
        }
        XCTAssertEqual(store.ledger.state(for: scope), RewardState(points: 4, currentStreak: 3, bestStreak: 3))
        let wrong = try rejectedLetter(sessionID: sessionID)
        try service.processAttempt(wrong)
        XCTAssertEqual(service.cleanWordRun, 0)
        XCTAssertTrue(store.ledger.processedEventIDs.contains(wrong.id))
        XCTAssertEqual(store.ledger.state(for: scope).points, 4)
        XCTAssertEqual(store.ledger.state(for: scope).currentStreak, 3)
        let repaired = LanguageWordCompletion(id: UUID(), contentItemID: ContentItemID(rawValue: "word"), hadIncorrectLetter: true)
        try service.processCompletion(repaired, sessionID: sessionID, product: .minikPlus, occurredAt: .distantPast)
        XCTAssertEqual(store.ledger.state(for: scope), RewardState(points: 5, currentStreak: 4, bestStreak: 4))
        let next = LanguageWordCompletion(id: UUID(), contentItemID: ContentItemID(rawValue: "next"), hadIncorrectLetter: false)
        try service.processCompletion(next, sessionID: sessionID, product: .minikPlus, occurredAt: .distantPast)
        XCTAssertEqual(store.ledger.state(for: scope).points, 6)
        XCTAssertEqual(service.cleanWordRun, 1)
        let newSession = ActivitySessionID()
        let later = LanguageWordCompletion(id: UUID(), contentItemID: ContentItemID(rawValue: "later"), hadIncorrectLetter: false)
        let recreatedService = LanguageWordPracticeRewardService(repository: store)
        try recreatedService.processCompletion(later, sessionID: newSession, product: .minikPlus, occurredAt: .distantPast)
        XCTAssertEqual(recreatedService.cleanWordRun, 6, "Re-entry restores the five-word displayed streak before adding this word.")
        try recreatedService.processAttempt(wrong)
        XCTAssertEqual(recreatedService.cleanWordRun, 6, "Persisted rejection identity must survive service recreation.")
    }

    private func arrowChallenge() throws -> BuildChallenge {
        let item = try XCTUnwrap(LanguageWordCatalog.item(stableKey: "shapes_arrow"))
        let text = try XCTUnwrap(LanguageWordContentProvider.learnedText(for: item, language: .english))
        let tokens = text.text.enumerated().map { index, letter in
            let letterText = String(letter)
            return BuildToken(id: BuildTokenID(rawValue: "fixture-letter-\(index)"),
                representation: .learningText(LearningTextRepresentation(
                    text: letterText,
                    language: .english,
                    direction: .leftToRight)))
        }
        return try XCTUnwrap(BuildChallenge(
            id: ChallengeID(rawValue: "opaque-presentation"), prompt: try XCTUnwrap(Prompt(
                representations: [.imageAsset(item.image)], speechCue: text.learningSpeechCue)),
            availableTokens: tokens, expectedTokenSequence: tokens.map(\.id),
            primarySkill: LanguageSkillIDs.wordConstruction,
            curriculumStage: LanguageCurriculumStageIDs.wordsLevelA,
            difficulty: try XCTUnwrap(Difficulty(0.5)), validationMode: .immediatePrefix,
            languageWordContent: try XCTUnwrap(LanguageWordBuildContent(contentItemID: item.id, targetText: text))
        ))
    }

    private func rejectedLetter(sessionID: ActivitySessionID) throws -> ActivityEvent {
        let attempt = try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "opaque-letter"), attemptIndex: 1, result: .incorrect,
            activityFamily: .buildWord, skillID: LanguageSkillIDs.wordConstruction))
        return try XCTUnwrap(ActivityEvent(sessionID: sessionID,
            context: ActivityEventContext(product: .minikPlus, activityID: ProgressActivityID(rawValue: "language.wordBuild")),
            kind: .gradedAttempt, occurredAt: .distantPast, attemptData: attempt))
    }

    private final class Store: RewardRepository {
        var ledger = RewardLedger()
        func loadLedger() throws -> RewardLedger { ledger }
        func saveLedger(_ ledger: RewardLedger) throws { self.ledger = ledger }
    }
}
