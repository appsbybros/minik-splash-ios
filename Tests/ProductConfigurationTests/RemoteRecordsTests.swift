import XCTest
@testable import MinikPlus

private let testSecurePlayerID = "v2_00000000-0000-4000-8000-000000000001"

final class RemoteRecordsTests: XCTestCase {
    private let scope = RewardScope(ownerID: .localDefault, product: .minikPlus)
    private let alias = PublicLeaderboardAlias(
        adjective: .bright,
        noun: .otter,
        number: 27,
        avatar: .star
    )!

    func testAndroidCompatibleConfigurationPreservesProductCollections() throws {
        let plus = try XCTUnwrap(RemoteRecordsConfiguration.androidCompatible(for: .minikPlus))
        let englishOnly = try XCTUnwrap(RemoteRecordsConfiguration.androidCompatible(for: .minikPlusEnglish))

        XCTAssertEqual(plus.scoreCollection, "score_records")
        XCTAssertEqual(plus.streakCollection, "correct_answers_in_row")
        XCTAssertEqual(englishOnly.scoreCollection, "score_records_english_only")
        XCTAssertEqual(englishOnly.streakCollection, "correct_answers_in_row")
        XCTAssertNil(RemoteRecordsConfiguration.androidCompatible(for: .minikMath))
        XCTAssertNil(RemoteRecordsConfiguration.androidCompatible(for: .minikPingPong))
        XCTAssertEqual(RemoteRecordsConfiguration.appID, "3")
        XCTAssertEqual(RemoteRecordsConfiguration.topRecordsLimit, 20)
    }

    func testAndroidProductionDocumentDecodesAndIOSWriteMatchesItsSchema() async throws {
        let androidFields: [String: RemoteRecordValue] = [
            "app_id": .string("3"),
            "player_id": .string("android-player"),
            "score": .integer(64),
            "correct_answers_in_row": .integer(9),
            "date_achived": .date(Date(timeIntervalSince1970: 1_700_000_000)),
            "user_name": .string(alias.publicAlias)
        ]
        let dataSource = FakeRemoteRecordsDataSource(results: [
            "score_records": RemoteRecordsQueryResult(
                documents: [RemoteRecordDocument(documentID: "android-player", fields: androidFields)],
                isFromCache: false
            ),
            "correct_answers_in_row": RemoteRecordsQueryResult(documents: [], isFromCache: false)
        ])

        let snapshot = try await makeRepository(dataSource: dataSource).loadTopRecords()
        let decoded = snapshot.scoreRecords
        XCTAssertEqual(decoded.first?.playerID, "android-player")
        XCTAssertEqual(decoded.first?.score, 64)
        XCTAssertEqual(decoded.first?.correctAnswersInRow, 9)
        XCTAssertEqual(decoded.first?.publicAlias, alias.publicAlias)

        let writeSource = FakeRemoteRecordsDataSource(results: emptyResults())
        _ = try await makeRepository(dataSource: writeSource).submit(candidate(points: 64, streak: 9))
        let writeBatches = await writeSource.recordedWriteBatches()
        let writes = writeBatches.flatMap { $0 }
        let scoreWrite = try XCTUnwrap(writes.first { $0.collection == "score_records" })
        XCTAssertEqual(
            Set(scoreWrite.fields.keys),
            Set(androidFields.keys).union(["avatar_id"])
        )
        XCTAssertEqual(scoreWrite.fields["date_achived"], .serverTimestamp)
    }

    func testReleaseAppCheckPolicyCannotSelectDebugProvider() {
        XCTAssertEqual(
            FirebaseAppCheckBuildPolicy.providerMode(isDebugBuild: false),
            .appAttest
        )
        XCTAssertEqual(
            FirebaseAppCheckBuildPolicy.providerMode(isDebugBuild: true),
            .debug
        )
    }

    func testLoadUsesTopTwentyQueriesAndSuppressesLegacyFreeTextNames() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dataSource = FakeRemoteRecordsDataSource(results: [
            "score_records": RemoteRecordsQueryResult(
                documents: [scoreDocument(
                    id: "score-1",
                    playerID: "player-1",
                    score: 42,
                    streak: 7,
                    date: date,
                    publicAlias: alias.publicAlias,
                    avatarID: alias.avatarID
                )],
                isFromCache: false
            ),
            "correct_answers_in_row": RemoteRecordsQueryResult(
                documents: [streakDocument(
                    id: "streak-1",
                    playerID: "player-2",
                    streak: 12,
                    date: date,
                    publicAlias: "Maya"
                )],
                isFromCache: true
            )
        ])
        let repository = makeRepository(dataSource: dataSource)

        let snapshot = try await repository.loadTopRecords()

        XCTAssertEqual(snapshot.scoreRecords, [RemoteScoreRecord(
            documentID: "score-1",
            appID: "3",
            playerID: "player-1",
            score: 42,
            correctAnswersInRow: 7,
            dateAchieved: date,
            publicAlias: alias.publicAlias,
            avatarID: alias.avatarID
        )])
        XCTAssertEqual(snapshot.streakRecords.first?.correctAnswersInRow, 12)
        // An Android player's approved public name is shown as written.
        XCTAssertEqual(snapshot.streakRecords.first?.publicAlias, "Maya")
        XCTAssertNil(snapshot.streakRecords.first?.avatarID)
        XCTAssertTrue(snapshot.isFromCache)

