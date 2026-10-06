struct LanguageOrderedTokenAttemptTracker: Sendable {
    private struct Challenge: Hashable, Sendable {
        let presentationIndex: Int
        let contentItemID: ContentItemID
        let tokenIndex: Int
    }

    private var currentChallenge: Challenge?
    private var attemptCount = 0

    init() {}

    mutating func makeAttempt(
        presentationIndex: Int,
        contentItemID: ContentItemID,
        tokenIndex: Int,
        result: GradedAttemptResult,
        responseDurationSeconds: Double?,
        activityFamily: ActivityFamily,
        skillID: SkillID? = nil,
        languageVocabularyLevel: LanguageVocabularyLevel? = nil
    ) -> ActivityAttemptData? {
        guard presentationIndex > 0,
              tokenIndex >= 0,
              activityFamily == .soccer || activityFamily == .tower
                || activityFamily == .buildWord || activityFamily == .mixed else {
            return nil
        }

        let challenge = Challenge(
            presentationIndex: presentationIndex,
            contentItemID: contentItemID,
            tokenIndex: tokenIndex
        )
        let nextAttemptCount = currentChallenge == challenge ? attemptCount + 1 : 1
        guard let attempt = ActivityAttemptData(
            itemID: ActivityItemID(
                rawValue: "\(contentItemID.rawValue).ordered-token.\(tokenIndex)"
            ),
            attemptIndex: nextAttemptCount,
            result: result,
            responseDurationSeconds: responseDurationSeconds,
            activityFamily: activityFamily,
            skillID: skillID,
            languageContentItemID: contentItemID,
            languageVocabularyLevel: languageVocabularyLevel
        ) else {
            return nil
        }

        currentChallenge = challenge
        attemptCount = nextAttemptCount
        return attempt
    }
}
