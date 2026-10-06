import Foundation
import SwiftUI
import XCTest
@testable import MinikPlus

final class LanguageInterfaceLocalizationTests: XCTestCase {
    func testHebrewResolvesRealParentAndMenuTextUsingExplicitLocale() {
        XCTAssertEqual(InterfaceLocaleID.hebrew.text("Parent Area"), "אזור הורים")
        XCTAssertEqual(InterfaceLocaleID.hebrew.text("Interface language"), "שפת האפליקציה")
        XCTAssertEqual(InterfaceLocaleID.hebrew.text(LanguageActivityKind.letterPairs.titleKey), "זוגות")
        XCTAssertEqual(InterfaceLocaleID.english.text("Parent Area"), "Parent Area")
    }

    func testEverySupportedInterfaceLocaleHasParentTranslation() {
        for locale in InterfaceLocaleID.allCases where locale != .english {
            XCTAssertNotEqual(locale.text("Parent Area"), "Parent Area", locale.rawValue)
            XCTAssertNotEqual(locale.text("Interface language"), "Interface language", locale.rawValue)
        }
    }

    @MainActor
    func testSelectionUpdatesCurrentTextAndSurvivesControllerRecreation() async {
        let suiteName = "LanguageInterfaceLocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = InterfaceLocaleRepository(userDefaults: defaults)
        let controller = InterfaceLocaleController(product: .minikPlus, repository: repository)
        controller.select(.hebrew)
        XCTAssertEqual(controller.selectedLocale.text("Parent Area"), "אזור הורים")
        let restored = InterfaceLocaleController(product: .minikPlus, repository: repository)
        XCTAssertEqual(restored.selectedLocale, .hebrew)
        restored.select(.french)
        XCTAssertEqual(restored.selectedLocale.text("Interface language"), InterfaceLocaleID.french.text("Interface language"))
        XCTAssertNotEqual(restored.selectedLocale.text("Interface language"), "שפת האפליקציה")
    }

    func testInterfaceDirectionIsIndependentOfLearnedLanguage() {
        XCTAssertEqual(InterfaceLocaleID.hebrew.layoutDirection, .rightToLeft)
        XCTAssertEqual(InterfaceLocaleID.arabic.layoutDirection, .rightToLeft)
        XCTAssertEqual(InterfaceLocaleID.english.layoutDirection, .leftToRight)
        let configuration = ProductConfiguration.configuration(for: .minikPlusEnglish)
        XCTAssertEqual(configuration.fixedLearnedLanguage, .english)
        XCTAssertTrue(InterfaceLocalePolicy.allowedLocales(for: .minikPlusEnglish).contains(.arabic))
    }

    func testLearnedContentDirectionMapsToSwiftUILayoutDirection() {
        XCTAssertEqual(ContentDirection.leftToRight.layoutDirection, .leftToRight)
        XCTAssertEqual(ContentDirection.rightToLeft.layoutDirection, .rightToLeft)
    }
}
