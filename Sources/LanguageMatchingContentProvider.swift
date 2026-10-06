struct LanguageMatchingContentProvider: Sendable {
    private let configuration: ProductConfiguration
    private let learnProvider: LanguageLearnContentProvider

    init(configuration: ProductConfiguration) {
        self.configuration = configuration
        self.learnProvider = LanguageLearnContentProvider(configuration: configuration)
    }

    func equivalenceSets(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> [EquivalenceSet] {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .pairs || request.activityType == .memory,
              request.curriculumStage == LanguageCurriculumStageIDs.alphabet,
              request.primarySkill == LanguageSkillIDs.letterWordAssociation,
              request.interaction == .matching,
              let setCount = resolvedSetCount(for: request.countRequirement) else {
            return []
        }

        let candidates = learnProvider.studyCards(for: learnedLanguage).compactMap { card in
            Self.equivalenceSet(from: card)
        }
        guard candidates.count >= setCount else {
            return []
        }

        return Array(candidates.shuffled().prefix(setCount))
    }

    private func resolvedSetCount(
        for requirement: ContentCountRequirement?
    ) -> Int? {
        guard let requirement else {
            return 4
        }
        guard requirement.kind == .items,
              (2 ... 6).contains(requirement.count) else {
            return nil
        }
        return requirement.count
    }

    private static func equivalenceSet(from card: StudyCard) -> EquivalenceSet? {
        guard card.representations.count == 3,
              case .learningText = card.representations[0],
              case .learningText = card.representations[1],
              case .imageAsset = card.representations[2] else {
            return nil
        }

        return EquivalenceSet(
            semanticValue: .contentItem(ContentItemID(rawValue: card.id.rawValue)),
            representations: Array(card.representations.prefix(2))
        )
    }
}

extension LanguageSkillIDs {
    static let letterWordAssociation = SkillID(rawValue: "language.letterWordAssociation")
}
