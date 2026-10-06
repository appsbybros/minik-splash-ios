import Foundation

/// Deterministic generic store for caller-side tests and previews. It has no
/// StoreKit dependency and never claims a transaction was App-Store verified.
public actor InMemoryCommerceStore: CommerceStore {
    private let products: [CommerceProduct]
    private var outcomeByProductID: [CommerceProductID: PurchaseOutcome]
    private var entitlementState: EntitlementState
    private var continuations: [UUID: AsyncStream<CommerceTransactionUpdate>.Continuation] = [:]

    public init(
        products: [CommerceProduct] = [],
        entitlementState: EntitlementState = EntitlementState(),
        outcomeByProductID: [CommerceProductID: PurchaseOutcome] = [:]
    ) {
        self.products = products
        self.entitlementState = entitlementState
        self.outcomeByProductID = outcomeByProductID
    }

    public func loadProducts() async throws -> [CommerceProduct] {
        products
    }

    public func purchase(productID: CommerceProductID) async throws -> PurchaseOutcome {
        guard products.contains(where: { $0.id == productID }) else {
            throw CommerceError.productNotFound(productID)
        }
        guard let outcome = outcomeByProductID[productID] else {
            throw CommerceError.purchaseOutcomeNotConfigured(productID)
        }
        if case .purchased(let state) = outcome {
            entitlementState = state
        }
        return outcome
    }

    public func refreshEntitlements() async throws -> EntitlementState {
        entitlementState
    }

    public func restorePurchases() async throws -> EntitlementState {
        entitlementState
    }

    public func transactionUpdates() async -> AsyncStream<CommerceTransactionUpdate> {
        let identifier = UUID()
        return AsyncStream { continuation in
            continuations[identifier] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(identifier) }
            }
        }
    }

    public func setPurchaseOutcome(_ outcome: PurchaseOutcome, for productID: CommerceProductID) {
        outcomeByProductID[productID] = outcome
    }

    public func setEntitlementState(_ state: EntitlementState) {
        entitlementState = state
        emit(.entitlements(state))
    }

    public func emitFailure(_ failure: CommerceProcessingFailure) {
        emit(.failure(failure))
    }

    public func finishUpdates() {
        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
    }

    public var updateListenerCount: Int { continuations.count }

    private func emit(_ update: CommerceTransactionUpdate) {
        for continuation in continuations.values {
            continuation.yield(update)
        }
    }

    private func removeContinuation(_ identifier: UUID) {
        continuations[identifier] = nil
    }
}
