import Foundation

/// Android Plus fixes reading capability to fluent in IntroScreen (458/1902).
/// WriteScreen's clue is independent of the learned target and letter tokens.
struct LanguageWordBuildClue: Hashable, Sendable {
    let text: LearningTextRepresentation?
    let image: AssetReference?

    static func make(for challenge: BuildChallenge, interfaceLocale: InterfaceLocaleID) -> Self {
        guard let content = challenge.languageWordContent,
              let item = LanguageWordCatalog.allItems.first(where: { $0.id == content.contentItemID }) else {
            return Self(text: nil, image: challenge.prompt.representations.compactMap {
                if case .imageAsset(let image) = $0 { return image }
                return nil
            }.first)
        }
        return make(item: item, learnedLanguage: content.targetText.language, interfaceLocale: interfaceLocale)
    }

    static func make(item: LanguageWordCatalogItem, learnedLanguage: LanguageIdentifier?,
                     interfaceLocale: InterfaceLocaleID) -> Self {
        let hostCode = interfaceLocale.locale.language.languageCode?.identifier
        let sameLanguage = hostCode == learnedLanguage?.rawValue
        let hostWordLanguage: LanguageIdentifier = hostCode == "he" ? .hebrew : .english
        // WordItemLoader uses Hebrew for Hebrew host, English otherwise.
        // Non-en/he Plus hosts retain the image + English clue source path.
        let text = sameLanguage ? nil : LanguageWordContentProvider.learnedText(for: item, language: hostWordLanguage)
        let image = hostCode == "en" || hostCode == "he" ? nil : item.imageAssetReference
        return Self(text: text, image: image)
    }
}

struct LanguageWordCompletion: Hashable, Sendable {
    let id: UUID
    let contentItemID: ContentItemID
    let hadIncorrectLetter: Bool
    let vocabularyLevel: LanguageVocabularyLevel?

    init(id: UUID, contentItemID: ContentItemID, hadIncorrectLetter: Bool,
         vocabularyLevel: LanguageVocabularyLevel? = nil) {
        self.id = id
        self.contentItemID = contentItemID
        self.hadIncorrectLetter = hadIncorrectLetter
        self.vocabularyLevel = vocabularyLevel
    }
}
