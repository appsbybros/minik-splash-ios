import Foundation

enum LanguageSoccerMatchOutcome: Hashable, Sendable {
    case childWin
    case draw
    case minikWin
}

enum LanguagePictureMemoryRewardMapper {
    static func rewardEvent(for event: ActivityEvent) -> RewardEvent? {
        guard event.kind == .completed,
              event.context.activityID.rawValue == "language.wordMemory",
              event.context.product == .minikPlus || event.context.product == .minikPlusEnglish,
              event.context.skillID == LanguageSkillIDs.wordImageAssociation,
              event.attemptData == nil else {
            return nil
        }

        return RewardEvent(
            id: event.id,
            sourceActivityEventID: event.id,
            scope: RewardScope(ownerID: .localDefault, product: event.context.product),
            reason: .activityCompleted,
            occurredAt: event.occurredAt
        )
    }
}

enum LanguageSoccerRewardMapper {
    static func rewardEvent(
        sourceEventID: UUID,
        product: ProductVariant,
        outcome: LanguageSoccerMatchOutcome,
        occurredAt: Date
    ) -> RewardEvent? {
        guard product == .minikPlus || product == .minikPlusEnglish else {
            return nil
        }

        let reason: RewardReason
        switch outcome {
        case .childWin:
            reason = .matchWon
        case .draw:
            reason = .matchDrawn
        case .minikWin:
            return nil
        }

        return RewardEvent(
            id: sourceEventID,
            sourceActivityEventID: sourceEventID,
            scope: RewardScope(ownerID: .localDefault, product: product),
            reason: reason,
            occurredAt: occurredAt
        )
    }
}

enum LanguageTicTacToeRewardMapper {
    static func rewardEvent(
        sourceEventID: UUID,
        product: ProductVariant,
        outcome: TicTacToeOutcome,
        occurredAt: Date
    ) -> RewardEvent? {
        guard product == .minikPlus || product == .minikPlusEnglish else {
            return nil
        }

        let reason: RewardReason
        switch outcome {
        case .childWin:
            reason = .matchWon
        case .draw:
            reason = .matchDrawn
        case .minikWin:
            reason = .matchLost
        }

        return RewardEvent(
            id: sourceEventID,
            sourceActivityEventID: sourceEventID,
            scope: RewardScope(ownerID: .localDefault, product: product),
            reason: reason,
            occurredAt: occurredAt
        )
    }
}
