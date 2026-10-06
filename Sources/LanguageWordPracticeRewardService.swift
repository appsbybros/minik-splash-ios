import Foundation

/// Android WriteScreen's local bonus run is distinct from the persisted
/// displayed streak. Wrong Build letters reset the former without deducting
/// points or resetting the displayed streak; only the completed word scores.
final class LanguageWordPracticeRewardService {
    private let repository: RewardRepository
    private let service: LocalRewardService
    private var sessionID: ActivitySessionID?
    private(set) var cleanWordRun = 0

    init(repository: RewardRepository) {
        self.repository = repository
        service = LocalRewardService(repository: repository)
    }

    func processAttempt(_ event: ActivityEvent) throws {
        guard event.context.product == .minikPlus || event.context.product == .minikPlusEnglish,
              let attempt = event.attemptData, attempt.mathLevelID == nil else { return }
        guard !(try repository.loadLedger()).processedEventIDs.contains(event.id) else { return }
        if (event.context.activityID.rawValue == "language.wordBuild" || event.context.activityID.rawValue == "language.mixed"),
           (attempt.activityFamily == .buildWord || attempt.activityFamily == .mixed),
           attempt.skillID == LanguageSkillIDs.wordConstruction, attempt.result == .incorrect {
            try beginSession(event.sessionID, product: event.context.product)
            let marker = RewardEvent(
                id: event.id,
                sourceActivityEventID: event.id,
                scope: RewardScope(ownerID: .localDefault, product: event.context.product),
                reason: .incorrectAnswer,
                occurredAt: event.occurredAt
            )
            let policy = RewardPolicy(rules: [
                .incorrectAnswer: RewardRule(pointsDelta: 0, streakEffect: .unchanged)
            ])!
            if try service.process(marker, policy: policy) != nil { cleanWordRun = 0 }
            return
        }
        guard let reward = LanguageChoiceRewardMapper.rewardEvent(for: event),
              !(try repository.loadLedger()).processedEventIDs.contains(reward.id) else { return }
        try beginSession(event.sessionID, product: event.context.product)
        let correct = reward.reason == .correctAnswer
        let nextRun = correct ? increment(cleanWordRun) : 0
        let policy = RewardPolicy(rules: [
            reward.reason: RewardRule(pointsDelta: correct ? points(for: nextRun) : -1,
                                      streakEffect: correct ? .increment : .reset)
        ])!
        if try service.process(reward, policy: policy) != nil { cleanWordRun = nextRun }
    }

    func processCompletion(_ completion: LanguageWordCompletion, sessionID: ActivitySessionID,
                           product: ProductVariant, occurredAt: Date) throws {
        guard product == .minikPlus || product == .minikPlusEnglish,
              !(try repository.loadLedger()).processedEventIDs.contains(completion.id) else { return }
        try beginSession(sessionID, product: product)
        let nextRun = completion.hadIncorrectLetter ? 0 : increment(cleanWordRun)
        let event = RewardEvent(id: completion.id, sourceActivityEventID: completion.id,
                                scope: RewardScope(ownerID: .localDefault, product: product),
                                reason: .activityCompleted, occurredAt: occurredAt)
        let policy = RewardPolicy(rules: [
            .activityCompleted: RewardRule(pointsDelta: points(for: nextRun), streakEffect: .increment)
        ])!
        if try service.process(event, policy: policy) != nil { cleanWordRun = nextRun }
    }

    func beginSession(_ id: ActivitySessionID, product: ProductVariant) throws {
        guard sessionID != id else { return }
        let scope = RewardScope(ownerID: .localDefault, product: product)
        cleanWordRun = try repository.loadLedger().state(for: scope).currentStreak
        sessionID = id
    }

    private func increment(_ value: Int) -> Int { value == .max ? .max : value + 1 }

    private func points(for run: Int) -> Int64 {
        if run >= 20 { return 5 }
        if run >= 10 { return 4 }
        if run >= 5 { return 3 }
        if run >= 3 { return 2 }
        return 1
    }
}
