import Foundation
import XCTest
@testable import MinikPlus

final class MathM2ContentProviderTests: XCTestCase {
    private let provider = MathM2ContentProvider()

    func testCanonicalFactsStayWithinM2BoundsAndCoverEveryCategory() {
        XCTAssertEqual(Set(MathM2ContentProvider.facts.map(\.category)), Set(MathM2FactCategory.allCases))
        for fact in MathM2ContentProvider.facts {
            XCTAssertTrue((0...10).contains(fact.result))
            if fact.operation == .subtraction {
                XCTAssertGreaterThanOrEqual(fact.left, fact.right)
            }
            if fact.category == .complementToTen {
                XCTAssertEqual(fact.result, 10)
            }
        }
    }

    func testSixChallengeSequenceIncludesCompositionAdditionSubtractionAndComplement() {
        XCTAssertEqual(
            Set(provider.balancedFacts(count: 6).map(\.category)),
            Set(MathM2FactCategory.allCases)
        )
    }

    func testStudyAndMatchingContentUseOperationRelationships() throws {
        XCTAssertEqual(provider.studyCards().count, 10)
        let sets = provider.equivalenceSets()
        XCTAssertEqual(sets.count, 4)
        for set in sets {
            XCTAssertTrue(set.representations.contains { representation in
                if case .math(.arithmeticExpression(_)) = representation { return true }
                return false
            })
        }
    }

    func testBothChoiceDirectionsHaveFourUniqueAnswersAndOneCorrect() throws {
        for fact in provider.balancedFacts(count: 6) {
            for direction in [MathM2ChoiceDirection.operationToAnswer, .answerToOperation] {
                let challenge = try XCTUnwrap(provider.choiceChallenge(fact: fact, direction: direction))
                XCTAssertEqual(challenge.choices.count, 4)
                XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, 4)
                XCTAssertEqual(
                    challenge.choices.filter { $0.semanticValue == .integer(fact.result) }.count,
                    1
                )
            }
        }
    }

    func testBuildNumberConstructsResultAndBuildMathConstructsEquation() throws {
        let fact = try XCTUnwrap(provider.balancedFacts(count: 1).first)
        let number = try XCTUnwrap(provider.buildNumberChallenge(fact: fact))
        XCTAssertEqual(number.expectedTokenSequence.count, 1)
        guard case .math(.arithmeticExpression(_)) = number.prompt.representations.first else {
            return XCTFail("Build Number must be prompted by an M2 operation.")
        }

        let equation = try XCTUnwrap(provider.buildEquationChallenge(fact: fact))
        XCTAssertEqual(equation.expectedTokenSequence.count, 5)
        XCTAssertGreaterThan(equation.availableTokens.count, equation.expectedTokenSequence.count)
    }

    func testCountConstructionUsesOperationPromptSupportsZeroAndHasExtraObjects() throws {
        let zeroFact = try XCTUnwrap(MathM2ContentProvider.facts.first { $0.result == 0 })
        let round = try XCTUnwrap(provider.countRound(fact: zeroFact))
        XCTAssertEqual(round.target, 0)
        XCTAssertEqual(round.mathLevelID, .m2)
        XCTAssertGreaterThan(round.availableTokenIDs.count, round.target)
        guard case .math(.arithmeticExpression(_)) = round.prompt else {
            return XCTFail("M2 count construction must show an operation prompt.")
        }
    }

    func testSoccerUsesSixUniqueAnswerBallsAndOperationTargets() throws {
        let round = try XCTUnwrap(provider.soccerRound())
        XCTAssertEqual(round.answerBalls.count, 6)
        XCTAssertEqual(Set(round.answerBalls.map(\.semanticValue)).count, 6)
        XCTAssertEqual(round.challengeTargets.count, 6)
        for target in round.challengeTargets {
            guard case .math(.arithmeticExpression(_)) = target.challenge.prompt.representations.first else {
                return XCTFail("M2 Soccer must use operation prompts.")
            }
        }
    }

    func testProviderGenerationActuallyConsultsFitGate() throws {
        let probe = FitProbe()
        let rejecting = MathM2ContentProvider(fitGate: MathContentFitGate { _, _ in
            probe.record()
            return false
        })
        let fact = try XCTUnwrap(MathM2ContentProvider.facts.first)

        XCTAssertNil(rejecting.countRound(fact: fact))
        XCTAssertEqual(probe.count, MathPresentationFitPolicy.candidateAttemptLimit)
        XCTAssertNil(rejecting.choiceChallenge(fact: fact, direction: .operationToAnswer))
        XCTAssertNil(rejecting.buildNumberChallenge(fact: fact))
        XCTAssertNil(rejecting.buildEquationChallenge(fact: fact))
        XCTAssertNil(rejecting.soccerRound())
    }
}

private final class FitProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func record() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
