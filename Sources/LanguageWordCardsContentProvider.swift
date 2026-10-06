import Foundation

struct LanguageWordCardsContentProvider: Sendable {
    private let configuration: ProductConfiguration
    private let categoryID: LanguageWordCategoryID?

    init(
        configuration: ProductConfiguration,
        categoryID: LanguageWordCategoryID? = nil
    ) {
        self.configuration = configuration
        self.categoryID = categoryID
    }

    func studyCards(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> [StudyCard] {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .cards,
              let level = LanguageVocabularyLevel(curriculumStageID: request.curriculumStage),
              request.primarySkill == LanguageSkillIDs.wordRecognition,
              request.interaction == nil,
              request.countRequirement == nil else {
            return []
        }

        let levelItems = LanguageWordLevelContent.content(for: level).items(
            constrainedTo: categoryID,
            including: { $0.isLexical }
        )

        let locale = locale(for: learnedLanguage)
        var seenNormalizedWords = Set<String>()

        return levelItems.compactMap { item -> StudyCard? in
            guard let learnedText = LanguageWordContentProvider.learnedText(
                for: item,
                language: learnedLanguage
            ) else {
                return nil
            }

            let trimmedText = learnedText.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else {
                return nil
            }

            let normalizedKey = trimmedText.lowercased(with: locale)
            guard seenNormalizedWords.insert(normalizedKey).inserted else {
                return nil
            }

            let displayText = LearningTextRepresentation(
                text: trimmedText,
                language: learnedText.language,
                direction: learnedText.direction,
                speechText: learnedText.speechText
            )

            return StudyCard(
                id: StudyCardID(rawValue: "study.\(item.id.rawValue)"),
                representations: [.learningText(displayText)],
                primarySkill: request.primarySkill,
                curriculumStage: request.curriculumStage
            )
        }
    }

    private func locale(for learnedLanguage: LanguageIdentifier) -> Locale {
        switch learnedLanguage {
        case .english:
            return Locale(identifier: "en_US_POSIX")
        case .hebrew:
            return Locale(identifier: "he_IL")
        default:
            return Locale(identifier: learnedLanguage.rawValue)
        }
    }
}
