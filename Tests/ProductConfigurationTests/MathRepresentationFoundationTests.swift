import XCTest
@testable import MinikPlus

final class MathRepresentationFoundationTests: XCTestCase {
    func testEveryMathRepresentationFamilyHasAccessibilityAndLTRDirection() throws {
        let half = try XCTUnwrap(Rational(numerator: 1, denominator: 2))
        let zero = try XCTUnwrap(Rational(numerator: 0, denominator: 1))
        let one = try XCTUnwrap(Rational(numerator: 1, denominator: 1))
        let tens = try XCTUnwrap(MathPlaceValueComponent(placeValue: 10, digit: 4))
        let ones = try XCTUnwrap(MathPlaceValueComponent(placeValue: 1, digit: 2))
        let representations: [MathRepresentation] = [
            .numeral(MathNumeralRepresentation(value: 5, structureID: id("numeral"))),
            .quantity(try XCTUnwrap(MathQuantityRepresentation(count: 5, structureID: id("quantity")))),
            .groupedQuantity(try XCTUnwrap(MathGroupedQuantityRepresentation(
                groupCounts: [5, 5], structureID: id("grouped")
            ))),
            .placeValue(try XCTUnwrap(MathPlaceValueRepresentation(
                components: [tens, ones], structureID: id("place")
            ))),
            .equalGroups(try XCTUnwrap(MathEqualGroupsRepresentation(
                groupCount: 3, itemsPerGroup: 4, structureID: id("groups")
            ))),
            .numberLine(MathNumberLineRepresentation(
                lowerBound: zero, upperBound: one, position: half, structureID: id("line")
            )),
            .arithmeticExpression(MathArithmeticRepresentation(
                left: .integer(2), operation: .addition, right: .integer(3), structureID: id("arithmetic")
            )),
            .missingValueExpression(try XCTUnwrap(MathMissingValueRepresentation(
                left: .integer(2), operation: .addition, right: nil, result: .integer(5),
                missingPosition: .rightOperand, structureID: id("missing")
            ))),
            .fraction(MathFractionRepresentation(value: half, structureID: id("fraction"))),
            .decimal(MathDecimalRepresentation(displayText: "0.5", exactValue: half, structureID: id("decimal"))),
            .percent(MathPercentRepresentation(percentValue: try XCTUnwrap(Rational(
                numerator: 50, denominator: 1
            )), structureID: id("percent"))),
            .ratio(try XCTUnwrap(MathRatioRepresentation(first: 1, second: 2, structureID: id("ratio")))),
            .comparison(MathComparisonRepresentation(
                left: .integer(2), relation: .lessThan, right: .integer(3), structureID: id("comparison")
            ))
        ]

        XCTAssertEqual(representations.count, 13)
        for representation in representations {
            XCTAssertFalse(representation.displayText.isEmpty)
            XCTAssertFalse(representation.accessibilityDescription.isEmpty)
            XCTAssertTrue(representation.requiresLeftToRightLayout)
            XCTAssertEqual(
                Representation.math(representation).accessibilityDescription,
                representation.accessibilityDescription
            )
        }
    }

    func testDifferentVisualFamiliesCanShareOneExactSemanticValue() throws {
        let half = try XCTUnwrap(Rational(numerator: 1, denominator: 2))
        let representations: [Representation] = [
            .math(.fraction(MathFractionRepresentation(value: half, structureID: id("fraction.half")))),
            .math(.decimal(MathDecimalRepresentation(
                displayText: "0.5", exactValue: half, structureID: id("decimal.half")
            ))),
            .math(.percent(MathPercentRepresentation(
                percentValue: try XCTUnwrap(Rational(numerator: 50, denominator: 1)),
                structureID: id("percent.half")
            ))),
            .math(.ratio(try XCTUnwrap(MathRatioRepresentation(
                first: 1, second: 2, structureID: id("ratio.half")
            ))))
        ]
        let set = try XCTUnwrap(EquivalenceSet(
            semanticValue: .rational(half),
            representations: representations
        ))

        XCTAssertEqual(set.semanticValue, .rational(half))
        XCTAssertEqual(Set(set.representations).count, 4)
    }

    func testNumericEquivalenceNormalizesIntegersAndRationals() throws {
        let one = try XCTUnwrap(Rational(numerator: 4, denominator: 4))
        XCTAssertTrue(SemanticValue.integer(1).isNumericallyEquivalent(to: .rational(one)))
        XCTAssertFalse(SemanticValue.integer(2).isNumericallyEquivalent(to: .rational(one)))
        XCTAssertFalse(SemanticValue.contentItem(ContentItemID(rawValue: "one"))
            .isNumericallyEquivalent(to: .integer(1)))
    }

    func testCorrectnessDoesNotDependOnDisplayedMathText() throws {
        let half = try XCTUnwrap(Rational(numerator: 1, denominator: 2))
        let representation = Representation.math(.decimal(MathDecimalRepresentation(
            displayText: "one half",
            exactValue: half,
            structureID: id("decimal.non-parsed")
        )))
        let choice = Choice(
            id: ChoiceID(rawValue: "choice.half"),
            representation: representation,
            semanticValue: .rational(half)
        )

        XCTAssertEqual(choice.semanticValue, .rational(half))
        XCTAssertEqual(choice.representation, representation)
    }

    func testFoundationRejectsInvalidQuantityAndMissingValueShapes() {
        XCTAssertNil(MathQuantityRepresentation(count: -1, structureID: id("negative")))
        XCTAssertNil(MathGroupedQuantityRepresentation(groupCounts: [], structureID: id("empty.groups")))
        XCTAssertNil(MathRatioRepresentation(first: 1, second: 0, structureID: id("bad.ratio")))
        XCTAssertNil(MathMissingValueRepresentation(
            left: .integer(2), operation: .addition, right: .integer(3), result: .integer(5),
            missingPosition: .rightOperand, structureID: id("not.missing")
        ))
    }

    private func id(_ value: String) -> RepresentationStructureID {
        RepresentationStructureID(rawValue: "test.\(value)")
    }
}
