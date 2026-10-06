import XCTest
@testable import MinikPlus

final class MathDistractorEngineTests: XCTestCase {
    func testGeneratesFourUniqueChoicesWithCorrectAnswerExactlyOnce() throws {
        let request = try XCTUnwrap(MathDistractorRequest(
            correctAnswer: .integer(10),
            permittedDomain: Set((0...20).map(ExactNumericValue.integer)),
            strategies: [
                .offByOne,
                .nearby(offsets: [-2, 2]),
                .wrongPlaceValue(candidates: [.integer(1)])
            ]
        ))
        var generator = SeededMathRandomNumberGenerator(seed: 42)
        let choices = try XCTUnwrap(try? MathDistractorEngine().generate(for: request, using: &generator).get())
        XCTAssertEqual(choices.count, 4)
        XCTAssertEqual(Set(choices.map(\.normalizedRational)).count, 4)
        XCTAssertEqual(choices.filter { $0.normalizedRational == request.correctAnswer.normalizedRational }.count, 1)
    }

    func testSameSeedAndPolicyProduceSameOrder() throws {
        let request = try makeRequest()
        var firstGenerator = SeededMathRandomNumberGenerator(seed: 2026)
        var secondGenerator = SeededMathRandomNumberGenerator(seed: 2026)
        let first = try MathDistractorEngine().generate(for: request, using: &firstGenerator).get()
        let second = try MathDistractorEngine().generate(for: request, using: &secondGenerator).get()
        XCTAssertEqual(first, second)
    }

    func testDuplicateAndNumericallyEquivalentCandidatesCollapse() throws {
        let one = try XCTUnwrap(Rational(numerator: 2, denominator: 2))
        let request = try XCTUnwrap(MathDistractorRequest(
            correctAnswer: .integer(2),
            permittedDomain: [.integer(1), .integer(2), .integer(3), .integer(4)],
            strategies: [
                .operandConfusion(candidates: [.integer(1), .rational(one), .integer(1)]),
                .commonArithmeticMistake(candidates: [.integer(3), .integer(4)])
            ]
        ))
        var generator = SeededMathRandomNumberGenerator(seed: 7)
        let choices = try MathDistractorEngine().generate(for: request, using: &generator).get()
        XCTAssertEqual(Set(choices.map(\.normalizedRational)).count, 4)
    }

    func testReturnsFailureWhenPolicyCannotSupplyEnoughChoices() throws {
        let request = try XCTUnwrap(MathDistractorRequest(
            correctAnswer: .integer(0),
            permittedDomain: [.integer(0), .integer(1)],
            strategies: [.offByOne, .nearby(offsets: [-1, 1, 1])]
        ))
        var generator = SeededMathRandomNumberGenerator(seed: 1)
        XCTAssertEqual(
            MathDistractorEngine().generate(for: request, using: &generator),
            .failure(.insufficientUniqueCandidates(required: 3, available: 1))
        )
    }

    func testEdgeArithmeticDoesNotOverflowOrEscapePermittedDomain() throws {
        let request = try XCTUnwrap(MathDistractorRequest(
            correctAnswer: .integer(Int.max),
            choiceCount: 2,
            permittedDomain: [.integer(Int.max), .integer(Int.max - 1)],
            strategies: [.offByOne, .nearby(offsets: [1, -1])]
        ))
        var generator = SeededMathRandomNumberGenerator(seed: 9)
        let choices = try MathDistractorEngine().generate(for: request, using: &generator).get()
        XCTAssertEqual(Set(choices), [.integer(Int.max), .integer(Int.max - 1)])
    }

    func testCallerMustExplicitlyPermitCorrectAnswerAndStrategies() {
        XCTAssertNil(MathDistractorRequest(
            correctAnswer: .integer(4),
            permittedDomain: [.integer(1), .integer(2), .integer(3)],
            strategies: [.offByOne]
        ))
        XCTAssertNil(MathDistractorRequest(
            correctAnswer: .integer(4),
            permittedDomain: [.integer(4), .integer(5)],
            strategies: []
        ))
    }

    private func makeRequest() throws -> MathDistractorRequest {
        try XCTUnwrap(MathDistractorRequest(
            correctAnswer: .integer(8),
            permittedDomain: Set((0...16).map(ExactNumericValue.integer)),
            strategies: [
                .offByOne,
                .nearby(offsets: [-3, -2, 2, 3]),
                .inverseOperationResult(.integer(4)),
                .symbolicallyNearby(candidates: [.integer(6), .integer(9)])
            ]
        ))
    }
}
