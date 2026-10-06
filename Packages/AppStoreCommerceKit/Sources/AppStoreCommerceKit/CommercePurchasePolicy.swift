import Foundation

/// Shared pre-purchase validation used by the StoreKit adapter and deterministic
/// tests. Validation happens before calling StoreKit's purchase API.
public struct CommercePurchasePolicy: Sendable {
    public init() {}

    public func validate(_ product: CommerceProduct, in catalog: CommerceCatalog) throws {
        guard catalog.entitlement(for: product.id) != nil else {
            throw CommerceError.productNotFound(product.id)
        }
        guard catalog.supports(product.kind) else {
            throw CommerceError.unsupportedProductType(product.id, product.kind)
        }
    }
}
