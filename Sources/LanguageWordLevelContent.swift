import Foundation

struct LanguageWordLevelContent: Sendable {
    struct InitialGroupSource: Sendable, Equatable {
        let sourceID: String
        let groups: [String: [LanguageWordCatalogItem]]
    }

    struct InitialGroupSelection: Sendable, Equatable {
        let initial: String
        let items: [LanguageWordCatalogItem]
    }

    let categories: [LanguageWordCategory]
    let supplementalInitialLetterItems: [LanguageWordCatalogItem]

    static func content(for level: LanguageVocabularyLevel) -> LanguageWordLevelContent {
        LanguageWordLevelContent(
            categories: LanguageWordCatalog.categories(for: level),
            supplementalInitialLetterItems: level == .a
                ? LanguageWordCatalog.initialLetterSupportItems
                : []
        )
    }

    static let wordsLevelA = content(for: .a)

    var items: [LanguageWordCatalogItem] {
        categories.flatMap(\.items)
    }

    func orderedCategories(
        constrainedTo categoryID: LanguageWordCategoryID?
    ) -> [LanguageWordCategory] {
        guard let categoryID else {
            return categories
        }
        guard let category = categories.first(where: { $0.id == categoryID }) else {
            return []
        }
        return [category]
    }

    func categories(
        constrainedTo categoryID: LanguageWordCategoryID?,
        including includeItem: (LanguageWordCatalogItem) -> Bool = { _ in true }
    ) -> [LanguageWordCategory] {
        orderedCategories(constrainedTo: categoryID).compactMap { category in
            let filteredItems = category.items.filter(includeItem)
            guard !filteredItems.isEmpty else {
                return nil
            }
            return LanguageWordCategory(
                id: category.id,
                sourceName: category.sourceName,
                items: filteredItems
            )
        }
    }

    func items(
        constrainedTo categoryID: LanguageWordCategoryID?,
        including includeItem: (LanguageWordCatalogItem) -> Bool = { _ in true }
    ) -> [LanguageWordCatalogItem] {
        categories(constrainedTo: categoryID, including: includeItem).flatMap(\.items)
    }

    func eligibleCategories(
        constrainedTo categoryID: LanguageWordCategoryID?,
        including includeItem: (LanguageWordCatalogItem) -> Bool = { _ in true },
        where isEligible: (LanguageWordCategory) -> Bool
    ) -> [LanguageWordCategory] {
        categories(constrainedTo: categoryID, including: includeItem).filter(isEligible)
    }

    func eligibleItems(
        constrainedTo categoryID: LanguageWordCategoryID?,
        including includeItem: (LanguageWordCatalogItem) -> Bool = { _ in true },
        where isEligible: (LanguageWordCategory) -> Bool
    ) -> [LanguageWordCatalogItem] {
        eligibleCategories(
            constrainedTo: categoryID,
            including: includeItem,
            where: isEligible
        ).flatMap(\.items)
    }

    func fillDistinctItems(
        requiredCount: Int,
        constrainedTo categoryID: LanguageWordCategoryID?,
        preferredCategoryID: LanguageWordCategoryID? = nil,
        including includeItem: (LanguageWordCatalogItem) -> Bool = { _ in true }
    ) -> [LanguageWordCatalogItem]? {
        guard let prioritizedCategories = prioritizedCategories(
            constrainedTo: categoryID,
            preferredCategoryID: preferredCategoryID,
            including: includeItem
        ) else {
            return nil
        }

        var selectedItems: [LanguageWordCatalogItem] = []
        var seenIDs: Set<ContentItemID> = []

        for category in prioritizedCategories {
            for item in Self.distinctItems(from: category.items) where seenIDs.insert(item.id).inserted {
                selectedItems.append(item)
                if selectedItems.count == requiredCount {
                    return selectedItems
                }
            }
        }

        return nil
    }

    func letterPairItems(
        constrainedTo categoryID: LanguageWordCategoryID?
    ) -> [LanguageWordCatalogItem] {
        let baseItems = items(
            constrainedTo: categoryID,
            including: { $0.isImageReady }
        )
        guard categoryID == nil else {
            return baseItems
        }
        return Self.distinctItems(from: baseItems + supplementalInitialLetterItems.filter(\.isImageReady))
    }

    func initialGroupSources(
        constrainedTo categoryID: LanguageWordCategoryID?,
        learnedLanguage: LanguageIdentifier,
        initialProvider: (LanguageWordCatalogItem, LanguageIdentifier) -> String?
    ) -> [InitialGroupSource]? {
        let categorySources = tryInitialGroupSources(
            from: categories(
                constrainedTo: categoryID,
                including: { $0.isImageReady }
            ).map { category in
                (sourceID: Self.sourceID(for: category.id), items: category.items)
            },
            learnedLanguage: learnedLanguage,
            initialProvider: initialProvider
        )
        guard let categorySources else {
            return nil
        }

        guard categoryID == nil else {
            return categorySources
        }

        let supplementalSources = tryInitialGroupSources(
            from: [(
                sourceID: Self.supplementalSourceID,
                items: supplementalInitialLetterItems.filter(\.isImageReady)
            )],
            learnedLanguage: learnedLanguage,
            initialProvider: initialProvider
        )
        guard let supplementalSources else {
            return nil
        }

        return categorySources + supplementalSources
    }

