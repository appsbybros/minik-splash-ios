import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../localization/LanguageTest.kt (MinikCrossPong working tree on 828c6fc, 2026-10-04): the device-language
// catalog (`AppText` -> `MPText`, `AppText.configure` -> `MPText.configure`, `AppText.keys()` -> `MPText.keys`).
// The instrumentation test app/src/androidTest/.../LanguageDeviceTest.kt is ported in part: its language and direction checks
// run here; launching activities and taking screenshots has no unit-test counterpart on iOS.
final class LanguageTests: XCTestCase {
    // Kotlin: @After reset
    override func tearDown() {
        MPText.configure("en")
        super.tearDown()
    }

    // Kotlin: deviceTagsMapToSupportedLanguages
    func testDeviceTagsMapToSupportedLanguages() {
        XCTAssertEqual("es", MPText.normalize("es-MX")); XCTAssertEqual("hi", MPText.normalize("hi-IN"))
        XCTAssertEqual("nl", MPText.normalize("nl-NL")); XCTAssertEqual("ar", MPText.normalize("ar-SA"))
        XCTAssertEqual("he", MPText.normalize("iw")); XCTAssertEqual("en", MPText.normalize("fr"))
    }

    // Kotlin: allFourLanguagesHaveCompleteCatalogColumns
    func testAllFourLanguagesHaveCompleteCatalogColumns() {
        for lang in ["es", "ar", "hi", "nl"] {
            for key in MPText.keys {
                let text = MPText.translated(key, lang) ?? ""
                XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(lang) \(key)")
            }
        }
    }

    // Kotlin: rtlAndExistingHebrewArePreserved
    func testRtlAndExistingHebrewArePreserved() {
        MPText.configure("ar"); XCTAssertTrue(MPText.rtl); XCTAssertEqual("رجوع", MPText.t("Back", "חזרה", false))
        XCTAssertEqual("חזרה", MPText.t("Back", "חזרה", true)); MPText.configure("nl"); XCTAssertFalse(MPText.rtl)
    }

    // Kotlin: placeholdersPreservePrivateNamesAndNumbers
    func testPlaceholdersPreservePrivateNamesAndNumbers() {
        MPText.configure("es"); XCTAssertEqual("Quedan 7 segundos", MPText.t("7 seconds left"))
        let actual = MPText.t("Mia caught the ball! Their turn to call.")
        XCTAssertTrue(actual.contains("Mia")); XCTAssertFalse(actual.contains("caught"))
        XCTAssertEqual("A name not in the catalog", MPText.t("A name not in the catalog"))
    }

    // Kotlin (androidTest): LanguageDeviceTest.sixDeviceLanguagesResolveResourcesAndRenderCrossCourt — the language and the
    // layout direction of each device language, and a translated resource text (Android R.string.settings). The activity
    // launches and the screenshots are not ported.
    func testSixDeviceLanguagesResolveTextsAndDirection() {
        for lang in ["en", "he", "es", "ar", "hi", "nl"] {
            MPText.configure(lang)
            XCTAssertEqual(lang, MPText.language)
            XCTAssertEqual(["he", "ar"].contains(lang), MPText.rtl, lang)
            let settings = MPText.t("Settings", "הגדרות", MPText.language == "he")
            if ["es", "ar", "hi", "nl"].contains(lang) { XCTAssertNotEqual("Settings", settings, lang) }
            if lang == "he" { XCTAssertEqual("הגדרות", settings) }
            if lang == "en" { XCTAssertEqual("Settings", settings) }
        }
    }

