import Foundation

struct LanguageWordBuildContentProvider: Sendable {
    private let configuration: ProductConfiguration
    private let categoryID: LanguageWordCategoryID?

    init(
        configuration: ProductConfiguration,
        categoryID: LanguageWordCategoryID? = nil
    ) {
        self.configuration = configuration
        self.categoryID = categoryID
    }

    func buildChallenge(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> BuildChallenge? {
        guard let item = eligibleItems(for: request, learnedLanguage: learnedLanguage).randomElement() else {
            return nil
        }
        return buildChallenge(for: request, learnedLanguage: learnedLanguage, item: item)
    }

    func buildChallenges(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> [BuildChallenge] {
        eligibleItems(for: request, learnedLanguage: learnedLanguage).shuffled().compactMap { item in
            buildChallenge(for: request, learnedLanguage: learnedLanguage, item: item)
        }
    }

    private func buildChallenge(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier,
        item: LanguageWordCatalogItem
    ) -> BuildChallenge? {
        guard let level = validatedLevel(for: request, learnedLanguage: learnedLanguage),
              LanguageWordLevelContent.content(for: level).items(
                  constrainedTo: categoryID,
                  including: { $0.isImageReady }
              ).contains(where: { $0.id == item.id }),
              let learnedText = LanguageWordContentProvider.learnedText(
                  for: item,
                  language: learnedLanguage
              ),
              let prompt = Prompt(
                representations: [.imageAsset(item.image)],
                speechCue: learnedText.learningSpeechCue
              ) else {
            return nil
        }

        let instanceID = UUID().uuidString
        let tokens = learnedText.text.filter { !$0.isWhitespace }.enumerated().map { index, character in
            BuildToken(
                id: BuildTokenID(rawValue: "\(instanceID).token.\(index)"),
                representation: .learningText(LearningTextRepresentation(
                    text: String(character),
                    language: learnedText.language,
                    direction: learnedText.direction
                ))
            )
        }

        guard let languageWordContent = LanguageWordBuildContent(
            contentItemID: item.id,
            targetText: learnedText
        ) else {
            return nil
        }

        return BuildChallenge(
            id: ChallengeID(
                rawValue: "wordBuild.\(item.id.rawValue).\(instanceID).challenge"
            ),
            prompt: prompt,
            availableTokens: tokens,
            expectedTokenSequence: tokens.map(\.id),
            primarySkill: request.primarySkill,
            secondarySkills: [],
            curriculumStage: request.curriculumStage,
            difficulty: request.difficulty,
            validationMode: .immediatePrefix,
            languageWordContent: languageWordContent
        )
    }

    private func eligibleItems(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> [LanguageWordCatalogItem] {
        guard let level = validatedLevel(for: request, learnedLanguage: learnedLanguage) else { return [] }
        return LanguageWordLevelContent.content(for: level).items(
            constrainedTo: categoryID,
            including: { $0.isImageReady }
        )
    }

    private func validatedLevel(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> LanguageVocabularyLevel? {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .build,
              let level = LanguageVocabularyLevel(curriculumStageID: request.curriculumStage),
              request.primarySkill == LanguageSkillIDs.wordConstruction,
              request.interaction == .orderedTokens,
              request.countRequirement == nil else {
            return nil
        }
        return level
    }
}
