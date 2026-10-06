enum LanguageChoiceRewardMapper {
    static func rewardEvent(for event: ActivityEvent) -> RewardEvent? {
        let routes: Set<String> = [
            "language.firstLetterChoices", "language.firstLetterPictures",
            "language.imageToWord", "language.wordToImage", "language.mixed"
        ]
        let skills: Set<SkillID> = [
            LanguageSkillIDs.initialLetterAssociation, LanguageSkillIDs.wordImageAssociation,
            LanguageSkillIDs.wordRecognition
        ]
        guard event.kind == .gradedAttempt,
              event.context.product == .minikPlus || event.context.product == .minikPlusEnglish,
              routes.contains(event.context.activityID.rawValue),
              let attempt = event.attemptData,
              (attempt.activityFamily == .multipleChoice ||
               (event.context.activityID.rawValue == "language.mixed" && attempt.activityFamily == .mixed)),
              let skill = attempt.skillID, skills.contains(skill),
              attempt.mathLevelID == nil else { return nil }
        let reason: RewardReason
        switch attempt.result {
        case .correct: reason = .correctAnswer
        case .incorrect: reason = .incorrectAnswer
        case .skipped: return nil
        }
        return RewardEvent(
            id: event.id, sourceActivityEventID: event.id,
            scope: RewardScope(ownerID: .localDefault, product: event.context.product),
            reason: reason, occurredAt: event.occurredAt
        )
    }
}
