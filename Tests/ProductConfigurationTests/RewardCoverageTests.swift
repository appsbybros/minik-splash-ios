import XCTest
@testable import MinikPlus

final class RewardCoverageTests: XCTestCase {
    func testPictureMemoryCompletionMapsToAndroidFixedTwoPoints() throws {
        let id = UUID()
        let event = try XCTUnwrap(ActivityEvent(
            id: id,
            sessionID: ActivitySessionID(),
            context: ActivityEventContext(
                product: .minikPlus,
                activityID: ProgressActivityID(rawValue: "language.wordMemory"),
                skillID: LanguageSkillIDs.wordImageAssociation
            ),
            kind: .completed,
            occurredAt: .distantPast
        ))
        let reward = try XCTUnwrap(LanguagePictureMemoryRewardMapper.rewardEvent(for: event))
        let result = try XCTUnwrap(RewardProcessor().process(
            reward,
            state: RewardState(),
            policy: .androidPictureMemoryReference
        ))

        XCTAssertEqual(reward.id, id)
        XCTAssertEqual(result.state.points, 2)
        XCTAssertEqual(result.state.currentStreak, 0)
    }

    func testSoccerWinDrawAndLossPreserveAndroidPointContract() throws {
        let win = try XCTUnwrap(LanguageSoccerRewardMapper.rewardEvent(
            sourceEventID: UUID(),
            product: .minikPlus,
            outcome: .childWin,
            occurredAt: .distantPast
        ))
        let draw = try XCTUnwrap(LanguageSoccerRewardMapper.rewardEvent(
            sourceEventID: UUID(),
            product: .minikPlusEnglish,
            outcome: .draw,
            occurredAt: .distantPast
        ))

        XCTAssertEqual(RewardProcessor().process(
            win, state: RewardState(), policy: .androidSoccerReference
        )?.state.points, 3)
        XCTAssertEqual(RewardProcessor().process(
            draw, state: RewardState(), policy: .androidSoccerReference
        )?.state.points, 1)
        XCTAssertNil(LanguageSoccerRewardMapper.rewardEvent(
            sourceEventID: UUID(),
            product: .minikPlus,
            outcome: .minikWin,
            occurredAt: .distantPast
        ))
    }

    func testTicTacToeWinDrawAndLossPreserveAndroidPointContract() throws {
        let cases: [(TicTacToeOutcome, Int64)] = [
            (.childWin, 2),
            (.draw, 1),
            (.minikWin, 0)
        ]

        for (outcome, expectedPoints) in cases {
            let reward = try XCTUnwrap(LanguageTicTacToeRewardMapper.rewardEvent(
                sourceEventID: UUID(),
                product: .minikPlus,
                outcome: outcome,
                occurredAt: .distantPast
            ))
            let result = try XCTUnwrap(RewardProcessor().process(
                reward,
                state: RewardState(),
                policy: .androidTicTacToeReference
            ))
            XCTAssertEqual(result.state.points, expectedPoints)
            XCTAssertEqual(result.state.currentStreak, 0)
        }
    }

    func testNewLanguageRewardMappersRejectMathAndPingPong() {
        for product in [ProductVariant.minikMath, .minikPingPong] {
            XCTAssertNil(LanguageSoccerRewardMapper.rewardEvent(
                sourceEventID: UUID(),
                product: product,
                outcome: .childWin,
                occurredAt: .distantPast
            ))
            XCTAssertNil(LanguageTicTacToeRewardMapper.rewardEvent(
                sourceEventID: UUID(),
                product: product,
                outcome: .childWin,
                occurredAt: .distantPast
            ))
        }
    }

