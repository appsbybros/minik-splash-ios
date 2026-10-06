import Foundation
import StoreKit

public final class StoreKitCommerceStore: CommerceStore, @unchecked Sendable {
    private let catalog: CommerceCatalog
    private let deliveryProcessor: CommerceDeliveryProcessor
    private let purchasePolicy = CommercePurchasePolicy()

    public init(catalog: CommerceCatalog, fulfillmentHandler: some CommerceFulfillmentHandler) {
        self.catalog = catalog
        self.deliveryProcessor = CommerceDeliveryProcessor(handler: fulfillmentHandler)
    }

    public func loadProducts() async throws -> [CommerceProduct] {
        let products = try await Product.products(for: catalog.productIDs.map(\.rawValue))
        return products.map(Self.commerceProduct)
            .filter { catalog.supports($0.kind) }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func purchase(productID: CommerceProductID) async throws -> PurchaseOutcome {
        let products = try await Product.products(for: [productID.rawValue])
        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            throw CommerceError.productNotFound(productID)
        }
        try purchasePolicy.validate(Self.commerceProduct(product), in: catalog)

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try Self.verifiedTransaction(verification)
            return .purchased(try await reconcileAndAcknowledge(transaction))
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            throw CommerceError.unexpectedPurchaseResult
        }
    }

    public func refreshEntitlements() async throws -> EntitlementState {
        let catalog = catalog
        return try await deliveryProcessor.currentState {
            try await Self.readCurrentEntitlements(in: catalog)
        }
    }

    private static func readCurrentEntitlements(in catalog: CommerceCatalog) async throws -> EntitlementState {
        var active = Set<EntitlementID>()
        for await verification in Transaction.currentEntitlements {
            guard let productID = Self.configuredProductIDForRouting(verification, in: catalog),
                  let entitlement = catalog.entitlement(for: productID) else {
                continue
            }
            let transaction = try Self.verifiedTransaction(verification)
            guard catalog.supports(Self.productKind(for: transaction.productType)) else {
                continue
            }
            active.insert(entitlement)
        }
        return EntitlementState(activeEntitlementIDs: active)
    }

    public func restorePurchases() async throws -> EntitlementState {
        try await AppStore.sync()
        return try await refreshEntitlements()
    }

    public func transactionUpdates() async -> AsyncStream<CommerceTransactionUpdate> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                for await verification in Transaction.updates {
                    guard let productID = Self.configuredProductIDForRouting(verification, in: self.catalog) else {
                        continue
                    }
                    guard case .verified(let transaction) = verification else {
                        continuation.yield(.failure(CommerceProcessingFailure(kind: .verification, productID: productID)))
                        continue
                    }
                    guard self.catalog.supports(Self.productKind(for: transaction.productType)) else {
                        continuation.yield(.failure(CommerceProcessingFailure(kind: .unsupportedProduct, productID: productID)))
                        continue
                    }
                    do {
                        continuation.yield(.entitlements(try await self.reconcileAndAcknowledge(transaction)))
                    } catch let error as CommerceError {
                        continuation.yield(.failure(Self.processingFailure(for: error, productID: productID)))
                    } catch {
                        continuation.yield(.failure(CommerceProcessingFailure(kind: .fulfillment, productID: productID)))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func commerceProduct(_ product: Product) -> CommerceProduct {
        CommerceProduct(
            id: CommerceProductID(rawValue: product.id),
            displayName: product.displayName,
            displayPrice: product.displayPrice,
            kind: productKind(for: product.type)
        )
    }

    private static func productKind(for type: Product.ProductType) -> CommerceProductKind {
        switch type {
        case .consumable: .consumable
        case .nonConsumable: .nonConsumable
        case .autoRenewable: .autoRenewableSubscription
        case .nonRenewable: .nonRenewingSubscription
        default: .unknown(type.rawValue)
        }
    }

    private func reconcileAndAcknowledge(_ transaction: Transaction) async throws -> EntitlementState {
        let productID = CommerceProductID(rawValue: transaction.productID)
        guard let entitlementID = catalog.entitlement(for: productID) else {
            throw CommerceError.productNotFound(productID)
        }
        guard catalog.supports(Self.productKind(for: transaction.productType)) else {
            throw CommerceError.unsupportedProductType(productID, Self.productKind(for: transaction.productType))
        }
        let catalog = catalog
        return try await deliveryProcessor.process(
            transactionID: String(transaction.id),
            productID: productID,
            entitlementID: entitlementID,
            currentState: {
                try await Self.readCurrentEntitlements(in: catalog)
            },
            acknowledge: {
                await transaction.finish()
            }
        )
    }

    private static func processingFailure(
        for error: CommerceError,
        productID: CommerceProductID
    ) -> CommerceProcessingFailure {
        switch error {
        case .verificationFailed:
            CommerceProcessingFailure(kind: .verification, productID: productID)
        case .unsupportedProductType:
            CommerceProcessingFailure(kind: .unsupportedProduct, productID: productID)
        case .productNotFound, .unexpectedPurchaseResult, .purchaseOutcomeNotConfigured:
            CommerceProcessingFailure(kind: .entitlementRefresh, productID: productID)
        }
    }

    private static func configuredProductIDForRouting(
        _ result: VerificationResult<Transaction>,
        in catalog: CommerceCatalog
    ) -> CommerceProductID? {
        let rawProductID: String

        switch result {
        case .verified(let transaction):
            rawProductID = transaction.productID
        case .unverified(let transaction, _):
            rawProductID = transaction.productID
        }

        // Only the raw value is inspected; the returned identifier already belongs to the catalog.
        return catalog.configuredProductID(matchingRawValue: rawProductID)
    }

    private static func verifiedTransaction(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction): transaction
        case .unverified: throw CommerceError.verificationFailed
        }
    }

}
