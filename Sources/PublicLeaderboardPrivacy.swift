import Combine
import Foundation

enum PublicLeaderboardAliasAdjective: String, CaseIterable, Codable, Sendable {
    case bright = "Bright"
    case brave = "Brave"
    case clever = "Clever"
    case cosmic = "Cosmic"
    case friendly = "Friendly"
    case happy = "Happy"
    case mighty = "Mighty"
    case playful = "Playful"
    case quick = "Quick"
    case sunny = "Sunny"
    case `super` = "Super"
    case wise = "Wise"
}

enum PublicLeaderboardAliasNoun: String, CaseIterable, Codable, Sendable {
    case dolphin = "Dolphin"
    case fox = "Fox"
    case koala = "Koala"
    case lion = "Lion"
    case otter = "Otter"
    case owl = "Owl"
    case panda = "Panda"
    case penguin = "Penguin"
    case rabbit = "Rabbit"
    case tiger = "Tiger"
    case turtle = "Turtle"
    case whale = "Whale"
}

enum PublicLeaderboardAvatar: String, CaseIterable, Codable, Sendable {
    case bolt
    case leaf
    case moon
    case rainbow
    case rocket
    case star

    var symbolName: String {
        switch self {
        case .bolt: return "bolt.fill"
        case .leaf: return "leaf.fill"
        case .moon: return "moon.stars.fill"
        case .rainbow: return "rainbow"
        case .rocket: return "rocket.fill"
        case .star: return "star.fill"
        }
    }
}

struct PublicLeaderboardAlias: Hashable, Identifiable, Sendable, Codable {
    static let numberRange = 1...99

    let adjective: PublicLeaderboardAliasAdjective
    let noun: PublicLeaderboardAliasNoun
    let number: Int
    let avatar: PublicLeaderboardAvatar?

    var id: String {
        "\(adjective.rawValue).\(noun.rawValue).\(number).\(avatar?.rawValue ?? "none")"
    }

    var publicAlias: String {
        "\(adjective.rawValue) \(noun.rawValue) \(number)"
    }

    var avatarID: String? { avatar?.rawValue }

    init?(
        adjective: PublicLeaderboardAliasAdjective,
        noun: PublicLeaderboardAliasNoun,
        number: Int,
        avatar: PublicLeaderboardAvatar?
    ) {
        guard Self.numberRange.contains(number) else { return nil }
        self.adjective = adjective
        self.noun = noun
        self.number = number
        self.avatar = avatar
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let adjective = try container.decode(PublicLeaderboardAliasAdjective.self, forKey: .adjective)
        let noun = try container.decode(PublicLeaderboardAliasNoun.self, forKey: .noun)
        let number = try container.decode(Int.self, forKey: .number)
        let avatar = try container.decodeIfPresent(PublicLeaderboardAvatar.self, forKey: .avatar)
        guard let alias = Self(
            adjective: adjective,
            noun: noun,
            number: number,
            avatar: avatar
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .number,
                in: container,
                debugDescription: "Public leaderboard alias number is outside the curated range."
            )
        }
        self = alias
    }

    /// firestore.rules accepts a `user_name` of 1...32 characters with no leading or trailing whitespace.
    static let maximumRemoteAliasLength = 32

    /// A remote record's public name, shown as published under the shared Firestore contract. iOS publishes
    /// its curated "Adjective Noun Number" aliases; Android publishes the public name the child types (at most
    /// five characters) and approves it. Both are shown as written. Control characters, line separators and
    /// bidirectional embeddings, overrides and isolates are refused so a name cannot reorder or hide the rest
    /// of the row; such a record shows as "Player".
    static func validatedRemoteAlias(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.count <= maximumRemoteAliasLength,
              !normalized.unicodeScalars.contains(where: isDisallowedRemoteAliasScalar) else {
            return nil
        }
        return normalized
    }

    private static func isDisallowedRemoteAliasScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .lineSeparator, .paragraphSeparator:
            return true
        default:
            return (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value)
        }
    }
}

struct PublicLeaderboardAliasGenerator: Sendable {
    static let defaultChoiceCount = 4

