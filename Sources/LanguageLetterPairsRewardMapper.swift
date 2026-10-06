enum LanguageLetterPairsRewardMapper {
    static func rewardEvent(for activityEvent: ActivityEvent) -> RewardEvent? {
        guard activityEvent.kind == .gradedAttempt,
              activityEvent.context.activityID.rawValue == "language.letterPairs",
              (activityEvent.context.product == .minikPlus ||
                activityEvent.context.product == .minikPlusEnglish),
              let attempt = activityEvent.attemptData,
              attempt.activityFamily == .pairs,
              attempt.skillID == LanguageSkillIDs.initialLetterAssociation,
              attempt.mathLevelID == nil else {
            return nil
        }

        let reason: RewardReason
        switch attempt.result {
        case .correct:
            reason = .pairMatched
        case .incorrect:
            reason = .incorrectAnswer
        case .skipped:
            return nil
        }

        return RewardEvent(
            id: activityEvent.id,
            sourceActivityEventID: activityEvent.id,
            scope: RewardScope(
                ownerID: .localDefault,
                product: activityEvent.context.product
            ),
            reason: reason,
            occurredAt: activityEvent.occurredAt
        )
    }
}
