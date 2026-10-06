import AppStoreCommerceKit
import XCTest
@testable import MinikPlus

final class MinikCommerceIntegrationTests: XCTestCase {
    private let removeAdsID = CommerceProductID(rawValue: "test.remove-ads")

    func testConfigurationRequiresInjectedNonemptyProductIdentifier() {
        XCTAssertNil(MinikCommerceConfiguration(
            product: .minikPlus,
            removeAdsProductIdentifier: nil
        ).catalog)
        XCTAssertNil(MinikCommerceConfiguration(
            product: .minikPlus,
            removeAdsProductIdentifier: "   "
        ).catalog)

        let configuration = MinikCommerceConfiguration(
            product: .minikPlus,
            removeAdsProductIdentifier: " test.remove-ads "
        )
        XCTAssertEqual(configuration.removeAdsProductID, removeAdsID)
        XCTAssertEqual(configuration.catalog?.entitlement(for: removeAdsID), .minikRemoveAds)
        XCTAssertEqual(configuration.catalog?.supportedProductKinds, [.nonConsumable])
    }

    func testCachedEntitlementIsIsolatedByProduct() {
        let defaults = makeDefaults()
        let repository = MinikCommerceEntitlementRepository(userDefaults: defaults)
        repository.save(
            EntitlementState(activeEntitlementIDs: [.minikRemoveAds]),
            for: .minikPlus
        )

        XCTAssertTrue(repository.isRemoveAdsActive(for: .minikPlus))
        XCTAssertFalse(repository.isRemoveAdsActive(for: .minikPlusEnglish))
        XCTAssertFalse(repository.isRemoveAdsActive(for: .minikMath))
    }

    @MainActor
    func testMissingProductionIdentifierRemainsFunctionalAndUnconfigured() async {
        let configuration = MinikCommerceConfiguration(
            product: .minikPlus,
            removeAdsProductIdentifier: nil
        )
        let controller = MinikCommerceController(configuration: configuration, store: nil)

        await controller.start()

        XCTAssertEqual(controller.status, .unconfigured)
        XCTAssertFalse(controller.isRemoveAdsActive)
        XCTAssertNil(controller.removeAdsProduct)
    }

    @MainActor
    func testStartupLoadsProductRefreshesEntitlementAndStartsOneListener() async {
        let store = InMemoryCommerceStore(
            products: [product()],
            entitlementState: EntitlementState(activeEntitlementIDs: [.minikRemoveAds])
        )
        let controller = makeController(store: store)

        await controller.start()
        await controller.start()

        XCTAssertEqual(controller.status, .ready)
        XCTAssertEqual(controller.removeAdsProduct, product())
        XCTAssertTrue(controller.isRemoveAdsActive)
        await waitForListener(store)
        let listenerCount = await store.updateListenerCount
        XCTAssertEqual(listenerCount, 1)
        await store.finishUpdates()
    }

    @MainActor
    func testPurchaseMapsRemoveAdsEntitlementAndPersistsIt() async {
        let defaults = makeDefaults()
        let repository = MinikCommerceEntitlementRepository(userDefaults: defaults)
        let active = EntitlementState(activeEntitlementIDs: [.minikRemoveAds])
        let store = InMemoryCommerceStore(
            products: [product()],
            outcomeByProductID: [removeAdsID: .purchased(active)]
        )
        let controller = makeController(store: store, repository: repository)
        await controller.start()

        await controller.purchaseRemoveAds()

        XCTAssertEqual(controller.status, .ready)
        XCTAssertTrue(controller.isRemoveAdsActive)
        XCTAssertTrue(repository.isRemoveAdsActive(for: .minikPlus))
        await store.finishUpdates()
    }

    @MainActor
    func testPendingPurchaseDoesNotGrantEntitlement() async {
        let store = InMemoryCommerceStore(
            products: [product()],
            outcomeByProductID: [removeAdsID: .pending]
        )
        let controller = makeController(store: store)
        await controller.start()

        await controller.purchaseRemoveAds()

        XCTAssertEqual(controller.status, .pending)
        XCTAssertFalse(controller.isRemoveAdsActive)
        await store.finishUpdates()
    }

    @MainActor
    func testTransactionUpdateAndRestoreReconcileAuthoritativeState() async {
        let store = InMemoryCommerceStore(products: [product()])
        let controller = makeController(store: store)
        await controller.start()
        await waitForListener(store)

        await store.setEntitlementState(EntitlementState(activeEntitlementIDs: [.minikRemoveAds]))
        await waitForEntitlement(controller)
        XCTAssertTrue(controller.isRemoveAdsActive)

        await store.setEntitlementState(EntitlementState())
        await controller.restorePurchases()
        XCTAssertFalse(controller.isRemoveAdsActive)
        XCTAssertEqual(controller.status, .ready)
        await store.finishUpdates()
    }

    func testParentalGateChallengeHasDeterministicAnswer() {
        XCTAssertEqual(ParentalGateChallenge(left: 37, right: 28).answer, 65)
    }

    func testParentalGateAcceptsArabicIndicDigitsAndRejectsWrongAnswers() {
        let challenge = ParentalGateChallenge(left: 37, right: 28)
        XCTAssertTrue(challenge.accepts("65"))
        XCTAssertTrue(challenge.accepts(" 65 "))
        XCTAssertTrue(challenge.accepts("٦٥"))
        XCTAssertFalse(challenge.accepts("64"))
        XCTAssertFalse(challenge.accepts(""))
        XCTAssertFalse(challenge.accepts("6a"))
        XCTAssertFalse(challenge.accepts("000065"))
    }

    @MainActor
    private func makeController(
        store: InMemoryCommerceStore,
        repository: MinikCommerceEntitlementRepository = MinikCommerceEntitlementRepository(
            userDefaults: UserDefaults(suiteName: "MinikCommerceIntegrationTests.\(UUID().uuidString)")!
        )
    ) -> MinikCommerceController {
        MinikCommerceController(
            configuration: MinikCommerceConfiguration(
                product: .minikPlus,
                removeAdsProductIdentifier: removeAdsID.rawValue
            ),
            store: store,
            repository: repository
        )
    }

    private func product() -> CommerceProduct {
        CommerceProduct(
            id: removeAdsID,
            displayName: "Remove Ads",
            displayPrice: "$1.99",
            kind: .nonConsumable
        )
    }

    @MainActor
    private func waitForListener(_ store: InMemoryCommerceStore) async {
        for _ in 0..<100 {
            if await store.updateListenerCount == 1 { return }
            await Task.yield()
        }
    }

    @MainActor
    private func waitForEntitlement(_ controller: MinikCommerceController) async {
        for _ in 0..<100 {
            if controller.isRemoveAdsActive { return }
            await Task.yield()
        }
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "MinikCommerceIntegrationTests.\(UUID().uuidString)")!
    }
}
