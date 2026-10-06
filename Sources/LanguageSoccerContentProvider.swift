import Foundation

struct LanguageSoccerContentProvider: Sendable {
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
    ) -> SoccerRound? {
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
    ) -> [SoccerRound] {
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
    ) -> SoccerRound? {
        guard let level = validatedLevel(
            for: request,
            learnedLanguage: learnedLanguage
        ),
              LanguageWordLevelContent.content(for: level).items(
                  constrainedTo: categoryID
              ).contains(where: { $0.id == item.id }),
              item.isLexical,
              let targetText = LanguageWordContentProvider.learnedText(
                  for: item,
                  language: learnedLanguage
              ) else {
            return nil
        }

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
        guard !expectedTokens.isEmpty,
              let language = targetText.language else {
            return nil
        }

        let instanceID = UUID().uuidString
        let balls = expectedTokens.enumerated().map { index, token in
            SoccerAnswerBall(
                id: SoccerBallID(rawValue: "languageSoccer.\(instanceID).ball.\(index)"),
                orderedToken: token,
                contentItemID: item.id
            )
        }.shuffled()
        let content = SoccerOrderedTokenContent(
            contentItemID: item.id,
            vocabularyLevel: level,
            targetText: targetText,
            expectedTokenSequence: expectedTokens,
            image: item.isImageReady ? item.imageAssetReference : nil,
            speechCue: LearningSpeechUtterance(
                text: targetText.speechText ?? targetText.text,
                language: language
            )
        )
        guard let content else {
            return nil
        }

        return SoccerRound(
            id: SoccerRoundID(
                rawValue: "languageSoccer.\(item.id.rawValue).\(instanceID).round"
            ),
            answerBalls: balls,
            orderedTokenContent: content
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
                item.isLexical
                    && LanguageWordContentProvider.learnedText(
                        for: item,
                        language: learnedLanguage
                    )?.text.contains(where: { !$0.isWhitespace }) == true
            }
        )
        let imageBackedItems = items.filter(\.isImageReady)
        return imageBackedItems.isEmpty ? items : imageBackedItems
    }

    private func validatedLevel(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> LanguageVocabularyLevel? {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .soccer,
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
