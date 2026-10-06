import XCTest
@testable import MinikPlus

final class LanguageLetterPairsContentProviderTests: XCTestCase {
    func testDefaultReturnsFourGroupsAndEightPairsItems() throws {
        let sets = try makeSets(language: .english)
        let session = try XCTUnwrap(PairsSession(equivalenceSets: sets))

        XCTAssertEqual(sets.count, 4)
        XCTAssertEqual(session.leftItems.count + session.rightItems.count, 8)
        XCTAssertEqual(Set(sets.map(\.semanticValue)).count, 4)
    }

    func testEnglishGroupsContainDistinctImagesWithSharedInitials() throws {
        let sets = try makeSets(language: .english)
        let groupInitials = try initials(in: sets)

        try assertGroups(sets, language: .english)
        XCTAssertEqual(groupInitials, ["G", "K", "L", "P"])
    }

    func testHebrewGroupsContainDistinctImagesWithSharedInitials() throws {
        let sets = try makeSets(language: .hebrew)
        let groupInitials = try initials(in: sets)

        try assertGroups(sets, language: .hebrew)
        XCTAssertEqual(Set(groupInitials), Set(["ל", "מ", "ש", "ת"]))
    }

    func testSemanticIDsRepresentInitialConceptsRatherThanWordItems() throws {
        let sets = try makeSets(language: .english)
        let wordIDs = Set(LanguageLetterPairsContentProvider.catalogItems.map(\.id))

        for set in sets {
            guard case .contentItem(let conceptID) = set.semanticValue else {
                return XCTFail("Expected an initial-letter content identity.")
            }
            XCTAssertTrue(conceptID.rawValue.hasPrefix("language.initialLetter.en."))
            XCTAssertFalse(wordIDs.contains(conceptID))
        }
    }

    func testProductionSessionUsesEightUniqueMixedImageTiles() throws {
        let session = try XCTUnwrap(provider.makeSession(
            for: makeRequest(),
            learnedLanguage: .english
        ))
        let items = session.leftItems + session.rightItems
        let imageReferences = try items.map { item -> AssetReference in
            guard case .imageAsset(let image) = item.representation else {
                throw InitialTestError.invalidRepresentation
            }
            return image
        }

        XCTAssertEqual(session.selectionStyle, .anyTwoTiles)
        XCTAssertEqual(session.activeMixedItems.count, 8)
        XCTAssertEqual(Set(items.map(\.id)).count, 8)
        XCTAssertEqual(Set(imageReferences).count, 8)
        XCTAssertEqual(Set(session.mixedPresentationOrder), Set(items.map(\.id)))
    }

    func testEnglishPhysicalTilesCarryLearnedWordSpeechAndAccessibility() throws {
        let session = try XCTUnwrap(provider.makeSession(
            for: makeRequest(),
            learnedLanguage: .english
        ))

        for item in session.leftItems + session.rightItems {
            let label = try XCTUnwrap(item.details.accessibilityLabel)
            let utterance = try XCTUnwrap(item.details.speechUtterance)
            XCTAssertFalse(label.isEmpty)
            XCTAssertFalse(utterance.text.isEmpty)
            XCTAssertEqual(utterance.language, .english)
        }
    }

    func testHebrewPhysicalTilesCarryHebrewLearnedWordSpeech() throws {
        let session = try XCTUnwrap(provider.makeSession(
            for: makeRequest(),
            learnedLanguage: .hebrew
        ))

        for item in session.leftItems + session.rightItems {
            let label = try XCTUnwrap(item.details.accessibilityLabel)
            let utterance = try XCTUnwrap(item.details.speechUtterance)
            XCTAssertFalse(label.isEmpty)
            XCTAssertFalse(utterance.text.isEmpty)
            XCTAssertEqual(utterance.language, .hebrew)
        }
        XCTAssertTrue(session.equivalenceSets.allSatisfy { set in
            guard case .contentItem(let id) = set.semanticValue else { return false }
            return id.rawValue.hasPrefix("language.initialLetter.he.")
        })
    }

