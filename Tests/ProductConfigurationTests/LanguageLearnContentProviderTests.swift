import XCTest
@testable import MinikPlus

final class LanguageLearnContentProviderTests: XCTestCase {
    func testEnglishCardsAreNonemptyDeterministicAndOrdered() {
        let provider = makeProvider(for: .minikPlus)

        let firstResult = provider.studyCards(for: .english)
        let secondResult = provider.studyCards(for: .english)

        XCTAssertFalse(firstResult.isEmpty)
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertEqual(firstResult.count, 26)
    }

    func testEnglishFirstAndLastCardsMatchAndroidLearnContent() throws {
        let cards = makeProvider(for: .minikPlus).studyCards(for: .english)
        let firstCard = try XCTUnwrap(cards.first)

        XCTAssertEqual(try textValues(in: firstCard), ["A a", "Apple"])
        XCTAssertEqual(try textValues(in: XCTUnwrap(cards.last)), ["Z z", "Zebra"])
        XCTAssertEqual(try assetValue(in: firstCard), "learn_a")
        XCTAssertEqual(try assetValue(in: XCTUnwrap(cards.last)), "learn_z")
        XCTAssertEqual(try spokenText(in: firstCard, at: 0), "a")
    }

    func testHebrewCardsAreNonemptyDeterministicAndOrdered() {
        let provider = makeProvider(for: .minikPlus)

        let firstResult = provider.studyCards(for: .hebrew)
        let secondResult = provider.studyCards(for: .hebrew)

        XCTAssertFalse(firstResult.isEmpty)
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertEqual(firstResult.count, 27)
    }

    func testHebrewFirstAndLastCardsMatchAndroidLearnContent() throws {
        let cards = makeProvider(for: .minikPlus).studyCards(for: .hebrew)
        let firstCard = try XCTUnwrap(cards.first)

        XCTAssertEqual(try textValues(in: firstCard), ["א", "אריה"])
        XCTAssertEqual(try textValues(in: XCTUnwrap(cards.last)), ["ץ", "עץ"])
        XCTAssertEqual(try assetValue(in: firstCard), "learn_alef")
        XCTAssertEqual(try assetValue(in: XCTUnwrap(cards.last)), "learn_chadik_sofit")
        XCTAssertEqual(try spokenText(in: firstCard, at: 0), "א")
    }

    func testHebrewFinalFormsFollowStandardAlphabetInAndroidOrder() throws {
        let cards = makeProvider(for: .minikPlus).studyCards(for: .hebrew)
        let finalCards = try cards.suffix(5).map(textValues)

        XCTAssertEqual(finalCards, [
            ["ך", "מלך"],
            ["ם", "עולם"],
            ["ן", "שעון"],
            ["ף", "אף"],
            ["ץ", "עץ"]
        ])
        XCTAssertEqual(try spokenText(in: cards[cards.count - 5], at: 0), "כ' סופית")
    }

    func testEveryEnglishExampleAndIllustrationMatchesAndroidLearnScreen() throws {
        let cards = makeProvider(for: .minikPlus).studyCards(for: .english)
        let expectedWords = [
            "Apple", "Banana", "Carrot", "Door", "Elephant", "Fish", "Grandfather",
            "Hat", "Igloo", "Juice", "Kangaroo", "Lettuce", "Mom", "Nose", "Onion",
            "Pear", "Queen", "Ruler", "Scissors", "Tomato", "Unicorn", "Violin",
            "Watermelon", "X-ray", "Yard", "Zebra"
        ]
        let expectedAssets = [
            "learn_a", "learn_b", "learn_c", "learn_d", "learn_e", "learn_f",
            "learn_g", "learn_h", "learn_i", "learn_j", "learn_k", "learn_l",
            "learn_m", "learn_n", "learn_o", "learn_p", "learn_q", "learn_r",
            "learn_s", "learn_t", "learn_u", "learn_v", "learn_w", "learn_x",
            "learn_y", "learn_z"
        ]

        XCTAssertEqual(try cards.map { try textValues(in: $0)[1] }, expectedWords)
        XCTAssertEqual(try cards.map(assetValue), expectedAssets)
    }

