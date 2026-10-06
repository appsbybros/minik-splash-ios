import Foundation

struct RewardOwnerID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A reward owner identifier cannot be empty.")
        self.rawValue = rawValue
    }

    static let localDefault = RewardOwnerID(rawValue: "local-default")
}

struct RewardScope: Hashable, Codable, Sendable {
    let ownerID: RewardOwnerID
    let product: ProductVariant
}

struct RewardState: Hashable, Codable, Sendable {
    fileprivate(set) var points: Int64
    fileprivate(set) var currentStreak: Int
    fileprivate(set) var bestStreak: Int

    init(points: Int64 = 0, currentStreak: Int = 0, bestStreak: Int = 0) {
        self.points = max(0, points)
        self.currentStreak = max(0, currentStreak)
        self.bestStreak = max(max(0, bestStreak), self.currentStreak)
    }
}

enum RewardReason: String, Hashable, Codable, Sendable {
    case correctAnswer
    case incorrectAnswer
    case pairMatched
    case activityCompleted
    case matchWon
    case matchDrawn
    case matchLost
}

struct RewardEvent: Hashable, Codable, Sendable {
    let id: UUID
    let sourceActivityEventID: UUID?
    let scope: RewardScope
    let reason: RewardReason
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        sourceActivityEventID: UUID? = nil,
        scope: RewardScope,
        reason: RewardReason,
        occurredAt: Date
    ) {
        self.id = id
        self.sourceActivityEventID = sourceActivityEventID
        self.scope = scope
        self.reason = reason
        self.occurredAt = occurredAt
    }
}

enum RewardStreakEffect: String, Hashable, Codable, Sendable {
    case increment
    case reset
    case unchanged
}

struct RewardRule: Hashable, Codable, Sendable {
    let pointsDelta: Int64
    let streakEffect: RewardStreakEffect
}

struct RewardStreakPointTier: Hashable, Codable, Sendable {
    let minimumResultingStreak: Int
    let points: Int64

    init?(minimumResultingStreak: Int, points: Int64) {
        guard minimumResultingStreak > 0, points >= 0 else { return nil }
        self.minimumResultingStreak = minimumResultingStreak
        self.points = points
    }
}

struct RewardPolicy: Sendable {
    let rules: [RewardReason: RewardRule]
    let correctAnswerPointTiers: [RewardStreakPointTier]

    init?(rules: [RewardReason: RewardRule], correctAnswerPointTiers: [RewardStreakPointTier] = []) {
        let sorted = correctAnswerPointTiers.sorted { $0.minimumResultingStreak < $1.minimumResultingStreak }
        guard Set(sorted.map(\.minimumResultingStreak)).count == sorted.count else { return nil }
        self.rules = rules
        self.correctAnswerPointTiers = sorted
    }

    func rule(for reason: RewardReason, currentState: RewardState) -> RewardRule? {
        guard var rule = rules[reason] else { return nil }
        if reason == .correctAnswer, !correctAnswerPointTiers.isEmpty {
            let nextStreak = currentState.currentStreak == .max ? Int.max : currentState.currentStreak + 1
            if let tier = correctAnswerPointTiers.last(where: { $0.minimumResultingStreak <= nextStreak }) {
                rule = RewardRule(pointsDelta: tier.points, streakEffect: rule.streakEffect)
            }
        }
        return rule
    }

    static var androidWordPracticeReference: RewardPolicy {
        RewardPolicy(
            rules: [
                .correctAnswer: RewardRule(pointsDelta: 1, streakEffect: .increment),
                .incorrectAnswer: RewardRule(pointsDelta: -1, streakEffect: .reset)
            ],
            correctAnswerPointTiers: [
                RewardStreakPointTier(minimumResultingStreak: 1, points: 1)!,
                RewardStreakPointTier(minimumResultingStreak: 3, points: 2)!,
                RewardStreakPointTier(minimumResultingStreak: 5, points: 3)!,
                RewardStreakPointTier(minimumResultingStreak: 10, points: 4)!,
                RewardStreakPointTier(minimumResultingStreak: 20, points: 5)!
            ]
        )!
    }

    static var androidLetterPairsReference: RewardPolicy {
        RewardPolicy(rules: [
            .pairMatched: RewardRule(pointsDelta: 1, streakEffect: .unchanged),
            .incorrectAnswer: RewardRule(pointsDelta: -1, streakEffect: .unchanged)
        ])!
    }

    static var androidTowerReference: RewardPolicy {
        RewardPolicy(rules: [
            .activityCompleted: RewardRule(
                pointsDelta: 2,
                streakEffect: .unchanged
            )
        ])!
    }

    static var androidPictureMemoryReference: RewardPolicy {
        RewardPolicy(rules: [
            .activityCompleted: RewardRule(
                pointsDelta: 2,
                streakEffect: .unchanged
            )
        ])!
    }

