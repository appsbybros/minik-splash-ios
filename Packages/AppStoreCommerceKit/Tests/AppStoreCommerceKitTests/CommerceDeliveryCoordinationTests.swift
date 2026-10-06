import XCTest
@testable import AppStoreCommerceKit

final class CommerceDeliveryCoordinationTests: XCTestCase {
    func testConcurrentIdenticalTransactionDeliversAndAcknowledgesOnce() async throws {
        let gate = AsyncGate()
        let firstSuspended = expectation(description: "First delivery suspended")
        let secondQueued = expectation(description: "Second operation queued behind first")
        let operationsFinished = expectation(description: "Both operations finished")
        operationsFinished.expectedFulfillmentCount = 2
        let handler = StateHandler(
            gate: gate,
            suspendFirstDelivery: true,
            onFirstDeliverySuspended: { firstSuspended.fulfill() }
        )
        let processor = CommerceDeliveryProcessor(
            handler: handler,
            onOperationQueued: { secondQueued.fulfill() }
        )
        let delivery = makeDelivery(state: state("featureA"))
        let acknowledger = AcknowledgementRecorder()

        let first = Task {
            defer { operationsFinished.fulfill() }
            return try await processor.process(delivery) { try await acknowledger.record() }
        }
        let firstSuspensionResult = await XCTWaiter.fulfillment(of: [firstSuspended], timeout: 2.0)
        guard firstSuspensionResult == .completed else {
            await gate.release()
            first.cancel()
            XCTFail("First delivery did not reach its suspension point")
            return
        }
        let second = Task {
            defer { operationsFinished.fulfill() }
            return try await processor.process(delivery) { try await acknowledger.record() }
        }
        let secondQueueResult = await XCTWaiter.fulfillment(of: [secondQueued], timeout: 2.0)
        guard secondQueueResult == .completed else {
            await gate.release()
            first.cancel()
            second.cancel()
            XCTFail("Second operation did not queue behind the suspended delivery")
            return
        }
        await gate.release()
        let completionResult = await XCTWaiter.fulfillment(of: [operationsFinished], timeout: 2.0)
        guard completionResult == .completed else {
            first.cancel()
            second.cancel()
            XCTFail("Coordinated operations did not complete")
            return
        }

        let firstState = try await first.value
        let secondState = try await second.value
        let deliveries = await handler.deliveries
        let acknowledgements = await acknowledger.count
        XCTAssertEqual(firstState, delivery.entitlementState)
        XCTAssertEqual(secondState, delivery.entitlementState)
        XCTAssertEqual(deliveries, [delivery.entitlementState])
        XCTAssertEqual(acknowledgements, 1)
    }

    func testChangedStateAfterAcknowledgementIsAppliedButIdenticalReplayIsNot() async throws {
        let handler = StateHandler()
        let processor = CommerceDeliveryProcessor(handler: handler)
        let acknowledger = AcknowledgementRecorder()
        let first = makeDelivery(state: state("featureA"))
        let removal = makeDelivery(state: EntitlementState())

        _ = try await processor.process(first) { try await acknowledger.record() }
        _ = try await processor.process(removal) { try await acknowledger.record() }
        _ = try await processor.process(removal) { try await acknowledger.record() }

        let deliveries = await handler.deliveries
        let finalState = await handler.finalState
        let acknowledgements = await acknowledger.count
        XCTAssertEqual(deliveries, [first.entitlementState, removal.entitlementState])
        XCTAssertEqual(finalState, EntitlementState())
        XCTAssertEqual(acknowledgements, 1)
    }

    func testChangedStateDuringAcknowledgementRetryIsAppliedBeforeRetryCompletes() async throws {
        let handler = StateHandler()
        let processor = CommerceDeliveryProcessor(handler: handler)
        let acknowledger = AcknowledgementRecorder(failuresRemaining: 1)
        let first = makeDelivery(state: state("featureA"))
        let removal = makeDelivery(state: EntitlementState())

        do {
            _ = try await processor.process(first) { try await acknowledger.record() }
            XCTFail("Expected acknowledgement failure")
        } catch is CoordinationTestError {}
        _ = try await processor.process(removal) { try await acknowledger.record() }

        let deliveries = await handler.deliveries
        let finalState = await handler.finalState
        let acknowledgements = await acknowledger.count
        XCTAssertEqual(deliveries, [first.entitlementState, removal.entitlementState])
        XCTAssertEqual(finalState, EntitlementState())
        XCTAssertEqual(acknowledgements, 2)
    }

    func testGlobalStateIsReappliedWhenFirstTransactionReturnsAfterAnotherTransactionRemovesIt() async throws {
        let handler = StateHandler()
        let processor = CommerceDeliveryProcessor(handler: handler)
        let acknowledger = AcknowledgementRecorder()
        let first = makeDelivery(transactionID: "T1", state: state("featureA"))
        let second = makeDelivery(transactionID: "T2", state: EntitlementState())

        _ = try await processor.process(first) { try await acknowledger.record() }
        _ = try await processor.process(second) { try await acknowledger.record() }
        _ = try await processor.process(first) { try await acknowledger.record() }

        let deliveries = await handler.deliveries
        let acknowledgements = await acknowledger.count
        XCTAssertEqual(deliveries, [first.entitlementState, second.entitlementState, first.entitlementState])
        XCTAssertEqual(acknowledgements, 2)
    }

