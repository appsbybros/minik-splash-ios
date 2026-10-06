import Foundation

struct LocalRecordsReadModel: Hashable, Sendable {
    let product: ProductVariant
    let hasRecordedState: Bool
    let currentStreak: Int
    let bestStreak: Int
}

enum LocalRecordsReadModelBuilder {
    static func make(
        ledger: RewardLedger,
        product: ProductVariant,
        ownerID: RewardOwnerID = .localDefault
    ) -> LocalRecordsReadModel {
        let scope = RewardScope(ownerID: ownerID, product: product)
        guard let entry = ledger.entries.first(where: { $0.scope == scope }) else {
            return LocalRecordsReadModel(
                product: product,
                hasRecordedState: false,
                currentStreak: 0,
                bestStreak: 0
            )
        }

        return LocalRecordsReadModel(
            product: product,
            hasRecordedState: true,
            currentStreak: entry.state.currentStreak,
            bestStreak: entry.state.bestStreak
        )
    }
}
