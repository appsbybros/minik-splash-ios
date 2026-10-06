import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../cross/CrossTestSupport.kt and CrossEngineSupport.kt (MinikCrossPong 828c6fc).
// Shared by every cross test file: do not redeclare these names elsewhere in the test target.

func assertNear(_ expected: MPPoint, _ actual: MPPoint, _ eps: Double = 1e-9, _ message: String = "",
                file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(expected.x, actual.x, accuracy: eps, "\(message) x", file: file, line: line)
    XCTAssertEqual(expected.y, actual.y, accuracy: eps, "\(message) y", file: file, line: line)
}

/// Kotlin `samples(count, seed, span)`: the same points as `kotlin.random.Random(seed)` draws.
func samples(_ count: Int, seed: Int32, span: Double = 1.5) -> [MPPoint] {
    var random = MPKotlinRandom(intSeed: seed)
    var points: [MPPoint] = []
    for _ in 0..<count {
        let x = random.nextDouble(-span, span)
        let y = random.nextDouble(-span, span)
        points.append(MPPoint(x, y))
    }
    return points
}

extension CrossBall {
    /// Steps the live ball in engine substeps until its first event: the event and the steps taken.
    func firstEvent(_ seconds: Double = 6) -> (event: CrossBallEvent?, steps: Int) {
        var steps = 0
        while Double(steps) < seconds * 120 {
            steps += 1
            if let event = step(CrossBall.substep) { return (event, steps) }
        }
        return (nil, steps)
    }
}

func houseSeat(_ index: Int, _ character: String) -> CrossSeat {
    CrossSeat(index: index, kind: .house, id: "bot_\(character)", name: character, bot: MPRoster.find(character)?.profile,
              characterId: character)
}

func humanSeat(_ index: Int, _ kind: CrossSeatKind = .local) -> CrossSeat {
    CrossSeat(index: index, kind: kind, id: "uid\(index)", name: "Player \(index)")
}

/// Seat 0 is the local human, the house characters follow.
func localTable(_ characters: String...) -> [CrossSeat] {
    var seats = [humanSeat(0)]
    for (i, character) in characters.enumerated() { seats.append(houseSeat(i + 1, character)) }
    return seats
}

func houseTable(_ characters: String...) -> [CrossSeat] {
    var seats: [CrossSeat] = []
    for (i, character) in characters.enumerated() { seats.append(houseSeat(i, character)) }
    return seats
}

struct CrossContactInfo: Equatable {
    var seat: Int
    var id: Int
    var point: MPPoint
    var height: Double
}

struct CrossSwingInfo: Equatable {
    var seat: Int
    var id: Int
}

extension Array where Element == CrossEvent {
    func contacts(_ seat: Int) -> [CrossContactInfo] {
        var found: [CrossContactInfo] = []
        for event in self {
            if case let .contact(s, id, point, height) = event, s == seat {
                found.append(CrossContactInfo(seat: s, id: id, point: point, height: height))
            }
        }
        return found
    }

    func swings(_ seat: Int) -> [CrossSwingInfo] {
        var found: [CrossSwingInfo] = []
        for event in self {
            if case let .swing(s, id) = event, s == seat { found.append(CrossSwingInfo(seat: s, id: id)) }
        }
        return found
    }

    func rallies() -> [CrossRallyOutcome] {
        var found: [CrossRallyOutcome] = []
        for event in self {
            if case let .rally(outcome) = event { found.append(outcome) }
        }
        return found
    }
}

extension CrossEngine {
    /// Advances in engine substeps, collecting drained events (appended to `events`), until `until` holds or `seconds` pass.
    @discardableResult
    func play(_ seconds: Double, into events: [CrossEvent] = [], until: () -> Bool = { false }) -> [CrossEvent] {
        var collected = events
        var steps = 0
        while Double(steps) < seconds * 120 && !until() {
            steps += 1
            advance(CrossEngine.step)
            collected += drainEvents()
        }
        return collected
    }

