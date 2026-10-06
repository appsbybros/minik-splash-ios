import XCTest
@testable import MinikPlus

final class MathObjectCatalogTests: XCTestCase {
    func testManifestDecodingRejectsDuplicateStableIDs() throws {
        let data = try XCTUnwrap("""
        {
          "version": 1,
          "objects": [
            {"id":"duplicate","assetName":"object","category":"fruits","accessibilityLabel":"Object"}
          ],
          "zeroStates": [
            {"id":"duplicate","assetName":"empty","category":"zero-states","accessibilityLabel":"Empty"}
          ],
          "groupingSupport": [
            {"id":"group","assetName":"group","category":"grouping-support","accessibilityLabel":"Group"}
          ]
        }
        """.data(using: .utf8))

        XCTAssertThrowsError(try MathObjectCatalog.decode(data)) { error in
            XCTAssertEqual(error as? MathObjectCatalogError, .duplicateID("duplicate"))
        }
    }

    func testInjectedRandomSelectionIsDeterministicAndAvoidsImmediateRepeat() throws {
        let themes = try ["apple", "ball", "book"].map { name in
            try XCTUnwrap(MathObjectTheme(
                id: MathObjectThemeID(rawValue: name),
                objects: [MathObjectAsset(assetName: name, accessibilityLabel: name)],
                emptyStateAsset: MathObjectAsset(assetName: "empty", accessibilityLabel: "Empty")
            ))
        }
        var firstGenerator = SeededMathRandomNumberGenerator(seed: 42)
        var secondGenerator = SeededMathRandomNumberGenerator(seed: 42)
        var first = MathObjectThemeSelector(themes: themes)
        var second = MathObjectThemeSelector(themes: themes)
        var firstIDs: [MathObjectThemeID] = []
        var secondIDs: [MathObjectThemeID] = []

        for _ in 0..<20 {
            firstIDs.append(try XCTUnwrap(first.next(using: &firstGenerator)).id)
            secondIDs.append(try XCTUnwrap(second.next(using: &secondGenerator)).id)
        }

        XCTAssertEqual(firstIDs, secondIDs)
        for index in 1..<firstIDs.count {
            XCTAssertNotEqual(firstIDs[index - 1], firstIDs[index])
        }
    }

    func testThemeDoesNotParticipateInQuantityCorrectness() throws {
        let quantity = try XCTUnwrap(MathQuantityRepresentation(
            count: 5,
            structureID: RepresentationStructureID(rawValue: "quantity.five")
        ))
        let firstTheme = MathObjectThemeID(rawValue: "apple")
        let secondTheme = MathObjectThemeID(rawValue: "ball")

        XCTAssertEqual(quantity.count, 5)
        XCTAssertNotEqual(firstTheme, secondTheme)
        XCTAssertTrue(SemanticValue.integer(quantity.count).isNumericallyEquivalent(to: .integer(5)))
    }
}
