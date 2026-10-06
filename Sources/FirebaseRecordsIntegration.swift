import Foundation

#if (MINIK_PLUS || MINIK_PLUS_ENGLISH) && canImport(FirebaseAppCheck) && canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
#endif

enum FirebaseAppCheckProviderMode: Equatable, Sendable {
    case appAttest
    case debug
}

enum FirebaseAppCheckBuildPolicy {
    static func providerMode(isDebugBuild: Bool) -> FirebaseAppCheckProviderMode {
        isDebugBuild ? .debug : .appAttest
    }

    static var currentProviderMode: FirebaseAppCheckProviderMode {
        #if DEBUG
        return providerMode(isDebugBuild: true)
        #else
        return providerMode(isDebugBuild: false)
        #endif
    }
}

enum FirebaseBootstrapState: Equatable, Sendable {
    case configured
    case alreadyConfigured
    case unsupportedProduct
    case missingConfigurationFile
    case invalidConfigurationFile
    case sdkUnavailable

    var canUseRemoteRecords: Bool {
        self == .configured || self == .alreadyConfigured
    }
}

enum FirebaseBootstrap {
    @MainActor
    static func configureIfAvailable(
        for product: ProductVariant,
        bundle: Bundle = .main
    ) -> FirebaseBootstrapState {
        guard RemoteRecordsConfiguration.androidCompatible(for: product) != nil else {
            return .unsupportedProduct
        }

        #if (MINIK_PLUS || MINIK_PLUS_ENGLISH) && canImport(FirebaseAppCheck) && canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        if FirebaseApp.app() != nil {
            return .alreadyConfigured
        }
        guard let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist") else {
            return .missingConfigurationFile
        }
        guard let options = FirebaseOptions(contentsOfFile: path) else {
            return .invalidConfigurationFile
        }
        FirebaseAppCheckBootstrap.configureProvider()
        FirebaseApp.configure(options: options)
        return .configured
        #else
        return .sdkUnavailable
        #endif
    }
}

enum ProductionRecordsRepositoryFactory {
    @MainActor
    static func make(
        for product: ProductVariant,
        ownerID: RewardOwnerID = .localDefault,
        publicLeaderboardStore: UserDefaultsPublicLeaderboardStateStore? = nil
    ) -> (any RecordsRepository)? {
        guard let configuration = RemoteRecordsConfiguration.androidCompatible(for: product) else {
            return nil
        }

        #if (MINIK_PLUS || MINIK_PLUS_ENGLISH) && canImport(FirebaseAppCheck) && canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else { return nil }
        let scope = RewardScope(ownerID: ownerID, product: product)
        let stateStore = publicLeaderboardStore
            ?? UserDefaultsPublicLeaderboardStateStore(scope: scope)
        let identityStore = AndroidCompatibleRecordsIdentityStore(
            product: product,
            ownerID: ownerID
        )
        let authentication = FirebaseAnonymousRecordsAuthentication()
        let firebaseDataSource = FirebaseFirestoreRecordsDataSource()
        return AndroidCompatibleRecordsRepository(
            configuration: configuration,
            dataSource: AuthenticatedRemoteRecordsDataSource(
                dataSource: firebaseDataSource,
                authentication: authentication
            ),
            ownershipStore: AuthenticatedRemoteRecordsOwnershipStore(
                dataSource: firebaseDataSource,
                authentication: authentication
            ),
            identityProvider: identityStore,
            publicAliasProvider: stateStore,
            participationProvider: stateStore
        )
        #else
        return nil
        #endif
    }
}

#if (MINIK_PLUS || MINIK_PLUS_ENGLISH) && canImport(FirebaseAppCheck) && canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
private enum FirebaseAppCheckBootstrap {
    static func configureProvider() {
        switch FirebaseAppCheckBuildPolicy.currentProviderMode {
        case .debug:
            #if DEBUG
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            preconditionFailure("Release builds cannot select the Firebase App Check debug provider.")
            #endif
        case .appAttest:
            AppCheck.setAppCheckProviderFactory(MinikAppAttestProviderFactory())
        }
    }
}

private final class MinikAppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}

private final class FirebaseFirestoreRecordsDataSource:
    RemoteRecordsDataSource,
    RemoteRecordsOwnershipClaiming,
    @unchecked Sendable {
    private let database: Firestore

    init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    func query(_ query: RemoteRecordsQuery) async throws -> RemoteRecordsQueryResult {
        let snapshot = try await database
            .collection(query.collection)
            .whereField(RemoteRecordsSchema.appID, isEqualTo: query.appID)
            .order(by: query.orderField, descending: true)
            .limit(to: query.limit)
            .getDocuments()
        return RemoteRecordsQueryResult(
            documents: snapshot.documents.map(Self.document),
            isFromCache: snapshot.metadata.isFromCache
        )
    }

    func mergeAtomically(_ writes: [RemoteRecordsWrite]) async throws {
        guard !writes.isEmpty else { return }
        let batch = database.batch()
        for write in writes {
            let reference = database.collection(write.collection).document(write.documentID)
            batch.setData(Self.firebaseFields(write.fields), forDocument: reference, merge: true)
        }
        try await batch.commit()
    }

    func deleteAtomically(_ deletions: [RemoteRecordsDeletion]) async throws {
        guard !deletions.isEmpty else { return }
        let batch = database.batch()
        for deletion in deletions {
            let reference = database.collection(deletion.collection).document(deletion.documentID)
            batch.deleteDocument(reference)
        }
        try await batch.commit()
    }

    func claimOwnership(_ claim: RemoteRecordsOwnershipClaim) async throws {
        try await database
            .collection(RemoteRecordsOwnershipSchema.collection)
            .document(claim.playerID)
            .setData([
                RemoteRecordsOwnershipSchema.ownerUID: claim.ownerUID
            ], merge: false)
    }

    private static func document(_ snapshot: QueryDocumentSnapshot) -> RemoteRecordDocument {
        RemoteRecordDocument(
            documentID: snapshot.documentID,
            fields: snapshot.data().compactMapValues(remoteValue)
        )
    }

    private static func remoteValue(_ value: Any) -> RemoteRecordValue? {
        switch value {
        case let value as String:
            return .string(value)
        case let value as Timestamp:
            return .date(value.dateValue())
        case let value as NSNumber:
            return .integer(value.int64Value)
        case let value as Date:
            return .date(value)
        default:
            return nil
        }
    }

    private static func firebaseFields(_ fields: [String: RemoteRecordValue]) -> [String: Any] {
        fields.mapValues { value in
            switch value {
            case .string(let value):
                return value
            case .integer(let value):
                return value
            case .date(let value):
                return Timestamp(date: value)
            case .serverTimestamp:
                return FieldValue.serverTimestamp()
            }
        }
    }
}

private actor FirebaseAnonymousRecordsAuthentication: RemoteRecordsAuthenticating {
    private var inFlightAuthentication: Task<String, Error>?

    func ensureAuthenticated() async throws -> String {
        if let currentUser = Auth.auth().currentUser { return currentUser.uid }
        if let inFlightAuthentication {
            return try await inFlightAuthentication.value
        }

        let task = Task<String, Error> {
            let result = try await Auth.auth().signInAnonymously()
            return result.user.uid
        }
        inFlightAuthentication = task
        defer { inFlightAuthentication = nil }
        return try await task.value
    }
}
#endif
