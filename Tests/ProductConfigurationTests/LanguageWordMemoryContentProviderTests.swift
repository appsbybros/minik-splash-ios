import XCTest
@testable import MinikPlus

final class LanguageWordMemoryContentProviderTests: XCTestCase {
    func testDefaultRequestReturnsSixDistinctRealContentSets() throws {
        let sets = try makeSets()
        let semanticValues = sets.map(\.semanticValue)
        let catalogIDs = Set(LanguageWordLevelContent.wordsLevelA.items.map(\.id))

        XCTAssertEqual(sets.count, 6)
        XCTAssertEqual(Set(semanticValues).count, 6)
        for semanticValue in semanticValues {
            guard case .contentItem(let id) = semanticValue else {
                return XCTFail("Expected a real content-item identity.")
            }
            XCTAssertTrue(catalogIDs.contains(id))
        }
    }

    func testEachSetContainsTwoIdenticalImagesForTheSameContentItem() throws {
        try assertSetRepresentations(
            provider.equivalenceSets(for: try makeRequest(), learnedLanguage: .english)
        )
        try assertSetRepresentations(
            provider.equivalenceSets(for: try makeRequest(), learnedLanguage: .hebrew)
        )
    }

    func testDefaultSetsProduceTwelveMemoryCardInstances() throws {
        let sets = try makeSets()
        let session = try XCTUnwrap(MemorySession(equivalenceSets: sets))

        XCTAssertEqual(session.equivalenceSets.count, 6)
        XCTAssertEqual(session.cards.count, 12)
        XCTAssertEqual(Set(session.cards.map(\.id)).count, 12)
    }

