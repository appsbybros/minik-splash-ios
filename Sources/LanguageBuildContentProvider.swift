import Foundation

struct LanguageBuildContentProvider: Sendable {
    private let configuration: ProductConfiguration
    private let learnProvider: LanguageLearnContentProvider

    init(configuration: ProductConfiguration) {
        self.configuration = configuration
        self.learnProvider = LanguageLearnContentProvider(configuration: configuration)
    }

    func buildChallenge(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> BuildChallenge? {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .build,
              request.curriculumStage == LanguageCurriculumStageIDs.alphabet,
              request.primarySkill == LanguageSkillIDs.wordConstruction,
              request.interaction == .orderedTokens,
              request.countRequirement == nil else {
            return nil
        }

        let cards = learnProvider.studyCards(for: learnedLanguage)
        guard let card = cards.randomElement(),
              card.representations.count == 3,
              case .learningText = card.representations[0],
              case .learningText(let word) = card.representations[1],
              case .imageAsset = card.representations[2] else {
            return nil
        }

        let instanceID = UUID().uuidString
        let tokens = Array(word.text).enumerated().map { index, character in
            BuildToken(
                id: BuildTokenID(rawValue: "\(instanceID).token.\(index)"),
                representation: .learningText(LearningTextRepresentation(
                    text: String(character),
                    language: word.language,
                    direction: word.direction
                ))
            )
        }
        guard let prompt = Prompt(representations: [card.representations[0]]) else {
            return nil
        }

        return BuildChallenge(
            id: ChallengeID(rawValue: "\(instanceID).challenge"),
            prompt: prompt,
            availableTokens: tokens,
            expectedTokenSequence: tokens.map(\.id),
            primarySkill: request.primarySkill,
            secondarySkills: [],
            curriculumStage: request.curriculumStage,
            difficulty: request.difficulty
        )
    }
}

extension LanguageSkillIDs {
    static let wordConstruction = SkillID(rawValue: "language.wordConstruction")
}
