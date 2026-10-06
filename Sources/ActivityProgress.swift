import Foundation

struct ProgressActivityID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A progress activity identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct ActivitySessionID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct ActivityItemID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "An activity item identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

enum ActivityFamily: String, Hashable, Codable, Sendable {
    case learn
    case multipleChoice
    case buildNumber
    case buildQuantity
    case buildMath
    case buildWord
    case mixed
    case cards
    case pairs
    case memory
    case tower
    case soccer
    case ticTacToe
    case pingPong
}

enum GradedAttemptResult: String, Hashable, Codable, Sendable {
    case correct
    case incorrect
    case skipped
}

struct ActivityAttemptData: Hashable, Codable, Sendable {
    let itemID: ActivityItemID
    let attemptIndex: Int
    let result: GradedAttemptResult
    let responseDurationSeconds: Double?
    let activityFamily: ActivityFamily
    let mathLevelID: MathCurriculumLevelID?
    let skillID: SkillID?
    let languageContentItemID: ContentItemID?
    let languageVocabularyLevel: LanguageVocabularyLevel?

    init?(
        itemID: ActivityItemID,
        attemptIndex: Int,
        result: GradedAttemptResult,
        responseDurationSeconds: Double? = nil,
        activityFamily: ActivityFamily,
        mathLevelID: MathCurriculumLevelID? = nil,
        skillID: SkillID? = nil,
        languageContentItemID: ContentItemID? = nil,
        languageVocabularyLevel: LanguageVocabularyLevel? = nil
    ) {
        guard attemptIndex > 0,
              responseDurationSeconds.map({ $0 >= 0 && $0.isFinite }) ?? true else {
            return nil
        }
        self.itemID = itemID
        self.attemptIndex = attemptIndex
        self.result = result
        self.responseDurationSeconds = responseDurationSeconds
        self.activityFamily = activityFamily
        self.mathLevelID = mathLevelID
        self.skillID = skillID
        self.languageContentItemID = languageContentItemID
        self.languageVocabularyLevel = languageVocabularyLevel
    }

    var isFirstAttempt: Bool { attemptIndex == 1 }
}

struct ActivityEventContext: Hashable, Codable, Sendable {
    let product: ProductVariant
    let activityID: ProgressActivityID
    let curriculumStageID: CurriculumStageID?
    let skillID: SkillID?

    init(
        product: ProductVariant,
        activityID: ProgressActivityID,
        curriculumStageID: CurriculumStageID? = nil,
        skillID: SkillID? = nil
    ) {
        self.product = product
        self.activityID = activityID
        self.curriculumStageID = curriculumStageID
        self.skillID = skillID
    }
}

enum ActivityEventKind: String, Hashable, Codable, Sendable {
    case sessionStarted
    case sessionEnded
    case attempted
    case answeredCorrectly
    case answeredIncorrectly
    case skipped
    case advanced
    case completed
    case matchCompleted
    case gradedAttempt
}

struct ActivityEvent: Hashable, Codable, Sendable {
    let id: UUID
    let sessionID: ActivitySessionID
    let context: ActivityEventContext
    let kind: ActivityEventKind
    let occurredAt: Date
    let practiceDurationSeconds: Double?
    let attemptData: ActivityAttemptData?

    init?(
        id: UUID = UUID(),
        sessionID: ActivitySessionID,
        context: ActivityEventContext,
        kind: ActivityEventKind,
        occurredAt: Date,
        practiceDurationSeconds: Double? = nil,
        attemptData: ActivityAttemptData? = nil
    ) {
        guard practiceDurationSeconds.map({ $0 >= 0 && $0.isFinite }) ?? true,
              (kind == .gradedAttempt) == (attemptData != nil) else {
            return nil
        }
        self.id = id
        self.sessionID = sessionID
        self.context = context
        self.kind = kind
        self.occurredAt = occurredAt
        self.practiceDurationSeconds = practiceDurationSeconds
        self.attemptData = attemptData
    }
}

protocol ActivityEventSink: AnyObject {
    func record(_ event: ActivityEvent) throws
}

