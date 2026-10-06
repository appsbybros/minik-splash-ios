import Foundation

struct SoccerIntroductionRepository {
    static let maximumPresentationCount = 3

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "minik.languageSoccer.introductionPresentationCount.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    @discardableResult
    func registerPresentationIfNeeded() -> Bool {
        let presentationCount = max(0, userDefaults.integer(forKey: storageKey))
        guard presentationCount < Self.maximumPresentationCount else {
            return false
        }

        userDefaults.set(presentationCount + 1, forKey: storageKey)
        return true
    }
}
