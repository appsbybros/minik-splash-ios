import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../ClassicFixesTest.kt (MinikCrossPong 828c6fc): regressions for two defects found in the original
// Modern app. Kotlin `ModernEngine` is iOS `MPEngine`; Kotlin `Random(seed)` is MPEngine's own seeded MPRandom (a different
// generator, so individual rallies differ from Android's; the assertions are bounds). Kotlin `lastResolution` is read from the
// engine's `.point` events. Kotlin Difficulty STARTER/BEGINNER are MPLevel .easy/.beginner; a Kotlin `match.award(player)` is
// one point the engine itself resolves (a ball leaving the table off the other side).
final class ClassicFixesTests: XCTestCase {
    /// One engine substep; records the point's resolution like Kotlin `lastResolution`.
    private func tick(_ e: MPEngine, _ last: inout MPResolution?) {
        e.advance(1.0 / 120)
        for event in e.drainEvents() {
            if case let .point(resolution, _, _) = event { last = resolution }
        }
    }

    /// A flight struck by the side opposite `side` that leaves the table on the next substep, so the engine awards `side`.
    private func outgoingFlight(_ e: MPEngine, awarding side: MPSide) -> MPFlight {
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

    /// Kotlin `match.award(side)` on the engine's match: one point for `side` through the engine's own scoring.
    @discardableResult
    private func awardRoomPoint(_ e: MPEngine, to side: MPSide) -> Bool {
        let before = e.score.rallies
        var state = e.snapshot()
        state.flight = outgoingFlight(e, awarding: side)
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

    // Kotlin: beginnerPositioningBeforeTheBounceIsNotAim
    func testBeginnerPositioningBeforeTheBounceIsNotAim() {
        var outs = 0
        for seed in 1...20 {
            let e = MPEngine(level: .beginner, target: 7, houseControls: true, seed: UInt64(seed))
            var last: MPResolution? = nil
            // Wait for Minik's serve to approach the child's side.
            var steps = 0
            while e.flight == nil && steps < 600 {
                steps += 1
                tick(e, &last)
            }
            guard let f = e.flight else { continue }
            // Finger down on the resting paddle, then a long sideways drag onto the ball's line before it bounces.
            e.touch(MPPoint(0.5, 0.87), down: true)
            e.touch(MPPoint(f.position.x.mpClamp(0.1, 0.9), 0.87), movement: .zero, down: false)
            steps = 0
            while last == nil && e.flight?.striker != .child && steps < 900 {
                steps += 1
                tick(e, &last)
            }
            if e.flight?.striker == .child {
                steps = 0
                while last == nil && e.flight?.receiver != true && steps < 900 {
                    steps += 1
                    tick(e, &last)
                }
                if let fault = last?.fault, fault == .leftTable || fault == .firstBounceOut { outs += 1 }
            }
        }
        XCTAssertTrue(outs <= 2, "positioning drags made \(outs) automatic returns go out")
    }

    // Kotlin: roomFixturesAgainstHousePlayersAlternateTheServe
    func testRoomFixturesAgainstHousePlayersAlternateTheServe() throws {
        let bot = try XCTUnwrap(MPRoster.find("kyra")).profile
        let room = MPEngine(level: .easy, target: 7, bot: bot, houseControls: true, seed: 3, alternateServe: true)
        var servers: [MPSide] = [room.score.server]
        for i in 0..<4 {
            awardRoomPoint(room, to: i % 2 == 0 ? .child : .minik)
            servers.append(room.score.server)
        }
        XCTAssertTrue(servers.contains(.child), "the human must serve in a room fixture: \(servers)")
        XCTAssertTrue(servers.contains(.minik))
        let single = MPEngine(level: .easy, target: 7, houseControls: true, seed: 3)
        var classic: [MPSide] = [single.score.server]
        for _ in 0..<4 {
            awardRoomPoint(single, to: .child)
            classic.append(single.score.server)
        }
        XCTAssertTrue(classic.allSatisfy { $0 == .minik }, "single-player Starter keeps Minik serving: \(classic)")
    }
}
