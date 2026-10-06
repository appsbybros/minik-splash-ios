import Foundation
import XCTest
@testable import MinikPlus

final class LanguageChoiceParityTests: XCTestCase {
    func testEveryCanonicalChoiceFamilyRetainsItsAndroidLayoutBoundary() {
        let cases: [(MultipleChoicePresentation, Bool, Bool)] = [
            (.firstLetterPictureToLetter, true, false),
            (.firstLetterLetterToPicture, false, true),
            (.pictureToWord, true, false),
            (.wordToPicture, false, true)
        ]
        for (presentation, picturePrompt, pictureAnswers) in cases {
            XCTAssertEqual(presentation.usesPicturePrompt, picturePrompt)
            XCTAssertEqual(presentation.usesPictureAnswers, pictureAnswers)
            XCTAssertTrue(presentation.usesExpectedSemanticProgressIdentity)
        }
        XCTAssertFalse(MultipleChoicePresentation.standard.usesExpectedSemanticProgressIdentity)
    }

    func testAllFourProductionRewardRoutesAndMixedUseTypedSkills() throws {
        let routes: [(String, SkillID)] = [
            ("firstLetterChoices", LanguageSkillIDs.initialLetterAssociation),
            ("firstLetterPictures", LanguageSkillIDs.initialLetterAssociation),
            ("imageToWord", LanguageSkillIDs.wordRecognition),
            ("wordToImage", LanguageSkillIDs.wordImageAssociation),
            ("mixed", LanguageSkillIDs.wordRecognition)
        ]
        for product in [ProductVariant.minikPlus, .minikPlusEnglish] {
            for (route, skill) in routes {
                let correct = try event(route: route, skill: skill, result: .correct, product: product)
                let mapped = try XCTUnwrap(LanguageChoiceRewardMapper.rewardEvent(for: correct))
                XCTAssertEqual(mapped.id, correct.id)
                XCTAssertEqual(mapped.sourceActivityEventID, correct.id)
                XCTAssertEqual(mapped.scope.product, product)
                XCTAssertEqual(mapped.reason, .correctAnswer)
                let wrong = try event(route: route, skill: skill, result: .incorrect, product: product)
                XCTAssertEqual(LanguageChoiceRewardMapper.rewardEvent(for: wrong)?.reason, .incorrectAnswer)
                let skip = try event(route: route, skill: skill, result: .skipped, product: product)
                XCTAssertNil(LanguageChoiceRewardMapper.rewardEvent(for: skip))
            }
        }
        XCTAssertNil(LanguageChoiceRewardMapper.rewardEvent(for:
            try event(route: "wordCards", skill: LanguageSkillIDs.wordRecognition)))
        XCTAssertNil(LanguageChoiceRewardMapper.rewardEvent(for:
            try event(route: "imageToWord", skill: nil)))
        XCTAssertNil(LanguageChoiceRewardMapper.rewardEvent(for:
            try event(route: "imageToWord", skill: LanguageSkillIDs.wordRecognition, product: .minikMath)))
    }

    func testRewardRetryClampStreakAndEventReplayArePreserved() throws {
        let store = InMemoryRewards()
        let service = LanguageWordPracticeRewardService(repository: store)
        let scope = RewardScope(ownerID: .localDefault, product: .minikPlus)
        let wrong = try event(route: "imageToWord", skill: LanguageSkillIDs.wordRecognition, result: .incorrect)
        try service.processAttempt(wrong)
        XCTAssertEqual(store.ledger.state(for: scope).points, 0)
        XCTAssertEqual(store.ledger.state(for: scope).currentStreak, 0)
        for _ in 0..<3 {
            let correct = try event(route: "imageToWord", skill: LanguageSkillIDs.wordRecognition)
            try service.processAttempt(correct)
            try service.processAttempt(correct)
        }
        XCTAssertEqual(store.ledger.state(for: scope), RewardState(points: 4, currentStreak: 3, bestStreak: 3))
        XCTAssertEqual(service.cleanWordRun, 3)
        try service.processAttempt(wrong)
        XCTAssertEqual(service.cleanWordRun, 3, "An older replay cannot reset this session or its bonus.")
        let error = try event(route: "imageToWord", skill: LanguageSkillIDs.wordRecognition, result: .incorrect)
        try service.processAttempt(error)
        XCTAssertEqual(store.ledger.state(for: scope), RewardState(points: 3, currentStreak: 0, bestStreak: 3))
        XCTAssertEqual(service.cleanWordRun, 0)
        let retry = try event(route: "imageToWord", skill: LanguageSkillIDs.wordRecognition)
        try service.processAttempt(retry)
        XCTAssertEqual(store.ledger.state(for: scope), RewardState(points: 4, currentStreak: 1, bestStreak: 3))
        try service.processAttempt(error)
        XCTAssertEqual(service.cleanWordRun, 1)
    }

