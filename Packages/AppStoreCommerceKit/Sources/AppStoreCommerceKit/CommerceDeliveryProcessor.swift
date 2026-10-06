import Foundation

/// Coordinates the complete read/apply/acknowledge operation. Actor isolation
/// alone does not protect code across `await`; this queue deliberately keeps
/// snapshot reads, state delivery, and acknowledgement in one ordered lane.
public actor CommerceDeliveryProcessor {
    private let handler: any CommerceFulfillmentHandler
    private var isProcessing = false
    private var waitingOperations: [CheckedContinuation<Void, Never>] = []
    private var deliveredStateByTransactionID: [String: EntitlementState] = [:]
    private var lastAppliedState: EntitlementState?
    private var acknowledgedTransactionIDs = Set<String>()
    private let onOperationQueued: (@Sendable () -> Void)?

    public init(handler: some CommerceFulfillmentHandler) {
        self.handler = handler
        self.onOperationQueued = nil
    }

    /// Test-only observation seam used to prove that a competing operation has
    /// reached the occupied serial lane. Production clients use `init(handler:)`.
    init(
        handler: some CommerceFulfillmentHandler,
        onOperationQueued: @escaping @Sendable () -> Void
    ) {
        self.handler = handler
        self.onOperationQueued = onOperationQueued
    }

    /// Reads the authoritative state only after this operation reaches the
    /// coordinator. A changed state is delivered even for an already-finished
    /// transaction; acknowledgement is intentionally tracked separately.
    public func process(
        transactionID: String,
        productID: CommerceProductID,
        entitlementID: EntitlementID,
        currentState: @escaping @Sendable () async throws -> EntitlementState,
        acknowledge: @escaping @Sendable () async throws -> Void
    ) async throws -> EntitlementState {
        await acquireLane()
        defer { releaseLane() }

        let state = try await currentState()
        if deliveredStateByTransactionID[transactionID] != state || lastAppliedState != state {
            try await handler.fulfill(
                CommerceFulfillment(
                    transactionID: transactionID,
                    productID: productID,
                    entitlementID: entitlementID,
                    entitlementState: state
                )
            )
            deliveredStateByTransactionID[transactionID] = state
            lastAppliedState = state
        }

        if !acknowledgedTransactionIDs.contains(transactionID) {
            try await acknowledge()
            acknowledgedTransactionIDs.insert(transactionID)
        }
        return state
    }

    /// Convenience for deterministic callers that already own a snapshot.
    public func process(
        _ fulfillment: CommerceFulfillment,
        acknowledge: @escaping @Sendable () async throws -> Void
    ) async throws -> EntitlementState {
        try await process(
            transactionID: fulfillment.transactionID,
            productID: fulfillment.productID,
            entitlementID: fulfillment.entitlementID,
            currentState: { fulfillment.entitlementState },
            acknowledge: acknowledge
        )
    }

    /// Serializes non-transaction refresh/restore reads with transaction work.
    public func currentState(
        _ read: @escaping @Sendable () async throws -> EntitlementState
    ) async throws -> EntitlementState {
        await acquireLane()
        defer { releaseLane() }
        return try await read()
    }

    private func acquireLane() async {
        guard isProcessing else {
            isProcessing = true
            return
        }
        await withCheckedContinuation { continuation in
            waitingOperations.append(continuation)
            onOperationQueued?()
        }
    }

    private func releaseLane() {
        if waitingOperations.isEmpty {
            isProcessing = false
        } else {
            waitingOperations.removeFirst().resume()
        }
    }
}
