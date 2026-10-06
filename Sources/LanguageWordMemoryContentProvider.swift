import Foundation

struct LanguageWordMemoryContent: Sendable {
    let equivalenceSets: [EquivalenceSet]
    let revealSpeechCues: [SemanticValue: LearningSpeechUtterance]
}

struct LanguageWordMemoryContentProvider: Sendable {
    private let configuration: ProductConfiguration
    private let categoryID: LanguageWordCategoryID?

    init(
        configuration: ProductConfiguration,
        categoryID: LanguageWordCategoryID? = nil
    ) {
        self.configuration = configuration
        self.categoryID = categoryID
    }

    func equivalenceSets(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> [EquivalenceSet] {
        content(for: request, learnedLanguage: learnedLanguage)?.equivalenceSets ?? []
    }

    func content(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> LanguageWordMemoryContent? {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .memory,
              let level = LanguageVocabularyLevel(curriculumStageID: request.curriculumStage),
              request.primarySkill == LanguageSkillIDs.wordImageAssociation,
              request.interaction == .matching,
              let setCount = resolvedSetCount(for: request.countRequirement),
              let selectedItems = selectedItems(
                  from: LanguageWordLevelContent.content(for: level),
                  requiredCount: setCount
              ) else {
            return nil
        }
        let sets = selectedItems.compactMap { item in
            EquivalenceSet(
                semanticValue: .contentItem(item.id),
                representations: [
                    .imageAsset(item.image),
                    .imageAsset(item.image)
                ]
            )
        }
        let speechCues = selectedItems.compactMap { item -> (SemanticValue, LearningSpeechUtterance)? in
            guard let cue = Self.revealSpeechCue(
                for: item,
                learnedLanguage: learnedLanguage
            ) else {
                return nil
            }
            return (.contentItem(item.id), cue)
        }

        guard sets.count == setCount,
              speechCues.count == setCount else {
            return nil
        }
        return LanguageWordMemoryContent(
            equivalenceSets: sets,
            revealSpeechCues: Dictionary(uniqueKeysWithValues: speechCues)
        )
    }

    static func revealSpeechCue(
        for item: LanguageWordCatalogItem,
        learnedLanguage: LanguageIdentifier
    ) -> LearningSpeechUtterance? {
        guard let learnedText = LanguageWordContentProvider.learnedText(
            for: item,
            language: learnedLanguage
        ), let language = learnedText.language else {
            return nil
        }
        return LearningSpeechUtterance(
            text: learnedText.speechText ?? learnedText.text,
            language: language
        )
    }

    private func resolvedSetCount(
        for requirement: ContentCountRequirement?
    ) -> Int? {
        guard let requirement else {
            return 6
        }
        guard requirement.kind == .items,
              (2 ... 6).contains(requirement.count) else {
            return nil
        }
        return requirement.count
    }

    private func selectedItems(
        from levelContent: LanguageWordLevelContent,
        requiredCount: Int
    ) -> [LanguageWordCatalogItem]? {
        if let categoryID {
            let categoryItems = levelContent
                .items(constrainedTo: categoryID, including: { $0.isImageReady })
                .shuffled()
            guard categoryItems.count >= requiredCount else {
                return nil
            }
            return Array(categoryItems.prefix(requiredCount))
        }

        let eligibleCategories = levelContent.eligibleCategories(
            constrainedTo: nil,
            including: { $0.isImageReady },
            where: { !$0.items.isEmpty }
        )
        guard let preferredCategory = eligibleCategories.randomElement() else {
            return nil
        }

        let prioritizedCategoryIDs = [preferredCategory.id] +
            eligibleCategories
                .filter { $0.id != preferredCategory.id }
                .shuffled()
                .map(\.id)

        var selectedItems: [LanguageWordCatalogItem] = []
        var seenIDs: Set<ContentItemID> = []

        for categoryID in prioritizedCategoryIDs {
            let categoryItems = levelContent
                .items(constrainedTo: categoryID, including: { $0.isImageReady })
                .shuffled()
                .filter { seenIDs.insert($0.id).inserted }
            selectedItems.append(contentsOf: categoryItems)
            if selectedItems.count >= requiredCount {
                return Array(selectedItems.prefix(requiredCount))
            }
        }

        return nil
    }
}
