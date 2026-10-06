import XCTest
@testable import MinikPlus

final class MathStructuredConstructionSessionTests: XCTestCase {
    func testPlaceValueRequiresCorrectTensAndOnesStructure() throws {
        let round = try XCTUnwrap(makePlaceValueRound())
        var session = try XCTUnwrap(MathStructuredConstructionSession(rounds: [round]))
        let tens = round.availableTokens.filter { $0.unit == .placeValue(10) }
        let ones = round.availableTokens.filter { $0.unit == .placeValue(1) }

        for token in tens.prefix(4) { session.add(token.id) }
        for token in ones.prefix(6) { session.add(token.id) }
        XCTAssertEqual(session.submit(), .incorrect, "The same total with the wrong structure must fail.")

        for token in session.selectedTokenIDs { session.remove(token) }
        for token in tens.prefix(3) { session.add(token.id) }
        for token in ones.prefix(17) { session.add(token.id) }
        XCTAssertEqual(session.submit(), .incorrect)

        for token in session.selectedTokenIDs { session.remove(token) }
        for token in tens.prefix(4) { session.add(token.id) }
        for token in ones.prefix(7) { session.add(token.id) }
        XCTAssertEqual(session.submit(), .correct)
    }

    func testEqualGroupsRejectsWrongGroupSize() throws {
        let correctUnit = MathStructuredConstructionUnit.equalGroup(itemsPerGroup: 4)
        let wrongUnit = MathStructuredConstructionUnit.equalGroup(itemsPerGroup: 3)
        let tokens = (0..<5).map {
            MathStructuredConstructionToken(id: .init(rawValue: "four.\($0)"), unit: correctUnit)
        } + (0..<3).map {
            MathStructuredConstructionToken(id: .init(rawValue: "three.\($0)"), unit: wrongUnit)
        }
        let prompt = numeral(12)
        let round = try XCTUnwrap(MathStructuredConstructionRound(
            id: ChallengeID(rawValue: "groups.3x4"),
            targetValue: 12,
            expectedUnitCounts: [correctUnit: 3],
            availableTokens: tokens,
            prompt: prompt,
            spokenPrompt: "12",
            mathLevelID: .m5,
            skillID: MathSkillIDs.equalGroups
        ))
        var session = try XCTUnwrap(MathStructuredConstructionSession(rounds: [round]))
        for token in tokens.suffix(3) { session.add(token.id) }
        XCTAssertEqual(session.submit(), .incorrect)
        for token in session.selectedTokenIDs { session.remove(token) }
        for token in tokens.prefix(3) { session.add(token.id) }
        XCTAssertEqual(session.submit(), .correct)
    }

    private func makePlaceValueRound() -> MathStructuredConstructionRound? {
        let tens = (0..<5).map {
            MathStructuredConstructionToken(id: .init(rawValue: "ten.\($0)"), unit: .placeValue(10))
        }
        let ones = (0..<17).map {
            MathStructuredConstructionToken(id: .init(rawValue: "one.\($0)"), unit: .placeValue(1))
        }
        return MathStructuredConstructionRound(
            id: ChallengeID(rawValue: "place.47"),
            targetValue: 47,
            expectedUnitCounts: [.placeValue(10): 4, .placeValue(1): 7],
            availableTokens: tens + ones,
            prompt: numeral(47),
            spokenPrompt: "47",
            mathLevelID: .m4,
            skillID: MathSkillIDs.placeValue
        )
    }

    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(
            value: value,
            structureID: RepresentationStructureID(rawValue: "test.numeral.\(value)")
        )))
    }
}
