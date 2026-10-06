import Foundation
import XCTest
@testable import MinikPlus

final class InterfaceLocaleTests: XCTestCase {
    func testFullProductsExposeAllSupportedInterfaceLocales() {
        for product in [ProductVariant.minikPlus, .minikMath, .minikPingPong] {
            XCTAssertEqual(
                InterfaceLocalePolicy.allowedLocales(for: product),
                InterfaceLocaleID.allCases
            )
        }
    }

    func testEnglishOnlyProductExcludesHebrewInterfaceLocale() {
        let allowed = InterfaceLocalePolicy.allowedLocales(for: .minikPlusEnglish)

        XCTAssertEqual(allowed.count, InterfaceLocaleID.allCases.count - 1)
        XCTAssertFalse(allowed.contains(.hebrew))
    }

    func testRepositoryFallsBackForInvalidOrDisallowedStoredLocale() {
        let suiteName = "InterfaceLocaleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = InterfaceLocaleRepository(userDefaults: defaults, preferredLanguages: { ["en-US"] })

        defaults.set("not-a-locale", forKey: "minik.interface-locale.v1")
        XCTAssertEqual(repository.load(for: .minikPlus), .english)

        defaults.set(InterfaceLocaleID.hebrew.rawValue, forKey: "minik.interface-locale.v1")
        XCTAssertEqual(repository.load(for: .minikPlusEnglish), .english)
    }

    func testRepositoryPersistsInterfaceLocaleIndependentOfLearnedLanguage() {
        let suiteName = "InterfaceLocaleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = InterfaceLocaleRepository(userDefaults: defaults, preferredLanguages: { ["en-US"] })

        defaults.set("am", forKey: "minik.selected-language.v1")
        repository.save(.french, for: .minikPlus)

        XCTAssertEqual(repository.load(for: .minikPlus), .french)
        XCTAssertEqual(defaults.string(forKey: "minik.selected-language.v1"), "am")
    }

    func testUnsetInterfaceLocaleFollowsPrimaryDeviceLanguageLikeAndroid() {
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlus, preferredLanguages: ["he-IL", "en-IL"]), .hebrew)
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlus, preferredLanguages: ["iw"]), .hebrew)
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikMath, preferredLanguages: ["ar-SA"]), .arabic)
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlus, preferredLanguages: ["pt-PT"]), .portuguesePortugal)
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlus, preferredLanguages: ["pt-BR"]), .portugueseBrazil)
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlus, preferredLanguages: ["zh-Hans-CN", "he-IL"]), .english)
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlus, preferredLanguages: []), .english)
    }

    func testEnglishOnlyTurnsAHebrewDeviceIntoEnglishButKeepsArabic() {
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlusEnglish, preferredLanguages: ["he-IL", "ru-RU"]), .english)
        XCTAssertEqual(InterfaceLocalePolicy.deviceDefault(for: .minikPlusEnglish, preferredLanguages: ["ar-EG"]), .arabic)
    }

    func testParentChoiceOverridesDeviceLanguage() {
        let suiteName = "InterfaceLocaleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = InterfaceLocaleRepository(userDefaults: defaults, preferredLanguages: { ["he-IL"] })

        XCTAssertEqual(repository.load(for: .minikPlus), .hebrew)
        repository.save(.english, for: .minikPlus)
        XCTAssertEqual(repository.load(for: .minikPlus), .english)
    }
}
