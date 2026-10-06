import Foundation

extension LanguageSkillIDs {
    static let initialLetterAssociation = SkillID(
        rawValue: "language.initialLetterAssociation"
    )
}

struct LanguageLetterPairsContentProvider: Sendable {
    private struct RoundGroup: Sendable {
        let initial: String
        let items: [LanguageWordCatalogItem]
    }

    private static let roundBuildAttempts = 40

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
        makeSession(for: request, learnedLanguage: learnedLanguage)?.equivalenceSets ?? []
    }

    func makeSession(
        for request: ChallengeRequest,
        learnedLanguage: LanguageIdentifier
    ) -> PairsSession? {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              request.activityType == .pairs,
              let level = LanguageVocabularyLevel(curriculumStageID: request.curriculumStage),
              request.primarySkill == LanguageSkillIDs.initialLetterAssociation,
              request.interaction == .matching,
              let groupCount = resolvedGroupCount(for: request.countRequirement),
              let groupSelections = selectedGroups(
                  from: LanguageWordLevelContent.content(for: level),
                  requiredCount: groupCount,
                  learnedLanguage: learnedLanguage
              ) else {
            return nil
        }

        guard let roundGroups = makeRoundGroups(from: groupSelections) else {
            return nil
        }

        var sets: [EquivalenceSet] = []
        var details: [[PairsItemDetails]] = []
        for group in roundGroups {
            guard let set = EquivalenceSet(
                semanticValue: .contentItem(Self.initialConceptID(
                    language: learnedLanguage,
                    initial: group.initial
                )),
                representations: group.items.map { .imageAsset($0.image) }
            ) else {
                return nil
            }

            let groupDetails = group.items.compactMap { item -> PairsItemDetails? in
                guard let learnedText = LanguageWordContentProvider.learnedText(
                    for: item,
                    language: learnedLanguage
                ) else {
                    return nil
                }
                return PairsItemDetails(
                    accessibilityLabel: learnedText.text,
                    speechUtterance: LearningSpeechUtterance(
                        text: learnedText.speechText ?? learnedText.text,
                        language: learnedLanguage
                    )
                )
            }
            guard groupDetails.count == 2 else {
                return nil
            }
            sets.append(set)
            details.append(groupDetails)
        }

        guard sets.count == groupSelections.count else {
            return nil
        }
        return PairsSession(
            equivalenceSets: sets,
            selectionStyle: .anyTwoTiles,
            itemDetails: details
        )
    }

    private func resolvedGroupCount(
        for requirement: ContentCountRequirement?
    ) -> Int? {
        guard let requirement else {
            return 4
        }
        guard requirement.kind == .items,
              (2 ... 4).contains(requirement.count) else {
            return nil
        }
        return requirement.count
    }

    func eligibleGroups(
        for learnedLanguage: LanguageIdentifier
    ) -> [String: [LanguageWordCatalogItem]]? {
        LanguageWordLevelContent.initialGroups(
            from: sourceItems,
            learnedLanguage: learnedLanguage,
            initialProvider: Self.initialLetter(for:language:)
        )
    }

    static func initialLetter(
        for item: LanguageWordCatalogItem,
        language: LanguageIdentifier
    ) -> String? {
        guard let learnedText = LanguageWordContentProvider.learnedText(
            for: item,
            language: language
        ) else {
            return nil
        }

        let normalized = learnedText.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .decomposedStringWithCanonicalMapping
        guard let firstCharacter = normalized.first(where: { $0.isLetter }),
              let baseLetter = String(firstCharacter).unicodeScalars.first(where: {
                CharacterSet.letters.contains($0)
              }) else {
            return nil
        }

        let initial = String(baseLetter)
        switch language {
        case .english:
            return initial.uppercased(with: Locale(identifier: "en_US_POSIX"))
        case .hebrew:
            return initial
        default:
            return nil
        }
    }

    static func initialConceptID(
        language: LanguageIdentifier,
        initial: String
    ) -> ContentItemID {
        let component = language == .english
            ? initial.lowercased(with: Locale(identifier: "en_US_POSIX"))
            : initial
        return ContentItemID(
            rawValue: "language.initialLetter.\(language.rawValue).\(component)"
        )
    }

    private var sourceItems: [LanguageWordCatalogItem] {
        LanguageWordLevelContent.wordsLevelA.letterPairItems(
            constrainedTo: categoryID
        )
    }

    private func selectedGroups(
        from levelContent: LanguageWordLevelContent,
        requiredCount: Int,
        learnedLanguage: LanguageIdentifier
    ) -> [LanguageWordLevelContent.InitialGroupSelection]? {
        guard let sources = levelContent.initialGroupSources(
            constrainedTo: categoryID,
            learnedLanguage: learnedLanguage,
            initialProvider: Self.initialLetter(for:language:)
        ) else {
            return nil
        }

        let preferredSourceID: String?
        if let categoryID {
            preferredSourceID = "category.\(categoryID.rawValue)"
        } else if let source = sources.randomElement() {
            preferredSourceID = source.sourceID
        } else {
            preferredSourceID = nil
        }

        return levelContent.selectInitialGroups(
            requiredCount: requiredCount,
            constrainedTo: categoryID,
            preferredSourceID: preferredSourceID,
            learnedLanguage: learnedLanguage,
            initialProvider: Self.initialLetter(for:language:)
        )
    }

    private func makeRoundGroups(
        from selections: [LanguageWordLevelContent.InitialGroupSelection]
    ) -> [RoundGroup]? {
        for _ in 0 ..< Self.roundBuildAttempts {
            var usedImages: Set<AssetReference> = []
            var roundGroups: [RoundGroup] = []

            for selection in selections {
                var selectedItems: [LanguageWordCatalogItem] = []
                for item in selection.items.shuffled() where !usedImages.contains(item.image) {
                    usedImages.insert(item.image)
                    selectedItems.append(item)
                    if selectedItems.count == 2 {
                        break
                    }
                }
                guard selectedItems.count == 2 else {
                    break
                }
                roundGroups.append(RoundGroup(
                    initial: selection.initial,
                    items: selectedItems
                ))
            }

            if roundGroups.count == selections.count {
                return roundGroups
            }
        }
        return nil
    }

    static var catalogItems: [LanguageWordCatalogItem] {
        LanguageWordContentProvider.levelAFruits + additionalLevelAItems
    }

    static var additionalLevelAItems: [LanguageWordCatalogItem] {
        LanguageWordCatalog.initialLetterSupportItems
    }
}