    func choices(count: Int = Self.defaultChoiceCount) -> [PublicLeaderboardAlias] {
        var generator = SystemRandomNumberGenerator()
        return choices(count: count, using: &generator)
    }

    func choices<Generator: RandomNumberGenerator>(
        count: Int = Self.defaultChoiceCount,
        using generator: inout Generator
    ) -> [PublicLeaderboardAlias] {
        guard count > 0 else { return [] }
        let avatarOptions: [PublicLeaderboardAvatar?] = [nil]
            + PublicLeaderboardAvatar.allCases.map(Optional.some)
        let maximumCount = PublicLeaderboardAliasAdjective.allCases.count
            * PublicLeaderboardAliasNoun.allCases.count
            * PublicLeaderboardAlias.numberRange.count
            * avatarOptions.count
        let targetCount = min(count, maximumCount)
        var choices: [PublicLeaderboardAlias] = []
        var seen = Set<PublicLeaderboardAlias>()

        while choices.count < targetCount {
            let adjective = PublicLeaderboardAliasAdjective.allCases.randomElement(using: &generator)!
            let noun = PublicLeaderboardAliasNoun.allCases.randomElement(using: &generator)!
            let number = Int.random(in: PublicLeaderboardAlias.numberRange, using: &generator)
            let avatar = avatarOptions.randomElement(using: &generator) ?? nil
            let alias = PublicLeaderboardAlias(
                adjective: adjective,
                noun: noun,
                number: number,
                avatar: avatar
            )!
            if seen.insert(alias).inserted {
                choices.append(alias)
            }
        }

        return choices
    }
}

struct PublicLeaderboardLocalState: Equatable, Sendable, Codable {
    var participationEnabled = true
    var selectedAlias: PublicLeaderboardAlias?
    var pendingCandidate: RewardRecordCandidate?
    /// The best values shown when the child last chose "Not now". The alias
    /// prompt returns only after a better score, as on Android.
    var dismissedAliasPromptCandidate: RewardRecordCandidate?

    private enum CodingKeys: String, CodingKey {
        case participationEnabled
        case selectedAlias
        case pendingCandidate
        case dismissedAliasPromptCandidate
    }

    init(
        participationEnabled: Bool = true,
        selectedAlias: PublicLeaderboardAlias? = nil,
        pendingCandidate: RewardRecordCandidate? = nil,
        dismissedAliasPromptCandidate: RewardRecordCandidate? = nil
    ) {
        self.participationEnabled = participationEnabled
        self.selectedAlias = selectedAlias
        self.pendingCandidate = pendingCandidate
        self.dismissedAliasPromptCandidate = dismissedAliasPromptCandidate
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedAlias = try container.decodeIfPresent(PublicLeaderboardAlias.self, forKey: .selectedAlias)
        pendingCandidate = try container.decodeIfPresent(RewardRecordCandidate.self, forKey: .pendingCandidate)
        dismissedAliasPromptCandidate = try container.decodeIfPresent(
            RewardRecordCandidate.self,
            forKey: .dismissedAliasPromptCandidate
        )
        // Approval-gated v1 data has no explicit opt-out preference. Preserve
        // its alias/pending candidate while adopting the new enabled default.
        participationEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .participationEnabled
        ) ?? true
    }

    mutating func stage(_ candidate: RewardRecordCandidate) {
        guard let existing = pendingCandidate else {
            pendingCandidate = candidate
            return
        }
        let points = max(existing.points, candidate.points)
        let streak = max(existing.bestStreak, candidate.bestStreak)
        guard points != existing.points || streak != existing.bestStreak else { return }
        pendingCandidate = RewardRecordCandidate(
            scope: candidate.scope,
            points: points,
            bestStreak: streak,
            achievedAt: candidate.achievedAt
        )
    }
}

enum PublicLeaderboardLocalStoreError: Error, Equatable, Sendable {
    case encodingFailed
}

protocol PublicLeaderboardAliasProviding: Sendable {
    func selectedPublicAlias() async -> PublicLeaderboardAlias?
}

protocol PublicLeaderboardParticipationProviding: Sendable {
    func isLeaderboardParticipationEnabled() async -> Bool
}