        let queries = await dataSource.recordedQueries()
        XCTAssertEqual(Set(queries.map(\.collection)), ["score_records", "correct_answers_in_row"])
        XCTAssertTrue(queries.allSatisfy { $0.appID == "3" && $0.limit == 20 })
        XCTAssertEqual(queries.first(where: { $0.collection == "score_records" })?.orderField, "score")
        XCTAssertEqual(
            queries.first(where: { $0.collection == "correct_answers_in_row" })?.orderField,
            "correct_answers_in_row"
        )
    }

    func testMissingOptionalFirestoreFieldsUseAndroidDefaults() async throws {
        let dataSource = FakeRemoteRecordsDataSource(results: [
            "score_records": RemoteRecordsQueryResult(
                documents: [RemoteRecordDocument(documentID: "legacy", fields: [:])],
                isFromCache: false
            ),
            "correct_answers_in_row": RemoteRecordsQueryResult(documents: [], isFromCache: false)
        ])

        let snapshot = try await makeRepository(dataSource: dataSource).loadTopRecords()

        XCTAssertEqual(snapshot.scoreRecords.first?.appID, "")
        XCTAssertEqual(snapshot.scoreRecords.first?.playerID, "")
        XCTAssertEqual(snapshot.scoreRecords.first?.score, 0)
        XCTAssertEqual(snapshot.scoreRecords.first?.correctAnswersInRow, 0)
        XCTAssertNil(snapshot.scoreRecords.first?.dateAchieved)
        XCTAssertEqual(snapshot.scoreRecords.first?.publicAlias, "")
        XCTAssertNil(snapshot.scoreRecords.first?.avatarID)
    }

    func testTopTwentyRankingMatchesAndroidTieAndCutoffRules() {
        XCTAssertNil(AndroidCompatibleRecordsRepository.topTwentyPosition(newValue: 0, existingValues: []))
        XCTAssertEqual(
            AndroidCompatibleRecordsRepository.topTwentyPosition(newValue: 90, existingValues: [100, 90, 90]),
            2
        )
        XCTAssertEqual(
            AndroidCompatibleRecordsRepository.topTwentyPosition(
                newValue: 1,
                existingValues: Array(2...20).map { Int64($0) }
            ),
            20
        )
        XCTAssertNil(
            AndroidCompatibleRecordsRepository.topTwentyPosition(
                newValue: 1,
                existingValues: Array(1...20).map { Int64($0) }
            )
        )
    }

    func testRemotePayloadUsesOnlyAllowlistedFieldsAndNeverLocalName() async throws {
        let localChildName = "Maya Local Child"
        let suiteName = "RemoteRecordsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let identityStore = AndroidCompatibleRecordsIdentityStore(
            product: .minikPlus,
            ownerID: scope.ownerID,
            userDefaults: defaults
        )
        let playerID = try await identityStore.playerID()
        defaults.set(
            localChildName,
            forKey: "minik.records.name.v1.\(ProductVariant.minikPlus.rawValue).records_name_\(playerID)"
        )
        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let stateStore = InMemoryPublicLeaderboardStateStore(state: PublicLeaderboardLocalState(
            participationEnabled: true,
            selectedAlias: alias,
            pendingCandidate: nil
        ))
        let repository = AndroidCompatibleRecordsRepository(
            configuration: try XCTUnwrap(RemoteRecordsConfiguration.androidCompatible(for: .minikPlus)),
            dataSource: dataSource,
            ownershipStore: TestRemoteRecordsOwnershipStore(),
            identityProvider: identityStore,
            publicAliasProvider: stateStore,
            participationProvider: stateStore
        )

        let result = try await repository.submit(candidate(points: 50, streak: 8))
        guard case .saved(let placements) = result else {
            return XCTFail("Expected both qualifying records to be saved.")
        }
        XCTAssertEqual(Set(placements.map(\.type)), [.score, .correctAnswersStreak])
        XCTAssertTrue(placements.allSatisfy { $0.position == 1 })

        let batches = await dataSource.recordedWriteBatches()
        let writes = try XCTUnwrap(batches.first)
        XCTAssertEqual(writes.count, 2)
        XCTAssertTrue(writes.allSatisfy { $0.documentID == playerID })
        let allowedKeys: Set<String> = [
            "app_id", "player_id", "score", "correct_answers_in_row",
            "date_achived", "user_name", "avatar_id"
        ]
        XCTAssertTrue(writes.allSatisfy { Set($0.fields.keys).isSubset(of: allowedKeys) })
        XCTAssertTrue(writes.allSatisfy { $0.fields["user_name"] == .string(alias.publicAlias) })
        XCTAssertTrue(writes.allSatisfy { $0.fields["avatar_id"] == .string("star") })
        XCTAssertFalse(writes.contains { write in
            write.fields.values.contains(.string(localChildName))
        })
        XCTAssertFalse(writes.flatMap { $0.fields.keys }.contains("local_name"))
        let scoreWrite = try XCTUnwrap(writes.first { $0.collection == "score_records" })
        XCTAssertEqual(scoreWrite.fields["app_id"], .string("3"))
        XCTAssertEqual(scoreWrite.fields["player_id"], .string(playerID))
        XCTAssertEqual(scoreWrite.fields["score"], .integer(50))
        XCTAssertEqual(scoreWrite.fields["correct_answers_in_row"], .integer(8))
        XCTAssertEqual(scoreWrite.fields["date_achived"], .serverTimestamp)
    }

    func testEqualOrBetterCurrentParticipantRecordIsNotOverwritten() async throws {
        let dataSource = FakeRemoteRecordsDataSource(results: [
            "score_records": RemoteRecordsQueryResult(
                documents: [scoreDocument(
                    id: testSecurePlayerID,
                    playerID: testSecurePlayerID,
                    score: 50,
                    streak: 8,
                    publicAlias: alias.publicAlias
                )],
                isFromCache: false
            ),
            "correct_answers_in_row": RemoteRecordsQueryResult(
                documents: [streakDocument(
                    id: testSecurePlayerID,
                    playerID: testSecurePlayerID,
                    streak: 8,
                    publicAlias: alias.publicAlias
                )],
                isFromCache: false
            )
        ])
        let repository = makeRepository(dataSource: dataSource, playerID: testSecurePlayerID)

        let result = try await repository.submit(candidate(points: 50, streak: 8))

        XCTAssertEqual(result, .noNewRecord)
        let writeBatches = await dataSource.recordedWriteBatches()
        XCTAssertTrue(writeBatches.isEmpty)
    }

    func testNoRemoteWriteBeforeAliasSelectionAndAliasSelectionPublishesPendingScore() async throws {
        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let stateStore = InMemoryPublicLeaderboardStateStore()
        let repository = makeRepository(dataSource: dataSource, stateStore: stateStore)
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: repository,
            localStateStore: stateStore
        )

        let firstResult = await service.submit(
            state: RewardState(points: 12, currentStreak: 2, bestStreak: 3),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        XCTAssertEqual(firstResult, .publicAliasRequired)
        var queries = await dataSource.recordedQueries()
        var writeBatches = await dataSource.recordedWriteBatches()
        // Only the public Top 20 is read to decide whether the score qualifies.
        XCTAssertEqual(queries.count, 2)
        XCTAssertTrue(writeBatches.isEmpty)

        let aliasResult = await service.selectPublicAliasAndRetry(alias)
        guard case .saved = aliasResult else {
            return XCTFail("Expected curated alias selection to publish the pending record.")
        }
        queries = await dataSource.recordedQueries()
        writeBatches = await dataSource.recordedWriteBatches()
        let publishedState = await service.localState()
        XCTAssertEqual(queries.count, 4)
        XCTAssertEqual(writeBatches.count, 1)
        XCTAssertEqual(publishedState.selectedAlias, alias)
        XCTAssertTrue(publishedState.participationEnabled)
        XCTAssertNil(publishedState.pendingCandidate)
    }

    func testAliasPromptOnlyForAQualifyingScoreAndNotAfterParentOptOut() async throws {
        let fullBoard = (1...20).map { index in
            scoreDocument(
                id: "v2_full_\(index)",
                playerID: "v2_full_\(index)",
                score: Int64(1_000 + index),
                streak: 0,
                publicAlias: "Brave Panda \(index)"
            )
        }
        let fullStreaks = (1...20).map { index in
            streakDocument(
                id: "v2_full_\(index)",
                playerID: "v2_full_\(index)",
                streak: Int64(500 + index),
                publicAlias: "Brave Panda \(index)"
            )
        }
        let dataSource = FakeRemoteRecordsDataSource(results: [
            "score_records": RemoteRecordsQueryResult(documents: fullBoard, isFromCache: false),
            "correct_answers_in_row": RemoteRecordsQueryResult(documents: fullStreaks, isFromCache: false)
        ])
        let stateStore = InMemoryPublicLeaderboardStateStore()
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: makeRepository(dataSource: dataSource, stateStore: stateStore),
            localStateStore: stateStore
        )

        let lowScore = await service.submit(
            state: RewardState(points: 12, bestStreak: 3),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        XCTAssertEqual(lowScore, .noNewRecord)
        let lowScoreWrites = await dataSource.recordedWriteBatches()
        XCTAssertTrue(lowScoreWrites.isEmpty)

        let qualifying = await service.submit(
            state: RewardState(points: 5_000, bestStreak: 3),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_100)
        )
        XCTAssertEqual(qualifying, .publicAliasRequired)

        _ = await service.setParticipationEnabled(false)
        let queriesBeforeOptOutSubmit = await dataSource.recordedQueries().count
        let optedOut = await service.submit(
            state: RewardState(points: 6_000, bestStreak: 3),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_200)
        )
        XCTAssertEqual(optedOut, .participationDisabled)
        let queriesAfterOptOutSubmit = await dataSource.recordedQueries().count
        XCTAssertEqual(queriesAfterOptOutSubmit, queriesBeforeOptOutSubmit)
    }

    func testNotNowWaitsForABetterScoreBeforeAskingAgain() async throws {
        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let stateStore = InMemoryPublicLeaderboardStateStore()
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: makeRepository(dataSource: dataSource, stateStore: stateStore),
            localStateStore: stateStore
        )

        let first = await service.submit(
            state: RewardState(points: 20, bestStreak: 4),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        XCTAssertEqual(first, .publicAliasRequired)
        await service.dismissPublicAliasPrompt()

        let sameBest = await service.submit(
            state: RewardState(points: 20, bestStreak: 4),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_100)
        )
        XCTAssertEqual(sameBest, .noNewRecord)

        let betterBest = await service.submit(
            state: RewardState(points: 25, bestStreak: 4),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_200)
        )
        XCTAssertEqual(betterBest, .publicAliasRequired)
        let writes = await dataSource.recordedWriteBatches()
        XCTAssertTrue(writes.isEmpty)
    }

    func testPendingScoreSurvivesMissingFirebaseConfiguration() async {
        let stateStore = InMemoryPublicLeaderboardStateStore(state: PublicLeaderboardLocalState(
            participationEnabled: true,
            selectedAlias: alias,
            pendingCandidate: nil
        ))
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: nil,
            localStateStore: stateStore
        )

        let result = await service.submit(
            state: RewardState(points: 31, bestStreak: 5),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )

        XCTAssertEqual(result, .notConfigured)
        let pendingState = await service.localState()
        XCTAssertEqual(pendingState.pendingCandidate?.points, 31)
        XCTAssertEqual(pendingState.pendingCandidate?.bestStreak, 5)
    }

    func testNoRemoteWriteWithoutAuthAndPendingRetriesAfterAnonymousAuthIsAvailable() async {
        let rawDataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let authentication = FakeRemoteRecordsAuthentication(isAvailable: false)
        let authenticatedDataSource = AuthenticatedRemoteRecordsDataSource(
            dataSource: rawDataSource,
            authentication: authentication
        )
        let stateStore = InMemoryPublicLeaderboardStateStore(state: PublicLeaderboardLocalState(
            participationEnabled: true,
            selectedAlias: alias,
            pendingCandidate: nil
        ))
        let repository = AndroidCompatibleRecordsRepository(
            configuration: RemoteRecordsConfiguration.androidCompatible(for: .minikPlus)!,
            dataSource: authenticatedDataSource,
            ownershipStore: AuthenticatedRemoteRecordsOwnershipStore(
                dataSource: rawDataSource,
                authentication: authentication
            ),
            identityProvider: StaticAnonymousRecordsIdentityProvider(id: testSecurePlayerID),
            publicAliasProvider: stateStore,
            participationProvider: stateStore
        )
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: repository,
            localStateStore: stateStore
        )

        let unavailableResult = await service.submit(
            state: RewardState(points: 44, bestStreak: 7),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
        XCTAssertEqual(unavailableResult, .failed)
        let unavailableWrites = await rawDataSource.recordedWriteBatches()
        let pendingState = await service.localState()
        XCTAssertTrue(unavailableWrites.isEmpty)
        XCTAssertEqual(pendingState.pendingCandidate?.points, 44)

        await authentication.setAvailable(true)
        let retryResult = await service.setParticipationEnabled(true)
        guard case .saved = retryResult else {
            return XCTFail("Expected the pending score to publish after anonymous auth recovered.")
        }
        let recoveredWrites = await rawDataSource.recordedWriteBatches()
        let recoveredOwnershipClaims = await rawDataSource.recordedOwnershipClaims()
        let recoveredState = await service.localState()
        let recoveredIdentity = await authentication.lastIdentity()
        XCTAssertEqual(recoveredWrites.count, 1)
        XCTAssertEqual(recoveredOwnershipClaims, [
            RemoteRecordsOwnershipClaim(
                playerID: testSecurePlayerID,
                ownerUID: "firebase-anonymous-uid"
            )
        ])
        XCTAssertNil(recoveredState.pendingCandidate)
        XCTAssertEqual(recoveredIdentity, "firebase-anonymous-uid")
    }

    func testFutureRecordsReuseAliasAndDisablingStopsUploadsImmediately() async throws {
        let enabledState = PublicLeaderboardLocalState(
            participationEnabled: true,
            selectedAlias: alias,
            pendingCandidate: nil
        )
        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let stateStore = InMemoryPublicLeaderboardStateStore(state: enabledState)
        let repository = makeRepository(dataSource: dataSource, stateStore: stateStore)
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: repository,
            localStateStore: stateStore
        )

        guard case .saved = await service.submit(
            state: RewardState(points: 20, bestStreak: 4),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_000)
        ) else {
            return XCTFail("Expected an enabled future record to upload.")
        }
        let firstWriteBatches = await dataSource.recordedWriteBatches()
        let firstBatch = try XCTUnwrap(firstWriteBatches.first)
        XCTAssertTrue(firstBatch.allSatisfy { $0.fields["user_name"] == .string(alias.publicAlias) })

        let disableResult = await service.setParticipationEnabled(false)
        XCTAssertEqual(disableResult, .noEligibleValue)
        let queryCount = await dataSource.recordedQueries().count
        let batchCount = await dataSource.recordedWriteBatches().count
        let disabledResult = await service.submit(
            state: RewardState(points: 30, bestStreak: 6),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_720_000_000)
        )
        XCTAssertEqual(disabledResult, .participationDisabled)
        let disabledQueries = await dataSource.recordedQueries()
        let disabledWriteBatches = await dataSource.recordedWriteBatches()
        let disabledState = await service.localState()
        XCTAssertEqual(disabledQueries.count, queryCount)
        XCTAssertEqual(disabledWriteBatches.count, batchCount)
        XCTAssertEqual(disabledState.selectedAlias, alias)
        XCTAssertEqual(disabledState.pendingCandidate?.points, 30)
    }

    func testDeletionRemovesPublicDocumentsWithoutDeletingLocalProgress() async throws {
        let suiteName = "RemoteRecordsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let rewardRepository = LocalRewardRepository(
            userDefaults: defaults,
            storageKey: "test.local.rewards"
        )
        let localRewardService = LocalRewardService(repository: rewardRepository)
        _ = try localRewardService.process(
            RewardEvent(scope: scope, reason: .correctAnswer, occurredAt: Date()),
            policy: .androidWordPracticeReference
        )
        let localProgressBeforeDeletion = try rewardRepository.loadLedger().state(for: scope)

        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let stateStore = InMemoryPublicLeaderboardStateStore(state: PublicLeaderboardLocalState(
            participationEnabled: false,
            selectedAlias: alias,
            pendingCandidate: candidate(points: 9, streak: 2)
        ))
        let repository = makeRepository(
            dataSource: dataSource,
            playerID: testSecurePlayerID,
            stateStore: stateStore
        )
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: repository,
            localStateStore: stateStore
        )

        let deleted = await service.deletePublicRecords()
        let deletionBatches = await dataSource.recordedDeletionBatches()
        let stateAfterDeletion = await service.localState()
        XCTAssertTrue(deleted)
        XCTAssertEqual(Set(deletionBatches.flatMap { $0.map(\.collection) }), [
            "score_records", "correct_answers_in_row"
        ])
        XCTAssertEqual(
            try rewardRepository.loadLedger().state(for: scope),
            localProgressBeforeDeletion
        )
        XCTAssertEqual(stateAfterDeletion.selectedAlias, alias)
        XCTAssertNotNil(stateAfterDeletion.pendingCandidate)
    }

    func testAliasGeneratorProducesOnlyCuratedTypedValuesAndRejectsFreeText() throws {
        var generator = SeededGenerator(seed: 0xC0FFEE)
        let choices = PublicLeaderboardAliasGenerator().choices(count: 24, using: &generator)

        XCTAssertEqual(choices.count, 24)
        XCTAssertEqual(Set(choices).count, choices.count)
        XCTAssertTrue(choices.allSatisfy { PublicLeaderboardAlias.numberRange.contains($0.number) })
        XCTAssertTrue(choices.allSatisfy {
            PublicLeaderboardAlias.validatedRemoteAlias($0.publicAlias) == $0.publicAlias
        })
        // iOS's own alias stays curated: free text never decodes as this device's alias.
        let arbitraryJSON = Data(#"{"adjective":"Uncurated","noun":"Otter","number":27,"avatar":"star"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(PublicLeaderboardAlias.self, from: arbitraryJSON))
    }

    /// Android's approved public names (typed, at most five characters) are shown as written, like
    /// iOS aliases, under the shared Firestore user_name contract (1...32 characters, no outer spaces).
    func testRemoteNamesFromEitherPlatformAreShownUnderTheSharedContract() {
        XCTAssertEqual(PublicLeaderboardAlias.validatedRemoteAlias("Maya"), "Maya")
        XCTAssertEqual(PublicLeaderboardAlias.validatedRemoteAlias("נועה"), "נועה")
        XCTAssertEqual(PublicLeaderboardAlias.validatedRemoteAlias("  Tom1 "), "Tom1")
        XCTAssertEqual(PublicLeaderboardAlias.validatedRemoteAlias("Bright Otter 27"), "Bright Otter 27")
        XCTAssertEqual(PublicLeaderboardAlias.validatedRemoteAlias(String(repeating: "a", count: 32)),
                       String(repeating: "a", count: 32))
        XCTAssertNil(PublicLeaderboardAlias.validatedRemoteAlias(String(repeating: "a", count: 33)))
        XCTAssertNil(PublicLeaderboardAlias.validatedRemoteAlias(""))
        XCTAssertNil(PublicLeaderboardAlias.validatedRemoteAlias("   "))
        XCTAssertNil(PublicLeaderboardAlias.validatedRemoteAlias("Ma\nya"))
        XCTAssertNil(PublicLeaderboardAlias.validatedRemoteAlias("Ma\u{202E}ya"))
        XCTAssertNil(PublicLeaderboardAlias.validatedRemoteAlias("Ma\u{2066}ya"))
    }

    func testAliasAndParticipationPreferencePersistIndependentlyPerLocalProfile() async throws {
        let suiteName = "RemoteRecordsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstScope = RewardScope(ownerID: RewardOwnerID(rawValue: "child-1"), product: .minikPlus)
        let secondScope = RewardScope(ownerID: RewardOwnerID(rawValue: "child-2"), product: .minikPlus)
        let firstStore = UserDefaultsPublicLeaderboardStateStore(scope: firstScope, userDefaults: defaults)
        let secondStore = UserDefaultsPublicLeaderboardStateStore(scope: secondScope, userDefaults: defaults)
        try await firstStore.saveState(PublicLeaderboardLocalState(
            participationEnabled: false,
            selectedAlias: alias,
            pendingCandidate: nil
        ))

        let firstState = await firstStore.loadState()
        let secondState = await secondStore.loadState()
        XCTAssertEqual(firstState.selectedAlias, alias)
        XCTAssertFalse(firstState.participationEnabled)
        XCTAssertNil(secondState.selectedAlias)
        XCTAssertTrue(secondState.participationEnabled)
    }

    func testIdentityIsStableAndScopedByProductAndLocalProfile() async throws {
        let suiteName = "RemoteRecordsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = AndroidCompatibleRecordsIdentityStore(
            product: .minikPlus,
            ownerID: RewardOwnerID(rawValue: "child-1"),
            userDefaults: defaults
        )
        let second = AndroidCompatibleRecordsIdentityStore(
            product: .minikPlus,
            ownerID: RewardOwnerID(rawValue: "child-2"),
            userDefaults: defaults
        )
        let otherProduct = AndroidCompatibleRecordsIdentityStore(
            product: .minikPlusEnglish,
            ownerID: RewardOwnerID(rawValue: "child-1"),
            userDefaults: defaults
        )

        let firstID = try await first.playerID()
        let repeatedFirstID = try await first.playerID()
        let secondID = try await second.playerID()
        let otherProductID = try await otherProduct.playerID()
        XCTAssertEqual(repeatedFirstID, firstID)
        XCTAssertNotEqual(secondID, firstID)
        XCTAssertNotEqual(otherProductID, firstID)
        XCTAssertTrue(SecureLeaderboardParticipantID.isValid(firstID))
    }

    func testOneAnonymousUIDCanOwnMultipleDistinctChildProfiles() async throws {
        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let authentication = FakeRemoteRecordsAuthentication(
            isAvailable: true,
            identity: "anonymous-owner-a"
        )
        let ownership = AuthenticatedRemoteRecordsOwnershipStore(
            dataSource: dataSource,
            authentication: authentication
        )
        let firstPlayerID = "v2_00000000-0000-4000-8000-000000000011"
        let secondPlayerID = "v2_00000000-0000-4000-8000-000000000012"

        try await ownership.ensureOwnership(of: firstPlayerID)
        try await ownership.ensureOwnership(of: secondPlayerID)

        let claims = await dataSource.recordedOwnershipClaims()
        XCTAssertEqual(Set(claims.map(\.playerID)), [firstPlayerID, secondPlayerID])
        XCTAssertTrue(claims.allSatisfy { $0.ownerUID == "anonymous-owner-a" })
    }

    func testAnotherAnonymousUIDCannotTakeOverOwnedParticipant() async throws {
        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let first = AuthenticatedRemoteRecordsOwnershipStore(
            dataSource: dataSource,
            authentication: FakeRemoteRecordsAuthentication(
                isAvailable: true,
                identity: "anonymous-owner-a"
            )
        )
        let second = AuthenticatedRemoteRecordsOwnershipStore(
            dataSource: dataSource,
            authentication: FakeRemoteRecordsAuthentication(
                isAvailable: true,
                identity: "anonymous-owner-b"
            )
        )

        try await first.ensureOwnership(of: testSecurePlayerID)
        do {
            try await second.ensureOwnership(of: testSecurePlayerID)
            XCTFail("A second anonymous UID must not take over an owned participant.")
        } catch {
            XCTAssertEqual(error as? FakeOwnershipError, .alreadyOwned)
        }
    }

    func testLegacyParticipantCannotBeClaimedAndLocalBestRepublishesWithSecureID() async throws {
        let suiteName = "RemoteRecordsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacyPlayerID = "10000000-0000-4000-8000-000000000099"
        defaults.set(
            legacyPlayerID,
            forKey: "minik.records.player-id.v1.\(ProductVariant.minikPlus.rawValue).\(scope.ownerID.rawValue)"
        )
        defaults.set(
            legacyPlayerID,
            forKey: "minik.records.player-id.v1.\(ProductVariant.minikPlus.rawValue)"
        )
        let identityStore = AndroidCompatibleRecordsIdentityStore(
            product: .minikPlus,
            ownerID: scope.ownerID,
            userDefaults: defaults
        )
        let securePlayerID = try await identityStore.playerID()
        XCTAssertNotEqual(securePlayerID, legacyPlayerID)
        XCTAssertTrue(SecureLeaderboardParticipantID.isValid(securePlayerID))

        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let stateStore = InMemoryPublicLeaderboardStateStore(state: PublicLeaderboardLocalState(
            participationEnabled: true,
            selectedAlias: alias,
            pendingCandidate: nil
        ))
        let repository = AndroidCompatibleRecordsRepository(
            configuration: try XCTUnwrap(RemoteRecordsConfiguration.androidCompatible(for: .minikPlus)),
            dataSource: dataSource,
            ownershipStore: TestRemoteRecordsOwnershipStore(),
            identityProvider: identityStore,
            publicAliasProvider: stateStore,
            participationProvider: stateStore
        )
        let service = RewardRecordSubmissionService(
            scope: scope,
            repository: repository,
            localStateStore: stateStore
        )

        let result = await service.submit(
            state: RewardState(points: 73, bestStreak: 11),
            scope: scope,
            achievedAt: Date(timeIntervalSince1970: 1_730_000_000)
        )

        guard case .saved = result else {
            return XCTFail("Expected the retained local best to republish under a secure participant ID.")
        }
        let writeBatches = await dataSource.recordedWriteBatches()
        let writes = writeBatches.flatMap { $0 }
        XCTAssertFalse(writes.isEmpty)
        XCTAssertTrue(writes.allSatisfy { $0.documentID == securePlayerID })
        XCTAssertFalse(writes.contains { $0.documentID == legacyPlayerID })
    }

    func testLegacyPlayerIDCannotReachOwnershipClaimSource() async {
        let dataSource = FakeRemoteRecordsDataSource(results: emptyResults())
        let ownership = AuthenticatedRemoteRecordsOwnershipStore(
            dataSource: dataSource,
            authentication: FakeRemoteRecordsAuthentication(isAvailable: true)
        )

        do {
            try await ownership.ensureOwnership(of: "10000000-0000-4000-8000-000000000099")
            XCTFail("Legacy participant IDs must never be claimable by a new auth session.")
        } catch {
            XCTAssertEqual(error as? RemoteRecordsRepositoryError, .identityUnavailable)
        }
        let claims = await dataSource.recordedOwnershipClaims()
        XCTAssertTrue(claims.isEmpty)
    }

    @MainActor
    func testLeaderboardViewModelExposesNotConfiguredAndFailureStates() async {
        let unavailable = RecordsLeaderboardViewModel(repository: nil)
        await unavailable.load()
        XCTAssertEqual(unavailable.state, .notConfigured)

        let failing = RecordsLeaderboardViewModel(repository: FailingRecordsRepository())
        await failing.load()
        XCTAssertEqual(failing.state, .failed)
    }

    private func makeRepository(
        dataSource: FakeRemoteRecordsDataSource,
        product: ProductVariant = .minikPlus,
        playerID: String = testSecurePlayerID,
        stateStore: InMemoryPublicLeaderboardStateStore? = nil
    ) -> AndroidCompatibleRecordsRepository {
        let provider = stateStore ?? InMemoryPublicLeaderboardStateStore(state: PublicLeaderboardLocalState(
            participationEnabled: true,
            selectedAlias: alias,
            pendingCandidate: nil
        ))
        return AndroidCompatibleRecordsRepository(
            configuration: RemoteRecordsConfiguration.androidCompatible(for: product)!,
            dataSource: dataSource,
            ownershipStore: TestRemoteRecordsOwnershipStore(),
            identityProvider: StaticAnonymousRecordsIdentityProvider(id: playerID),
            publicAliasProvider: provider,
            participationProvider: provider
        )
    }

    private func candidate(points: Int64, streak: Int) -> RewardRecordCandidate {
        RewardRecordCandidate(
            scope: scope,
            points: points,
            bestStreak: streak,
            achievedAt: Date(timeIntervalSince1970: 1_710_000_000)
        )
    }

    private func emptyResults() -> [String: RemoteRecordsQueryResult] {
        [
            "score_records": RemoteRecordsQueryResult(documents: [], isFromCache: false),
            "correct_answers_in_row": RemoteRecordsQueryResult(documents: [], isFromCache: false)
        ]
    }

    private func scoreDocument(
        id: String,
        playerID: String,
        score: Int64,
        streak: Int64,
        date: Date? = nil,
        publicAlias: String,
        avatarID: String? = nil
    ) -> RemoteRecordDocument {
        var fields: [String: RemoteRecordValue] = [
            "app_id": .string("3"),
            "player_id": .string(playerID),
            "score": .integer(score),
            "correct_answers_in_row": .integer(streak),
            "user_name": .string(publicAlias)
        ]
        if let date { fields["date_achived"] = .date(date) }
        if let avatarID { fields["avatar_id"] = .string(avatarID) }
        return RemoteRecordDocument(documentID: id, fields: fields)
    }

    private func streakDocument(
        id: String,
        playerID: String,
        streak: Int64,
        date: Date? = nil,
        publicAlias: String,
        avatarID: String? = nil
    ) -> RemoteRecordDocument {
        var fields: [String: RemoteRecordValue] = [
            "app_id": .string("3"),
            "player_id": .string(playerID),
            "correct_answers_in_row": .integer(streak),
            "user_name": .string(publicAlias)
        ]
        if let date { fields["date_achived"] = .date(date) }
        if let avatarID { fields["avatar_id"] = .string(avatarID) }
        return RemoteRecordDocument(documentID: id, fields: fields)
    }
}