struct ActivityProgressSummary: Hashable, Codable, Sendable {
    let context: ActivityEventContext
    private(set) var sessionsStarted = 0
    private(set) var sessionsEnded = 0
    private(set) var attempts = 0
    private(set) var correctAnswers = 0
    private(set) var incorrectAnswers = 0
    private(set) var skips = 0
    private(set) var advances = 0
    private(set) var completions = 0
    private(set) var completedMatches = 0
    private(set) var gradedAttempts = 0
    private(set) var firstAttemptCorrectAnswers = 0
    private(set) var firstAttemptIncorrectAnswers = 0
    private(set) var firstAttemptSkips = 0
    private(set) var practiceDurationSeconds = 0.0
    private(set) var lastPracticedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case context
        case sessionsStarted
        case sessionsEnded
        case attempts
        case correctAnswers
        case incorrectAnswers
        case skips
        case advances
        case completions
        case completedMatches
        case gradedAttempts
        case firstAttemptCorrectAnswers
        case firstAttemptIncorrectAnswers
        case firstAttemptSkips
        case practiceDurationSeconds
        case lastPracticedAt
    }

    init(context: ActivityEventContext) {
        self.context = context
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        context = try container.decode(ActivityEventContext.self, forKey: .context)
        sessionsStarted = try container.decode(Int.self, forKey: .sessionsStarted)
        sessionsEnded = try container.decode(Int.self, forKey: .sessionsEnded)
        attempts = try container.decode(Int.self, forKey: .attempts)
        correctAnswers = try container.decode(Int.self, forKey: .correctAnswers)
        incorrectAnswers = try container.decode(Int.self, forKey: .incorrectAnswers)
        skips = try container.decode(Int.self, forKey: .skips)
        advances = try container.decode(Int.self, forKey: .advances)
        completions = try container.decode(Int.self, forKey: .completions)
        completedMatches = try container.decode(Int.self, forKey: .completedMatches)
        gradedAttempts = try container.decodeIfPresent(Int.self, forKey: .gradedAttempts) ?? 0
        firstAttemptCorrectAnswers = try container.decodeIfPresent(
            Int.self,
            forKey: .firstAttemptCorrectAnswers
        ) ?? 0
        firstAttemptIncorrectAnswers = try container.decodeIfPresent(
            Int.self,
            forKey: .firstAttemptIncorrectAnswers
        ) ?? 0
        firstAttemptSkips = try container.decodeIfPresent(
            Int.self,
            forKey: .firstAttemptSkips
        ) ?? 0
        practiceDurationSeconds = try container.decode(
            Double.self,
            forKey: .practiceDurationSeconds
        )
        lastPracticedAt = try container.decodeIfPresent(Date.self, forKey: .lastPracticedAt)
    }

    mutating func apply(_ event: ActivityEvent) {
        precondition(event.context == context)
        switch event.kind {
        case .sessionStarted: sessionsStarted += 1
        case .sessionEnded: sessionsEnded += 1
        case .attempted: attempts += 1
        case .answeredCorrectly: correctAnswers += 1
        case .answeredIncorrectly: incorrectAnswers += 1
        case .skipped: skips += 1
        case .advanced: advances += 1
        case .completed: completions += 1
        case .matchCompleted: completedMatches += 1
        case .gradedAttempt:
            guard let attempt = event.attemptData else {
                preconditionFailure("A graded-attempt event requires typed attempt data.")
            }
            gradedAttempts += 1
            attempts += 1
            switch attempt.result {
            case .correct:
                correctAnswers += 1
                if attempt.isFirstAttempt { firstAttemptCorrectAnswers += 1 }
            case .incorrect:
                incorrectAnswers += 1
                if attempt.isFirstAttempt { firstAttemptIncorrectAnswers += 1 }
            case .skipped:
                skips += 1
                if attempt.isFirstAttempt { firstAttemptSkips += 1 }
            }
        }
        practiceDurationSeconds += event.practiceDurationSeconds
            ?? event.attemptData?.responseDurationSeconds
            ?? 0
        if lastPracticedAt.map({ event.occurredAt > $0 }) ?? true {
            lastPracticedAt = event.occurredAt
        }
    }
}

struct ProgressSnapshot: Hashable, Codable, Sendable {
    private(set) var summaries: [ActivityProgressSummary]
    private(set) var appliedEventIDs: Set<UUID>

    init(
        summaries: [ActivityProgressSummary] = [],
        appliedEventIDs: Set<UUID> = []
    ) {
        self.summaries = summaries
        self.appliedEventIDs = appliedEventIDs
    }

    mutating func apply(_ event: ActivityEvent) {
        guard appliedEventIDs.insert(event.id).inserted else { return }
        if let index = summaries.firstIndex(where: { $0.context == event.context }) {
            summaries[index].apply(event)
        } else {
            var summary = ActivityProgressSummary(context: event.context)
            summary.apply(event)
            summaries.append(summary)
            summaries.sort { lhs, rhs in
                let first = "\(lhs.context.product.rawValue).\(lhs.context.activityID.rawValue)"
                let second = "\(rhs.context.product.rawValue).\(rhs.context.activityID.rawValue)"
                return first < second
            }
        }
    }

    func summary(for context: ActivityEventContext) -> ActivityProgressSummary? {
        summaries.first { $0.context == context }
    }

    private enum CodingKeys: String, CodingKey {
        case summaries
        case appliedEventIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summaries = try container.decode([ActivityProgressSummary].self, forKey: .summaries)
        appliedEventIDs = try container.decodeIfPresent(
            Set<UUID>.self,
            forKey: .appliedEventIDs
        ) ?? []
    }
}

protocol ProgressRepository: AnyObject {
    func loadSnapshot() throws -> ProgressSnapshot
    func saveSnapshot(_ snapshot: ProgressSnapshot) throws
}

enum ProgressRepositoryError: Error, Equatable {
    case unsupportedSchema(found: Int, supported: Int)
    case encodingFailed
    case decodingFailed
}

final class LocalProgressRepository: ProgressRepository, ActivityEventSink {
    static let schemaVersion = 1

    private struct Envelope: Codable {
        let schemaVersion: Int
        let snapshot: ProgressSnapshot
    }

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "minik.activity-progress.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func loadSnapshot() throws -> ProgressSnapshot {
        guard let data = userDefaults.data(forKey: storageKey) else { return ProgressSnapshot() }
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            throw ProgressRepositoryError.decodingFailed
        }
        guard envelope.schemaVersion == Self.schemaVersion else {
            throw ProgressRepositoryError.unsupportedSchema(
                found: envelope.schemaVersion,
                supported: Self.schemaVersion
            )
        }
        return envelope.snapshot
    }

    func saveSnapshot(_ snapshot: ProgressSnapshot) throws {
        let data: Data
        do {
            data = try encoder.encode(Envelope(schemaVersion: Self.schemaVersion, snapshot: snapshot))
        } catch {
            throw ProgressRepositoryError.encodingFailed
        }
        userDefaults.set(data, forKey: storageKey)
    }

    func record(_ event: ActivityEvent) throws {
        var snapshot = try loadSnapshot()
        snapshot.apply(event)
        try saveSnapshot(snapshot)
    }
}