    /// Restores a rally in which `from` has just sent a ball that bounced legally at (`u`, `v`) in `to`'s territory: the
    /// referee awaits `to`'s return. Returns the ball right after that bounce.
    @discardableResult
    func incoming(from: Int, to: Int, u: Double = 0, v: Double = 0.8, pace: Double = 0.88, scores: [Int]? = nil) -> CrossBallState {
        let g = geometry
        let start = g.home(from)
        let launch = CrossShots.targeted(g, physics, from: start, height: 0.1, target: g.fromLocal(to, u, v), pace: pace)
        let probe = CrossBall(g, tuning: physics,
                              initial: CrossBallState(position: start, height: 0.1, velocity: launch.velocity, lift: launch.lift))
        var event: CrossBallEvent? = nil
        var guardSteps = 0
        while event == nil && guardSteps < 2_000 {
            event = probe.step(CrossBall.substep)
            guardSteps += 1
        }
        var bouncedInTarget = false
        if let found = event, case let .bounce(_, owner) = found, owner == to { bouncedInTarget = true }
        if !bouncedInTarget { XCTFail("Setup ball did not bounce in \(to): \(String(describing: event))") }
        var base = exportState()
        base.referee.phase = .receivable
        base.referee.striker = from
        base.referee.receiver = to
        base.referee.hits = 1
        if let scores { base.referee.scores = scores }
        base.ball = probe.state
        base.pointDelay = nil
        base.serveDelay = nil
        base.strike = nil
        do { try restoreState(base) } catch { XCTFail("incoming restore failed: \(error)") }
        discardEvents()
        return probe.state
    }

    /// Restores a rally in which `from` has just hit a ball that will bounce at (`u`, `v`) in `to`'s territory.
    @discardableResult
    func approaching(from: Int, to: Int, u: Double = 0, v: Double = 0.8, pace: Double = 0.88) -> CrossBallState {
        let start = geometry.home(from)
        let launch = CrossShots.targeted(geometry, physics, from: start, height: 0.1, target: geometry.fromLocal(to, u, v), pace: pace)
        let ball = CrossBallState(position: start, height: 0.1, velocity: launch.velocity, lift: launch.lift)
        var base = exportState()
        base.referee.phase = .toReceiver
        base.referee.striker = from
        base.referee.receiver = nil
        base.referee.hits = 1
        base.ball = ball
        base.pointDelay = nil
        base.serveDelay = nil
        base.strike = nil
        do { try restoreState(base) } catch { XCTFail("approaching restore failed: \(error)") }
        discardEvents()
        return ball
    }

    /// Where the live ball will be after `ticks` substeps (a copy; the live ball does not move).
    func ballAfter(_ ticks: Int) -> MPPoint {
        let probe = CrossBall(geometry, tuning: physics, initial: ballState)
        for _ in 0..<max(0, ticks) { probe.step(CrossBall.substep) }
        return probe.position
    }

    /// Steps until the ball is inside `seat`'s strike zone at depth >= `depth`.
    @discardableResult
    func waitForBall(_ seat: Int, depth: Double = 0.86) -> [CrossEvent] {
        play(3) { self.geometry.inStrikeZone(seat, self.ballPosition) && self.geometry.toLocal(seat, self.ballPosition).v >= depth }
    }
}

/// A scripted Beginner human: a tap serve with a random aim; follows its receivable ball with the paddle (drag-aiming left,
/// ahead or right) and now and then deliberately keeps the paddle away and misses.
final class BeginnerScript {
    private static let aims: [Double] = [-70, -20, 0, 20, 70]
    private let engine: CrossEngine
    private var random: MPKotlinRandom
    private let missRate: Double
    private var touching = false
    private var skipping = false
    private var aim = 0.0
    private(set) var serves = 0

    init(_ engine: CrossEngine, seed: Int32, missRate: Double = 0.12) {
        self.engine = engine
        self.random = MPKotlinRandom(intSeed: seed)
        self.missRate = missRate
    }

    func step() {
        let e = engine
        let g = e.geometry
        guard let local = e.localSeat else { return }
        if e.status == .yourServe && !touching {
            let u = random.nextDouble(-0.25, 0.25)
            let v = random.nextDouble(0.65, 0.9)
            e.touch(g.fromLocal(local, u, v), down: true)
            let swipe = random.element(BeginnerScript.aims)
            e.touch(g.fromLocal(local, 0, 0.8), drag: MPPoint(swipe, 0), down: false)
            e.endTouch()
            serves += 1
            return
        }
        if e.referee.phase == .receivable && e.referee.receiver == local {
            if !touching {
                touching = true
                skipping = random.nextDouble() < missRate
                aim = random.element(BeginnerScript.aims)
                e.touch(g.fromLocal(local, 0, CrossGeometry.homeDepth), down: true)
            }
            let ball = g.toLocal(local, e.ballPosition)
            // A deliberate miss keeps the paddle on the far side of the arm.
            let at = skipping ? g.fromLocal(local, ball.u > 0 ? -0.6 : 0.6, CrossGeometry.homeDepth) : e.ballPosition
            if g.inStrikeZone(local, at) { e.touch(at, drag: MPPoint(aim, 0), down: false) }
        } else if touching {
            touching = false
            e.endTouch()
        }
    }
}
