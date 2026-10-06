import XCTest
@testable import MinikPlus

final class LanguagePairsAttemptTrackerTests: XCTestCase {
    func testRetryKeepsSemanticIdentityAndIncrementsAttemptIndex() throws {
        var tracker = LanguagePairsAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.initialLetter.en.a")

        let incorrect = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            result: .incorrect,
            responseDurationSeconds: 1.5,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))
        let retry = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            result: .correct,
            responseDurationSeconds: 0.75,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))

        XCTAssertEqual(incorrect.itemID.rawValue, contentItemID.rawValue)
        XCTAssertEqual(incorrect.attemptIndex, 1)
        XCTAssertTrue(incorrect.isFirstAttempt)
        XCTAssertEqual(incorrect.result, .incorrect)
        XCTAssertEqual(incorrect.responseDurationSeconds, 1.5)
        XCTAssertEqual(retry.itemID, incorrect.itemID)
        XCTAssertEqual(retry.attemptIndex, 2)
        XCTAssertFalse(retry.isFirstAttempt)
        XCTAssertEqual(retry.result, .correct)
        XCTAssertEqual(retry.activityFamily, .pairs)
        XCTAssertEqual(retry.skillID, LanguageSkillIDs.initialLetterAssociation)
        XCTAssertNil(retry.mathLevelID)
    }

    func testDifferentSemanticPairHasIndependentFirstAttempt() throws {
        var tracker = LanguagePairsAttemptTracker()

        _ = tracker.makeAttempt(
            presentationIndex: 4,
            contentItemID: ContentItemID(rawValue: "language.initialLetter.he.א"),
            result: .incorrect,
            responseDurationSeconds: 1,
            skillID: LanguageSkillIDs.initialLetterAssociation
        )
        let otherPair = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 4,
            contentItemID: ContentItemID(rawValue: "language.initialLetter.he.ב"),
            result: .correct,
            responseDurationSeconds: 1,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))

        XCTAssertEqual(otherPair.attemptIndex, 1)
        XCTAssertTrue(otherPair.isFirstAttempt)
        XCTAssertNil(otherPair.mathLevelID)
    }

    func testRepeatedSemanticPairInNewRoundStartsAtAttemptOne() throws {
        var tracker = LanguagePairsAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.initialLetter.en.a")

        _ = tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            result: .incorrect,
            responseDurationSeconds: 1,
            skillID: LanguageSkillIDs.initialLetterAssociation
        )
        let newRound = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 2,
            contentItemID: contentItemID,
            result: .correct,
            responseDurationSeconds: 1,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))

        XCTAssertEqual(newRound.itemID.rawValue, contentItemID.rawValue)
        XCTAssertEqual(newRound.attemptIndex, 1)
        XCTAssertTrue(newRound.isFirstAttempt)
    }

    func testInvalidPresentationOrDurationDoesNotConsumeAttempt() throws {
        var tracker = LanguagePairsAttemptTracker()
        let contentItemID = ContentItemID(rawValue: "language.initialLetter.en.a")

        XCTAssertNil(tracker.makeAttempt(
            presentationIndex: 0,
            contentItemID: contentItemID,
            result: .incorrect,
            responseDurationSeconds: 1,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))
        XCTAssertNil(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            result: .incorrect,
            responseDurationSeconds: -1,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))
        let valid = try XCTUnwrap(tracker.makeAttempt(
            presentationIndex: 1,
            contentItemID: contentItemID,
            result: .correct,
            responseDurationSeconds: 1,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))

        XCTAssertEqual(valid.attemptIndex, 1)
    }
}
