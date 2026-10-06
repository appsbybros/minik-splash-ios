import Foundation

enum EducationalParentAreaPolicy {
    static func isAvailable(for product: ProductVariant) -> Bool {
        switch product {
        case .minikPlus, .minikPlusEnglish, .minikMath:
            return true
        case .minikPingPong:
            return false
        }
    }
}

final class LearnedLanguageRepository {
    private let userDefaults: UserDefaults
    private let storageKeyPrefix: String
    private let interfaceLocale: (ProductVariant) -> InterfaceLocaleID

    init(
        userDefaults: UserDefaults = .standard,
        storageKeyPrefix: String = "minik.learned-language.v1",
        interfaceLocale: @escaping (ProductVariant) -> InterfaceLocaleID = { InterfaceLocaleRepository().load(for: $0) }
    ) {
        self.userDefaults = userDefaults
        self.storageKeyPrefix = storageKeyPrefix
        self.interfaceLocale = interfaceLocale
    }

    func load(for configuration: ProductConfiguration) -> LanguageIdentifier? {
        let stored = userDefaults.string(forKey: storageKey(for: configuration.variant))
            .map(LanguageIdentifier.init(rawValue:))
        return configuration.resolveRestoredLearnedLanguage(stored) ?? defaultLanguage(for: configuration)
    }

    /// As on Android, a Hebrew interface learns English and any other interface learns Hebrew.
    func defaultLanguage(for configuration: ProductConfiguration) -> LanguageIdentifier? {
        if let fixed = configuration.fixedLearnedLanguage { return fixed }
        let preferred: LanguageIdentifier = interfaceLocale(configuration.variant) == .hebrew ? .english : .hebrew
        if configuration.allowsLearnedLanguage(preferred) { return preferred }
        return configuration.allowedLearnedLanguages.sorted { $0.rawValue < $1.rawValue }.first
    }

    func save(_ language: LanguageIdentifier, for configuration: ProductConfiguration) {
        guard let resolved = configuration.resolveRestoredLearnedLanguage(language) else { return }
        userDefaults.set(resolved.rawValue, forKey: storageKey(for: configuration.variant))
    }

    private func storageKey(for product: ProductVariant) -> String {
        "\(storageKeyPrefix).\(product.rawValue)"
    }
}

final class EncouragementPreferenceRepository {
    private let userDefaults: UserDefaults
    private let storageKeyPrefix: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKeyPrefix: String = "minik.encouragement-enabled.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKeyPrefix = storageKeyPrefix
    }

    func load(for product: ProductVariant) -> Bool {
        let key = storageKey(for: product)
        guard userDefaults.object(forKey: key) != nil else { return true }
        return userDefaults.bool(forKey: key)
    }

    func save(_ isEnabled: Bool, for product: ProductVariant) {
        userDefaults.set(isEnabled, forKey: storageKey(for: product))
    }

    private func storageKey(for product: ProductVariant) -> String {
        "\(storageKeyPrefix).\(product.rawValue)"
    }
}

enum LanguageLevelMode: String, CaseIterable, Equatable, Hashable, Sendable {
    case automatic
    case manual
}

enum LanguageSoccerLevel: String, CaseIterable, Equatable, Hashable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
}

struct LanguageParentLevelSettings: Equatable, Sendable {
    var mode: LanguageLevelMode
    var wordLevel: LanguageVocabularyLevel
    var soccerLevel: LanguageSoccerLevel
    var ticTacToeLevel: TicTacToeLevel

    static let androidDefault = LanguageParentLevelSettings(
        mode: .automatic,
        wordLevel: .a,
        soccerLevel: .a,
        ticTacToeLevel: .adaptive
    )
}

final class LanguageParentLevelSettingsRepository {
    private let userDefaults: UserDefaults
    private let storageKeyPrefix: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKeyPrefix: String = "minik.language-levels.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKeyPrefix = storageKeyPrefix
    }

    func load(for product: ProductVariant) -> LanguageParentLevelSettings {
        let defaults = LanguageParentLevelSettings.androidDefault
        return LanguageParentLevelSettings(
            mode: storedValue(LanguageLevelMode.self, name: "mode", product: product) ?? defaults.mode,
            wordLevel: storedValue(LanguageVocabularyLevel.self, name: "words", product: product) ?? defaults.wordLevel,
            soccerLevel: storedValue(LanguageSoccerLevel.self, name: "soccer", product: product) ?? defaults.soccerLevel,
            ticTacToeLevel: TicTacToePreferences(userDefaults: userDefaults).selectedLevel
        )
    }

    func save(_ settings: LanguageParentLevelSettings, for product: ProductVariant) {
        userDefaults.set(settings.mode.rawValue, forKey: storageKey(name: "mode", product: product))
        userDefaults.set(settings.wordLevel.rawValue, forKey: storageKey(name: "words", product: product))
        userDefaults.set(settings.soccerLevel.rawValue, forKey: storageKey(name: "soccer", product: product))
        TicTacToePreferences(userDefaults: userDefaults).selectedLevel = settings.ticTacToeLevel
    }

    private func storedValue<Value: RawRepresentable>(
        _ type: Value.Type,
        name: String,
        product: ProductVariant
    ) -> Value? where Value.RawValue == String {
        userDefaults.string(forKey: storageKey(name: name, product: product)).flatMap(Value.init(rawValue:))
    }

    private func storageKey(name: String, product: ProductVariant) -> String {
        "\(storageKeyPrefix).\(product.rawValue).\(name)"
    }
}

extension InterfaceLocaleID {
    var displayName: String { String(localized: displayNameKey) }

    var displayNameKey: String.LocalizationValue {
        switch self {
        case .english: return "English"
        case .amharic: return "Amharic"
        case .arabic: return "Arabic"
        case .german: return "German"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .hebrew: return "Hebrew"
        case .dutch: return "Dutch"
        case .portugueseBrazil: return "Portuguese (Brazil)"
        case .portuguesePortugal: return "Portuguese (Portugal)"
        case .russian: return "Russian"
        }
    }
}
