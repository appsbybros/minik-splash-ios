import Foundation
import Dispatch
import StoreKit
import StoreKitTest
import XCTest
import AppStoreCommerceKit

final class StoreKitCommerceStoreIntegrationTests: XCTestCase {
    private let fixtureProductID = CommerceProductID(rawValue: "org.example.appstorecommerce.fixture.permanent")
    private let fixtureEntitlementID = EntitlementID(rawValue: "fixture.permanent")
    private let subscriptionProductID = CommerceProductID(rawValue: "org.example.appstorecommerce.fixture.monthly")
    private let subscriptionEntitlementID = EntitlementID(rawValue: "fixture.monthly")

    func testConfiguredNonConsumableLoadsPurchasesRestoresAndReconcilesRefund() async throws {
        let session = try makeSession()
        session.clearTransactions()
        let handler = IntegrationHandler()
        let store = StoreKitCommerceStore(
            catalog: CommerceCatalog(entitlementByProductID: [fixtureProductID: fixtureEntitlementID]),
            fulfillmentHandler: handler
        )

        let products = try await Product.products(for: [fixtureProductID.rawValue])
        let nativeProduct = try XCTUnwrap(
            products.first(where: { $0.id == fixtureProductID.rawValue }),
            "Local StoreKit fixture did not expose \(fixtureProductID.rawValue) immediately"
        )
        XCTAssertEqual(nativeProduct.type, .nonConsumable)

        let loadedProducts = try await store.loadProducts()
        XCTAssertEqual(loadedProducts.map(\.id), [fixtureProductID])

        let purchase = try await store.purchase(productID: fixtureProductID)
        guard case .purchased(let purchasedState) = purchase else {
            return XCTFail("Expected fixture purchase to complete")
        }
        XCTAssertTrue(purchasedState.contains(fixtureEntitlementID))
        let appliedStates = await handler.states()
        XCTAssertEqual(appliedStates.last, purchasedState)

        let restoredState = try await store.restorePurchases()
        XCTAssertTrue(restoredState.contains(fixtureEntitlementID))

        let testTransaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: testTransaction.identifier)
        let refundedState = try await waitForEntitlement(
            fixtureEntitlementID,
            isActive: false,
            in: store
        )
        XCTAssertFalse(refundedState.contains(fixtureEntitlementID))
    }

    func testTransactionUpdatesApplyAndPublishRefundRemoval() async throws {
        let session = try makeSession()
        session.clearTransactions()
        let handler = IntegrationHandler()
        let store = StoreKitCommerceStore(
            catalog: CommerceCatalog(entitlementByProductID: [fixtureProductID: fixtureEntitlementID]),
            fulfillmentHandler: handler
        )
        let collector = UpdateCollector()
        let stream = await store.transactionUpdates()
        let listenerStarted = expectation(description: "Transaction update listener started")
        let listenerStopped = expectation(description: "Transaction update listener stopped")
        let listener = Task {
            defer { listenerStopped.fulfill() }
            var iterator = stream.makeAsyncIterator()
            listenerStarted.fulfill()
            while !Task.isCancelled, let update = await iterator.next() {
                if case .entitlements(let state) = update {
                    await collector.record(state)
                }
            }
        }
        let listenerStartResult = await XCTWaiter.fulfillment(of: [listenerStarted], timeout: 2.0)
        guard listenerStartResult == .completed else {
            guard await stopListener(listener, stoppedBy: listenerStopped) else { return }
            XCTFail("Transaction update listener did not start")
            return
        }

        do {
            let products = try await Product.products(for: [fixtureProductID.rawValue])
            _ = try XCTUnwrap(
                products.first(where: { $0.id == fixtureProductID.rawValue }),
                "Local StoreKit fixture did not expose \(fixtureProductID.rawValue) immediately"
            )
            let purchase = try await store.purchase(productID: fixtureProductID)
            guard case .purchased(let activeState) = purchase else {
                guard await stopListener(listener, stoppedBy: listenerStopped) else { return }
                return XCTFail("Expected fixture purchase to complete")
            }

            let appliedActive = try await handler.waitFor(activeState, afterEventCount: 0)
            XCTAssertTrue(appliedActive.contains(fixtureEntitlementID))

            // A state recorded before this point cannot satisfy either removal wait.
            let publishedMarker = await collector.eventCount()
            let appliedMarker = await handler.eventCount()
            let transaction = try XCTUnwrap(session.allTransactions().first)
            try session.refundTransaction(identifier: transaction.identifier)

            async let publishedRemoval = collector.waitFor(
                EntitlementState(),
                afterEventCount: publishedMarker
            )
            async let appliedRemoval = handler.waitFor(
                EntitlementState(),
                afterEventCount: appliedMarker
            )
            let removals = try await (publishedRemoval, appliedRemoval)
            XCTAssertEqual(removals.0, EntitlementState())
            XCTAssertEqual(removals.1, EntitlementState())
            let collectorWaiterCount = await collector.pendingWaiterCount()
            let handlerWaiterCount = await handler.pendingWaiterCount()
            XCTAssertEqual(collectorWaiterCount, 0)
            XCTAssertEqual(handlerWaiterCount, 0)
        } catch {
            guard await stopListener(listener, stoppedBy: listenerStopped) else { return }
            throw error
        }

        guard await stopListener(listener, stoppedBy: listenerStopped) else { return }
    }

    func testAutoRenewableSubscriptionRemainsAccessibleForGraceAndLosesAccessWhenExpired() async throws {
        let session = try makeSession()
        session.clearTransactions()
        session.timeRate = .oneRenewalEveryThirtySeconds
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = false
        let store = StoreKitCommerceStore(
            catalog: CommerceCatalog(entitlementByProductID: [subscriptionProductID: subscriptionEntitlementID]),
            fulfillmentHandler: IntegrationHandler()
        )
        let products = try await Product.products(for: [subscriptionProductID.rawValue])
        let subscriptionProduct = try XCTUnwrap(
            products.first(where: { $0.id == subscriptionProductID.rawValue }),
            "Local StoreKit fixture did not expose \(subscriptionProductID.rawValue) immediately"
        )
        XCTAssertEqual(subscriptionProduct.type, .autoRenewable)

        let purchase = try await store.purchase(productID: subscriptionProductID)
        guard case .purchased(let active) = purchase else {
            return XCTFail("Expected subscription fixture purchase to complete")
        }
        XCTAssertTrue(active.contains(subscriptionEntitlementID))
        let activeStatus = try await waitForVerifiedSubscriptionState(
            .subscribed,
            product: subscriptionProduct
        )
        XCTAssertEqual(activeStatus.state, .subscribed)

        let statusObserverStarted = expectation(
            description: "Subscription status-update observer started"
        )
        let statusObserverStopped = expectation(
            description: "Subscription status-update observer stopped"
        )
        let graceStatusTask = Task {
            defer { statusObserverStopped.fulfill() }
            return try await waitForVerifiedSubscriptionStatusUpdate(
                .inGracePeriod,
                productID: subscriptionProductID,
                timeoutNanoseconds: 90_000_000_000,
                onListening: {
                    statusObserverStarted.fulfill()
                }
            )
        }
        let statusObserverStartResult = await XCTWaiter.fulfillment(
            of: [statusObserverStarted],
            timeout: 2.0
        )
        guard statusObserverStartResult == .completed else {
            graceStatusTask.cancel()
            let stopResult = await XCTWaiter.fulfillment(
                of: [statusObserverStopped],
                timeout: 2.0
            )
            guard stopResult == .completed else {
                XCTFail("Subscription status-update observer did not stop after cancellation")
                return
            }
            _ = await graceStatusTask.result
            XCTFail("Subscription status-update observer did not start")
            return
        }

        session.shouldEnterBillingRetryOnRenewal = true

        let graceStatus = try await graceStatusTask.value
        let statusObserverStopResult = await XCTWaiter.fulfillment(
            of: [statusObserverStopped],
            timeout: 2.0
        )
        guard statusObserverStopResult == .completed else {
            XCTFail("Subscription status-update observer did not stop after completion")
            return
        }
        XCTAssertEqual(graceStatus.state, .inGracePeriod)
        let graceRenewalInfo: Product.SubscriptionInfo.RenewalInfo
        switch graceStatus.renewalInfo {
        case .verified(let renewalInfo):
            graceRenewalInfo = renewalInfo
        case .unverified(_, let verificationError):
            return XCTFail(
                "Expected verified renewal info during grace period: \(verificationError)"
            )
        }
        let gracePeriodExpirationDate = try XCTUnwrap(
            graceRenewalInfo.gracePeriodExpirationDate,
            "Verified grace-period renewal info did not include an expiration date"
        )
        let entitlementCheckStart = Date()
        XCTAssertGreaterThan(
            gracePeriodExpirationDate,
            entitlementCheckStart,
            "Grace period expired before the entitlement check began"
        )
        guard gracePeriodExpirationDate > entitlementCheckStart else { return }

        let graceState = try await waitForEntitlement(
            subscriptionEntitlementID,
            isActive: true,
            in: store,
            stage: "subscription-grace"
        )
        XCTAssertTrue(graceState.contains(subscriptionEntitlementID))

        try session.expireSubscription(productIdentifier: subscriptionProductID.rawValue)
        let expiredStatus = try await waitForVerifiedSubscriptionState(
            .expired,
            product: subscriptionProduct
        )
        XCTAssertEqual(expiredStatus.state, .expired)
        let expiredState = try await waitForEntitlement(
            subscriptionEntitlementID,
            isActive: false,
            in: store,
            stage: "subscription-expired"
        )
        XCTAssertFalse(expiredState.contains(subscriptionEntitlementID))
    }

    private func stopListener(
        _ listener: Task<Void, Never>,
        stoppedBy expectation: XCTestExpectation
    ) async -> Bool {
        listener.cancel()
        let stopResult = await XCTWaiter.fulfillment(of: [expectation], timeout: 2.0)
        guard stopResult == .completed else {
            XCTFail("Transaction update listener did not stop after cancellation")
            return false
        }
        _ = await listener.result
        return true
    }

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(
            configurationFileNamed: "AppStoreCommerceKit"
        )
        session.resetToDefaultState()
        session.disableDialogs = true
        return session
    }
}

