import XCTest
@testable import MinikPlus

final class RewardFoundationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "RewardFoundationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testAndroidWordReferenceTiersAndStreakRecordAreDeterministic() throws {
        var state = RewardState()
        let processor = RewardProcessor()
        let expectedPoints: [Int64] = [1, 1, 2, 2, 3, 3, 3, 3, 3, 4]
        for expected in expectedPoints {
            let result = try XCTUnwrap(processor.process(
                event(reason: .correctAnswer),
                state: state,
                policy: .androidWordPracticeReference
            ))
            XCTAssertEqual(result.appliedRule.pointsDelta, expected)
            state = result.state
        }
        XCTAssertEqual(state.currentStreak, 10)
        XCTAssertEqual(state.bestStreak, 10)
        XCTAssertEqual(state.points, expectedPoints.reduce(0, +))
    }

    func testIncorrectAnswerFloorsPointsAtZeroAndPreservesBestStreak() throws {
        let state = RewardState(points: 0, currentStreak: 4, bestStreak: 7)
        let result = try XCTUnwrap(RewardProcessor().process(
            event(reason: .incorrectAnswer),
            state: state,
            policy: .androidWordPracticeReference
        ))
        XCTAssertEqual(result.state.points, 0)
        XCTAssertEqual(result.state.currentStreak, 0)
        XCTAssertEqual(result.state.bestStreak, 7)
    }

    func testTicTacToeReferenceDoesNotChangeLearningStreak() throws {
        let state = RewardState(points: 5, currentStreak: 3, bestStreak: 4)
        let win = try XCTUnwrap(RewardProcessor().process(
            event(reason: .matchWon), state: state, policy: .androidTicTacToeReference
        ))
        XCTAssertEqual(win.state, RewardState(points: 7, currentStreak: 3, bestStreak: 4))
    }

    func testLetterPairsReferenceMatchesAndroidPointRulesWithoutAStreak() throws {
        let state = RewardState(points: 2, currentStreak: 3, bestStreak: 5)
        let correct = try XCTUnwrap(RewardProcessor().process(
            event(reason: .pairMatched),
            state: state,
            policy: .androidLetterPairsReference
        ))
        let incorrect = try XCTUnwrap(RewardProcessor().process(
            event(reason: .incorrectAnswer),
            state: correct.state,
            policy: .androidLetterPairsReference
        ))

        XCTAssertEqual(correct.state, RewardState(points: 3, currentStreak: 3, bestStreak: 5))
        XCTAssertEqual(incorrect.state, state)
    }

    func testLetterPairsMapperUsesActivityEventIdentityAndProductScope() throws {
        let activityEvent = try makeLetterPairsActivityEvent(result: .correct)
        let rewardEvent = try XCTUnwrap(
            LanguageLetterPairsRewardMapper.rewardEvent(for: activityEvent)
        )

        XCTAssertEqual(rewardEvent.id, activityEvent.id)
        XCTAssertEqual(rewardEvent.sourceActivityEventID, activityEvent.id)
        XCTAssertEqual(rewardEvent.scope, languageScope)
        XCTAssertEqual(rewardEvent.reason, .pairMatched)
        XCTAssertEqual(rewardEvent.occurredAt, activityEvent.occurredAt)
    }

    func testLetterPairsMapperRejectsOtherActivitiesProductsAndSkippedAttempts() throws {
        let otherActivity = try makeLetterPairsActivityEvent(
            result: .correct,
            activityID: "language.wordToImage"
        )
        let mathProduct = try makeLetterPairsActivityEvent(
            result: .correct,
            product: .minikMath
        )
        let skipped = try makeLetterPairsActivityEvent(result: .skipped)

        XCTAssertNil(LanguageLetterPairsRewardMapper.rewardEvent(for: otherActivity))
        XCTAssertNil(LanguageLetterPairsRewardMapper.rewardEvent(for: mathProduct))
        XCTAssertNil(LanguageLetterPairsRewardMapper.rewardEvent(for: skipped))
    }

    func testLocalServicePersistsAndRejectsDuplicateEvent() throws {
        let repository = LocalRewardRepository(userDefaults: defaults, storageKey: "test.rewards")
        let service = LocalRewardService(repository: repository)
        let rewardEvent = event(reason: .correctAnswer)
        XCTAssertNotNil(try service.process(rewardEvent, policy: .androidWordPracticeReference))
        XCTAssertNil(try service.process(rewardEvent, policy: .androidWordPracticeReference))
        XCTAssertEqual(try repository.loadLedger().state(for: languageScope).points, 1)
    }

    func testProductsAndOwnersUseIndependentRewardScopes() throws {
        var ledger = RewardLedger()
        let languageEvent = event(reason: .correctAnswer)
        let languageResult = try XCTUnwrap(RewardProcessor().process(
            languageEvent, state: RewardState(), policy: .androidWordPracticeReference
        ))
        ledger.store(languageResult.state, for: languageEvent)

        let pingPongScope = RewardScope(ownerID: .localDefault, product: .minikPingPong)
        XCTAssertEqual(ledger.state(for: languageScope).points, 1)
        XCTAssertEqual(ledger.state(for: pingPongScope).points, 0)
    }

    func testPingPongCanEmitTypedMatchRewardWithoutSceneLogic() throws {
        let policy = try XCTUnwrap(RewardPolicy(rules: [
            .matchWon: RewardRule(pointsDelta: 2, streakEffect: .unchanged)
        ]))
        let pingPongScope = RewardScope(ownerID: .localDefault, product: .minikPingPong)
        let rewardEvent = RewardEvent(
            scope: pingPongScope,
            reason: .matchWon,
            occurredAt: fixedDate
        )
        let result = try XCTUnwrap(RewardProcessor().process(
            rewardEvent, state: RewardState(), policy: policy
        ))
        XCTAssertEqual(result.state.points, 2)
        XCTAssertEqual(result.state.currentStreak, 0)
    }

    func testUnconfiguredReasonProducesNoReward() {
        let result = RewardProcessor().process(
            event(reason: .activityCompleted),
            state: RewardState(),
            policy: .androidWordPracticeReference
        )
        XCTAssertNil(result)
    }

    private var fixedDate: Date { Date(timeIntervalSince1970: 1_800_000_000) }

    private var languageScope: RewardScope {
        RewardScope(ownerID: .localDefault, product: .minikPlus)
    }

    private func event(reason: RewardReason) -> RewardEvent {
        RewardEvent(scope: languageScope, reason: reason, occurredAt: fixedDate)
    }

    private func makeLetterPairsActivityEvent(
        result: GradedAttemptResult,
        activityID: String = "language.letterPairs",
        product: ProductVariant = .minikPlus
    ) throws -> ActivityEvent {
        let attempt = try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "language.initialLetter.en.a"),
            attemptIndex: 1,
            result: result,
            responseDurationSeconds: 1,
            activityFamily: .pairs,
            skillID: LanguageSkillIDs.initialLetterAssociation
        ))
        return try XCTUnwrap(ActivityEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            sessionID: ActivitySessionID(
                rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000456")!
            ),
            context: ActivityEventContext(
                product: product,
                activityID: ProgressActivityID(rawValue: activityID),
                skillID: LanguageSkillIDs.initialLetterAssociation
            ),
            kind: .gradedAttempt,
            occurredAt: fixedDate,
            attemptData: attempt
        ))
    }
}
