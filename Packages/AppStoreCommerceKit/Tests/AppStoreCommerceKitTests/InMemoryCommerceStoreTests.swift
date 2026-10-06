import Dispatch
import XCTest
@testable import AppStoreCommerceKit

final class InMemoryCommerceStoreTests: XCTestCase {
    func testPurchaseRequiresExplicitConfiguredOutcome() async throws {
        let product = makeProduct()
        let store = InMemoryCommerceStore(products: [product])

        do {
            _ = try await store.purchase(productID: product.id)
            XCTFail("Expected an unconfigured purchase outcome")
        } catch let error as CommerceError {
            XCTAssertEqual(error, .purchaseOutcomeNotConfigured(product.id))
        }
    }

    func testUpdateStreamContinuesFromRecoverableFailureToEntitlementRemoval() async {
        let active = EntitlementState(activeEntitlementIDs: [EntitlementID(rawValue: "example.feature")])
        let store = InMemoryCommerceStore(entitlementState: active)
        let updates = await store.transactionUpdates()
        let receiver = Task { () -> [CommerceTransactionUpdate] in
            var iterator = updates.makeAsyncIterator()
            var received: [CommerceTransactionUpdate] = []
            while received.count < 2, let update = await iterator.next() {
                received.append(update)
            }
            return received
        }

        await Task.yield()
        await store.emitFailure(CommerceProcessingFailure(kind: .verification))
        await store.setEntitlementState(EntitlementState())
        let received = await receiver.value

        XCTAssertEqual(received, [.failure(CommerceProcessingFailure(kind: .verification)), .entitlements(EntitlementState())])
    }

    func testUpdateListenerCleanupOnCancellation() async {
        let store = InMemoryCommerceStore()
        let updates = await store.transactionUpdates()
        let receiver = Task {
            var iterator = updates.makeAsyncIterator()
            _ = await iterator.next()
        }

        await Task.yield()
        let initialListenerCount = await store.updateListenerCount
        XCTAssertEqual(initialListenerCount, 1)
        receiver.cancel()
        _ = await receiver.result

        var finalListenerCount = await store.updateListenerCount
        let cleanupDeadline = DispatchTime.now().uptimeNanoseconds + 250_000_000
        while finalListenerCount != 0,
              DispatchTime.now().uptimeNanoseconds < cleanupDeadline {
            try? await Task.sleep(nanoseconds: 1_000_000)
            finalListenerCount = await store.updateListenerCount
        }
        XCTAssertEqual(finalListenerCount, 0)
    }

    private func makeProduct() -> CommerceProduct {
        CommerceProduct(
            id: CommerceProductID(rawValue: "example.remove.ads"),
            displayName: "Example",
            displayPrice: "$1.99",
            kind: .nonConsumable
        )
    }
}
