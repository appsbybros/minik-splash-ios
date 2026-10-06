import Foundation

/// The Realtime Database operations Android OnlineSession uses, so the room protocol stays
/// independent of the Firebase SDK (and the app runs offline when Firebase is not configured).
enum SplashOnlineError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

enum TransactionDecision {
    case abort
    case commit(Any)
}

@MainActor
protocol SplashDatabase: AnyObject {
    /// `ServerValue.TIMESTAMP`.
    var serverTimestamp: Any { get }
    func signIn(_ completion: @escaping @MainActor (Result<String, Error>) -> Void)
    func set(_ path: String, _ value: Any, _ completion: (@MainActor (Error?) -> Void)?)
    func update(_ path: String, _ values: [String: Any], _ completion: (@MainActor (Error?) -> Void)?)
    /// Completion: error, value, exists.
    func get(_ path: String, _ completion: @escaping @MainActor (Error?, Any?, Bool) -> Void)
    func observe(_ path: String, _ onChange: @escaping @MainActor (Any?) -> Void, _ onCancel: @escaping @MainActor (Error) -> Void) -> Int
    /// Child added and child changed events (Android ChildEventListener).
    func observeChildren(_ path: String, _ onChild: @escaping @MainActor (String, Any?) -> Void, _ onCancel: @escaping @MainActor (Error) -> Void) -> Int
    func removeObserver(_ token: Int)
    /// The update block may run on any thread; it must only read its argument and captured constants.
    func transaction(_ path: String, _ update: @escaping @Sendable (Any?) -> TransactionDecision, _ completion: @escaping @MainActor (Error?, Bool) -> Void)
    func onDisconnectSet(_ path: String, _ value: Any)
}

enum SplashDatabaseFactory {
    /// Android: debug builds use only the local emulator; release needs the app's own Firebase
    /// registration. iOS creates a FirebaseApp only when GoogleService-Info.plist is bundled.
    @MainActor
    static func make(host: String) throws -> SplashDatabase {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseDatabase)
        return try FirebaseSplashDatabase.connect(host: host)
        #else
        throw SplashOnlineError.message("Production online registration is not activated.")
        #endif
    }
}