protocol PublicLeaderboardStateStoring:
    PublicLeaderboardAliasProviding,
    PublicLeaderboardParticipationProviding,
    Sendable {
    func loadState() async -> PublicLeaderboardLocalState
    func saveState(_ state: PublicLeaderboardLocalState) async throws
}

actor UserDefaultsPublicLeaderboardStateStore: PublicLeaderboardStateStoring {
    private static let schemaVersion = 1

    private struct Envelope: Codable {
        let schemaVersion: Int
        let state: PublicLeaderboardLocalState
    }

    let scope: RewardScope
    private let userDefaults: UserDefaults
    private let storageKeyPrefix: String

    init(
        scope: RewardScope,
        userDefaults: UserDefaults = .standard,
        storageKeyPrefix: String = "minik.public-leaderboard.v1"
    ) {
        self.scope = scope
        self.userDefaults = userDefaults
        self.storageKeyPrefix = storageKeyPrefix
    }

    func loadState() async -> PublicLeaderboardLocalState {
        guard let data = userDefaults.data(forKey: storageKey),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schemaVersion == Self.schemaVersion,
              envelope.state.pendingCandidate?.scope == nil
                || envelope.state.pendingCandidate?.scope == scope else {
            return PublicLeaderboardLocalState()
        }
        return envelope.state
    }

    func saveState(_ state: PublicLeaderboardLocalState) async throws {
        guard state.pendingCandidate?.scope == nil || state.pendingCandidate?.scope == scope,
              let data = try? JSONEncoder().encode(Envelope(
                schemaVersion: Self.schemaVersion,
                state: state
              )) else {
            throw PublicLeaderboardLocalStoreError.encodingFailed
        }
        userDefaults.set(data, forKey: storageKey)
    }

    func selectedPublicAlias() async -> PublicLeaderboardAlias? {
        (await loadState()).selectedAlias
    }

    func isLeaderboardParticipationEnabled() async -> Bool {
        (await loadState()).participationEnabled
    }

    private var storageKey: String {
        "\(storageKeyPrefix).\(scope.product.rawValue).\(scope.ownerID.rawValue)"
    }
}

@MainActor
final class PublicLeaderboardController: ObservableObject {
    enum Status: Equatable {
        case idle
        case working
        case enabled
        case enabledWaitingForAlias
        case enabledPendingRetry
        case disabled
        case deleted
        case failed
    }

    @Published private(set) var localState = PublicLeaderboardLocalState()
    @Published private(set) var status: Status = .idle

    private let service: RewardRecordSubmissionService

    init(service: RewardRecordSubmissionService) {
        self.service = service
    }

    var participationEnabled: Bool { localState.participationEnabled }
    var selectedAlias: PublicLeaderboardAlias? { localState.selectedAlias }
    var hasPendingPublication: Bool { localState.pendingCandidate != nil }
    var isWorking: Bool { status == .working }

    func refresh() async {
        localState = await service.localState()
    }

    func setParticipationEnabled(_ enabled: Bool) async {
        status = .working
        let result = await service.setParticipationEnabled(enabled)
        localState = await service.localState()
        guard enabled else {
            status = .disabled
            return
        }

        switch result {
        case .saved, .noEligibleValue, .noNewRecord:
            status = .enabled
        case .publicAliasRequired:
            status = .enabledWaitingForAlias
        case .notConfigured, .participationDisabled:
            status = .enabledPendingRetry
        case .failed:
            status = localState.participationEnabled ? .enabledPendingRetry : .failed
        }
    }

    func selectPublicAlias(_ alias: PublicLeaderboardAlias) async {
        status = .working
        let result = await service.selectPublicAliasAndRetry(alias)
        localState = await service.localState()
        switch result {
        case .saved, .noEligibleValue, .noNewRecord:
            status = localState.participationEnabled ? .enabled : .disabled
        case .publicAliasRequired:
            status = .enabledWaitingForAlias
        case .notConfigured, .participationDisabled:
            status = localState.participationEnabled ? .enabledPendingRetry : .disabled
        case .failed:
            status = localState.participationEnabled ? .enabledPendingRetry : .failed
        }
    }

    func deletePublicRecords() async {
        status = .working
        let deleted = await service.deletePublicRecords()
        localState = await service.localState()
        status = deleted ? .deleted : .failed
    }
}
