import XCTest
@testable import MinikPlus

final class MathQuantityLayoutTests: XCTestCase {
    private let layout = MathQuantityLayout(
        maximumRenderedItems: 30,
        minimumItemDiameter: 18,
        itemSpacing: 8,
        groupSpacing: 16
    )

    func testZeroProducesNeutralEmptyLayoutWithoutItems() throws {
        let result = try XCTUnwrap(layout.layout(count: 0, inWidth: 120, height: 80, mode: .individual))
        XCTAssertTrue(result.items.isEmpty)
    }

    func testOneObjectIsCentered() throws {
        let result = try XCTUnwrap(layout.layout(count: 1, inWidth: 120, height: 80, mode: .individual))
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].centerX, 60, accuracy: 0.001)
        XCTAssertEqual(result.items[0].centerY, 40, accuracy: 0.001)
    }

    func testSeveralObjectsAreDeterministicInNarrowAndWideContainers() throws {
        let narrow = try XCTUnwrap(layout.layout(count: 7, inWidth: 150, height: 180, mode: .individual))
        let narrowAgain = try XCTUnwrap(layout.layout(count: 7, inWidth: 150, height: 180, mode: .individual))
        let wide = try XCTUnwrap(layout.layout(count: 7, inWidth: 320, height: 120, mode: .individual))
        XCTAssertEqual(narrow, narrowAgain)
        XCTAssertEqual(narrow.items.count, 7)
        XCTAssertEqual(wide.items.count, 7)
        assertValid(narrow, width: 150, height: 180)
        assertValid(wide, width: 320, height: 120)
    }

    func testGroupedLayoutPreservesCallerSuppliedGroups() throws {
        let result = try XCTUnwrap(layout.layout(
            count: 8,
            inWidth: 360,
            height: 140,
            mode: .grouped(groupCounts: [3, 5])
        ))
        XCTAssertEqual(result.items.filter { $0.groupIndex == 0 }.count, 3)
        XCTAssertEqual(result.items.filter { $0.groupIndex == 1 }.count, 5)
        assertValid(result, width: 360, height: 140)
    }

    func testRejectsInvalidGroupsAndExcessiveIndividualArtwork() {
        XCTAssertNil(layout.layout(count: 8, inWidth: 360, height: 140, mode: .grouped(groupCounts: [4, 3])))
        XCTAssertNil(layout.layout(count: 108, inWidth: 800, height: 600, mode: .individual))
    }

    func testAssetManifestLookupIsTypedAndDeterministic() throws {
        let apple = MathObjectAsset(assetName: "math_apple", accessibilityLabel: "Apple")
        let pear = MathObjectAsset(assetName: "math_pear", accessibilityLabel: "Pear")
        let empty = MathObjectAsset(assetName: "math_empty_basket", accessibilityLabel: "Empty basket")
        let id = MathObjectThemeID(rawValue: "fruit")
        let theme = try XCTUnwrap(MathObjectTheme(id: id, objects: [apple, pear], emptyStateAsset: empty))
        let manifest = try XCTUnwrap(MathObjectThemeManifest(themes: [theme]))
        XCTAssertEqual(manifest.theme(for: id), theme)
        XCTAssertEqual(theme.object(forItemAt: 0), apple)
        XCTAssertEqual(theme.object(forItemAt: 2), apple)
        XCTAssertEqual(theme.emptyStateAsset, empty)
    }

    private func assertValid(_ result: MathQuantityLayoutResult, width: Double, height: Double) {
        for item in result.items {
            XCTAssertGreaterThanOrEqual(item.centerX - item.diameter / 2, -0.001)
            XCTAssertLessThanOrEqual(item.centerX + item.diameter / 2, width + 0.001)
            XCTAssertGreaterThanOrEqual(item.centerY - item.diameter / 2, -0.001)
            XCTAssertLessThanOrEqual(item.centerY + item.diameter / 2, height + 0.001)
        }
        for firstIndex in result.items.indices {
            for secondIndex in result.items.indices where secondIndex > firstIndex {
                let first = result.items[firstIndex]
                let second = result.items[secondIndex]
                let dx = first.centerX - second.centerX
                let dy = first.centerY - second.centerY
                let minimumDistance = (first.diameter + second.diameter) / 2
                XCTAssertGreaterThanOrEqual((dx * dx + dy * dy).squareRoot(), minimumDistance - 0.001)
            }
        }
    }
}
