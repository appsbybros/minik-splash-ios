import XCTest
@testable import AppStoreCommerceKit

final class CommercePurchasePolicyTests: XCTestCase {
    func testConfiguredNonConsumableIsSupported() throws {
        let product = makeProduct(kind: .nonConsumable)
        let catalog = makeCatalog(for: product.id)

        XCTAssertNoThrow(try CommercePurchasePolicy().validate(product, in: catalog))
    }

    func testConfiguredAutoRenewableSubscriptionIsSupported() throws {
        let product = makeProduct(kind: .autoRenewableSubscription)
        let catalog = makeCatalog(for: product.id)

        XCTAssertNoThrow(try CommercePurchasePolicy().validate(product, in: catalog))
    }

    func testConsumableNonRenewingAndUnknownProductsAreRejectedBeforePurchase() {
        let cases: [CommerceProductKind] = [.consumable, .nonRenewingSubscription, .unknown("future")]

        for kind in cases {
            let product = makeProduct(kind: kind)
            let catalog = makeCatalog(for: product.id)
            XCTAssertThrowsError(try CommercePurchasePolicy().validate(product, in: catalog)) { error in
                XCTAssertEqual(error as? CommerceError, .unsupportedProductType(product.id, kind))
            }
        }
    }

    func testUnknownCatalogProductIsRejected() {
        let product = makeProduct(kind: .nonConsumable)

        XCTAssertThrowsError(try CommercePurchasePolicy().validate(product, in: CommerceCatalog(entitlementByProductID: [:]))) { error in
            XCTAssertEqual(error as? CommerceError, .productNotFound(product.id))
        }
    }

    private func makeCatalog(for productID: CommerceProductID) -> CommerceCatalog {
        CommerceCatalog(entitlementByProductID: [productID: EntitlementID(rawValue: "example.feature")])
    }

    private func makeProduct(kind: CommerceProductKind) -> CommerceProduct {
        CommerceProduct(
            id: CommerceProductID(rawValue: "example.product"),
            displayName: "Example",
            displayPrice: "$1.99",
            kind: kind
        )
    }
}
