import Foundation

public struct CommerceProductID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A commerce product identifier cannot be empty.")
        self.rawValue = rawValue
    }

    public var id: String { rawValue }
}

public struct EntitlementID: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty, "An entitlement identifier cannot be empty.")
        self.rawValue = rawValue
    }

    public var id: String { rawValue }
}

public enum CommerceProductKind: Hashable, Sendable {
    case consumable
    case nonConsumable
    case autoRenewableSubscription
    case nonRenewingSubscription
    case unknown(String)

    var supportsPersistentEntitlementDelivery: Bool {
        switch self {
        case .nonConsumable, .autoRenewableSubscription:
            true
        case .consumable, .nonRenewingSubscription, .unknown:
            false
        }
    }
}

public struct CommerceProduct: Hashable, Sendable, Identifiable {
    public let id: CommerceProductID
    public let displayName: String
    public let displayPrice: String
    public let kind: CommerceProductKind

    public init(id: CommerceProductID, displayName: String, displayPrice: String, kind: CommerceProductKind) {
        self.id = id
        self.displayName = displayName
        self.displayPrice = displayPrice
        self.kind = kind
    }
}

public struct CommerceCatalog: Hashable, Sendable {
    public let entitlementByProductID: [CommerceProductID: EntitlementID]
    public let supportedProductKinds: Set<CommerceProductKind>

    public init(
        entitlementByProductID: [CommerceProductID: EntitlementID],
        supportedProductKinds: Set<CommerceProductKind> = [.nonConsumable, .autoRenewableSubscription]
    ) {
        self.entitlementByProductID = entitlementByProductID
        self.supportedProductKinds = supportedProductKinds
    }

    public var productIDs: Set<CommerceProductID> { Set(entitlementByProductID.keys) }

    public func entitlement(for productID: CommerceProductID) -> EntitlementID? {
        entitlementByProductID[productID]
    }

    func configuredProductID(matchingRawValue rawValue: String) -> CommerceProductID? {
        productIDs.first { $0.rawValue == rawValue }
    }

    public func supports(_ kind: CommerceProductKind) -> Bool {
        kind.supportsPersistentEntitlementDelivery && supportedProductKinds.contains(kind)
    }
}

public struct EntitlementState: Hashable, Sendable {
    public let activeEntitlementIDs: Set<EntitlementID>

    public init(activeEntitlementIDs: Set<EntitlementID> = []) {
        self.activeEntitlementIDs = activeEntitlementIDs
    }

    public func contains(_ entitlementID: EntitlementID) -> Bool {
        activeEntitlementIDs.contains(entitlementID)
    }
}

public enum PurchaseOutcome: Hashable, Sendable {
    case purchased(EntitlementState)
    case pending
    case userCancelled
}

public enum CommerceError: Error, Equatable, Sendable {
    case productNotFound(CommerceProductID)
    case unsupportedProductType(CommerceProductID, CommerceProductKind)
    case verificationFailed
    case unexpectedPurchaseResult
    case purchaseOutcomeNotConfigured(CommerceProductID)
}

public struct CommerceFulfillment: Hashable, Sendable {
    public let transactionID: String
    public let productID: CommerceProductID
    public let entitlementID: EntitlementID
    public let entitlementState: EntitlementState

    public init(
        transactionID: String,
        productID: CommerceProductID,
        entitlementID: EntitlementID,
        entitlementState: EntitlementState
    ) {
        self.transactionID = transactionID
        self.productID = productID
        self.entitlementID = entitlementID
        self.entitlementState = entitlementState
    }
}

/// The consuming application fulfills its own feature state using this neutral
/// value. It never receives a StoreKit transaction.
public protocol CommerceFulfillmentHandler: Sendable {
    func fulfill(_ fulfillment: CommerceFulfillment) async throws
}

public enum CommerceProcessingFailureKind: String, Equatable, Sendable {
    case verification
    case unsupportedProduct
    case entitlementRefresh
    case fulfillment
    case acknowledgment
}

public struct CommerceProcessingFailure: Equatable, Sendable {
    public let kind: CommerceProcessingFailureKind
    public let productID: CommerceProductID?

    public init(kind: CommerceProcessingFailureKind, productID: CommerceProductID? = nil) {
        self.kind = kind
        self.productID = productID
    }
}

public enum CommerceTransactionUpdate: Equatable, Sendable {
    case entitlements(EntitlementState)
    case failure(CommerceProcessingFailure)
}

public protocol CommerceStore: Sendable {
    func loadProducts() async throws -> [CommerceProduct]
    func purchase(productID: CommerceProductID) async throws -> PurchaseOutcome
    func refreshEntitlements() async throws -> EntitlementState
    func restorePurchases() async throws -> EntitlementState
    func transactionUpdates() async -> AsyncStream<CommerceTransactionUpdate>
}
