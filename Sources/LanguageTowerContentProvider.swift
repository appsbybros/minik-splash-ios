import Foundation

struct LanguageTowerContentProvider: Sendable {
    private let configuration: ProductConfiguration
    private let categoryID: LanguageWordCategoryID?

    init(
        configuration: ProductConfiguration,
        categoryID: LanguageWordCategoryID? = nil
    ) {
        self.configuration = configuration
        self.categoryID = categoryID
    }

    func round(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> TowerOrderedTokenRound? {
        guard let item = eligibleItems(
            for: request,
            learnedLanguage: learnedLanguage
        ).randomElement() else {
            return nil
        }
        return round(
            for: request,
            learnedLanguage: learnedLanguage,
            item: item
        )
    }

    func rounds(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> [TowerOrderedTokenRound] {
        eligibleItems(
            for: request,
            learnedLanguage: learnedLanguage
        ).shuffled().compactMap { item in
            round(
                for: request,
                learnedLanguage: learnedLanguage,
                item: item
            )
        }
    }

    func round(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier,
        item: LanguageWordCatalogItem
    ) -> TowerOrderedTokenRound? {
        guard let level = validatedLevel(
            for: request,
            learnedLanguage: learnedLanguage
        ),
              LanguageWordLevelContent.content(for: level).items(
                  constrainedTo: categoryID
              ).contains(where: { $0.id == item.id }),
              item.isLexical,
              let learnedText = LanguageWordContentProvider.learnedText(
                  for: item,
                  language: learnedLanguage
              ),
              let language = learnedText.language else {
            return nil
        }

        let targetText = LearningTextRepresentation(
            text: learnedText.text.uppercased(),
            language: learnedText.language,
            direction: learnedText.direction,
            speechText: learnedText.speechText ?? learnedText.text
        )
        let expectedTokens = targetText.text.compactMap { character -> LearningTextRepresentation? in
            guard !character.isWhitespace else {
                return nil
            }
            return LearningTextRepresentation(
                text: String(character),
                language: targetText.language,
                direction: targetText.direction,
                speechText: LanguageLearnContentProvider.pronunciationText(
                    forLetter: String(character),
                    language: learnedLanguage
                )
            )
        }
        guard (3 ... 10).contains(expectedTokens.count),
              let content = TowerOrderedTokenContent(
                  contentItemID: item.id,
                  vocabularyLevel: level,
                  targetText: targetText,
                  expectedTokenSequence: expectedTokens,
                  image: item.isImageReady ? item.imageAssetReference : nil,
                  speechCue: LearningSpeechUtterance(
                      text: learnedText.speechText ?? learnedText.text,
                      language: language
                  )
              ) else {
            return nil
        }

        let instanceID = UUID().uuidString
        let blocks = expectedTokens.enumerated().map { index, token in
            TowerBlock(
                id: TowerBlockID(
                    rawValue: "languageTower.\(instanceID).block.\(index)"
                ),
                orderedToken: token,
                contentItemID: item.id
            )
        }.shuffled()

        return TowerOrderedTokenRound(
            id: TowerRoundID(
                rawValue: "languageTower.\(item.id.rawValue).\(instanceID).round"
            ),
            blocks: blocks,
            content: content
        )
    }

    private func eligibleItems(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> [LanguageWordCatalogItem] {
        guard let level = validatedLevel(
            for: request,
            learnedLanguage: learnedLanguage
        ) else {
            return []
        }

        let items = LanguageWordLevelContent.content(for: level).items(
            constrainedTo: categoryID,
            including: { item in
                guard item.isLexical,
                      let text = LanguageWordContentProvider.learnedText(
                          for: item,
                          language: learnedLanguage
                      )?.text else {
                    return false
                }
                return (3 ... 10).contains(text.filter { !$0.isWhitespace }.count)
            }
        )
        return items
    }

    private func validatedLevel(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> LanguageVocabularyLevel? {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .tower,
              let level = LanguageVocabularyLevel(
                  curriculumStageID: request.curriculumStage
              ),
              request.primarySkill == LanguageSkillIDs.wordConstruction,
              request.interaction == .orderedTokens,
              request.countRequirement == nil else {
            return nil
        }
        return level
    }
}
