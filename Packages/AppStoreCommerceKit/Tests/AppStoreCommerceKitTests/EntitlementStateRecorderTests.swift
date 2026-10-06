import Foundation
import XCTest
@testable import AppStoreCommerceKit

final class EntitlementStateRecorderTests: XCTestCase {
    private let fixtureEntitlementID = EntitlementID(rawValue: "fixture.permanent")

    func testBoundedWaiterReceivesExpectedEventAndCleansUp() async throws {
        let recorder = EntitlementStateRecorder()
        let expected = EntitlementState(activeEntitlementIDs: [fixtureEntitlementID])
        let registered = expectation(description: "Waiter registered")
        let finished = expectation(description: "Waiter terminated")
        let waiter = Task {
            defer { finished.fulfill() }
            return try await recorder.waitFor(expected, onRegistered: { registered.fulfill() })
        }

        let registrationResult = await XCTWaiter.fulfillment(of: [registered], timeout: 2.0)
        guard registrationResult == .completed else {
            waiter.cancel()
            XCTFail("Waiter did not register")
            return
        }
        await recorder.record(expected)

        let finishResult = await XCTWaiter.fulfillment(of: [finished], timeout: 2.0)
        guard finishResult == .completed else {
            waiter.cancel()
            XCTFail("Waiter did not terminate after receiving its event")
            return
        }
        let receivedState = try await waiter.value
        XCTAssertEqual(receivedState, expected)
        let waiterCount = await recorder.pendingWaiterCount()
        XCTAssertEqual(waiterCount, 0)
    }

    func testBoundedWaiterTimesOutAndCleansUpWhenEventNeverArrives() async throws {
        let recorder = EntitlementStateRecorder()
        let expected = EntitlementState(activeEntitlementIDs: [fixtureEntitlementID])
        let finished = expectation(description: "Timed waiter terminated")
        let waiter = Task {
            defer { finished.fulfill() }
            return try await recorder.waitFor(expected, timeoutNanoseconds: 50_000_000)
        }

        let finishResult = await XCTWaiter.fulfillment(of: [finished], timeout: 2.0)
        guard finishResult == .completed else {
            waiter.cancel()
            XCTFail("Timed waiter did not terminate")
            return
        }

        do {
            _ = try await waiter.value
            XCTFail("Expected the bounded waiter to time out")
        } catch IntegrationWaitError.elapsed {
            // Expected.
        }

        let waiterCount = await recorder.pendingWaiterCount()
        XCTAssertEqual(waiterCount, 0)
    }

    func testBoundedWaiterEventCancellationRaceResumesOnceAndCleansUp() async throws {
        for iteration in 0..<20 {
            let recorder = EntitlementStateRecorder()
            let expected = EntitlementState(activeEntitlementIDs: [fixtureEntitlementID])
            let registered = expectation(description: "Race waiter registered \(iteration)")
            let finished = expectation(description: "Race waiter terminated \(iteration)")
            let waiter = Task {
                defer { finished.fulfill() }
                return try await recorder.waitFor(expected, onRegistered: { registered.fulfill() })
            }
            let registrationResult = await XCTWaiter.fulfillment(of: [registered], timeout: 2.0)
            guard registrationResult == .completed else {
                waiter.cancel()
                XCTFail("Race waiter did not register")
                return
            }

            await withTaskGroup(of: Void.self) { group in
                group.addTask { waiter.cancel() }
                group.addTask { await recorder.record(expected) }
            }

            let finishResult = await XCTWaiter.fulfillment(of: [finished], timeout: 2.0)
            guard finishResult == .completed else {
                waiter.cancel()
                XCTFail("Race waiter did not terminate")
                return
            }
            do {
                let receivedState = try await waiter.value
                XCTAssertEqual(receivedState, expected)
            } catch is CancellationError {
                // Either racing outcome is valid; a second resume would fail the test process.
            }
            let waiterCount = await recorder.pendingWaiterCount()
            XCTAssertEqual(waiterCount, 0)
        }
    }

    func testBoundedWaiterCancellationTerminatesAndCleansUp() async throws {
        let recorder = EntitlementStateRecorder()
        let expected = EntitlementState(activeEntitlementIDs: [fixtureEntitlementID])
        let registered = expectation(description: "Cancelled waiter registered")
        let finished = expectation(description: "Cancelled waiter terminated")
        let waiter = Task {
            defer { finished.fulfill() }
            return try await recorder.waitFor(expected, onRegistered: { registered.fulfill() })
        }
        let registrationResult = await XCTWaiter.fulfillment(of: [registered], timeout: 2.0)
        guard registrationResult == .completed else {
            waiter.cancel()
            XCTFail("Cancelled waiter did not register")
            return
        }

        waiter.cancel()
        let finishResult = await XCTWaiter.fulfillment(of: [finished], timeout: 2.0)
        guard finishResult == .completed else {
            waiter.cancel()
            XCTFail("Cancelled waiter did not terminate")
            return
        }
        do {
            _ = try await waiter.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        }

        let waiterCount = await recorder.pendingWaiterCount()
        XCTAssertEqual(waiterCount, 0)
    }
}

private enum IntegrationWaitError: Error { case elapsed }

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
