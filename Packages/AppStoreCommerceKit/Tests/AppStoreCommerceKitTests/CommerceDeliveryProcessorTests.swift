import XCTest
@testable import AppStoreCommerceKit

final class CommerceDeliveryProcessorTests: XCTestCase {
    func testFulfillmentPrecedesAcknowledgmentAndReplayDoesNotDuplicateDelivery() async throws {
        let recorder = DeliveryRecorder()
        let handler = RecordingFulfillmentHandler(recorder: recorder)
        let processor = CommerceDeliveryProcessor(handler: handler)
        let delivery = makeDelivery()

        _ = try await processor.process(delivery) { await recorder.record("acknowledge") }
        _ = try await processor.process(delivery) { await recorder.record("unexpected acknowledgment") }

        let events = await recorder.events
        let deliveries = await handler.deliveries
        XCTAssertEqual(events, ["fulfill", "acknowledge"])
        XCTAssertEqual(deliveries, [delivery])
    }

    func testAcknowledgmentFailureRetainsFulfillmentAndRetriesAcknowledgmentOnly() async throws {
        let recorder = DeliveryRecorder()
        let handler = RecordingFulfillmentHandler(recorder: recorder)
        let processor = CommerceDeliveryProcessor(handler: handler)
        let delivery = makeDelivery()

        do {
            _ = try await processor.process(delivery) {
                await recorder.record("acknowledge failed")
                throw DeliveryTestError.expected
            }
            XCTFail("Expected the acknowledgement failure")
        } catch {
            XCTAssertEqual(error as? DeliveryTestError, .expected)
        }

        _ = try await processor.process(delivery) { await recorder.record("acknowledge retry") }

        let events = await recorder.events
        let deliveries = await handler.deliveries
        XCTAssertEqual(events, ["fulfill", "acknowledge failed", "acknowledge retry"])
        XCTAssertEqual(deliveries, [delivery])
    }

    func testFulfillmentFailureDoesNotAcknowledgeAndCanRetry() async throws {
        let recorder = DeliveryRecorder()
        let handler = RecordingFulfillmentHandler(recorder: recorder, failuresRemaining: 1)
        let processor = CommerceDeliveryProcessor(handler: handler)
        let delivery = makeDelivery()

        do {
            _ = try await processor.process(delivery) { await recorder.record("unexpected acknowledgment") }
            XCTFail("Expected the fulfillment failure")
        } catch {
            XCTAssertEqual(error as? DeliveryTestError, .expected)
        }

        _ = try await processor.process(delivery) { await recorder.record("acknowledge") }

        let events = await recorder.events
        let deliveries = await handler.deliveries
        XCTAssertEqual(events, ["fulfill failed", "fulfill", "acknowledge"])
        XCTAssertEqual(deliveries, [delivery])
    }

    func testReconciledStateCanRetainSharedEntitlementAfterAnotherProductChanges() async throws {
        let recorder = DeliveryRecorder()
        let handler = RecordingFulfillmentHandler(recorder: recorder)
        let processor = CommerceDeliveryProcessor(handler: handler)
        let sharedEntitlement = EntitlementID(rawValue: "example.shared")
        let retainedState = EntitlementState(activeEntitlementIDs: [sharedEntitlement])
        let revokedProduct = CommerceFulfillment(
            transactionID: "transaction-revoked",
            productID: CommerceProductID(rawValue: "example.first"),
            entitlementID: sharedEntitlement,
            entitlementState: retainedState
        )

        _ = try await processor.process(revokedProduct) { await recorder.record("acknowledge") }

        let deliveries = await handler.deliveries
        XCTAssertEqual(deliveries.single?.entitlementState, retainedState)
        XCTAssertTrue(deliveries.single?.entitlementState.contains(sharedEntitlement) == true)
    }

    private func makeDelivery() -> CommerceFulfillment {
        CommerceFulfillment(
            transactionID: "transaction-1",
            productID: CommerceProductID(rawValue: "example.one"),
            entitlementID: EntitlementID(rawValue: "example.feature"),
            entitlementState: EntitlementState(activeEntitlementIDs: [EntitlementID(rawValue: "example.feature")])
        )
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}

private enum DeliveryTestError: Error, Equatable {
    case expected
}

private actor DeliveryRecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private actor RecordingFulfillmentHandler: CommerceFulfillmentHandler {
    private let recorder: DeliveryRecorder
    private var failuresRemaining: Int
    private(set) var deliveries: [CommerceFulfillment] = []

    init(recorder: DeliveryRecorder, failuresRemaining: Int = 0) {
        self.recorder = recorder
        self.failuresRemaining = failuresRemaining
    }

    func fulfill(_ fulfillment: CommerceFulfillment) async throws {
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            await recorder.record("fulfill failed")
            throw DeliveryTestError.expected
        }
        deliveries.append(fulfillment)
        await recorder.record("fulfill")
    }
}
