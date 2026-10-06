import XCTest
@testable import MinikPlus

final class LocalRecordsReadModelTests: XCTestCase {
    func testMissingScopeProducesHonestEmptyState() {
        let model = LocalRecordsReadModelBuilder.make(
            ledger: RewardLedger(),
            product: .minikMath
        )

        XCTAssertFalse(model.hasRecordedState)
        XCTAssertEqual(model.currentStreak, 0)
        XCTAssertEqual(model.bestStreak, 0)
    }

    func testExistingScopeUsesActualStoredStreakValues() {
        let model = LocalRecordsReadModelBuilder.make(
            ledger: RewardLedger(entries: [
                RewardLedgerEntry(
                    scope: RewardScope(ownerID: .localDefault, product: .minikPlus),
                    state: RewardState(points: 42, currentStreak: 4, bestStreak: 9)
                )
            ]),
            product: .minikPlus
        )

        XCTAssertTrue(model.hasRecordedState)
        XCTAssertEqual(model.currentStreak, 4)
        XCTAssertEqual(model.bestStreak, 9)
    }

    func testOtherProductsAndOwnersDoNotLeakIntoReadModel() {
        let otherOwner = RewardOwnerID(rawValue: "other-owner")
        let ledger = RewardLedger(entries: [
            RewardLedgerEntry(
                scope: RewardScope(ownerID: .localDefault, product: .minikPingPong),
                state: RewardState(currentStreak: 3, bestStreak: 7)
            ),
            RewardLedgerEntry(
                scope: RewardScope(ownerID: otherOwner, product: .minikMath),
                state: RewardState(currentStreak: 5, bestStreak: 8)
            )
        ])

        let model = LocalRecordsReadModelBuilder.make(ledger: ledger, product: .minikMath)

        XCTAssertFalse(model.hasRecordedState)
        XCTAssertEqual(model.currentStreak, 0)
        XCTAssertEqual(model.bestStreak, 0)
    }
}
