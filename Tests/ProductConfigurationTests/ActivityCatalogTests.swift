import XCTest
@testable import MinikPlus

final class ActivityCatalogTests: XCTestCase {
    func testMinikPlusUsesSharedLanguageCatalogAndNoMathCatalog() {
        let configuration = ProductConfiguration.configuration(for: .minikPlus)

        XCTAssertEqual(configuration.contentDomain, .language)
        XCTAssertTrue(configuration.allowsLearnedLanguage(.english))
        XCTAssertTrue(configuration.allowsLearnedLanguage(.hebrew))
        XCTAssertEqual(
            languageActivityKinds(in: ActivityCatalog.languageSections(for: configuration)),
            Set(LanguageActivityKind.productionKinds)
        )
        XCTAssertEqual(
            ActivityCatalog.languageSections(for: configuration).map(\.id),
            LanguageActivityKind.sections.map(\.id)
        )
        XCTAssertEqual(
            ActivityCatalog.languageSections(for: configuration).map(\.activities),
            LanguageActivityKind.sections.map(\.activities)
        )
        XCTAssertTrue(ActivityCatalog.mathSections(for: configuration, levelID: .m3).isEmpty)
    }

    func testMinikPlusEnglishUsesSameSharedLanguageCatalogAndNoMathCatalog() {
        let configuration = ProductConfiguration.configuration(for: .minikPlusEnglish)
        let plusConfiguration = ProductConfiguration.configuration(for: .minikPlus)

        XCTAssertEqual(configuration.contentDomain, .language)
        XCTAssertTrue(configuration.allowsLearnedLanguage(.english))
        XCTAssertFalse(configuration.allowsLearnedLanguage(.hebrew))
        XCTAssertEqual(
            languageActivityKinds(in: ActivityCatalog.languageSections(for: configuration)),
            Set(LanguageActivityKind.productionKinds)
        )
        XCTAssertEqual(
            ActivityCatalog.languageSections(for: configuration).map(\.activities),
            ActivityCatalog.languageSections(for: plusConfiguration).map(\.activities)
        )
        XCTAssertTrue(ActivityCatalog.mathSections(for: configuration, levelID: .m3).isEmpty)
    }

    func testTicTacToeIsAJustForFunGameInBothLanguageProductsOnly() throws {
        for product in [ProductVariant.minikPlus, .minikPlusEnglish] {
            let configuration = ProductConfiguration.configuration(for: product)
            let games = try XCTUnwrap(
                ActivityCatalog.languageSections(for: configuration).first { $0.id == "games" }
            )

            XCTAssertTrue(games.activities.contains(.ticTacToe))
            XCTAssertEqual(LanguageActivityKind.ticTacToe.title, "Tic-Tac-Toe")
            XCTAssertEqual(LanguageActivityKind.ticTacToe.subtitle, "Just for Fun")
        }

        let mathConfiguration = ProductConfiguration.configuration(for: .minikMath)
        XCTAssertTrue(ActivityCatalog.languageSections(for: mathConfiguration).isEmpty)
        XCTAssertFalse(
            ActivityCatalog.productGameSections(for: mathConfiguration)
                .flatMap(\.activities)
                .isEmpty
        )

        // The session API has no LanguageIdentifier input. Learned-language
        // selection therefore cannot alter game rules, marks, or difficulty.
        let session = TicTacToeSession()
        XCTAssertEqual(session.level, .adaptive)
        XCTAssertEqual(session.childMark, .cross)
    }

    func testMinikMathExposesPingPongOutsideMathCurriculumCatalog() {
        let configuration = ProductConfiguration.configuration(for: .minikMath)
        let productGames = ActivityCatalog.productGameSections(for: configuration)
            .flatMap(\.activities)

        XCTAssertEqual(productGames, [.pingPong])
        XCTAssertEqual(ProductGameKind.pingPong.title, "Ping Pong")
        XCTAssertFalse(MathActivityKind.allCases.map(\.rawValue).contains("pingPong"))
        XCTAssertTrue(ActivityCatalog.productGameSections(
            for: ProductConfiguration.configuration(for: .minikPlus)
        ).isEmpty)
    }

    func testMinikMathCatalogUsesTheCentralStageCapabilityPolicy() {
        let configuration = ProductConfiguration.configuration(for: .minikMath)

        XCTAssertEqual(configuration.contentDomain, .math)
        XCTAssertTrue(ActivityCatalog.languageSections(for: configuration).isEmpty)

        for level in MathCurriculumPolicy.runnableLevels {
            let sections = ActivityCatalog.mathSections(
                for: configuration,
                levelID: level.id
            )
            XCTAssertEqual(
                mathActivityKinds(in: sections),
                Set(MathProductionActivityID.allCases.filter {
                    $0.curriculumRole == .curriculum
                })
            )
            XCTAssertTrue(sections.allSatisfy { !$0.activities.isEmpty })
        }
    }

    func testMinikMathCatalogPreservesAllTwelveEducationalIdentitiesAtEveryLevel() {
        let configuration = ProductConfiguration.configuration(for: .minikMath)

        XCTAssertEqual(
            mathActivityKinds(in: ActivityCatalog.mathSections(
                for: configuration,
                levelID: .m1
            )),
            Set(MathProductionActivityID.allCases.filter { $0.curriculumRole == .curriculum })
        )
        XCTAssertEqual(
            mathActivityKinds(in: ActivityCatalog.mathSections(
                for: configuration,
                levelID: .m2
            )),
            Set(MathProductionActivityID.allCases.filter { $0.curriculumRole == .curriculum })
        )
    }

    func testMinikMathM3CatalogPreservesEveryProductIdentity() {
        let configuration = ProductConfiguration.configuration(for: .minikMath)

        XCTAssertEqual(
            mathActivityKinds(in: ActivityCatalog.mathSections(
                for: configuration,
                levelID: .m3
            )),
            Set(MathProductionActivityID.allCases.filter { $0.curriculumRole == .curriculum })
        )
    }

    func testEveryCanonicalMathLevelKeepsAllProductIdentitiesVisible() {
        let configuration = ProductConfiguration.configuration(for: .minikMath)
        for level in MathCurriculumPolicy.levels {
            XCTAssertEqual(
                mathActivityKinds(in: ActivityCatalog.mathSections(
                    for: configuration,
                    levelID: level.id
                )),
                Set(MathProductionActivityID.allCases.filter { $0.curriculumRole == .curriculum })
            )
        }
    }

    private func languageActivityKinds(
        in sections: [ActivitySection<LanguageActivityKind>]
    ) -> Set<LanguageActivityKind> {
        Set(sections.flatMap(\.activities))
    }

    private func mathActivityKinds(
        in sections: [ActivitySection<MathProductionActivityID>]
    ) -> Set<MathProductionActivityID> {
        Set(sections.flatMap(\.activities))
    }
}