    func testFactoryWiresCatalogBackedRevealSpeechForEnglishAndHebrew() throws {
        let factory = LanguageActivitySessionFactory(
            configuration: .configuration(for: .minikPlus)
        )
        let catalogByID = Dictionary(
            LanguageWordLevelContent.wordsLevelA.items.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for language in [LanguageIdentifier.english, .hebrew] {
            let session = try XCTUnwrap(factory.makeWordMemorySession(for: language))

            for (groupIndex, set) in session.equivalenceSets.enumerated() {
                guard case .contentItem(let id) = set.semanticValue else {
                    return XCTFail("Expected a real content-item identity.")
                }
                let item = try XCTUnwrap(catalogByID[id])
                let card = try XCTUnwrap(session.cards.first {
                    $0.id.groupIndex == groupIndex
                })
                var singleRevealSession = session
                let expectedText: String
                if language == .english {
                    expectedText = item.englishText
                } else {
                    expectedText = item.hebrewSpeechText ?? item.hebrewText
                }

                XCTAssertEqual(
                    singleRevealSession.selectCard(card.id),
                    LearningSpeechUtterance(
                        text: expectedText,
                        language: language
                    )
                )
            }
        }
    }

    func testHebrewKiwiRevealSpeechPreservesPronunciationOverride() throws {
        let kiwi = try XCTUnwrap(LanguageWordContentProvider.levelAFruits.first {
            $0.englishText == "Kiwi"
        })

        XCTAssertEqual(kiwi.hebrewText, "קיווי")
        XCTAssertEqual(kiwi.hebrewSpeechText, "Kiwi")
        XCTAssertEqual(
            LanguageWordMemoryContentProvider.revealSpeechCue(
                for: kiwi,
                learnedLanguage: .hebrew
            ),
            LearningSpeechUtterance(text: "Kiwi", language: .hebrew)
        )
        XCTAssertEqual(
            LanguageWordMemoryContentProvider.revealSpeechCue(
                for: kiwi,
                learnedLanguage: .english
            ),
            LearningSpeechUtterance(text: "Kiwi", language: .english)
        )
    }

    func testExplicitItemCountsTwoThroughSixAreHonored() throws {
        for count in 2 ... 6 {
            let requirement = try XCTUnwrap(ContentCountRequirement(
                kind: .items,
                count: count
            ))
            let request = try makeRequest(countRequirement: requirement)
            let sets = provider.equivalenceSets(
                for: request,
                learnedLanguage: .english
            )

            XCTAssertEqual(sets.count, count)
        }
    }

    func testInvalidRequestShapesReturnNoSets() throws {
        let wrongActivity = try makeRequest(activityType: .pairs)
        let wrongStage = try makeRequest(curriculumStage: LanguageCurriculumStageIDs.alphabet)
        let wrongSkill = try makeRequest(primarySkill: LanguageSkillIDs.wordRecognition)
        let wrongInteraction = try makeRequest(interaction: .singleChoice)
        let wrongKind = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .choices, count: 4)
        ))
        let tooMany = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .items, count: 7)
        ))
        let tooFew = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .items, count: 1)
        ))

        XCTAssertEqual(provider.equivalenceSets(for: wrongActivity, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongStage, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongSkill, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongInteraction, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongKind, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: tooMany, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: tooFew, learnedLanguage: .english), [])
    }

    func testProductConfigurationEnforcesEveryLanguagePolicy() throws {
        let request = try makeRequest()
        let plus = LanguageWordMemoryContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnly = LanguageWordMemoryContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageWordMemoryContentProvider(
            configuration: .configuration(for: .minikMath)
        )

        XCTAssertEqual(plus.equivalenceSets(for: request, learnedLanguage: .english).count, 6)
        XCTAssertEqual(plus.equivalenceSets(for: request, learnedLanguage: .hebrew).count, 6)
        XCTAssertEqual(englishOnly.equivalenceSets(
            for: request,
            learnedLanguage: .english
        ).count, 6)
        XCTAssertEqual(englishOnly.equivalenceSets(
            for: request,
            learnedLanguage: .hebrew
        ), [])
        XCTAssertEqual(math.equivalenceSets(for: request, learnedLanguage: .english), [])
    }

    func testUnsupportedLearnedLanguageReturnsNoSets() throws {
        let request = try makeRequest()
        let unsupported = LanguageIdentifier(rawValue: "fr")

        XCTAssertEqual(provider.equivalenceSets(
            for: request,
            learnedLanguage: unsupported
        ), [])
    }

    func testUnsupportedCategoryReturnsNoSetsWithoutFallingBackToFruits() throws {
        let provider = LanguageWordMemoryContentProvider(
            configuration: .configuration(for: .minikPlus),
            categoryID: LanguageWordCategoryID(rawValue: "unsupported.test.category")
        )

        XCTAssertEqual(provider.equivalenceSets(
            for: try makeRequest(),
            learnedLanguage: .english
        ), [])
    }

    func testExplicitCategoryReturnsOnlyItemsFromThatCategory() throws {
        let provider = LanguageWordMemoryContentProvider(
            configuration: .configuration(for: .minikPlus),
            categoryID: .fruits
        )
        let sets = provider.equivalenceSets(
            for: try makeRequest(),
            learnedLanguage: .english
        )
        let fruitIDs = Set(LanguageWordContentProvider.levelAFruits.map(\.id))

        XCTAssertEqual(sets.count, 6)
        XCTAssertTrue(sets.allSatisfy { set in
            guard case .contentItem(let id) = set.semanticValue else {
                return false
            }
            return fruitIDs.contains(id)
        })
    }

    private var provider: LanguageWordMemoryContentProvider {
        LanguageWordMemoryContentProvider(configuration: .configuration(for: .minikPlus))
    }

    private func makeSets() throws -> [EquivalenceSet] {
        let request = try makeRequest()
        return provider.equivalenceSets(for: request, learnedLanguage: .english)
    }

    private func makeRequest(
        activityType: ActivityType = .memory,
        curriculumStage: CurriculumStageID = LanguageCurriculumStageIDs.wordsLevelA,
        primarySkill: SkillID = LanguageSkillIDs.wordImageAssociation,
        interaction: Interaction = .matching,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: curriculumStage,
            primarySkill: primarySkill,
            difficulty: try XCTUnwrap(Difficulty(0.5)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private func assertSetRepresentations(
        _ sets: [EquivalenceSet],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let catalogByID = Dictionary(
            LanguageWordLevelContent.wordsLevelA.items.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for set in sets {
            XCTAssertEqual(set.representations.count, 2, file: file, line: line)
            guard case .contentItem(let id) = set.semanticValue,
                  case .imageAsset(let firstImage) = set.representations[0],
                  case .imageAsset(let secondImage) = set.representations[1] else {
                return XCTFail(
                    "Expected two image representations.",
                    file: file,
                    line: line
                )
            }

            let item = try XCTUnwrap(catalogByID[id], file: file, line: line)
            XCTAssertEqual(firstImage, item.image, file: file, line: line)
            XCTAssertEqual(secondImage, item.image, file: file, line: line)
            XCTAssertEqual(firstImage, secondImage, file: file, line: line)
        }
    }
}