private actor IntegrationHandler: CommerceFulfillmentHandler {
    private let recorder = EntitlementStateRecorder()

    func fulfill(_ fulfillment: CommerceFulfillment) async throws {
        await recorder.record(fulfillment.entitlementState)
    }

    func states() async -> [EntitlementState] {
        await recorder.recordedStates()
    }

    func eventCount() async -> Int {
        await recorder.eventCount()
    }

    func waitFor(
        _ state: EntitlementState,
        afterEventCount: Int = 0
    ) async throws -> EntitlementState {
        try await recorder.waitFor(state, afterEventCount: afterEventCount)
    }

    func pendingWaiterCount() async -> Int {
        await recorder.pendingWaiterCount()
    }
}

private actor UpdateCollector {
    private let recorder = EntitlementStateRecorder()

    func record(_ state: EntitlementState) async {
        await recorder.record(state)
    }

    func eventCount() async -> Int {
        await recorder.eventCount()
    }

    func waitFor(
        _ state: EntitlementState,
        afterEventCount: Int = 0
    ) async throws -> EntitlementState {
        try await recorder.waitFor(state, afterEventCount: afterEventCount)
    }

    func pendingWaiterCount() async -> Int {
        await recorder.pendingWaiterCount()
    }
}

private enum IntegrationWaitError: Error {
    case elapsed
    case entitlementStateTimedOut(stage: String, expectedActive: Bool)
    case subscriptionStatusTimedOut(
        expectedState: Product.SubscriptionInfo.RenewalState
    )
}

