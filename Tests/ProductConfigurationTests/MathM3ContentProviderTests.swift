import Foundation
import XCTest
@testable import MinikPlus

final class MathM3ContentProviderTests: XCTestCase {
    private let provider = MathM3ContentProvider()

    func testCanonicalRelationshipsStayWithinTwentyAndCoverAllCategories() {
        XCTAssertEqual(
            Set(MathM3ContentProvider.relationships.map(\.category)),
            Set(MathM3RelationshipCategory.allCases)
        )
        for relationship in MathM3ContentProvider.relationships {
            XCTAssertTrue((0...20).contains(relationship.answer))
            if relationship.operation == .subtraction {
                XCTAssertGreaterThanOrEqual(relationship.left, relationship.right)
            }
        }
    }

    func testStudyAndMatchingContentUseMissingAndEquivalentRelationships() throws {
        XCTAssertEqual(provider.studyCards().count, 10)
        let sets = provider.equivalenceSets()
        XCTAssertEqual(sets.count, 4)
        XCTAssertTrue(sets.contains { set in
            set.representations.contains {
                if case .math(.missingValueExpression(_)) = $0 { return true }
                return false
            }
        })
        XCTAssertTrue(sets.contains { set in
            set.representations.allSatisfy {
                if case .math(.arithmeticExpression(_)) = $0 { return true }
                return false
            }
        })
    }

    func testBothChoiceDirectionsHaveFourUniqueSemanticAnswers() throws {
        for relationship in provider.balancedRelationships(count: 6) {
            for direction in [MathM3ChoiceDirection.relationshipToAnswer, .answerToRelationship] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(
                    relationship: relationship,
                    direction: direction
                ))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, 4)
                XCTAssertEqual(
                    challenge.choices.filter { $0.semanticValue == .integer(relationship.answer) }.count,
                    1
                )
            }
        }
    }

    func testBuildNumberUsesDistinctPhysicalDigitIDsAndBuildMathUsesEquationGrammar() throws {
        let repeatedDigit = try XCTUnwrap(MathM3ContentProvider.relationships.first { $0.answer == 11 })
        let number = try XCTUnwrap(provider.buildNumberChallenge(relationship: repeatedDigit))
        XCTAssertEqual(number.expectedTokenSequence.count, 2)
        XCTAssertEqual(Set(number.expectedTokenSequence).count, 2)
        XCTAssertGreaterThan(number.availableTokens.count, number.expectedTokenSequence.count)

        let equation = try XCTUnwrap(provider.buildEquationChallenge(relationship: repeatedDigit))
        XCTAssertEqual(equation.expectedTokenSequence.count, 5)
        XCTAssertGreaterThan(equation.availableTokens.count, equation.expectedTokenSequence.count)
    }

    func testCountAndSoccerCarryM3Semantics() throws {
        let relationship = try XCTUnwrap(MathM3ContentProvider.relationships.first)
        let count = try XCTUnwrap(provider.countRound(relationship: relationship))
        XCTAssertEqual(count.mathLevelID, .m3)
        XCTAssertGreaterThan(count.availableTokenIDs.count, count.target)
        guard case .math(.missingValueExpression(_)) = count.prompt else {
            return XCTFail("M3 count construction must use a relationship prompt.")
        }

        let soccer = try XCTUnwrap(provider.soccerRound())
        XCTAssertEqual(soccer.answerBalls.count, 6)
        XCTAssertEqual(Set(soccer.answerBalls.map(\.semanticValue)).count, 6)
        XCTAssertEqual(soccer.challengeTargets.count, 6)
    }

    func testZeroResultCanBeConstructedWithoutAnySelectedObjects() throws {
        let zero = try XCTUnwrap(MathM3ContentProvider.relationships.first { $0.answer == 0 })
        let round = try XCTUnwrap(provider.countRound(relationship: zero))
        XCTAssertEqual(round.target, 0)
        XCTAssertFalse(round.availableTokenIDs.isEmpty)
    }

    func testEveryBuildEquationRetainsItsTypedRelationshipAndOrderedSolution() throws {
        XCTAssertEqual(MathM3ContentProvider.relationships.count, 16)
        XCTAssertEqual(Set(MathM3ContentProvider.relationships.map(\.missingPosition)),
                       Set([MathMissingPosition.leftOperand, .rightOperand, .result]))
        for relationship in MathM3ContentProvider.relationships {
            let challenge = try XCTUnwrap(provider.buildEquationChallenge(relationship: relationship))
            XCTAssertEqual(challenge.prompt.representations.count, 1)
            guard case .math(.missingValueExpression(let prompt)) = try XCTUnwrap(challenge.prompt.representations.first) else {
                return XCTFail("Every M3 equation form must preserve a typed missing-value prompt: \(relationship.id)")
            }
            XCTAssertEqual(prompt.operation, relationship.operation, relationship.id)
            XCTAssertEqual(prompt.missingPosition, relationship.missingPosition, relationship.id)
            XCTAssertEqual(prompt.left, relationship.missingPosition == .leftOperand ? nil : .integer(relationship.left), relationship.id)
            XCTAssertEqual(prompt.right, relationship.missingPosition == .rightOperand ? nil : .integer(relationship.right), relationship.id)
            XCTAssertEqual(prompt.result, relationship.missingPosition == .result ? nil : .integer(relationship.result), relationship.id)

            let pieces = try challenge.expectedTokenSequence.map { tokenID -> String in
                let token = try XCTUnwrap(challenge.availableTokens.first { $0.id == tokenID })
                guard case .mathExpression(let expression) = token.representation else {
                    throw M3BuildTokenError.unexpectedRepresentation
                }
                return expression.expression
            }
            XCTAssertEqual(pieces, [String(relationship.left), relationship.operation.symbol, String(relationship.right), "=", String(relationship.result)], relationship.id)
            XCTAssertEqual(challenge.availableTokens.count, 6, relationship.id)
            XCTAssertEqual(Set(challenge.availableTokens.map(\.id)).count, 6, relationship.id)
            XCTAssertEqual(challenge.validationMode, .submitSequence)
        }
    }

    func testActualProviderGenerationUsesBoundedFitGate() throws {
        let probe = M3FitProbe()
        let rejecting = MathM3ContentProvider(fitGate: MathContentFitGate { _, _ in
            probe.record()
            return false
        })
        let relationship = try XCTUnwrap(MathM3ContentProvider.relationships.first)
        XCTAssertNil(rejecting.countRound(relationship: relationship))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
        XCTAssertNil(rejecting.buildNumberChallenge(relationship: relationship))
        XCTAssertNil(rejecting.choiceChallenge(relationship: relationship, direction: .relationshipToAnswer))
        XCTAssertNil(rejecting.soccerRound())
    }
}

private enum M3BuildTokenError: Error {
    case unexpectedRepresentation
}

private final class M3FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func record() {
        lock.lock(); value += 1; lock.unlock()
    }
}
