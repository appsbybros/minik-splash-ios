import Foundation

struct LanguageWordCategoryID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension LanguageWordCategoryID {
    static let fruits = LanguageWordCategoryID(rawValue: "fruits")
}

struct LanguageWordCatalogItem: Hashable, Sendable {
    let id: ContentItemID
    let stableKey: String
    let androidWordID: String?
    let englishText: String
    let hebrewText: String
    let imageManifestEntry: LanguageVocabularyImageManifestEntry?
    let baseLevel: LanguageVocabularyLevel
    let categoryID: LanguageWordCategoryID
    let hebrewSpeechText: String?
    let contentKind: LanguageVocabularyContentKind

    var category: String {
        categoryID.rawValue
    }

    var androidLevel: String {
        baseLevel.rawValue
    }

    var imageAssetReference: AssetReference? {
        imageManifestEntry?.assetReference
    }

    var isImageReady: Bool {
        imageManifestEntry?.isReadyInCurrentIOS == true
    }

    var isLexical: Bool {
        contentKind != .sentence
    }

    var image: AssetReference {
        guard let imageAssetReference else {
            preconditionFailure("Image access requires an image-capable vocabulary item.")
        }
        return imageAssetReference
    }
}

struct LanguageWordCategory: Hashable, Sendable {
    let id: LanguageWordCategoryID
    let sourceName: String
    let items: [LanguageWordCatalogItem]
}

enum LanguageWordCatalog {
    static let defaultCategoryID = LanguageWordCategoryID.fruits

    static let categories = categories(for: .a)

    static let imageManifestEntries = runtimeCatalog.imageManifestEntries

    static let currentIOSReadyImageAssets = runtimeCatalog.availableImageAssetReferences

    static let initialLetterSupportItems = [
        item(stableKey: "vegetables_garlic"),
        item(stableKey: "other_king")
    ].compactMap { $0 }

    static func categories(
        for level: LanguageVocabularyLevel
    ) -> [LanguageWordCategory] {
        runtimeCatalog.categories(for: level)
    }

    static func items(
        for level: LanguageVocabularyLevel
    ) -> [LanguageWordCatalogItem] {
        runtimeCatalog.items(for: level)
    }

    static func category(
        withID id: LanguageWordCategoryID,
        level: LanguageVocabularyLevel = .a
    ) -> LanguageWordCategory? {
        categories(for: level).first { $0.id == id }
    }

    static var allItems: [LanguageWordCatalogItem] {
        runtimeCatalog.allItems
    }

    static func item(
        stableKey: String
    ) -> LanguageWordCatalogItem? {
        runtimeCatalog.item(stableKey: stableKey)
    }

    private static let runtimeCatalog: LanguageVocabularyCatalogData = {
        do {
            return try LanguageVocabularyCatalogLoader.loadApprovedCatalog()
        } catch {
            preconditionFailure("Failed to load vocabulary resources: \(error)")
        }
    }()
}
