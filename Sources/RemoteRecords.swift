import Foundation

struct RemoteScoreRecord: Hashable, Sendable, Identifiable {
    let documentID: String
    let appID: String
    let playerID: String
    let score: Int64
    let correctAnswersInRow: Int64
    let dateAchieved: Date?
    let publicAlias: String
    let avatarID: String?

    var id: String { documentID }
}

struct RemoteStreakRecord: Hashable, Sendable, Identifiable {
    let documentID: String
    let appID: String
    let playerID: String
    let correctAnswersInRow: Int64
    let dateAchieved: Date?
    let publicAlias: String
    let avatarID: String?

    var id: String { documentID }
}

struct RemoteRecordsSnapshot: Hashable, Sendable {
    let scoreRecords: [RemoteScoreRecord]
    let streakRecords: [RemoteStreakRecord]
    let isFromCache: Bool

    var isEmpty: Bool { scoreRecords.isEmpty && streakRecords.isEmpty }
}

enum RemoteRecordType: String, Hashable, Sendable {
    case score
    case correctAnswersStreak
}

struct RemoteRecordPlacement: Hashable, Sendable {
    let type: RemoteRecordType
    let position: Int
    let previousPosition: Int?
    let value: Int64

    var positionImproved: Bool {
        guard let previousPosition else { return true }
        return position < previousPosition
    }
}

enum RemoteRecordSubmissionResult: Hashable, Sendable {
    case noNewRecord
    case saved([RemoteRecordPlacement])
}

enum RemoteRecordsRepositoryError: Error, Equatable, Sendable {
    case unsupportedProduct(ProductVariant)
    case identityUnavailable
    case participationDisabled
    case publicAliasRequired
    case malformedDocument(collection: String, documentID: String)
    case loadFailed
    case saveFailed
    case deleteFailed
}

protocol RecordsRepository: AnyObject, Sendable {
    func loadTopRecords() async throws -> RemoteRecordsSnapshot
    func submit(_ candidate: RewardRecordCandidate) async throws -> RemoteRecordSubmissionResult
    func deleteParticipantRecords() async throws
}

enum RewardRecordSyncResult: Equatable, Sendable {
    case notConfigured
    case noEligibleValue
    case noNewRecord
    case publicAliasRequired
    case participationDisabled
    case saved([RemoteRecordPlacement])
    case failed
}