    func testSpeechCompletionWaitsForBothWordAndEncouragementAndIgnoresLateCancel() {
        let oldWord = NSObject(), word = NSObject(), encouragement = NSObject()
        var queue = LearningSpeechQueueState()
        queue.enqueue(ObjectIdentifier(oldWord))
        queue.cancelAll()
        queue.enqueue(ObjectIdentifier(word))
        queue.enqueue(ObjectIdentifier(encouragement))
        XCTAssertFalse(queue.finish(ObjectIdentifier(oldWord)))
        XCTAssertFalse(queue.finish(ObjectIdentifier(word)))
        XCTAssertFalse(queue.pending.isEmpty)
        XCTAssertTrue(queue.finish(ObjectIdentifier(encouragement)))
        XCTAssertTrue(queue.pending.isEmpty)
        XCTAssertFalse(queue.finish(ObjectIdentifier(encouragement)))
    }

    func testAndroidSuccessJumpHasVisibleFullSizeMidpointAndLeavesBothEdges() {
        let start = LanguageSuccessJump.sample(elapsed: 0, width: 330, height: 680, artworkHeight: 265, direction: 1)
        let peak = LanguageSuccessJump.sample(elapsed: 0.775, width: 330, height: 680, artworkHeight: 265, direction: 1)
        let end = LanguageSuccessJump.sample(elapsed: 1.55, width: 330, height: 680, artworkHeight: 265, direction: 1)
        XCTAssertEqual(start.opacity, 0)
        XCTAssertEqual(end.opacity, 0)
        XCTAssertEqual(peak.opacity, 1)
        XCTAssertEqual(peak.x, 165, accuracy: 0.001)
        XCTAssertLessThan(peak.y + 132.5, 680)
        XCTAssertGreaterThan(peak.y - 132.5, 0)
        let mirrored = LanguageSuccessJump.sample(elapsed: 0.4, width: 330, height: 680, artworkHeight: 265, direction: -1)
        let forward = LanguageSuccessJump.sample(elapsed: 0.4, width: 330, height: 680, artworkHeight: 265, direction: 1)
        XCTAssertEqual(mirrored.x + forward.x, 330, accuracy: 0.001)
        XCTAssertEqual(mirrored.y, forward.y)
        XCTAssertEqual(mirrored.rotation, -forward.rotation)
    }

    private func event(route: String, skill: SkillID?, result: GradedAttemptResult = .correct,
                       product: ProductVariant = .minikPlus) throws -> ActivityEvent {
        let attempt = try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "opaque-content-id"), attemptIndex: 1, result: result,
            activityFamily: route == "mixed" ? .mixed : .multipleChoice, skillID: skill
        ))
        return try XCTUnwrap(ActivityEvent(
            sessionID: ActivitySessionID(),
            context: ActivityEventContext(product: product, activityID: ProgressActivityID(rawValue: "language." + route)),
            kind: .gradedAttempt, occurredAt: Date(timeIntervalSince1970: 100), attemptData: attempt
        ))
    }

    private final class InMemoryRewards: RewardRepository {
        var ledger = RewardLedger()
        func loadLedger() throws -> RewardLedger { ledger }
        func saveLedger(_ ledger: RewardLedger) throws { self.ledger = ledger }
    }
}