    func testProductionLanguageRewardCoverageMatchesAndroidObservedActivities() {
        let rewarded: Set<LanguageActivityKind> = [
            .firstLetterChoices,
            .firstLetterPictures,
            .wordBuild,
            .letterPairs,
            .imageToWord,
            .wordToImage,
            .wordMemory,
            .mixed,
            .soccer,
            .tower,
            .ticTacToe
        ]
        let intentionallyUnrewarded: Set<LanguageActivityKind> = [.learn, .wordCards]

        XCTAssertEqual(Set(LanguageActivityKind.productionKinds), rewarded.union(intentionallyUnrewarded))
        XCTAssertTrue(rewarded.isDisjoint(with: intentionallyUnrewarded))
    }

    func testRecordSubmissionForwardsExactAggregateRewardState() async {
        let repository = CapturingRecordsRepository(result: .noNewRecord)
        let achievedAt = Date(timeIntervalSince1970: 123_456)
        let scope = RewardScope(ownerID: .localDefault, product: .minikPlusEnglish)
        let stateStore = RewardCoveragePublicLeaderboardStateStore(enabled: true)
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: repository,
            localStateStore: stateStore
        )

        let result = await service.submit(
            state: RewardState(points: 42, currentStreak: 3, bestStreak: 7),
            scope: scope,
            achievedAt: achievedAt
        )

        XCTAssertEqual(result, .noNewRecord)
        let candidates = await repository.candidates()
        XCTAssertEqual(candidates, [RewardRecordCandidate(
            scope: scope,
            points: 42,
            bestStreak: 7,
            achievedAt: achievedAt
        )])
    }

    func testRecordSubmissionSkipsZeroStateAndFailsClosedWithoutConfiguration() async {
        let repository = CapturingRecordsRepository(result: .noNewRecord)
        let scope = RewardScope(ownerID: .localDefault, product: .minikPlus)
        let stateStore = RewardCoveragePublicLeaderboardStateStore(enabled: true)
        let configured = RewardRecordSubmissionService(
            scope: scope,
            repository: repository,
            localStateStore: stateStore
        )
        let unconfigured = RewardRecordSubmissionService(
            scope: scope,
            repository: nil,
            localStateStore: stateStore
        )

        let zeroResult = await configured.submit(
            state: RewardState(),
            scope: scope,
            achievedAt: .distantPast
        )
        let capturedCandidates = await repository.candidates()
        let unconfiguredResult = await unconfigured.submit(
            state: RewardState(points: 1),
            scope: scope,
            achievedAt: .distantPast
        )

        XCTAssertEqual(zeroResult, .noEligibleValue)
        XCTAssertTrue(capturedCandidates.isEmpty)
        XCTAssertEqual(unconfiguredResult, .notConfigured)
    }
}

private actor CapturingRecordsRepository: RecordsRepository {
    private let result: RemoteRecordSubmissionResult
    private var submittedCandidates: [RewardRecordCandidate] = []

    init(result: RemoteRecordSubmissionResult) {
        self.result = result
    }

    func loadTopRecords() async throws -> RemoteRecordsSnapshot {
        RemoteRecordsSnapshot(scoreRecords: [], streakRecords: [], isFromCache: false)
    }

    func submit(_ candidate: RewardRecordCandidate) async throws -> RemoteRecordSubmissionResult {
        submittedCandidates.append(candidate)
        return result
    }

    func candidates() -> [RewardRecordCandidate] {
        submittedCandidates
    }

    func deleteParticipantRecords() async throws {}
}

private actor RewardCoveragePublicLeaderboardStateStore: PublicLeaderboardStateStoring {
    private var state: PublicLeaderboardLocalState

    init(enabled: Bool) {
        state = PublicLeaderboardLocalState(
            participationEnabled: enabled,
            selectedAlias: PublicLeaderboardAlias(
                adjective: .bright,
                noun: .otter,
                number: 27,
                avatar: .star
            ),
            pendingCandidate: nil
        )
    }

    func loadState() async -> PublicLeaderboardLocalState { state }
    func saveState(_ state: PublicLeaderboardLocalState) async throws { self.state = state }
    func selectedPublicAlias() async -> PublicLeaderboardAlias? { state.selectedAlias }
    func isLeaderboardParticipationEnabled() async -> Bool { state.participationEnabled }
}