    func selectInitialGroups(
        requiredCount: Int,
        constrainedTo categoryID: LanguageWordCategoryID?,
        preferredSourceID: String?,
        learnedLanguage: LanguageIdentifier,
        initialProvider: (LanguageWordCatalogItem, LanguageIdentifier) -> String?
    ) -> [InitialGroupSelection]? {
        guard let sources = initialGroupSources(
            constrainedTo: categoryID,
            learnedLanguage: learnedLanguage,
            initialProvider: initialProvider
        ) else {
            return nil
        }

        let prioritizedSources: [InitialGroupSource]
        if let preferredSourceID {
            guard let orderedSources = Self.prioritizedSources(
                sources,
                preferredSourceID: preferredSourceID
            ) else {
                return nil
            }
            prioritizedSources = orderedSources
        } else {
            guard categoryID == nil else {
                return nil
            }
            prioritizedSources = []
        }

        var selections: [InitialGroupSelection] = []
        var seenInitials: Set<String> = []

        appendInitialGroups(
            from: prioritizedSources,
            into: &selections,
            seenInitials: &seenInitials
        )

        if selections.count < requiredCount,
           categoryID == nil,
           let combinedGroups = Self.initialGroups(
               from: letterPairItems(constrainedTo: nil),
               learnedLanguage: learnedLanguage,
               initialProvider: initialProvider
           ) {
            appendInitialGroups(
                from: [InitialGroupSource(sourceID: "combined", groups: combinedGroups)],
                into: &selections,
                seenInitials: &seenInitials
            )
        }

        guard selections.count >= requiredCount else {
            return nil
        }
        return Array(selections.prefix(requiredCount))
    }

    static func initialGroups(
        from items: [LanguageWordCatalogItem],
        learnedLanguage: LanguageIdentifier,
        initialProvider: (LanguageWordCatalogItem, LanguageIdentifier) -> String?
    ) -> [String: [LanguageWordCatalogItem]]? {
        guard learnedLanguage == .english || learnedLanguage == .hebrew else {
            return nil
        }

        var groups: [String: [LanguageWordCatalogItem]] = [:]
        for item in items {
            guard let initial = initialProvider(item, learnedLanguage) else {
                return nil
            }
            groups[initial, default: []].append(item)
        }

        return groups.compactMapValues { items in
            var seenIDs: Set<ContentItemID> = []
            var seenImages: Set<AssetReference> = []
            let distinctItems = items.filter { item in
                guard seenIDs.insert(item.id).inserted,
                      let imageAssetReference = item.imageAssetReference else {
                    return false
                }
                return seenImages.insert(imageAssetReference).inserted
            }
            return distinctItems.count >= 2 ? distinctItems : nil
        }
    }

    private func prioritizedCategories(
        constrainedTo categoryID: LanguageWordCategoryID?,
        preferredCategoryID: LanguageWordCategoryID?,
        including includeItem: (LanguageWordCatalogItem) -> Bool
    ) -> [LanguageWordCategory]? {
        let categories = categories(constrainedTo: categoryID, including: includeItem)
        guard !categories.isEmpty else {
            return nil
        }
        guard let preferredCategoryID else {
            return categories
        }
        guard let preferredCategory = categories.first(where: { $0.id == preferredCategoryID }) else {
            return nil
        }
        return [preferredCategory] + categories.filter { $0.id != preferredCategoryID }
    }

    private func tryInitialGroupSources(
        from sources: [(sourceID: String, items: [LanguageWordCatalogItem])],
        learnedLanguage: LanguageIdentifier,
        initialProvider: (LanguageWordCatalogItem, LanguageIdentifier) -> String?
    ) -> [InitialGroupSource]? {
        var results: [InitialGroupSource] = []

        for source in sources {
            guard let groups = Self.initialGroups(
                from: Self.distinctItems(from: source.items),
                learnedLanguage: learnedLanguage,
                initialProvider: initialProvider
            ) else {
                return nil
            }
            guard !groups.isEmpty else {
                continue
            }
            results.append(InitialGroupSource(sourceID: source.sourceID, groups: groups))
        }

        return results
    }

    private static func prioritizedSources(
        _ sources: [InitialGroupSource],
        preferredSourceID: String
    ) -> [InitialGroupSource]? {
        guard let preferredSource = sources.first(where: { $0.sourceID == preferredSourceID }) else {
            return nil
        }
        return [preferredSource] + sources.filter { $0.sourceID != preferredSourceID }
    }

    private func appendInitialGroups(
        from sources: [InitialGroupSource],
        into selections: inout [InitialGroupSelection],
        seenInitials: inout Set<String>
    ) {
        for source in sources {
            for initial in source.groups.keys.sorted() where seenInitials.insert(initial).inserted {
                guard let items = source.groups[initial] else {
                    continue
                }
                selections.append(InitialGroupSelection(initial: initial, items: items))
            }
        }
    }

    private static func sourceID(for categoryID: LanguageWordCategoryID) -> String {
        "category.\(categoryID.rawValue)"
    }

    private static let supplementalSourceID = "supplemental"

    private static func distinctItems(
        from items: [LanguageWordCatalogItem]
    ) -> [LanguageWordCatalogItem] {
        var seenIDs: Set<ContentItemID> = []
        return items.filter { seenIDs.insert($0.id).inserted }
    }
}