    static var androidSoccerReference: RewardPolicy {
        RewardPolicy(rules: [
            .matchWon: RewardRule(pointsDelta: 3, streakEffect: .unchanged),
            .matchDrawn: RewardRule(pointsDelta: 1, streakEffect: .unchanged)
        ])!
    }

    static var androidTicTacToeReference: RewardPolicy {
        RewardPolicy(rules: [
            .matchWon: RewardRule(pointsDelta: 2, streakEffect: .unchanged),
            .matchDrawn: RewardRule(pointsDelta: 1, streakEffect: .unchanged),
            .matchLost: RewardRule(pointsDelta: -1, streakEffect: .unchanged)
        ])!
    }
}

struct RewardProcessingResult: Hashable, Sendable {
    let event: RewardEvent
    let appliedRule: RewardRule
    let previousState: RewardState
    let state: RewardState
    let achievedNewBestStreak: Bool
}

struct RewardProcessor: Sendable {
    func process(
        _ event: RewardEvent,
        state: RewardState,
        policy: RewardPolicy
    ) -> RewardProcessingResult? {
        guard let rule = policy.rule(for: event.reason, currentState: state) else { return nil }
        var next = state
        next.points = addingClampedToNonnegative(state.points, rule.pointsDelta)
        switch rule.streakEffect {
        case .increment:
            next.currentStreak = state.currentStreak == .max ? .max : state.currentStreak + 1
        case .reset:
            next.currentStreak = 0
        case .unchanged:
            break
        }
        next.bestStreak = max(state.bestStreak, next.currentStreak)
        return RewardProcessingResult(
            event: event,
            appliedRule: rule,
            previousState: state,
            state: next,
            achievedNewBestStreak: next.bestStreak > state.bestStreak
        )
    }

    private func addingClampedToNonnegative(_ points: Int64, _ delta: Int64) -> Int64 {
        let (result, overflow) = points.addingReportingOverflow(delta)
        if overflow { return delta >= 0 ? .max : 0 }
        return max(0, result)
    }
}

struct RewardLedgerEntry: Hashable, Codable, Sendable {
    let scope: RewardScope
    var state: RewardState
}

struct RewardLedger: Hashable, Codable, Sendable {
    private(set) var entries: [RewardLedgerEntry]
    private(set) var processedEventIDs: Set<UUID>

    init(entries: [RewardLedgerEntry] = [], processedEventIDs: Set<UUID> = []) {
        self.entries = entries
        self.processedEventIDs = processedEventIDs
    }

    func state(for scope: RewardScope) -> RewardState {
        entries.first(where: { $0.scope == scope })?.state ?? RewardState()
    }

    mutating func store(_ state: RewardState, for event: RewardEvent) {
        if let index = entries.firstIndex(where: { $0.scope == event.scope }) {
            entries[index].state = state
        } else {
            entries.append(RewardLedgerEntry(scope: event.scope, state: state))
        }
        processedEventIDs.insert(event.id)
    }
}

protocol RewardRepository: AnyObject {
    func loadLedger() throws -> RewardLedger
    func saveLedger(_ ledger: RewardLedger) throws
}

struct RewardRecordCandidate: Hashable, Codable, Sendable {
    let scope: RewardScope
    let points: Int64
    let bestStreak: Int
    let achievedAt: Date
}

enum RewardRepositoryError: Error, Equatable {
    case unsupportedSchema(found: Int, supported: Int)
    case encodingFailed
    case decodingFailed
}

final class LocalRewardRepository: RewardRepository {
    static let schemaVersion = 1

    private struct Envelope: Codable {
        let schemaVersion: Int
        let ledger: RewardLedger
    }

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "minik.rewards.v1") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func loadLedger() throws -> RewardLedger {
        guard let data = userDefaults.data(forKey: storageKey) else { return RewardLedger() }
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw RewardRepositoryError.decodingFailed
        }
        guard envelope.schemaVersion == Self.schemaVersion else {
            throw RewardRepositoryError.unsupportedSchema(
                found: envelope.schemaVersion,
                supported: Self.schemaVersion
            )
        }
        return envelope.ledger
    }

    func saveLedger(_ ledger: RewardLedger) throws {
        do {
            userDefaults.set(
                try JSONEncoder().encode(Envelope(schemaVersion: Self.schemaVersion, ledger: ledger)),
                forKey: storageKey
            )
        } catch {
            throw RewardRepositoryError.encodingFailed
        }
    }
}

final class LocalRewardService {
    private let repository: RewardRepository
    private let processor: RewardProcessor

    init(repository: RewardRepository, processor: RewardProcessor = RewardProcessor()) {
        self.repository = repository
        self.processor = processor
    }

    func process(_ event: RewardEvent, policy: RewardPolicy) throws -> RewardProcessingResult? {
        var ledger = try repository.loadLedger()
        guard !ledger.processedEventIDs.contains(event.id) else { return nil }
        guard let result = processor.process(event, state: ledger.state(for: event.scope), policy: policy) else {
            return nil
        }
        ledger.store(result.state, for: event)
        try repository.saveLedger(ledger)
        return result
    }
}