private struct StaticAnonymousRecordsIdentityProvider: ExistingRecordsIdentityProviding {
    let id: String

    func playerID() async throws -> String { id }
    func existingPlayerID() async -> String? { id }
}

private actor InMemoryPublicLeaderboardStateStore: PublicLeaderboardStateStoring {
    private var state: PublicLeaderboardLocalState

    init(state: PublicLeaderboardLocalState = PublicLeaderboardLocalState()) {
        self.state = state
    }

    func loadState() async -> PublicLeaderboardLocalState { state }
    func saveState(_ state: PublicLeaderboardLocalState) async throws { self.state = state }
    func selectedPublicAlias() async -> PublicLeaderboardAlias? { state.selectedAlias }
    func isLeaderboardParticipationEnabled() async -> Bool { state.participationEnabled }
}

private struct TestRemoteRecordsOwnershipStore: RemoteRecordsOwnershipSecuring {
    func ensureOwnership(of playerID: String) async throws {
        guard SecureLeaderboardParticipantID.isValid(playerID) else {
            throw RemoteRecordsRepositoryError.identityUnavailable
        }
    }
}

private enum FakeOwnershipError: Error, Equatable {
    case alreadyOwned
}

private actor FakeRemoteRecordsDataSource: RemoteRecordsDataSource, RemoteRecordsOwnershipClaiming {
    private let results: [String: RemoteRecordsQueryResult]
    private var queries: [RemoteRecordsQuery] = []
    private var writeBatches: [[RemoteRecordsWrite]] = []
    private var deletionBatches: [[RemoteRecordsDeletion]] = []
    private var ownershipClaims: [RemoteRecordsOwnershipClaim] = []
    private var ownersByPlayerID: [String: String] = [:]

    init(results: [String: RemoteRecordsQueryResult]) {
        self.results = results
    }

    func query(_ query: RemoteRecordsQuery) async throws -> RemoteRecordsQueryResult {
        queries.append(query)
        guard let result = results[query.collection] else {
            throw RemoteRecordsRepositoryError.loadFailed
        }
        return result
    }

    func mergeAtomically(_ writes: [RemoteRecordsWrite]) async throws {
        writeBatches.append(writes)
    }

    func deleteAtomically(_ deletions: [RemoteRecordsDeletion]) async throws {
        deletionBatches.append(deletions)
    }

    func claimOwnership(_ claim: RemoteRecordsOwnershipClaim) async throws {
        if let existingOwner = ownersByPlayerID[claim.playerID],
           existingOwner != claim.ownerUID {
            throw FakeOwnershipError.alreadyOwned
        }
        ownersByPlayerID[claim.playerID] = claim.ownerUID
        ownershipClaims.append(claim)
    }

    func recordedQueries() -> [RemoteRecordsQuery] { queries }
    func recordedWriteBatches() -> [[RemoteRecordsWrite]] { writeBatches }
    func recordedDeletionBatches() -> [[RemoteRecordsDeletion]] { deletionBatches }
    func recordedOwnershipClaims() -> [RemoteRecordsOwnershipClaim] { ownershipClaims }
}

private enum FakeAuthenticationError: Error {
    case unavailable
}

private actor FakeRemoteRecordsAuthentication: RemoteRecordsAuthenticating {
    private var isAvailable: Bool
    private var authenticatedIdentity: String?
    private let identity: String

    init(isAvailable: Bool, identity: String = "firebase-anonymous-uid") {
        self.isAvailable = isAvailable
        self.identity = identity
    }

    func setAvailable(_ isAvailable: Bool) {
        self.isAvailable = isAvailable
    }

    func ensureAuthenticated() async throws -> String {
        guard isAvailable else { throw FakeAuthenticationError.unavailable }
        authenticatedIdentity = identity
        return identity
    }

    func lastIdentity() -> String? { authenticatedIdentity }
}

private actor FailingRecordsRepository: RecordsRepository {
    func loadTopRecords() async throws -> RemoteRecordsSnapshot {
        throw RemoteRecordsRepositoryError.loadFailed
    }

    func submit(_ candidate: RewardRecordCandidate) async throws -> RemoteRecordSubmissionResult {
        throw RemoteRecordsRepositoryError.saveFailed
    }

    func deleteParticipantRecords() async throws {
        throw RemoteRecordsRepositoryError.deleteFailed
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return state
    }
}
