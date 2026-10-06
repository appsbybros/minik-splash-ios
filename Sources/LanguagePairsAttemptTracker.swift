struct LanguagePairsAttemptTracker: Sendable {
    private struct Challenge: Hashable, Sendable {
        let presentationIndex: Int
        let contentItemID: ContentItemID
    }

    private var attemptCounts: [Challenge: Int] = [:]

    init() {}

    mutating func makeAttempt(
        presentationIndex: Int,
        contentItemID: ContentItemID,
        result: GradedAttemptResult,
        responseDurationSeconds: Double?,
        skillID: SkillID
    ) -> ActivityAttemptData? {
        guard presentationIndex > 0 else {
            return nil
        }

        let challenge = Challenge(
            presentationIndex: presentationIndex,
            contentItemID: contentItemID
        )
        let attemptIndex = (attemptCounts[challenge] ?? 0) + 1
        guard let attempt = ActivityAttemptData(
            itemID: ActivityItemID(rawValue: contentItemID.rawValue),
            attemptIndex: attemptIndex,
            result: result,
            responseDurationSeconds: responseDurationSeconds,
            activityFamily: .pairs,
            skillID: skillID
        ) else {
            return nil
        }

        attemptCounts[challenge] = attemptIndex
        return attempt
    }
}