    // iOS: the language list, the catalog and the lookups keep Android's rules (Android LocalizedActivity / AppText).
    func testLanguagesFollowAndroid() {
        XCTAssertEqual(MPText.languages, Set(["en", "he", "es", "ar", "hi", "nl"]))
        XCTAssertEqual(["es", "ar", "hi", "nl"], MPText.columns)
        XCTAssertEqual(820, MPText.keys.count)
        XCTAssertEqual(MPText.keys.count, Set(MPText.keys).count)
        XCTAssertEqual("en", MPText.normalize("")); XCTAssertEqual("he", MPText.normalize("he-IL")); XCTAssertEqual("es", MPText.normalize("ES"))
        // iOS tags may use an underscore ("hi_IN"); only the language part counts, as for "hi-IN".
        XCTAssertEqual("hi", MPText.normalize("hi_IN")); XCTAssertEqual("en", MPText.normalize("pt-BR"))
        XCTAssertNil(MPText.translated("Back", "en")); XCTAssertNil(MPText.translated("Back", "he"))
        XCTAssertEqual("Terug", MPText.translated("Back", "nl-BE"))
        MPText.configure("hi"); XCTAssertFalse(MPText.rtl)
        MPText.configure("en"); XCTAssertEqual("Back", MPText.t("Back", "חזרה", false))
        MPText.configure("he"); XCTAssertEqual("Back", MPText.t("Back")); XCTAssertTrue(MPText.rtl)
    }

    // iOS: a caller's padding and a " · " suffix keep their spacing around the catalog text (Android AppText.t).
    func testPaddingAndSuffixKeepTheirSpacing() {
        MPText.configure("es")
        XCTAssertEqual(" jugadores", MPText.t(" players", " שחקנים", false))
        XCTAssertEqual("Rival: ", MPText.t("Opponent: ", "יריב: ", false))
        XCTAssertEqual(" · tú", MPText.t(" · you", " · אתם", false))
        XCTAssertEqual(" · אתם", MPText.t(" · you", " · אתם", true))
    }

    // iOS: the ported game texts pass through the catalog call by call, as the Android working tree does; Hebrew is unchanged
    // and the texts Android leaves out of the catalog stay English.
    func testGameTextsUseTheCatalog() {
        MPText.configure("es")
        XCTAssertEqual("Final", MPKnockout.stage(players: 2, hebrew: false))
        XCTAssertEqual("Ronda de 16", MPGroupTournament.stage(16, 4, hebrew: false, advance: 2))
        XCTAssertEqual("Mesas de semifinales", MPGroupTournament.stage(8, 4, hebrew: false, advance: 2))
        XCTAssertEqual("Principiante", MPControlChoice.title(4, hebrew: false))
        XCTAssertEqual("Estándar", MPControlChoice.title(0, hebrew: false))
        XCTAssertEqual("Pasa sin jugar", MPKnockout.walkoverTitle(hebrew: false))
        XCTAssertEqual("Desempate por la última plaza: el primer punto decide quién avanza.", MPKnockout.tiebreakStatus(hebrew: false))
        XCTAssertEqual("שובר שוויון על המקום האחרון: הנקודה הראשונה מכריעה מי עולה.", MPKnockout.tiebreakStatus(hebrew: true))
        XCTAssertEqual("Duelo final", MPMatchText.duelTitle(hebrew: false))
        XCTAssertEqual("Eliminación directa", MPTournamentFormat.knockout.title(false))
        XCTAssertEqual("Elimination", MPGameMode.elimination.title(false))
        XCTAssertEqual("הדחה", MPGameMode.elimination.title(true))
    }

    // iOS: the cross guide's card and status line (Android CrossTutorial.card / statusText of the working tree): the control
    // line is looked up with its control name already translated.
    func testCrossTourTextsUseTheCatalog() {
        MPText.configure("es")
        let tour = CrossTutorial(players: 4, control: .beginner, names: ["Tú"], hebrew: false)
        let card = tour.card(false)
        XCTAssertEqual("¡Juguemos a Multi Ping Pong!", card.title)
        XCTAssertEqual("Controles: Principiante (cámbialos en Ajustes ⚙)\n\n4 jugadores comparten mesa y pelota. Siempre estás abajo. Envía la pelota a CUALQUIER rival hasta que alguien alcance la puntuación objetivo.",
                       card.message)
        XCTAssertEqual("1/6 · Principiante · Cómo jugar", tour.statusText(false))
        MPText.configure("en")
        XCTAssertTrue(tour.card(false).message.hasPrefix("Controls: Beginner (change it in Settings ⚙)\n\n4 players share one table"))
        XCTAssertTrue(tour.card(true).message.hasPrefix("רמת שליטה: מתחילים (אפשר לשנות בהגדרות ⚙)\n\n"))
    }
}