    func testEveryHebrewExampleAndIllustrationMatchesAndroidLearnScreen() throws {
        let cards = makeProvider(for: .minikPlus).studyCards(for: .hebrew)
        let expectedWords = [
            "אריה", "בננה", "גזר", "דג", "הר", "ורד", "זברה", "חתול", "טווס",
            "יען", "כבשה", "ליצן", "מלכה", "נמר", "סוס", "עכבר", "פרפר", "צב",
            "קנגורו", "רכבת", "שבלול", "תות", "מלך", "עולם", "שעון", "אף", "עץ"
        ]
        let expectedAssets = [
            "learn_alef", "learn_beit", "learn_gimel", "learn_dalet", "learn_eih",
            "learn_vav", "learn_zain", "learn_het", "learn_tet", "learn_yud",
            "learn_kaf", "learn_lamed", "learn_mem", "learn_noon", "learn_sameh",
            "learn_hain", "learn_pei", "learn_chadik", "learn_kuf", "learn_reish",
            "learn_shin", "learn_taf", "learn_kaf_sofit", "learn_mem_sofit",
            "learn_noon_sofit", "learn_pei_sofit", "learn_chadik_sofit"
        ]

        XCTAssertEqual(try cards.map { try textValues(in: $0)[1] }, expectedWords)
        XCTAssertEqual(try cards.map(assetValue), expectedAssets)
    }

    func testEveryEnglishTextHasEnglishLanguageAndLeftToRightDirection() throws {
        let cards = makeProvider(for: .minikPlus).studyCards(for: .english)

        try assertTextMetadata(in: cards, language: .english, direction: .leftToRight)
    }

    func testEveryCardContainsLetterWordAndImageInOrder() {
        let provider = makeProvider(for: .minikPlus)
        let cards = provider.studyCards(for: .english) + provider.studyCards(for: .hebrew)

        for card in cards {
            XCTAssertEqual(card.representations.count, 3)
            guard case .learningText = card.representations[0],
                  case .learningText = card.representations[1],
                  case .imageAsset = card.representations[2] else {
                return XCTFail("Expected letter, word, and image representations in order.")
            }
        }
    }

    func testEveryHebrewTextHasHebrewLanguageAndRightToLeftDirection() throws {
        let cards = makeProvider(for: .minikPlus).studyCards(for: .hebrew)

        try assertTextMetadata(in: cards, language: .hebrew, direction: .rightToLeft)
    }

    func testProviderEnforcesProductLearnedLanguagePolicy() {
        let plusProvider = makeProvider(for: .minikPlus)
        let englishOnlyProvider = makeProvider(for: .minikPlusEnglish)

        XCTAssertFalse(plusProvider.studyCards(for: .english).isEmpty)
        XCTAssertFalse(plusProvider.studyCards(for: .hebrew).isEmpty)
        XCTAssertFalse(englishOnlyProvider.studyCards(for: .english).isEmpty)
        XCTAssertTrue(englishOnlyProvider.studyCards(for: .hebrew).isEmpty)
    }

    private func makeProvider(for variant: ProductVariant) -> LanguageLearnContentProvider {
        LanguageLearnContentProvider(configuration: .configuration(for: variant))
    }

    private func textValues(in card: StudyCard) throws -> [String] {
        try card.representations.prefix(2).map { representation in
            guard case .learningText(let text) = representation else {
                throw TestError.expectedLearningText
            }
            return text.text
        }
    }

    private func assetValue(in card: StudyCard) throws -> String {
        guard card.representations.count == 3,
              case .imageAsset(let asset) = card.representations[2] else {
            throw TestError.expectedImageAsset
        }
        return asset.rawValue
    }

    private func spokenText(in card: StudyCard, at index: Int) throws -> String {
        guard card.representations.indices.contains(index),
              case .learningText(let text) = card.representations[index] else {
            throw TestError.expectedLearningText
        }
        return text.speechText ?? text.text
    }

    private func assertTextMetadata(
        in cards: [StudyCard],
        language: LanguageIdentifier,
        direction: ContentDirection
    ) throws {
        XCTAssertFalse(cards.isEmpty)

        for representation in cards.flatMap({ $0.representations.prefix(2) }) {
            guard case .learningText(let text) = representation else {
                throw TestError.expectedLearningText
            }
            XCTAssertEqual(text.language, language)
            XCTAssertEqual(text.direction, direction)
        }
    }

    private enum TestError: Error {
        case expectedLearningText
        case expectedImageAsset
    }
}