private actor EntitlementStateRecorder {
    private struct Waiter {
        let expectedState: EntitlementState
        let afterEventCount: Int
        let continuation: CheckedContinuation<EntitlementState, Error>
        let timeoutTask: Task<Void, Never>
    }

    private var states: [EntitlementState] = []
    private var activeWaiterIDs = Set<UUID>()
    private var waiters: [UUID: Waiter] = [:]

    func record(_ state: EntitlementState) {
        states.append(state)
        let eventCount = states.count
        let matchingIDs = waiters.compactMap { id, waiter in
            eventCount > waiter.afterEventCount && state == waiter.expectedState ? id : nil
        }
        for id in matchingIDs {
            succeed(id: id, with: state)
        }
    }

    func recordedStates() -> [EntitlementState] {
        states
    }

    func eventCount() -> Int {
        states.count
    }

    func pendingWaiterCount() -> Int {
        activeWaiterIDs.count
    }

    func waitFor(
        _ expectedState: EntitlementState,
        afterEventCount: Int = 0,
        timeoutNanoseconds: UInt64 = 10_000_000_000,
        onRegistered: (@Sendable () -> Void)? = nil
    ) async throws -> EntitlementState {
        if let existing = states.dropFirst(min(afterEventCount, states.count)).first(where: { $0 == expectedState }) {
            return existing
        }

        let id = UUID()
        activeWaiterIDs.insert(id)
        return try await withTaskCancellationHandler {
            try await registerAndSuspend(
                id: id,
                expectedState: expectedState,
                afterEventCount: afterEventCount,
                timeoutNanoseconds: timeoutNanoseconds,
                onRegistered: onRegistered
            )
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    private func registerAndSuspend(
        id: UUID,
        expectedState: EntitlementState,
        afterEventCount: Int,
        timeoutNanoseconds: UInt64,
        onRegistered: (@Sendable () -> Void)?
    ) async throws -> EntitlementState {
        guard activeWaiterIDs.contains(id), !Task.isCancelled else {
            activeWaiterIDs.remove(id)
            throw CancellationError()
        }
        if let existing = states.dropFirst(min(afterEventCount, states.count)).first(where: { $0 == expectedState }) {
            activeWaiterIDs.remove(id)
            return existing
        }

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                } catch {
                    return
                }
                guard let self else { return }
                await self.timeout(id: id)
            }
            waiters[id] = Waiter(
                expectedState: expectedState,
                afterEventCount: afterEventCount,
                continuation: continuation,
                timeoutTask: timeoutTask
            )
            onRegistered?()
        }
    }

    private func cancel(id: UUID) {
        guard let waiter = removeWaiter(id: id) else { return }
        waiter.timeoutTask.cancel()
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func timeout(id: UUID) {
        guard let waiter = removeWaiter(id: id) else { return }
        waiter.timeoutTask.cancel()
        waiter.continuation.resume(throwing: IntegrationWaitError.elapsed)
    }

    private func succeed(id: UUID, with state: EntitlementState) {
        guard let waiter = removeWaiter(id: id) else { return }
        waiter.timeoutTask.cancel()
        waiter.continuation.resume(returning: state)
    }

    private func removeWaiter(id: UUID) -> Waiter? {
        guard activeWaiterIDs.remove(id) != nil else { return nil }
        return waiters.removeValue(forKey: id)
    }
}

