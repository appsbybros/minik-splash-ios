import XCTest
@testable import MinikPlus

final class LanguageOrderedTokenAttemptTrackerTests: XCTestCase {
    func testRetryUsesSameChallengeAndIncrementsAttemptIndex() throws {
        var tracker = LanguageOrderedTokenAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.words.apple")

        let first = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .incorrect,
            responseDurationSeconds: 1.25,
            activityFamily: .soccer
        ))
        let retry = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .correct,
            responseDurationSeconds: 0.75,
            activityFamily: .soccer
        ))

        XCTAssertEqual(first.itemID.rawValue, "language.words.apple.ordered-token.0")
        XCTAssertEqual(first.attemptIndex, 1)
        XCTAssertTrue(first.isFirstAttempt)
        XCTAssertEqual(first.result, .incorrect)
        XCTAssertEqual(first.responseDurationSeconds, 1.25)
        XCTAssertEqual(first.activityFamily, .soccer)
        XCTAssertNil(first.mathLevelID)
        XCTAssertNil(first.skillID)
        XCTAssertEqual(retry.itemID, first.itemID)
        XCTAssertEqual(retry.attemptIndex, 2)
        XCTAssertFalse(retry.isFirstAttempt)
        XCTAssertEqual(retry.result, .correct)
    }

    func testNewTokenAndNewContentEachResetAttemptIndex() throws {
        var tracker = LanguageOrderedTokenAttemptTracker()
        let firstWord = ContentItemID(rawValue: "language.words.apple")
        let secondWord = ContentItemID(rawValue: "language.words.ball")

        _ = tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: firstWord,
            tokenIndex: 0,
            result: .incorrect,
            responseDurationSeconds: 1,
            activityFamily: .tower
        )
        let nextToken = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: firstWord,
            tokenIndex: 1,
            result: .correct,
            responseDurationSeconds: 2,
            activityFamily: .tower
        ))
        let nextWord = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 2,
            contentItemID: secondWord,
            tokenIndex: 1,
            result: .correct,
            responseDurationSeconds: 3,
            activityFamily: .tower
        ))

        XCTAssertEqual(nextToken.attemptIndex, 1)
        XCTAssertEqual(nextToken.itemID.rawValue, "language.words.apple.ordered-token.1")
        XCTAssertEqual(nextToken.activityFamily, .tower)
        XCTAssertEqual(nextWord.attemptIndex, 1)
        XCTAssertEqual(nextWord.itemID.rawValue, "language.words.ball.ordered-token.1")
    }

    func testTrackerRejectsUnsupportedFamiliesAndInvalidTokenIndex() {
        var tracker = LanguageOrderedTokenAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.words.apple")

        XCTAssertNil(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .correct,
            responseDurationSeconds: 1,
            activityFamily: .pairs
        ))
        XCTAssertNil(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            tokenIndex: -1,
            result: .correct,
            responseDurationSeconds: 1,
            activityFamily: .soccer
        ))
    }

    func testBuildWordAttemptsKeepSemanticTokenIdentitySkillAndRetryIndex() throws {
        var tracker = LanguageOrderedTokenAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.words.ice_cream")
        let skillID = LanguageSkillIDs.wordConstruction

        let wrong = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 3,
            contentItemID: contentItemID,
            tokenIndex: 2,
            result: .incorrect,
            responseDurationSeconds: 0.5,
            activityFamily: .buildWord,
            skillID: skillID
        ))
        let retry = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 3,
            contentItemID: contentItemID,
            tokenIndex: 2,
            result: .correct,
            responseDurationSeconds: 0.25,
            activityFamily: .buildWord,
            skillID: skillID
        ))

        XCTAssertEqual(wrong.itemID.rawValue, "language.words.ice_cream.ordered-token.2")
        XCTAssertEqual(wrong.attemptIndex, 1)
        XCTAssertEqual(wrong.activityFamily, .buildWord)
        XCTAssertEqual(wrong.skillID, skillID)
        XCTAssertNil(wrong.mathLevelID)
        XCTAssertEqual(retry.itemID, wrong.itemID)
        XCTAssertEqual(retry.attemptIndex, 2)
    }

    func testInvalidDurationDoesNotConsumeAttemptIndex() throws {
        var tracker = LanguageOrderedTokenAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.words.apple")

        XCTAssertNil(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .incorrect,
            responseDurationSeconds: -1,
            activityFamily: .soccer
        ))
        let valid = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .correct,
            responseDurationSeconds: 1,
            activityFamily: .soccer
        ))

        XCTAssertEqual(valid.attemptIndex, 1)
        XCTAssertTrue(valid.isFirstAttempt)
    }

    func testRepeatedSemanticTokenInNewPresentationStartsAtAttemptOne() throws {
        var tracker = LanguageOrderedTokenAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.words.apple")

        let firstPresentation = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 7,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .incorrect,
            responseDurationSeconds: 1,
            activityFamily: .soccer
        ))
        let secondPresentation = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 8,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .correct,
            responseDurationSeconds: 1,
            activityFamily: .soccer
        ))

        XCTAssertEqual(firstPresentation.itemID, secondPresentation.itemID)
        XCTAssertEqual(firstPresentation.attemptIndex, 1)
        XCTAssertEqual(secondPresentation.attemptIndex, 1)
        XCTAssertTrue(secondPresentation.isFirstAttempt)
        XCTAssertNil(secondPresentation.mathLevelID)
        XCTAssertNil(secondPresentation.skillID)
    }

    func testInvalidPresentationIndexDoesNotConsumeAttemptIndex() throws {
        var tracker = LanguageOrderedTokenAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.words.apple")

        XCTAssertNil(tracker.makeAttempt(
            presentationIndex: 0,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .incorrect,
            responseDurationSeconds: 1,
            activityFamily: .tower
        ))
        let valid = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            tokenIndex: 0,
            result: .correct,
            responseDurationSeconds: 1,
            activityFamily: .tower
        ))

        XCTAssertEqual(valid.attemptIndex, 1)
    }
}
