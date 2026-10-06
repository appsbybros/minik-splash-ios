import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../ClassicTiebreakTest.kt (MinikCrossPong 828c6fc): a two-player tournament tie-break is the classic
// game decided by its first point, whatever the difficulty.
// Kotlin `Match(difficulty, target, suddenDeath)` is iOS `MPEngine(level:target:suddenDeath:)` with its `MPScore`; a Kotlin
// `match.award(player)` is one point the engine itself resolves (a ball leaving the table off the other side). Kotlin
// Difficulty STARTER/EASY/MEDIUM/HARD/BEGINNER are MPLevel .easy/.medium/.hard/.superHard/.beginner (same ordinals).
final class ClassicTiebreakTests: XCTestCase {
    /// A flight struck by the side opposite `side` that leaves the table on the next substep, so the engine awards `side`.
    private func leavingFlight(_ e: MPEngine, awarding side: MPSide) -> MPFlight {
        let serve = MPShots.serve(MPPoint(0.5, 0.87), side: .child, tuning: e.tuning)
        var flight = MPFlight(serve, e.tuning)
        let striker = side.other
        flight.serve = nil
        flight.striker = striker
        flight.receiver = false
        flight.resolved = false
        flight.spin = 0
        flight.height = 0.3
        flight.lift = 0
        if striker == .child {
            flight.position = MPPoint(0.5, 0.004)
            flight.velocity = MPPoint(0, -1)
        } else {
            flight.position = MPPoint(0.5, 0.996)
            flight.velocity = MPPoint(0, 1)
        }
        return flight
    }

    /// Kotlin `match.award(side)`: one point for `side`, resolved by the engine's own scoring; false when nothing was awarded.
    @discardableResult
    private func awardPoint(_ e: MPEngine, to side: MPSide) -> Bool {
        let before = e.score.rallies
        var state = e.snapshot()
        state.flight = leavingFlight(e, awarding: side)
        state.pointDelay = nil
        state.serveDelay = nil
        state.pendingFault = nil
        e.restore(state)
        var steps = 0
        while e.score.rallies == before && steps < 30 {
            steps += 1
            e.advance(1.0 / 120)
        }
        return e.score.rallies > before
    }

    // Kotlin: theFirstPointDecidesEvenWhereATwoPointLeadIsNormallyNeeded
    func testTheFirstPointDecidesEvenWhereATwoPointLeadIsNormallyNeeded() {
        for d in MPLevel.allCases {
            let e = MPEngine(level: d, target: 1, seed: 7, suddenDeath: true)
            XCTAssertEqual(1, e.target)
            XCTAssertTrue(awardPoint(e, to: .minik), "difficulty \(d)")
            XCTAssertEqual(MPSide.minik, e.score.winner, "difficulty \(d)")
            XCTAssertFalse(awardPoint(e, to: .child), "difficulty \(d)")
        }
    }

    // Kotlin: ordinaryMatchesKeepTheirTargetsAndDeuce
    func testOrdinaryMatchesKeepTheirTargetsAndDeuce() {
        let e = MPEngine(level: .superHard, target: 1, seed: 7)
        XCTAssertEqual(7, e.target) // an unsupported target still falls back to 7
        for _ in 0..<6 {
            awardPoint(e, to: .child)
            awardPoint(e, to: .minik)
        }
        awardPoint(e, to: .child)
        XCTAssertNil(e.score.winner, "7:6 needs a two-point lead")
        awardPoint(e, to: .child)
        XCTAssertEqual(MPSide.child, e.score.winner)
    }

    // Kotlin: theEngineCarriesTheTiebreakThroughARestart
    func testTheEngineCarriesTheTiebreakThroughARestart() {
        let e = MPEngine(level: .hard, target: 5, seed: 7, suddenDeath: true)
        XCTAssertEqual(1, e.target)
        // iOS MPEngine has no restart(): its target is a constant; restoring the opening state is the closest restart.
        let opening = e.snapshot()
        awardPoint(e, to: .minik)
        e.restore(opening)
        XCTAssertEqual(1, e.target)
        XCTAssertTrue(e.suddenDeath)
    }
}
