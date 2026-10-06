enum LanguageTowerRewardMapper {
    static func rewardEvent(for activityEvent: ActivityEvent) -> RewardEvent? {
        guard activityEvent.kind == .completed,
              activityEvent.context.activityID.rawValue == "language.tower",
              (activityEvent.context.product == .minikPlus
                || activityEvent.context.product == .minikPlusEnglish),
              activityEvent.context.skillID == LanguageSkillIDs.wordConstruction,
              activityEvent.attemptData == nil else {
            return nil
        }

        return RewardEvent(
            id: activityEvent.id,
            sourceActivityEventID: activityEvent.id,
            scope: RewardScope(
                ownerID: .localDefault,
                product: activityEvent.context.product
            ),
            reason: .activityCompleted,
            occurredAt: activityEvent.occurredAt
        )
    }
}