    func testGlobalStateIsReappliedWhenFirstTransactionReturnsAfterAnotherTransactionAddsIt() async throws {
        let handler = StateHandler()
        let processor = CommerceDeliveryProcessor(handler: handler)
        let acknowledger = AcknowledgementRecorder()
        let first = makeDelivery(transactionID: "T1", state: EntitlementState())
        let second = makeDelivery(transactionID: "T2", state: state("featureA"))

        _ = try await processor.process(first) { try await acknowledger.record() }
        _ = try await processor.process(second) { try await acknowledger.record() }
        _ = try await processor.process(first) { try await acknowledger.record() }

        let deliveries = await handler.deliveries
        let acknowledgements = await acknowledger.count
        XCTAssertEqual(deliveries, [first.entitlementState, second.entitlementState, first.entitlementState])
        XCTAssertEqual(acknowledgements, 2)
    }

    func testOldSuspendedStateCannotOverwriteNewerQueuedState() async throws {
        let gate = AsyncGate()
        let oldSuspended = expectation(description: "Old fulfillment suspended before state application")
        let newerQueued = expectation(description: "Newer operation queued at occupied coordination lane")
        let operationsFinished = expectation(description: "Both coordinated operations finished")
        operationsFinished.expectedFulfillmentCount = 2
        let handler = StateHandler(
            gate: gate,
            suspendFirstDelivery: true,
            onFirstDeliverySuspended: { oldSuspended.fulfill() }
        )
        let processor = CommerceDeliveryProcessor(
            handler: handler,
            onOperationQueued: { newerQueued.fulfill() }
        )
        let old = makeDelivery(transactionID: "old", productID: "product.old", state: state("featureA"))
        let newer = makeDelivery(transactionID: "new", productID: "product.new", state: state("featureA", "featureB"))
        let acknowledger = AcknowledgementRecorder()

        let first = Task {
            defer { operationsFinished.fulfill() }
            return try await processor.process(
                transactionID: old.transactionID,
                productID: old.productID,
                entitlementID: old.entitlementID,
                currentState: { old.entitlementState },
                acknowledge: { try await acknowledger.record() }
            )
        }
        let oldSuspensionResult = await XCTWaiter.fulfillment(of: [oldSuspended], timeout: 2.0)
        guard oldSuspensionResult == .completed else {
            await gate.release()
            first.cancel()
            XCTFail("Old delivery did not reach its suspension point")
            return
        }
        let second = Task {
            defer { operationsFinished.fulfill() }
            return try await processor.process(
                transactionID: newer.transactionID,
                productID: newer.productID,
                entitlementID: newer.entitlementID,
                currentState: { newer.entitlementState },
                acknowledge: { try await acknowledger.record() }
            )
        }
        let newerQueueResult = await XCTWaiter.fulfillment(of: [newerQueued], timeout: 2.0)
        guard newerQueueResult == .completed else {
            await gate.release()
            first.cancel()
            second.cancel()
            XCTFail("Newer operation did not queue behind the suspended delivery")
            return
        }
        await gate.release()
        let completionResult = await XCTWaiter.fulfillment(of: [operationsFinished], timeout: 2.0)
        guard completionResult == .completed else {
            first.cancel()
            second.cancel()
            XCTFail("Coordinated operations did not complete")
            return
        }

        let firstState = try await first.value
        let secondState = try await second.value
        let finalState = await handler.finalState
        XCTAssertEqual(firstState, old.entitlementState)
        XCTAssertEqual(secondState, newer.entitlementState)
        XCTAssertEqual(finalState, newer.entitlementState)
    }

    private func makeDelivery(
        transactionID: String = "transaction",
        productID: String = "product",
        state: EntitlementState
    ) -> CommerceFulfillment {
        CommerceFulfillment(
            transactionID: transactionID,
            productID: CommerceProductID(rawValue: productID),
            entitlementID: EntitlementID(rawValue: "feature"),
            entitlementState: state
        )
    }

    private func state(_ identifiers: String...) -> EntitlementState {
        EntitlementState(activeEntitlementIDs: Set(identifiers.map(EntitlementID.init(rawValue:))))
    }
}

private enum CoordinationTestError: Error { case acknowledgement }

private actor AcknowledgementRecorder {
    private var failuresRemaining: Int
    private(set) var count = 0

    init(failuresRemaining: Int = 0) { self.failuresRemaining = failuresRemaining }

    func record() throws {
        count += 1
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw CoordinationTestError.acknowledgement
        }
    }
}

private actor StateHandler: CommerceFulfillmentHandler {
    private let gate: AsyncGate?
    private var suspendFirstDelivery: Bool
    private let onFirstDeliverySuspended: (@Sendable () -> Void)?
    private(set) var deliveries: [EntitlementState] = []
    private(set) var finalState = EntitlementState()

    init(
        gate: AsyncGate? = nil,
        suspendFirstDelivery: Bool = false,
        onFirstDeliverySuspended: (@Sendable () -> Void)? = nil
    ) {
        self.gate = gate
        self.suspendFirstDelivery = suspendFirstDelivery
        self.onFirstDeliverySuspended = onFirstDeliverySuspended
    }

    func fulfill(_ fulfillment: CommerceFulfillment) async throws {
        if suspendFirstDelivery {
            suspendFirstDelivery = false
            onFirstDeliverySuspended?()
            await gate?.waitUntilReleased()
        }
        deliveries.append(fulfillment.entitlementState)
        finalState = fulfillment.entitlementState
    }
}

private actor AsyncGate {
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    func waitUntilReleased() async {
        if !isReleased {
            await withCheckedContinuation { releaseContinuation = $0 }
        }
    }

    func release() {
        isReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
