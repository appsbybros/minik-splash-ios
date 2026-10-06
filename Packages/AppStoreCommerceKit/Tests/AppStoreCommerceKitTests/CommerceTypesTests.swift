import XCTest
@testable import AppStoreCommerceKit

final class CommerceTypesTests: XCTestCase {
    func testCatalogMapsProductsToCallerSuppliedEntitlements() {
        let product = CommerceProductID(rawValue: "other.app.remove.ads")
        let entitlement = EntitlementID(rawValue: "other.app.entitlement.remove.ads")
        let catalog = CommerceCatalog(entitlementByProductID: [product: entitlement])

        XCTAssertEqual(catalog.productIDs, [product])
        XCTAssertEqual(catalog.entitlement(for: product), entitlement)
    }

    func testCatalogMatchesRawRoutingValuesOnlyToConfiguredProductIdentifiers() {
        let configured = CommerceProductID(rawValue: "other.app.remove.ads")
        let catalog = CommerceCatalog(
            entitlementByProductID: [configured: EntitlementID(rawValue: "other.app.entitlement.remove.ads")]
        )

        XCTAssertEqual(catalog.configuredProductID(matchingRawValue: configured.rawValue), configured)
        XCTAssertNil(catalog.configuredProductID(matchingRawValue: "other.app.unconfigured"))
        XCTAssertNil(catalog.configuredProductID(matchingRawValue: ""))
    }

    func testEntitlementStateContainsOnlyActiveCallerSuppliedIdentifiers() {
        let active = EntitlementID(rawValue: "other.app.feature.active")
        let inactive = EntitlementID(rawValue: "other.app.feature.inactive")
        let state = EntitlementState(activeEntitlementIDs: [active])

        XCTAssertTrue(state.contains(active))
        XCTAssertFalse(state.contains(inactive))
    }

    func testInMemoryStoreReportsConfiguredPendingOutcome() async throws {
        let id = CommerceProductID(rawValue: "other.app.remove.ads")
        let product = CommerceProduct(
            id: id,
            displayName: "Remove ads",
            displayPrice: "$1.99",
            kind: .nonConsumable
        )
        let store = InMemoryCommerceStore(products: [product])
        await store.setPurchaseOutcome(.pending, for: id)

        let loadedProducts = try await store.loadProducts()
        let purchaseOutcome = try await store.purchase(productID: id)
        let entitlements = try await store.refreshEntitlements()

        XCTAssertEqual(loadedProducts, [product])
        XCTAssertEqual(purchaseOutcome, .pending)
        XCTAssertEqual(entitlements, EntitlementState())
    }
}
