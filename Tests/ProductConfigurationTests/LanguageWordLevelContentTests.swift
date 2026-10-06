import XCTest
@testable import MinikPlus

final class LanguageWordLevelContentTests: XCTestCase {
    func testMultipleChoiceEligibilityReturnsAllSufficientCategories() {
        let first = makeCategory(
            id: "fruits",
            words: [("apple", "Apple", "תפוח"), ("pear", "Pear", "אגס"), ("kiwi", "Kiwi", "קיווי")]
        )
        let second = makeCategory(
            id: "animals",
            words: [
                ("bear", "Bear", "דוב"),
                ("camel", "Camel", "גמל"),
                ("dog", "Dog", "כלב"),
                ("eagle", "Eagle", "נשר")
            ]
        )
        let third = makeCategory(
            id: "tools",
            words: [
                ("fork", "Fork", "מזלג"),
                ("glove", "Glove", "כפפה"),
                ("hammer", "Hammer", "פטיש"),
                ("igloo", "Igloo", "איגלו")
            ]
        )
        let content = LanguageWordLevelContent(
            categories: [first, second, third],
            supplementalInitialLetterItems: []
        )

        let eligible = content.eligibleCategories(
            constrainedTo: nil,
            where: { $0.items.count >= 4 }
        )

        XCTAssertEqual(eligible.map(\.id), [
            LanguageWordCategoryID(rawValue: "animals"),
            LanguageWordCategoryID(rawValue: "tools")
        ])
    }

    func testExplicitCategoryConstraintIsExactAndCanFail() {
        let fruits = makeCategory(
            id: "fruits",
            words: [("apple", "Apple", "תפוח"), ("banana", "Banana", "בננה")]
        )
        let animals = makeCategory(
            id: "animals",
            words: [
                ("bear", "Bear", "דוב"),
                ("camel", "Camel", "גמל"),
                ("dog", "Dog", "כלב"),
                ("eagle", "Eagle", "נשר")
            ]
        )
        let content = LanguageWordLevelContent(
            categories: [fruits, animals],
            supplementalInitialLetterItems: []
        )

        XCTAssertEqual(
            content.eligibleCategories(
                constrainedTo: LanguageWordCategoryID(rawValue: "animals"),
                where: { $0.items.count >= 4 }
            ).map(\.id),
            [LanguageWordCategoryID(rawValue: "animals")]
        )
        XCTAssertTrue(content.eligibleCategories(
            constrainedTo: .fruits,
            where: { $0.items.count >= 4 }
        ).isEmpty)
        XCTAssertNil(content.fillDistinctItems(
            requiredCount: 6,
            constrainedTo: .fruits,
            preferredCategoryID: .fruits
        ))
    }

    func testMemoryFillCanPreferLaterCategoryAndThenUseAnotherWithoutDuplicateIDs() throws {
        let first = makeCategory(
            id: "fruits",
            words: [
                ("apple", "Apple", "תפוח"),
                ("banana", "Banana", "בננה")
            ]
        )
        let second = makeCategory(
            id: "animals",
            words: [
                ("bear", "Bear", "דוב"),
                ("camel", "Camel", "גמל"),
                ("dog", "Dog", "כלב"),
                ("eagle", "Eagle", "נשר")
            ]
        )
        let third = makeCategory(
            id: "tools",
            words: [
                ("fork", "Fork", "מזלג"),
                ("glove", "Glove", "כפפה")
            ]
        )
        let content = LanguageWordLevelContent(
            categories: [first, second, third],
            supplementalInitialLetterItems: []
        )

        let selectedItems = try XCTUnwrap(content.fillDistinctItems(
            requiredCount: 6,
            constrainedTo: nil,
            preferredCategoryID: LanguageWordCategoryID(rawValue: "animals")
        ))

        XCTAssertEqual(selectedItems.count, 6)
        XCTAssertEqual(Set(selectedItems.map(\.id)).count, 6)
        XCTAssertEqual(selectedItems.prefix(4).map(\.category), Array(repeating: "animals", count: 4))
        XCTAssertEqual(Set(selectedItems.suffix(2).map(\.category)), Set(["fruits"]))
    }

    func testLetterPairsCanFallbackToCombinedGroupsWhenNoCategoryHasLocalPairs() throws {
        let fruits = makeCategory(
            id: "fruits",
            words: [
                ("apple", "Apple", "אלון"),
                ("boat", "Boat", "בלון"),
                ("cat", "Cat", "גמל"),
                ("dog", "Dog", "דוב")
            ]
        )
        let animals = makeCategory(
            id: "animals",
            words: [
                ("ant", "Ant", "אנט"),
                ("ball", "Ball", "בל"),
                ("camel", "Camel", "גמלון"),
                ("drum", "Drum", "דלעת")
            ]
        )
        let content = LanguageWordLevelContent(
            categories: [fruits, animals],
            supplementalInitialLetterItems: []
        )

        let sources = try XCTUnwrap(content.initialGroupSources(
            constrainedTo: nil,
            learnedLanguage: .english,
            initialProvider: LanguageLetterPairsContentProvider.initialLetter(for:language:)
        ))
        let selections = try XCTUnwrap(content.selectInitialGroups(
            requiredCount: 4,
            constrainedTo: nil,
            preferredSourceID: nil,
            learnedLanguage: .english,
            initialProvider: LanguageLetterPairsContentProvider.initialLetter(for:language:)
        ))

        XCTAssertTrue(sources.isEmpty)
        XCTAssertEqual(selections.map(\.initial), ["A", "B", "C", "D"])
        XCTAssertTrue(selections.allSatisfy { Set($0.items.map(\.id)).count == 2 })
        XCTAssertTrue(selections.allSatisfy { Set($0.items.map(\.image)).count == 2 })
        XCTAssertNil(content.selectInitialGroups(
            requiredCount: 4,
            constrainedTo: .fruits,
            preferredSourceID: "category.fruits",
            learnedLanguage: .english,
            initialProvider: LanguageLetterPairsContentProvider.initialLetter(for:language:)
        ))
    }

    private func makeCategory(
        id: String,
        words: [(String, String, String)]
    ) -> LanguageWordCategory {
        let categoryID = LanguageWordCategoryID(rawValue: id)
        return LanguageWordCategory(
            id: categoryID,
            sourceName: id.uppercased(),
            items: words.map { key, english, hebrew in
                let androidWordID = "\(id)_\(key)"
                return LanguageWordCatalogItem(
                    id: ContentItemID(rawValue: "language.words.\(androidWordID)"),
                    stableKey: androidWordID,
                    androidWordID: androidWordID,
                    englishText: english,
                    hebrewText: hebrew,
                    imageManifestEntry: LanguageVocabularyImageManifestEntry(
                        stableKey: androidWordID,
                        assetReference: AssetReference(rawValue: key),
                        source: "test",
                        englishText: english,
                        hebrewText: hebrew,
                        level: .a,
                        categoryID: categoryID,
                        iosAssetStatus: .existingIOS,
                        androidAssetStatus: .existingAndroid,
                        imageAction: .reuseIOS,
                        isReadyInCurrentIOS: true
                    ),
                    baseLevel: .a,
                    categoryID: categoryID,
                    hebrewSpeechText: nil,
                    contentKind: .word
                )
            }
        )
    }
}
