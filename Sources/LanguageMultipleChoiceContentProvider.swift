import Foundation

struct LanguageMultipleChoiceContentProvider: Sendable {
    private struct AlphabetChoiceSource {
        let contentID: ContentItemID
        let letter: Representation
        let word: Representation
    }

    private let configuration: ProductConfiguration
    private let learnProvider: LanguageLearnContentProvider

    init(configuration: ProductConfiguration) {
        self.configuration = configuration
        self.learnProvider = LanguageLearnContentProvider(configuration: configuration)
    }

    func challenge(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> Challenge? {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .multipleChoice,
              request.curriculumStage == LanguageCurriculumStageIDs.alphabet,
              request.primarySkill == LanguageSkillIDs.alphabetRecognition,
              request.interaction == .singleChoice,
              let choiceCount = resolvedChoiceCount(for: request.countRequirement) else {
            return nil
        }

        let cards = learnProvider.studyCards(for: learnedLanguage)
        let sources = cards.compactMap(Self.choiceSource)
        guard sources.count == cards.count,
              sources.count >= choiceCount,
              let correctSource = sources.randomElement() else {
            return nil
        }

        let distractors = sources
            .filter { $0.contentID != correctSource.contentID }
            .shuffled()
            .prefix(choiceCount - 1)
        let selectedSources = ([correctSource] + distractors).shuffled()
        let instanceID = UUID().uuidString
        let choices = selectedSources.enumerated().map { index, source in
            Choice(
                id: ChoiceID(rawValue: "\(instanceID).choice.\(index)"),
                representation: source.word,
                semanticValue: .contentItem(source.contentID)
            )
        }

        guard let prompt = Prompt(representations: [correctSource.letter]) else {
            return nil
        }

        return Challenge(
            id: ChallengeID(rawValue: "\(instanceID).challenge"),
            prompt: prompt,
            choices: choices,
            interaction: .singleChoice,
            validationRule: .exactIdentity,
            expectedAnswer: .semanticValue(.contentItem(correctSource.contentID)),
            primarySkill: request.primarySkill,
            secondarySkills: [],
            curriculumStage: request.curriculumStage,
            difficulty: request.difficulty
        )
    }

    private func resolvedChoiceCount(
        for requirement: ContentCountRequirement?
    ) -> Int? {
        guard let requirement else {
            return 4
        }
        guard requirement.kind == .choices,
              (2 ... 4).contains(requirement.count) else {
            return nil
        }
        return requirement.count
    }

    private static func choiceSource(from card: StudyCard) -> AlphabetChoiceSource? {
        guard card.representations.count == 3,
              case .learningText = card.representations[0],
              case .learningText = card.representations[1],
              case .imageAsset = card.representations[2] else {
            return nil
        }

        return AlphabetChoiceSource(
            contentID: ContentItemID(rawValue: card.id.rawValue),
            letter: card.representations[0],
            word: card.representations[1]
        )
    }
}
