import XCTest
@testable import MinikPlus

final class MathPresentationFitTests: XCTestCase {
    func testNormalAndReducedFontDecisionsRespectMinimumReadableSize() {
        XCTAssertEqual(decision(for: "100", width: 120), .normal)
        guard case .reducedFont(let points) = decision(for: "100000", width: 120) else {
            return XCTFail("Expected a readable reduced-font decision.")
        }
        XCTAssertGreaterThanOrEqual(points, MathPresentationFitPolicy.minimumReadablePointSize)
    }

    func testLongValueUsesLastResortMultilineBeforeFailing() {
        let constraints = MathPresentationConstraints(
            availableWidth: 80,
            maximumExpandedWidth: 120,
            preferredFontSize: 40
        )
        XCTAssertEqual(
            MathPresentationFitPolicy.decision(for: "123456789012345678", constraints: constraints),
            .multiline(points: MathPresentationFitPolicy.minimumReadablePointSize)
        )
    }

    func testUnfitValueReturnsFailureInsteadOfTruncation() {
        let constraints = MathPresentationConstraints(
            availableWidth: 60,
            maximumExpandedWidth: 80,
            preferredFontSize: 40
        )
        XCTAssertEqual(
            MathPresentationFitPolicy.decision(
                for: String(repeating: "8", count: 40),
                constraints: constraints
            ),
            .unfit
        )
    }

    func testCandidateGenerationStopsAtTwelveAttempts() {
        var calls = 0
        let result: MathPresentationCandidateResult<String> =
            MathPresentationFitPolicy.resolvedCandidate(
                generate: {
                    calls += 1
                    return "too-long"
                },
                isReadable: { _ in false }
            )

        XCTAssertEqual(calls, 12)
        guard case .unavailable = result else {
            return XCTFail("Expected a bounded failure result.")
        }
    }

    func testCompactFallbackRunsOnlyAfterBoundedCandidatesFail() {
        var calls = 0
        let result: MathPresentationCandidateResult<String> =
            MathPresentationFitPolicy.resolvedCandidate(
                generate: {
                    calls += 1
                    return "wide representation"
                },
                isReadable: { $0 == "1/2" },
                compactFallback: { "1/2" }
            )

        XCTAssertEqual(calls, 12)
        guard case .compactFallback(let value) = result else {
            return XCTFail("Expected compact fallback.")
        }
        XCTAssertEqual(value, "1/2")
    }

    func testSoccerNeverCollapsesBelowFourAnswers() {
        XCTAssertEqual(MathPresentationFitPolicy.minimumSoccerAnswerPool, 4)
    }

    private func decision(for text: String, width: Double) -> MathPresentationDecision {
        MathPresentationFitPolicy.decision(
            for: text,
            constraints: MathPresentationConstraints(
                availableWidth: width,
                maximumExpandedWidth: 240,
                preferredFontSize: 40
            )
        )
    }
}