actor RewardRecordSubmissionService {
    private let scope: RewardScope
    private let repository: (any RecordsRepository)?
    private let localStateStore: any PublicLeaderboardStateStoring

    init(
        scope: RewardScope,
        repository: (any RecordsRepository)?,
        localStateStore: any PublicLeaderboardStateStoring
    ) {
        self.scope = scope
        self.repository = repository
        self.localStateStore = localStateStore
    }

    func submit(
        state: RewardState,
        scope: RewardScope,
        achievedAt: Date
    ) async -> RewardRecordSyncResult {
        guard state.points > 0 || state.bestStreak > 0 else {
            return .noEligibleValue
        }

        let candidate = RewardRecordCandidate(
            scope: scope,
            points: state.points,
            bestStreak: state.bestStreak,
            achievedAt: achievedAt
        )
        guard candidate.scope == scope else { return .failed }

        var localState = await localStateStore.loadState()
        localState.stage(candidate)
        do {
            try await localStateStore.saveState(localState)
        } catch {
            return .failed
        }
        // A parent opt-out wins over asking the child for an alias.
        guard localState.participationEnabled else { return .participationDisabled }
        guard localState.selectedAlias != nil else { return await aliasPromptDecision(for: localState) }
        return await publishPendingCandidate()
    }

    /// Records "Not now" so the alias prompt waits for a better score.
    func dismissPublicAliasPrompt() async {
        var localState = await localStateStore.loadState()
        localState.dismissedAliasPromptCandidate = localState.pendingCandidate
        try? await localStateStore.saveState(localState)
    }

    /// As on Android and per the 2026-09-13 decision, the alias is offered only
    /// for a best that would enter the public Top 20, and not again after
    /// "Not now" until a better score. Only the public board is read here;
    /// nothing is written before an alias is chosen.
    private func aliasPromptDecision(for localState: PublicLeaderboardLocalState) async -> RewardRecordSyncResult {
        guard let candidate = localState.pendingCandidate else { return .noEligibleValue }
        if let dismissed = localState.dismissedAliasPromptCandidate,
           candidate.points <= dismissed.points,
           candidate.bestStreak <= dismissed.bestStreak {
            return .noNewRecord
        }
        guard let repository,
              let snapshot = try? await repository.loadTopRecords() else {
            return .noNewRecord
        }
        let scorePosition = AndroidCompatibleRecordsRepository.topTwentyPosition(
            newValue: candidate.points,
            existingValues: snapshot.scoreRecords.map(\.score)
        )
        let streakPosition = AndroidCompatibleRecordsRepository.topTwentyPosition(
            newValue: Int64(candidate.bestStreak),
            existingValues: snapshot.streakRecords.map(\.correctAnswersInRow)
        )
        return scorePosition != nil || streakPosition != nil ? .publicAliasRequired : .noNewRecord
    }

    func selectPublicAliasAndRetry(_ alias: PublicLeaderboardAlias) async -> RewardRecordSyncResult {
        var localState = await localStateStore.loadState()
        localState.selectedAlias = alias
        do {
            try await localStateStore.saveState(localState)
        } catch {
            return .failed
        }
        guard localState.pendingCandidate != nil else { return .noEligibleValue }
        guard localState.participationEnabled else { return .participationDisabled }
        return await publishPendingCandidate()
    }

    func setParticipationEnabled(_ enabled: Bool) async -> RewardRecordSyncResult {
        var localState = await localStateStore.loadState()
        localState.participationEnabled = enabled
        do {
            try await localStateStore.saveState(localState)
        } catch {
            return .failed
        }
        guard enabled else { return .noEligibleValue }
        guard localState.pendingCandidate != nil else { return .noEligibleValue }
        guard localState.selectedAlias != nil else { return .publicAliasRequired }
        return await publishPendingCandidate()
    }

    func localState() async -> PublicLeaderboardLocalState {
        await localStateStore.loadState()
    }

    func deletePublicRecords() async -> Bool {
        let localState = await localStateStore.loadState()
        guard !localState.participationEnabled, let repository else { return false }
        do {
            try await repository.deleteParticipantRecords()
            return true
        } catch {
            return false
        }
    }

    private func publishPendingCandidate() async -> RewardRecordSyncResult {
        var localState = await localStateStore.loadState()
        guard localState.participationEnabled else { return .participationDisabled }
        guard localState.selectedAlias != nil else { return .publicAliasRequired }
        guard let candidate = localState.pendingCandidate else { return .noEligibleValue }
        guard let repository else { return .notConfigured }

        do {
            switch try await repository.submit(candidate) {
            case .noNewRecord:
                localState.pendingCandidate = nil
                try await localStateStore.saveState(localState)
                return .noNewRecord
            case .saved(let placements):
                localState.pendingCandidate = nil
                try await localStateStore.saveState(localState)
                return .saved(placements)
            }
        } catch let error as RemoteRecordsRepositoryError where error == .participationDisabled {
            return .participationDisabled
        } catch let error as RemoteRecordsRepositoryError where error == .publicAliasRequired {
            return .publicAliasRequired
        } catch {
            // Local rewards remain authoritative when Firebase is unavailable.
            // A later activity exit provides another bounded submission attempt.
            return .failed
        }
    }
}

protocol AnonymousRecordsIdentityProviding: Sendable {
    func playerID() async throws -> String
}

protocol ExistingRecordsIdentityProviding: AnonymousRecordsIdentityProviding {
    func existingPlayerID() async -> String?
}

enum SecureLeaderboardParticipantID {
    static let prefix = "v2_"

    static func make() -> String {
        prefix + UUID().uuidString.lowercased()
    }

    static func isValid(_ value: String) -> Bool {
        guard value.hasPrefix(prefix),
              value.count == 39,
              value == value.lowercased() else { return false }
        return UUID(uuidString: String(value.dropFirst(prefix.count))) != nil
    }
}

