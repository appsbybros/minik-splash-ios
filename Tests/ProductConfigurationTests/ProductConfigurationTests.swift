import XCTest
@testable import MinikPlus

final class ProductConfigurationTests: XCTestCase {
    func testMinikPlusAllowsEnglishAndHebrew() {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)

        XCTAssertTrue(configuration.allowsLearnedLanguage(.english))
        XCTAssertTrue(configuration.allowsLearnedLanguage(.hebrew))
    }

    func testMinikPlusEnglishAllowsOnlyEnglish() {
        let configuration = ProductConfiguration.configuration(for: .minikPlusEnglish)

        XCTAssertTrue(configuration.allowsLearnedLanguage(.english))
        XCTAssertFalse(configuration.allowsLearnedLanguage(.hebrew))
        XCTAssertEqual(configuration.allowedLearnedLanguages, [.english])
        XCTAssertEqual(configuration.fixedLearnedLanguage, .english)
    }

    func testMinikPlusEnglishResolvesRestoredHebrewToEnglish() {
        let configuration = ProductConfiguration.configuration(for: .minikPlusEnglish)

        XCTAssertEqual(configuration.resolveRestoredLearnedLanguage(.hebrew), .english)
    }

    func testMinikPlusEnglishResolvesMissingLanguageToEnglish() {
        let configuration = ProductConfiguration.configuration(for: .minikPlusEnglish)

        XCTAssertEqual(configuration.resolveRestoredLearnedLanguage(nil), .english)
    }

    func testMinikPlusAcceptsRestoredHebrew() {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)

        XCTAssertEqual(configuration.resolveRestoredLearnedLanguage(.hebrew), .hebrew)
    }

    func testMinikPlusRejectsUnsupportedRestoredLanguage() {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)
        let spanish = LanguageIdentifier(rawValue: "es")

        XCTAssertNil(configuration.resolveRestoredLearnedLanguage(spanish))
    }

    func testMinikMathUsesMathContentDomain() {
        let configuration = ProductConfiguration.configuration(for: .minikMath)

        XCTAssertEqual(configuration.contentDomain, .math)
        XCTAssertNil(configuration.resolveRestoredLearnedLanguage(.english))
    }

    func testMinikPingPongHasNoCurriculumOrLearnedLanguageState() {
        let configuration = ProductConfiguration.configuration(for: .minikPingPong)

        XCTAssertEqual(configuration.contentDomain, .game)
        XCTAssertEqual(configuration.launchExperience, .pingPong)
        XCTAssertTrue(configuration.allowedLearnedLanguages.isEmpty)
        XCTAssertNil(configuration.fixedLearnedLanguage)
        XCTAssertFalse(configuration.isLearningLanguageSelectionAvailable)
        XCTAssertNil(configuration.resolveRestoredLearnedLanguage(.english))
        XCTAssertTrue(ActivityCatalog.languageSections(for: configuration).isEmpty)
        XCTAssertTrue(ActivityCatalog.mathSections(for: configuration, levelID: .m1).isEmpty)
        XCTAssertTrue(ActivityCatalog.productGameSections(for: configuration).isEmpty)
    }

    func testEducationalProductsLaunchTheSharedActivityHub() {
        XCTAssertEqual(
            ProductConfiguration.configuration(for: .minikPlus).launchExperience,
            .activityHub
        )
        XCTAssertEqual(
            ProductConfiguration.configuration(for: .minikPlusEnglish).launchExperience,
            .activityHub
        )
        XCTAssertEqual(
            ProductConfiguration.configuration(for: .minikMath).launchExperience,
            .activityHub
        )
    }

    func testLanguageIdentifiersCanGrowWithoutChangingProductVariant() {
        let spanish = LanguageIdentifier(rawValue: "es")

        XCTAssertEqual(spanish.rawValue, "es")
        XCTAssertFalse(ProductConfiguration.configuration(for: .minikPlus).allowsLearnedLanguage(spanish))
    }
}
