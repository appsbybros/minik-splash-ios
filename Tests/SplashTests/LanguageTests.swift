import XCTest
@testable import MinikSplash

/// Port of Android LanguageTest.kt plus golden catalog lookups from the Android AppText.
final class LanguageTests: XCTestCase {
    override func tearDown() {
        AppText.configure("en")
        super.tearDown()
    }

    func testDeviceTagsMapToSupportedLanguages() {
        XCTAssertEqual(AppText.normalize("es-MX"), "es")
        XCTAssertEqual(AppText.normalize("hi-IN"), "hi")
        XCTAssertEqual(AppText.normalize("nl-NL"), "nl")
        XCTAssertEqual(AppText.normalize("ar-SA"), "ar")
        XCTAssertEqual(AppText.normalize("iw"), "he")
        XCTAssertEqual(AppText.normalize("fr"), "en")
        XCTAssertEqual(AppText.normalize("he-IL"), "he")
    }

    func testAllFourLanguagesHaveCompleteCatalogColumns() {
        let keys = AppText.keys()
        XCTAssertEqual(keys.count, 820)
        for lang in ["es", "ar", "hi", "nl"] {
            for key in keys {
                let value = AppText.translated(key, lang) ?? ""
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(lang) \(key)")
            }
        }
    }

    func testRtlAndExistingHebrewArePreserved() {
        AppText.configure("ar")
        XCTAssertTrue(AppText.rtl)
        XCTAssertEqual(AppText.t("Back", "חזרה", hebrew: false), "رجوع")
        XCTAssertEqual(AppText.t("Back", "חזרה", hebrew: true), "חזרה")
        AppText.configure("nl")
        XCTAssertFalse(AppText.rtl)
        AppText.configure("he")
        XCTAssertTrue(AppText.rtl)
        XCTAssertEqual(AppText.t("Back", "חזרה"), "חזרה")
    }

    func testPlaceholdersPreservePrivateNamesAndNumbers() {
        AppText.configure("es")
        XCTAssertEqual(AppText.t("7 seconds left"), "Quedan 7 segundos")
        let actual = AppText.t("Mia caught the ball! Their turn to call.")
        XCTAssertTrue(actual.contains("Mia"))
        XCTAssertFalse(actual.contains("caught"))
        XCTAssertEqual(AppText.t("A name not in the catalog"), "A name not in the catalog")
    }

    func testEnglishReturnsTheSourceText() {
        AppText.configure("en")
        XCTAssertEqual(AppText.t("Back", "חזרה"), "Back")
        XCTAssertEqual(AppText.t("Correct answers: 3 · Hits: 2"), "Correct answers: 3 · Hits: 2")
    }

    /// Lookups (direct rows, templates, padding and " · " prefixes) match Android output exactly.
    func testGoldenTranslationsMatchAndroid() {
        let keys = ["Back", "Correct answers: 3 · Hits: 2", "Cup · round 2 / 3", "Independent: 4 · With help: 1",
                    "Private room ABC123", "Return to ABC123",
                    "Previous question: 5 + 3 = 8 That wrong-answer balloon burst in your hand. Choose the right balloon, then throw!",
                    " · Not ready", " · You", "A name not in the catalog", "Multiply first: 3 × 4 = 12. 5 + 3 × 4 = 17",
                    "1 + 2 over the common denominator 4 = 3/4", "Star", "Pacific", "  Back  ", "7 seconds left", "12 − 5", "Cup · 2 / 3",
                    "Which word names an animal?", "The Sun is our nearest star.", "Practice", "TAP", "YOUR QUESTION", "Mia · Not ready",
                    "Easy · tap a balloon to walk and collect", "Addition", "Fractions", "World knowledge",
                    "Questions and answers were created with AI. AI can make mistakes."]
        let rows = AndroidGolden.rows(AndroidGolden.translations)
        XCTAssertEqual(rows.count, keys.count * 4)
        for row in rows {
            let parts = row.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map { String($0) }
            guard parts.count == 4, let index = Int(parts[2]), index < keys.count else {
                XCTFail(row)
                continue
            }
            AppText.configure(parts[1])
            let expected = parts[3].replacingOccurrences(of: "\\n", with: "\n")
            XCTAssertEqual(AppText.t(keys[index], keys[index], hebrew: false), expected, row)
        }
    }
}