actor AndroidCompatibleRecordsIdentityStore:
    AnonymousRecordsIdentityProviding,
    ExistingRecordsIdentityProviding {
    private let product: ProductVariant
    private let ownerID: RewardOwnerID
    private let userDefaults: UserDefaults
    private let identityKeyPrefix: String

    init(
        product: ProductVariant,
        ownerID: RewardOwnerID = .localDefault,
        userDefaults: UserDefaults = .standard,
        identityKeyPrefix: String = "minik.records.player-id.v2"
    ) {
        self.product = product
        self.ownerID = ownerID
        self.userDefaults = userDefaults
        self.identityKeyPrefix = identityKeyPrefix
    }

    func playerID() async throws -> String {
        if let existing = await existingPlayerID() {
            return existing
        }

        let created = SecureLeaderboardParticipantID.make()
        userDefaults.set(created, forKey: scopedIdentityKey)
        return created
    }

    func existingPlayerID() async -> String? {
        if let existing = normalizedID(forKey: scopedIdentityKey),
           SecureLeaderboardParticipantID.isValid(existing) {
            return existing
        }
        return nil
    }

    private var scopedIdentityKey: String {
        "\(identityKeyPrefix).\(product.rawValue).\(ownerID.rawValue)"
    }

    private func normalizedID(forKey key: String) -> String? {
        let value = userDefaults.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

enum RemoteRecordValue: Equatable, Sendable {
    case string(String)
    case integer(Int64)
    case date(Date)
    case serverTimestamp
}

struct RemoteRecordDocument: Equatable, Sendable {
    let documentID: String
    let fields: [String: RemoteRecordValue]
}

struct RemoteRecordsQuery: Hashable, Sendable {
    let collection: String
    let appID: String
    let orderField: String
    let limit: Int
}

struct RemoteRecordsQueryResult: Equatable, Sendable {
    let documents: [RemoteRecordDocument]
    let isFromCache: Bool
}

struct RemoteRecordsWrite: Equatable, Sendable {
    let collection: String
    let documentID: String
    let fields: [String: RemoteRecordValue]
}

struct RemoteRecordsDeletion: Equatable, Sendable {
    let collection: String
    let documentID: String
}

protocol RemoteRecordsDataSource: Sendable {
    func query(_ query: RemoteRecordsQuery) async throws -> RemoteRecordsQueryResult
    func mergeAtomically(_ writes: [RemoteRecordsWrite]) async throws
    func deleteAtomically(_ deletions: [RemoteRecordsDeletion]) async throws
}

protocol RemoteRecordsAuthenticating: Sendable {
    @discardableResult
    func ensureAuthenticated() async throws -> String
}

struct RemoteRecordsOwnershipClaim: Equatable, Sendable {
    let playerID: String
    let ownerUID: String
}

protocol RemoteRecordsOwnershipClaiming: Sendable {
    func claimOwnership(_ claim: RemoteRecordsOwnershipClaim) async throws
}

protocol RemoteRecordsOwnershipSecuring: Sendable {
    func ensureOwnership(of playerID: String) async throws
}

struct AuthenticatedRemoteRecordsOwnershipStore: RemoteRecordsOwnershipSecuring {
    let dataSource: any RemoteRecordsOwnershipClaiming
    let authentication: any RemoteRecordsAuthenticating

    func ensureOwnership(of playerID: String) async throws {
        guard SecureLeaderboardParticipantID.isValid(playerID) else {
            throw RemoteRecordsRepositoryError.identityUnavailable
        }
        let ownerUID = try await authentication.ensureAuthenticated()
        guard !ownerUID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RemoteRecordsRepositoryError.identityUnavailable
        }
        try await dataSource.claimOwnership(RemoteRecordsOwnershipClaim(
            playerID: playerID,
            ownerUID: ownerUID
        ))
    }
}

/// Keeps the authentication boundary in front of every Firestore operation.
/// The authenticator accepts no profile data, so a local child's name cannot
/// become either Firebase identity input or leaderboard document identity.
struct AuthenticatedRemoteRecordsDataSource: RemoteRecordsDataSource {
    let dataSource: any RemoteRecordsDataSource
    let authentication: any RemoteRecordsAuthenticating

    func query(_ query: RemoteRecordsQuery) async throws -> RemoteRecordsQueryResult {
        _ = try await authentication.ensureAuthenticated()
        return try await dataSource.query(query)
    }

    func mergeAtomically(_ writes: [RemoteRecordsWrite]) async throws {
        guard !writes.isEmpty else { return }
        _ = try await authentication.ensureAuthenticated()
        try await dataSource.mergeAtomically(writes)
    }

    func deleteAtomically(_ deletions: [RemoteRecordsDeletion]) async throws {
        guard !deletions.isEmpty else { return }
        _ = try await authentication.ensureAuthenticated()
        try await dataSource.deleteAtomically(deletions)
    }
}

struct RemoteRecordsConfiguration: Hashable, Sendable {
    static let appID = "3"
    static let topRecordsLimit = 20

    let product: ProductVariant
    let scoreCollection: String
    let streakCollection: String

    static func androidCompatible(for product: ProductVariant) -> RemoteRecordsConfiguration? {
        switch product {
        case .minikPlus:
            return RemoteRecordsConfiguration(
                product: product,
                scoreCollection: "score_records",
                streakCollection: "correct_answers_in_row"
            )
        case .minikPlusEnglish:
            // Android intentionally keeps the English-only score table separate while
            // continuing to use the established shared streak table.
            return RemoteRecordsConfiguration(
                product: product,
                scoreCollection: "score_records_english_only",
                streakCollection: "correct_answers_in_row"
            )
        case .minikMath, .minikPingPong:
            return nil
        }
    }
}

enum RemoteRecordsSchema {
    static let appID = "app_id"
    static let playerID = "player_id"
    static let score = "score"
    static let correctAnswersInRow = "correct_answers_in_row"
    // This legacy spelling is part of the existing Firestore schema.
    static let dateAchieved = "date_achived"
    static let userName = "user_name"
    static let avatarID = "avatar_id"
}

enum RemoteRecordsOwnershipSchema {
    static let collection = "leaderboard_owners"
    static let ownerUID = "owner_uid"
}

actor AndroidCompatibleRecordsRepository: RecordsRepository {
    private let configuration: RemoteRecordsConfiguration
    private let dataSource: any RemoteRecordsDataSource
    private let ownershipStore: any RemoteRecordsOwnershipSecuring
    private let identityProvider: any AnonymousRecordsIdentityProviding
    private let publicAliasProvider: any PublicLeaderboardAliasProviding
    private let participationProvider: any PublicLeaderboardParticipationProviding

    init(
        configuration: RemoteRecordsConfiguration,
        dataSource: any RemoteRecordsDataSource,
        ownershipStore: any RemoteRecordsOwnershipSecuring,
        identityProvider: any AnonymousRecordsIdentityProviding,
        publicAliasProvider: any PublicLeaderboardAliasProviding,
        participationProvider: any PublicLeaderboardParticipationProviding
    ) {
        self.configuration = configuration
        self.dataSource = dataSource
        self.ownershipStore = ownershipStore
        self.identityProvider = identityProvider
        self.publicAliasProvider = publicAliasProvider
        self.participationProvider = participationProvider
    }

    func loadTopRecords() async throws -> RemoteRecordsSnapshot {
        do {
            async let scoreResult = dataSource.query(RemoteRecordsQuery(
                collection: configuration.scoreCollection,
                appID: RemoteRecordsConfiguration.appID,
                orderField: RemoteRecordsSchema.score,
                limit: RemoteRecordsConfiguration.topRecordsLimit
            ))
            async let streakResult = dataSource.query(RemoteRecordsQuery(
                collection: configuration.streakCollection,
                appID: RemoteRecordsConfiguration.appID,
                orderField: RemoteRecordsSchema.correctAnswersInRow,
                limit: RemoteRecordsConfiguration.topRecordsLimit
            ))

            let (scores, streaks) = try await (scoreResult, streakResult)
            return RemoteRecordsSnapshot(
                scoreRecords: try scores.documents.map {
                    try Self.scoreRecord(from: $0, collection: configuration.scoreCollection)
                },
                streakRecords: try streaks.documents.map {
                    try Self.streakRecord(from: $0, collection: configuration.streakCollection)
                },
                isFromCache: scores.isFromCache || streaks.isFromCache
            )
        } catch let error as RemoteRecordsRepositoryError {
            throw error
        } catch {
            throw RemoteRecordsRepositoryError.loadFailed
        }
    }

    func submit(_ candidate: RewardRecordCandidate) async throws -> RemoteRecordSubmissionResult {
        guard candidate.scope.product == configuration.product else {
            throw RemoteRecordsRepositoryError.unsupportedProduct(candidate.scope.product)
        }
        guard await participationProvider.isLeaderboardParticipationEnabled() else {
            throw RemoteRecordsRepositoryError.participationDisabled
        }
        guard let publicAlias = await publicAliasProvider.selectedPublicAlias() else {
            throw RemoteRecordsRepositoryError.publicAliasRequired
        }

        let snapshot = try await loadTopRecords()
        let playerID: String
        do {
            playerID = try await identityProvider.playerID().trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw RemoteRecordsRepositoryError.identityUnavailable
        }
        guard SecureLeaderboardParticipantID.isValid(playerID) else {
            throw RemoteRecordsRepositoryError.identityUnavailable
        }

        let scorePosition = Self.topTwentyPosition(
            newValue: candidate.points,
            existingValues: snapshot.scoreRecords.map(\.score)
        )
        let streakValue = Int64(candidate.bestStreak)
        let streakPosition = Self.topTwentyPosition(
            newValue: streakValue,
            existingValues: snapshot.streakRecords.map(\.correctAnswersInRow)
        )
        let previousScorePosition = Self.currentPlayerPosition(
            playerID: playerID,
            records: snapshot.scoreRecords.map { ($0.playerID, $0.score) }
        )
        let previousStreakPosition = Self.currentPlayerPosition(
            playerID: playerID,
            records: snapshot.streakRecords.map { ($0.playerID, $0.correctAnswersInRow) }
        )
        let savesScore = scorePosition != nil && !snapshot.scoreRecords.contains {
            $0.playerID == playerID && $0.score >= candidate.points
        }
        let savesStreak = streakPosition != nil && !snapshot.streakRecords.contains {
            $0.playerID == playerID && $0.correctAnswersInRow >= streakValue
        }
        guard savesScore || savesStreak else { return .noNewRecord }

        var writes: [RemoteRecordsWrite] = []
        var placements: [RemoteRecordPlacement] = []
        if savesScore, let scorePosition {
            writes.append(RemoteRecordsWrite(
                collection: configuration.scoreCollection,
                documentID: playerID,
                fields: Self.scoreFields(
                    playerID: playerID,
                    publicAlias: publicAlias,
                    points: candidate.points,
                    bestStreak: streakValue
                )
            ))
            placements.append(RemoteRecordPlacement(
                type: .score,
                position: scorePosition,
                previousPosition: previousScorePosition,
                value: candidate.points
            ))
        }
        if savesStreak, let streakPosition {
            writes.append(RemoteRecordsWrite(
                collection: configuration.streakCollection,
                documentID: playerID,
                fields: Self.streakFields(
                    playerID: playerID,
                    publicAlias: publicAlias,
                    bestStreak: streakValue
                )
            ))
            placements.append(RemoteRecordPlacement(
                type: .correctAnswersStreak,
                position: streakPosition,
                previousPosition: previousStreakPosition,
                value: streakValue
            ))
        }

        guard await participationProvider.isLeaderboardParticipationEnabled() else {
            throw RemoteRecordsRepositoryError.participationDisabled
        }
        do {
            try await ownershipStore.ensureOwnership(of: playerID)
            try await dataSource.mergeAtomically(writes)
            return .saved(placements)
        } catch {
            throw RemoteRecordsRepositoryError.saveFailed
        }
    }

    func deleteParticipantRecords() async throws {
        guard let existingIdentityProvider = identityProvider as? any ExistingRecordsIdentityProviding,
              let existingPlayerID = await existingIdentityProvider.existingPlayerID() else {
            return
        }
        let playerID = existingPlayerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SecureLeaderboardParticipantID.isValid(playerID) else { return }
        let deletions = [
            RemoteRecordsDeletion(
                collection: configuration.scoreCollection,
                documentID: playerID
            ),
            RemoteRecordsDeletion(
                collection: configuration.streakCollection,
                documentID: playerID
            )
        ]
        do {
            try await ownershipStore.ensureOwnership(of: playerID)
            try await dataSource.deleteAtomically(deletions)
        } catch {
            throw RemoteRecordsRepositoryError.deleteFailed
        }
    }

    static func topTwentyPosition(newValue: Int64, existingValues: [Int64]) -> Int? {
        guard newValue > 0 else { return nil }
        let sorted = existingValues.sorted(by: >).prefix(RemoteRecordsConfiguration.topRecordsLimit)
        if sorted.count == RemoteRecordsConfiguration.topRecordsLimit,
           let last = sorted.last,
           newValue <= last {
            return nil
        }
        return sorted.filter { $0 > newValue }.count + 1
    }

    private static func currentPlayerPosition(
        playerID: String,
        records: [(playerID: String, value: Int64)]
    ) -> Int? {
        guard let best = records.filter({ $0.playerID == playerID }).map(\.value).max() else {
            return nil
        }
        return records.filter { $0.value > best }.count + 1
    }

    private static func scoreRecord(
        from document: RemoteRecordDocument,
        collection: String
    ) throws -> RemoteScoreRecord {
        guard !document.documentID.isEmpty else {
            throw RemoteRecordsRepositoryError.malformedDocument(
                collection: collection,
                documentID: document.documentID
            )
        }
        return RemoteScoreRecord(
            documentID: document.documentID,
            appID: document.string(RemoteRecordsSchema.appID),
            playerID: document.string(RemoteRecordsSchema.playerID),
            score: document.integer(RemoteRecordsSchema.score),
            correctAnswersInRow: document.integer(RemoteRecordsSchema.correctAnswersInRow),
            dateAchieved: document.date(RemoteRecordsSchema.dateAchieved),
            publicAlias: PublicLeaderboardAlias.validatedRemoteAlias(
                document.string(RemoteRecordsSchema.userName)
            ) ?? "",
            avatarID: document.validatedAvatarID(RemoteRecordsSchema.avatarID)
        )
    }

    private static func streakRecord(
        from document: RemoteRecordDocument,
        collection: String
    ) throws -> RemoteStreakRecord {
        guard !document.documentID.isEmpty else {
            throw RemoteRecordsRepositoryError.malformedDocument(
                collection: collection,
                documentID: document.documentID
            )
        }
        return RemoteStreakRecord(
            documentID: document.documentID,
            appID: document.string(RemoteRecordsSchema.appID),
            playerID: document.string(RemoteRecordsSchema.playerID),
            correctAnswersInRow: document.integer(RemoteRecordsSchema.correctAnswersInRow),
            dateAchieved: document.date(RemoteRecordsSchema.dateAchieved),
            publicAlias: PublicLeaderboardAlias.validatedRemoteAlias(
                document.string(RemoteRecordsSchema.userName)
            ) ?? "",
            avatarID: document.validatedAvatarID(RemoteRecordsSchema.avatarID)
        )
    }

    private static func scoreFields(
        playerID: String,
        publicAlias: PublicLeaderboardAlias,
        points: Int64,
        bestStreak: Int64
    ) -> [String: RemoteRecordValue] {
        var fields: [String: RemoteRecordValue] = [
            RemoteRecordsSchema.appID: .string(RemoteRecordsConfiguration.appID),
            RemoteRecordsSchema.playerID: .string(playerID),
            RemoteRecordsSchema.score: .integer(points),
            RemoteRecordsSchema.correctAnswersInRow: .integer(bestStreak),
            RemoteRecordsSchema.dateAchieved: .serverTimestamp,
            // user_name is the legacy Android field name. Its value is always
            // the curated public alias, never a local child/profile name.
            RemoteRecordsSchema.userName: .string(publicAlias.publicAlias)
        ]
        if let avatarID = publicAlias.avatarID {
            fields[RemoteRecordsSchema.avatarID] = .string(avatarID)
        }
        return fields
    }

    private static func streakFields(
        playerID: String,
        publicAlias: PublicLeaderboardAlias,
        bestStreak: Int64
    ) -> [String: RemoteRecordValue] {
        var fields: [String: RemoteRecordValue] = [
            RemoteRecordsSchema.appID: .string(RemoteRecordsConfiguration.appID),
            RemoteRecordsSchema.playerID: .string(playerID),
            RemoteRecordsSchema.correctAnswersInRow: .integer(bestStreak),
            RemoteRecordsSchema.dateAchieved: .serverTimestamp,
            RemoteRecordsSchema.userName: .string(publicAlias.publicAlias)
        ]
        if let avatarID = publicAlias.avatarID {
            fields[RemoteRecordsSchema.avatarID] = .string(avatarID)
        }
        return fields
    }
}

private extension RemoteRecordDocument {
    func string(_ key: String) -> String {
        guard case .string(let value) = fields[key] else { return "" }
        return value
    }

    func integer(_ key: String) -> Int64 {
        guard case .integer(let value) = fields[key] else { return 0 }
        return value
    }

    func date(_ key: String) -> Date? {
        guard case .date(let value) = fields[key] else { return nil }
        return value
    }

    func validatedAvatarID(_ key: String) -> String? {
        guard case .string(let value) = fields[key],
              PublicLeaderboardAvatar(rawValue: value) != nil else {
            return nil
        }
        return value
    }
}