private func waitForVerifiedSubscriptionStatusUpdate(
    _ expectedState: Product.SubscriptionInfo.RenewalState,
    productID: CommerceProductID,
    timeoutNanoseconds: UInt64,
    onListening: @escaping @Sendable () -> Void
) async throws -> Product.SubscriptionInfo.Status {
    return try await withThrowingTaskGroup(
        of: Product.SubscriptionInfo.Status.self
    ) { group in
        group.addTask {
            var iterator = Product.SubscriptionInfo.Status.updates.makeAsyncIterator()
            onListening()

            while let status = await iterator.next() {
                try Task.checkCancellation()
                guard status.state == expectedState else { continue }
                guard case .verified(let transaction) = status.transaction,
                      transaction.productID == productID.rawValue else {
                    continue
                }
                return status
            }
            throw CancellationError()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
            throw IntegrationWaitError.subscriptionStatusTimedOut(
                expectedState: expectedState
            )
        }
        defer { group.cancelAll() }

        guard let status = try await group.next() else {
            throw IntegrationWaitError.subscriptionStatusTimedOut(
                expectedState: expectedState
            )
        }
        group.cancelAll()
        return status
    }
}

private func waitForVerifiedSubscriptionState(
    _ expectedState: Product.SubscriptionInfo.RenewalState,
    product: Product,
    timeoutNanoseconds: UInt64 = 10_000_000_000
) async throws -> Product.SubscriptionInfo.Status {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    guard let subscription = product.subscription else {
        throw IntegrationWaitError.elapsed
    }

    repeat {
        for status in try await subscription.status where status.state == expectedState {
            if case .verified(let transaction) = status.transaction,
               transaction.productID == product.id {
                return status
            }
        }
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            throw IntegrationWaitError.subscriptionStatusTimedOut(
                expectedState: expectedState
            )
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    } while true
}

private func waitForEntitlement(
    _ entitlementID: EntitlementID,
    isActive: Bool,
    in store: StoreKitCommerceStore,
    stage: String = "entitlement",
    timeoutNanoseconds: UInt64 = 10_000_000_000
) async throws -> EntitlementState {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while true {
        let state = try await store.refreshEntitlements()
        if state.contains(entitlementID) == isActive {
            return state
        }
        guard DispatchTime.now().uptimeNanoseconds < deadline else {
            throw IntegrationWaitError.entitlementStateTimedOut(
                stage: stage,
                expectedActive: isActive
            )
        }
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}