    func testExplicitGroupCountsTwoThroughFourAreHonored() throws {
        for count in 2 ... 4 {
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
        let wrongActivity = try makeRequest(activityType: .memory)
        let wrongStage = try makeRequest(curriculumStage: LanguageCurriculumStageIDs.alphabet)
        let wrongSkill = try makeRequest(primarySkill: LanguageSkillIDs.wordImageAssociation)
        let wrongInteraction = try makeRequest(interaction: .singleChoice)
        let wrongKind = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .choices, count: 4)
        ))
        let tooFew = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .items, count: 1)
        ))
        let tooMany = try makeRequest(countRequirement: try XCTUnwrap(
            ContentCountRequirement(kind: .items, count: 5)
        ))

        XCTAssertEqual(provider.equivalenceSets(for: wrongActivity, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongStage, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongSkill, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongInteraction, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: wrongKind, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: tooFew, learnedLanguage: .english), [])
        XCTAssertEqual(provider.equivalenceSets(for: tooMany, learnedLanguage: .english), [])
    }

    func testProductConfigurationEnforcesLanguagePolicy() throws {
        let request = try makeRequest()
        let plus = LanguageLetterPairsContentProvider(
            configuration: .configuration(for: .minikPlus)
        )
        let englishOnly = LanguageLetterPairsContentProvider(
            configuration: .configuration(for: .minikPlusEnglish)
        )
        let math = LanguageLetterPairsContentProvider(
            configuration: .configuration(for: .minikMath)
        )

        XCTAssertEqual(plus.equivalenceSets(for: request, learnedLanguage: .english).count, 4)
        XCTAssertEqual(plus.equivalenceSets(for: request, learnedLanguage: .hebrew).count, 4)
        XCTAssertEqual(englishOnly.equivalenceSets(
            for: request,
            learnedLanguage: .english
        ).count, 4)
        XCTAssertEqual(englishOnly.equivalenceSets(
            for: request,
            learnedLanguage: .hebrew
        ), [])
        XCTAssertEqual(math.equivalenceSets(for: request, learnedLanguage: .english), [])
        XCTAssertEqual(plus.equivalenceSets(
            for: request,
            learnedLanguage: LanguageIdentifier(rawValue: "fr")
        ), [])
    }

    func testExistingFruitsRemainUnchangedAndOnlyTwoItemsExtendThePool() {
        XCTAssertEqual(
            Array(LanguageLetterPairsContentProvider.catalogItems.prefix(10)),
            LanguageWordContentProvider.levelAFruits
        )
        XCTAssertEqual(LanguageLetterPairsContentProvider.additionalLevelAItems.map(\.stableKey), [
            "vegetables_garlic", "other_king"
        ])
        XCTAssertEqual(LanguageLetterPairsContentProvider.additionalLevelAItems.map(\.image.rawValue), [
            "garlic", "king"
        ])
    }

    private var provider: LanguageLetterPairsContentProvider {
        LanguageLetterPairsContentProvider(configuration: .configuration(for: .minikPlus))
    }

    private func makeSets(
        language: LanguageIdentifier
    ) throws -> [EquivalenceSet] {
        let request = try makeRequest()
        return provider.equivalenceSets(for: request, learnedLanguage: language)
    }

    private func makeRequest(
        activityType: ActivityType = .pairs,
        curriculumStage: CurriculumStageID = LanguageCurriculumStageIDs.wordsLevelA,
        primarySkill: SkillID = LanguageSkillIDs.initialLetterAssociation,
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

    private func assertGroups(
        _ sets: [EquivalenceSet],
        language: LanguageIdentifier,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let itemsByImage = Dictionary(uniqueKeysWithValues:
            LanguageLetterPairsContentProvider.catalogItems.map { ($0.image, $0) }
        )

        for set in sets {
            XCTAssertEqual(set.representations.count, 2, file: file, line: line)
            guard case .imageAsset(let firstImage) = set.representations[0],
                  case .imageAsset(let secondImage) = set.representations[1] else {
                return XCTFail("Expected two image representations.", file: file, line: line)
            }
            let firstItem = try XCTUnwrap(itemsByImage[firstImage], file: file, line: line)
            let secondItem = try XCTUnwrap(itemsByImage[secondImage], file: file, line: line)
            let firstInitial = try XCTUnwrap(
                LanguageLetterPairsContentProvider.initialLetter(
                    for: firstItem,
                    language: language
                ),
                file: file,
                line: line
            )
            let secondInitial = try XCTUnwrap(
                LanguageLetterPairsContentProvider.initialLetter(
                    for: secondItem,
                    language: language
                ),
                file: file,
                line: line
            )

            XCTAssertNotEqual(firstImage, secondImage, file: file, line: line)
            XCTAssertNotEqual(firstItem.id, secondItem.id, file: file, line: line)
            XCTAssertEqual(firstInitial, secondInitial, file: file, line: line)
            XCTAssertEqual(
                set.semanticValue,
                .contentItem(LanguageLetterPairsContentProvider.initialConceptID(
                    language: language,
                    initial: firstInitial
                )),
                file: file,
                line: line
            )
        }
    }

    private func initials(in sets: [EquivalenceSet]) throws -> [String] {
        try sets.map { set in
            guard case .contentItem(let id) = set.semanticValue,
                  let initial = id.rawValue.split(separator: ".").last else {
                throw InitialTestError.invalidSemanticID
            }
            return String(initial).uppercased()
        }.sorted()
    }

    private enum InitialTestError: Error {
        case invalidSemanticID
        case invalidRepresentation
    }
}
