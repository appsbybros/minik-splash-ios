import UIKit
import XCTest
@testable import MinikPlus

final class LanguageLearnPresentationTests: XCTestCase {
    func testBananaSeparatesOutlinedLettersFromExampleWordAndPicture() throws {
        let cards = LanguageLearnContentProvider(configuration: .configuration(for: .minikPlus))
            .studyCards(for: .english)
        let display = try XCTUnwrap(LanguageLearnContentProvider.presentation(for: cards[1]))
        XCTAssertEqual(display.letter.text, "B b")
        XCTAssertEqual(display.word.text, "Banana")
        XCTAssertEqual(display.example.rawValue, "learn_b")
        XCTAssertEqual(display.smallLetterAsset, "language_letter_b")
        XCTAssertEqual(display.capitalLetterAsset, "language_letter_b_capital")
        XCTAssertEqual(cards[1].representations.count, 3)
    }

    @MainActor
    func testEveryAlphabetCardHasBothBundledOriginalLetterForms() async throws {
        let provider = LanguageLearnContentProvider(configuration: .configuration(for: .minikPlus))
        let cards = provider.studyCards(for: .english) + provider.studyCards(for: .hebrew)
        XCTAssertEqual(cards.count, 53)
        var names = Set<String>()
        for card in cards {
            let display = try XCTUnwrap(LanguageLearnContentProvider.presentation(for: card))
            for name in [display.smallLetterAsset, display.capitalLetterAsset] {
                XCTAssertTrue(names.insert(name).inserted, name)
                XCTAssertNotNil(UIImage(named: name), name)
            }
            XCTAssertEqual(display.letter.language, display.word.language)
            XCTAssertEqual(display.letter.direction, display.word.direction)
        }
        XCTAssertEqual(names.count, 106)
        XCTAssertNotNil(UIImage(named: "language_learn_divider"))
    }

    func testHebrewFinalLetterKeepsHandwrittenPrintFormsAndPronunciation() throws {
        let cards = LanguageLearnContentProvider(configuration: .configuration(for: .minikPlus))
            .studyCards(for: .hebrew)
        let display = try XCTUnwrap(LanguageLearnContentProvider.presentation(for: cards[22]))
        XCTAssertEqual(display.letter.text, "ך")
        XCTAssertEqual(display.letter.speechText, "כ' סופית")
        XCTAssertEqual(display.word.text, "מלך")
        XCTAssertEqual(display.smallLetterAsset, "language_letter_kaf_sofit")
        XCTAssertEqual(display.capitalLetterAsset, "language_letter_kaf_sofit_capital")
        XCTAssertEqual(display.word.direction, .rightToLeft)
    }

    func testProjectionUsesTypedCatalogContentWithoutParsingCardIdentity() throws {
        let source = try XCTUnwrap(LanguageLearnContentProvider(configuration: .configuration(for: .minikPlus))
            .studyCards(for: .english).first)
        let renamed = try XCTUnwrap(StudyCard(
            id: StudyCardID(rawValue: "independent-fixture"),
            representations: source.representations,
            primarySkill: source.primarySkill,
            secondarySkills: source.secondarySkills,
            curriculumStage: source.curriculumStage
        ))
        XCTAssertEqual(LanguageLearnContentProvider.presentation(for: source),
                       LanguageLearnContentProvider.presentation(for: renamed))
    }
}
