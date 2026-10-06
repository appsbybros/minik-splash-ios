import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../cross/CrossLinkTest.kt (MinikCrossPong 828c6fc). CrossLink (CROSS_DESIGN §8) over an in-memory
// repository: two or three humans and house players on real networked CrossEngines, every phone in the same world frame.
//
// Swift CrossLink calls the repository from main-actor Tasks (checkpoint, action, result), where Kotlin calls it
// synchronously. The fake backend therefore lets those Tasks run whenever it pumps (`pump` and `settle` yield the main actor
// until nothing moves), and a checkpoint write completes only when its delivery is pumped, exactly like Kotlin's `done`.

private struct LinkTestSetupError: Error {}

/// Kotlin test fields `ticks`, `offset`, `clock` and `sequences`, shared by every phone of one test.
private final class LinkTestTime {
    private(set) var ticks: Int64 = 0
    private var offset: Int64 = 0
    private(set) var clock: Int64 = 0
    private var sequences: [String: Int64] = [:]

    func next(_ uid: String) -> Int64 {
        let n = (sequences[uid] ?? 0) + 1
        sequences[uid] = n
        return n
    }

    func advance() {
        ticks += 1
        clock = ticks * 1000 / 120 + offset
    }

    /// Wall time passing without frames.
    func elapse(_ ms: Int64) {
        offset += ms
        clock += ms
    }
}

/// Kotlin `Net`, the backend: one checkpoint, a 16-slot action ring per sender and the room. With `manual` every listener
/// call and write completion waits for `pump`; `duplicate` repeats every action notification. Like RTDB, any change to the
/// action rings re-delivers all of them.
@MainActor private final class LinkTestNet {
    /// Main-actor turns without any queued delivery after which the backend counts as idle.
    static let turns = 6
    var session: MPSession
    let time: LinkTestTime
    var checkpoint: MPWire = [:]
    private var ring: [String: MPWire] = [:]
    /// Kotlin LinkedHashMap insertion order of the ring keys.
    private var ringOrder: [String] = []
    var written: [MPWire] = []
    private(set) var snapshots: [(token: Int, call: (MPWire) -> Void)] = []
    private(set) var actions: [(token: Int, call: (MPWire) -> Void)] = []
    var mutations: [String] = []
    var snapshotWrites = 0
    var deliveries = 0
    /// The stored checkpoint when the result was written.
    var atResult: MPWire?
    var manual = false
    var duplicate = false
    private var queue: [(tag: String, block: () -> Void)] = []
    private var tokens = 0

    init(_ session: MPSession, _ time: LinkTestTime) {
        self.session = session
        self.time = time
    }

    /// Kotlin `Net.match()`: the room's single fixture.
    var fixture: MPFixture { session.matches.values.first! }

    func later(_ tag: String, _ block: @escaping () -> Void) {
        if manual { queue.append((tag: tag, block: block)) } else { block() }
    }

    /// Runs queued deliveries (only `tag`'s when given), including those they cause, until none is left. The Tasks CrossLink
    /// starts (its repository calls) run in between.
    func pump(_ tag: String? = nil) async {
        var idle = 0
        while idle < LinkTestNet.turns {
            if let i = queue.firstIndex(where: { tag == nil || $0.tag == tag }) {
                let block = queue.remove(at: i).block
                block()
                idle = 0
            } else {
                await Task.yield()
                idle += 1
            }
        }
    }

    /// Lets the Tasks CrossLink started run (Kotlin makes those repository calls synchronously) without delivering anything.
    func settle() async {
        for _ in 0..<LinkTestNet.turns { await Task.yield() }
    }

    func store(_ key: String, _ w: MPWire) {
        if ring[key] == nil { ringOrder.append(key) }
        ring[key] = w
    }

    /// Every ring entry, by sequence (a stable sort, like Kotlin `sortedBy`).
    func all() -> [MPWire] {
        let entries = ringOrder.compactMap { ring[$0] }
        let order = entries.indices.sorted { (x: Int, y: Int) -> Bool in
            let left = MPCodec.number(entries[x], "sequence")
            let right = MPCodec.number(entries[y], "sequence")
            return left != right ? left < right : x < y
        }
        return order.map { entries[$0] }
    }

    func redeliver() {
        let work = all()
        for listener in actions {
            for w in work {
                deliveries += 1
                listener.call(w)
            }
        }
    }

    func listen(actions wantsActions: Bool, _ call: @escaping (MPWire) -> Void) -> Int {
        tokens += 1
        if wantsActions { actions.append((token: tokens, call: call)) } else { snapshots.append((token: tokens, call: call)) }
        return tokens
    }

    func listening(actions wantsActions: Bool, _ token: Int) -> Bool {
        let list = wantsActions ? actions : snapshots
        return list.contains(where: { $0.token == token })
    }

    func unlisten(actions wantsActions: Bool, _ token: Int) {
        if wantsActions { actions.removeAll(where: { $0.token == token }) } else { snapshots.removeAll(where: { $0.token == token }) }
    }

    /// Kotlin `List<Wire>.from(uid)` over `written`.
    func from(_ uid: String) -> [MPWire] { written.filter { CrossWire.text($0, "sender") == uid } }

    /// Kotlin `Net.connect(uid, on)`.
    func connect(_ uid: String, _ on: Bool) {
        if on { session.connections[uid] = ["court-\(uid)-\(time.ticks)": true] } else { session.connections[uid] = nil }
    }
}

/// Kotlin `Phone`: one person's repository on the shared backend.
@MainActor private final class LinkTestPhone: MPRepository {
    let uid: String
    let online = true
    private let net: LinkTestNet

    init(_ uid: String, _ net: LinkTestNet) {
        self.uid = uid
        self.net = net
    }

    func connect() async throws -> String { uid }
    func profile(index: Int, hebrew: Bool, avatar: Int, character: String) async throws -> MPIdentity {
        MPIdentity(id: uid, name: uid, avatar: avatar, characterId: character)
    }
    func get(_ kind: MPSessionKind, _ code: String) async throws -> MPSession? { net.session }
    func openRooms() async throws -> [(MPSessionKind, String)] { [] }
    func reserve(_ kind: MPSessionKind, _ code: String) async throws {}
    /// Kotlin: error("not needed").
    func create(_ session: MPSession) async throws -> MPSession { throw MPError.permission }
    func mutate(_ kind: MPSessionKind, _ code: String, _ change: @escaping (MPSession) throws -> MPSession) async throws -> MPSession {
        net.mutations.append(uid)
        net.atResult = net.checkpoint
        let next = try change(net.session)
        net.session = next
        return next
    }
    func observe(_ kind: MPSessionKind, _ code: String, _ changed: @escaping (Result<MPSession, Error>) -> Void) -> MPSubscription {
        MPSubscription()
    }
    func presence(_ kind: MPSessionKind, _ code: String) -> MPSubscription { MPSubscription() }
    func connection(_ changed: @escaping (Bool) -> Void) -> MPSubscription {
        changed(true)
        return MPSubscription()
    }
    func watchLive(_ id: String, actions: Bool, _ changed: @escaping (MPWire) -> Void, _ failed: @escaping (Error) -> Void) -> MPSubscription {
        let net = self.net
        if actions {
            let token = net.listen(actions: true, changed)
            net.later("action") {
                if net.listening(actions: true, token) {
                    for w in net.all() {
                        net.deliveries += 1
                        changed(w)
                    }
                }
            }
            return MPSubscription { net.unlisten(actions: true, token) }
        }
        let token = net.listen(actions: false, changed)
        net.later("snapshot") {
            if net.listening(actions: false, token) { changed(net.checkpoint) }
        }
        return MPSubscription { net.unlisten(actions: false, token) }
    }
    /// The write completes (Kotlin `done`) when its delivery is pumped.
    func checkpoint(_ id: String, _ value: MPWire) async throws {
        await withCheckedContinuation { (finished: CheckedContinuation<Void, Never>) in
            self.snapshot(id, value) { finished.resume() }
        }
    }
    func action(_ id: String, _ sequence: Int64, _ value: MPWire) async throws {
        send(id, sequence, value)
    }
    func leave(_ session: MPSession, delete: Bool) async throws {}
    func cleanup() async throws {}

    /// Kotlin `Phone.snapshot(id, body, done)`.
    func snapshot(_ id: String, _ body: MPWire, done: @escaping () -> Void = {}) {
        let net = self.net
        net.snapshotWrites += 1
        var stored = body
        stored["revision"] = MPCodec.number(net.checkpoint, "revision") + 1
        stored["authority"] = uid
        net.checkpoint = stored
        net.later("snapshot") {
            for listener in net.snapshots { listener.call(stored) }
            done()
        }
    }

    /// Kotlin `Phone.action(id, sequence, body)`: stored at once, delivered later; the write itself succeeds at once.
    func send(_ id: String, _ sequence: Int64, _ body: MPWire) {
        let net = self.net
        var w = body
        w["sender"] = uid
        w["sequence"] = sequence
        net.store("\(uid)/\(sequence % 16)", w)
        net.written.append(w)
        net.later("action") {
            let times = net.duplicate ? 2 : 1
            for _ in 0..<times { net.redeliver() }
        }
    }
}

/// Kotlin `failures::add`.
private final class LinkTestLog {
    var issues: [CrossLinkIssue] = []
}

/// Kotlin `Human`: a Beginner human like BeginnerScript, whose paddle also goes home between balls: two scripted humans
/// resting their paddles on the spot each other's straight return lands would otherwise trade identical automatic hits
/// forever.
private final class LinkTestHuman {
    private static let aims: [Double] = [-70, -20, 0, 20, 70]
    private let engine: CrossEngine
    private var random: MPKotlinRandom
    private let missRate: Double
    private var receiving = false
    private var skip = false
    private var aim = 0.0

    init(_ engine: CrossEngine, seed: Int32, missRate: Double) {
        self.engine = engine
        self.random = MPKotlinRandom(intSeed: seed)
        self.missRate = missRate
    }

    func step() {
        let e = engine
        let g = e.geometry
        guard let local = e.localSeat else { return }
        let home = g.fromLocal(local, 0, CrossGeometry.homeDepth)
        if e.status == .yourServe {
            let u = random.nextDouble(-0.25, 0.25)
            let v = random.nextDouble(0.65, 0.9)
            e.touch(g.fromLocal(local, u, v), down: true)
            let swipe = random.element(LinkTestHuman.aims)
            e.touch(g.fromLocal(local, 0, 0.8), drag: MPPoint(swipe, 0), down: false)
            e.endTouch()
            return
        }
        if e.referee.phase == .receivable && e.referee.receiver == local {
            if !receiving {
                receiving = true
                skip = random.nextDouble() < missRate
                aim = random.element(LinkTestHuman.aims)
                e.touch(home, down: true)
            }
            let ball = g.toLocal(local, e.ballPosition)
            // A deliberate miss keeps the paddle on the far side of the arm.
            let side: Double = ball.u > 0 ? -0.6 : 0.6
            let at = skip ? g.fromLocal(local, side, CrossGeometry.homeDepth) : e.ballPosition
            if g.inStrikeZone(local, at) { e.touch(at, drag: MPPoint(aim, 0), down: false) }
        } else if receiving {
            receiving = false
            e.touch(home, down: true)
            e.endTouch()
        }
    }
}

/// Kotlin `String.hashCode()` (UTF-16 code units, Int overflow): the scripted human's seed.
private func linkTestHashCode(_ text: String) -> Int32 {
    var h: Int32 = 0
    for unit in text.utf16 { h = h &* 31 &+ Int32(unit) }
    return h
}

private func linkTestIsContact(_ e: CrossEvent) -> Bool {
    if case .contact = e { return true }
    return false
}

private func linkTestIsReplay(_ e: CrossEvent) -> Bool {
    switch e {
    case .contact, .rally, .served: return true
    default: return false
    }
}

/// Kotlin `Client`: one phone, its engine built from the room, its link and a scripted Beginner human.
@MainActor private final class LinkTestClient {
    let uid: String
    let net: LinkTestNet
    let match: CrossMatch
    let link: CrossLink
    let seat: Int
    private let log: LinkTestLog
    private let script: LinkTestHuman
    var events: [CrossEvent] = []
    var engine: CrossEngine { match.engine }
    var failures: [CrossLinkIssue] { log.issues }

    init(_ uid: String, _ net: LinkTestNet, missRate: Double = 0.12) {
        let session = net.session
        let record = net.fixture
        let match = CrossMatch(roster: CrossLink.seats(session, record, uid: uid), control: .beginner, target: session.target, seed: record.seed,
                               networked: true, firstServer: CrossLink.firstServer(record))
        let log = LinkTestLog()
        let time = net.time
        let link = CrossLink(repo: LinkTestPhone(uid, net), session: session, record: record, match: match,
                             nextSequence: { time.next(uid) }, message: { log.issues.append($0) }, clock: { time.clock })
        link.active = true
        link.open()
        self.uid = uid
        self.net = net
        self.match = match
        self.log = log
        self.link = link
        seat = match.engine.localSeat ?? -1
        script = LinkTestHuman(match.engine, seed: linkTestHashCode(uid), missRate: missRate)
    }

    /// One frame as the activity runs it: room update, pause while not ready, input, engine, link.
    func tick() {
        link.update(net.session)
        match.paused = !link.ready
        script.step()
        match.advance(CrossEngine.step)
        let drained = match.drainEvents()
        events += drained
        link.frame(drained)
    }
}

final class CrossLinkTests: XCTestCase {
    private static let limit = 120 * 60 * 30

    /// A started friendly table seated in `order`: "a" hosts, "bot_<character>" are house players, the rest humans.
    private func table(_ order: [String]) throws -> MPSession {
        var s = MPSession(code: "ABC234", kind: .friendly, host: MPIdentity(id: "a", name: "Ann"), capacity: order.count, legs: 1,
                          winPoints: 3, difficulty: 4, target: 3, tableSize: order.count)
        for uid in order where uid != "a" {
            if uid.hasPrefix("bot_") {
                let character = String(uid.dropFirst(4))
                guard let house = MPRoster.find(character) else { throw LinkTestSetupError() }
                let bot = MPParticipant(identity: MPIdentity(id: uid, name: character, characterId: character), bot: house.profile)
                s = try MPRules.addBot(s, actor: "a", bot: bot)
            } else {
                s = try MPRules.join(s, MPIdentity(id: uid, name: uid.uppercased()))
            }
        }
        var seated = s
        var seats: [String: Int] = [:]
        for (i, id) in order.enumerated() { seats[id] = i }
        seated.seats = seats
        s = try MPRules.start(seated, actor: "a")
        guard s.matches.count == 1, let id = s.matches.keys.first else { throw LinkTestSetupError() }
        let humans = order.filter { !$0.hasPrefix("bot_") }
        var connections: [String: [String: Bool]] = [:]
        for h in humans { connections[h] = ["court-\(h)": true] }
        s.connections = connections
        for h in humans { s = try MPRules.ready(s, match: id, uid: h, value: true) }
        s = MPRules.startReady(s, match: id)
        guard let m = s.matches[id], m.phase == .playing, m.players == order, m.starts == 1 else { throw LinkTestSetupError() }
        return s
    }

    @MainActor private func lockstep(_ net: LinkTestNet, _ clients: [LinkTestClient]) async {
        for client in clients { client.tick() }
        await net.pump()
        net.time.advance()
    }

    /// Kotlin `assertInStep`; returns whether the peers agree, so frame loops stop at the first failure like Kotlin.
    @MainActor @discardableResult
    private func assertInStep(_ a: LinkTestClient, _ peer: LinkTestClient, _ label: String = "",
                              file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let mine = a.engine.referee.exportState()
        let theirs = peer.engine.referee.exportState()
        let ball = a.engine.ballState
        let theirBall = peer.engine.ballState
        XCTAssertEqual(mine, theirs, "referee \(label)", file: file, line: line)
        XCTAssertEqual(ball, theirBall, "ball \(label)", file: file, line: line)
        return mine == theirs && ball == theirBall
    }

    /// Plays in step to the result, checking every frame that the peers show exactly the authority's match.
    @MainActor @discardableResult
    private func playToTheEnd(_ net: LinkTestNet, _ a: LinkTestClient, _ peers: [LinkTestClient],
                              file: StaticString = #filePath, line: UInt = #line) async -> Bool {
        var steps = 0
        while net.fixture.phase == .playing && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a] + peers)
            for p in peers {
                let label = "\(net.fixture.players.count) players, frame \(steps)"
                if !assertInStep(a, p, label, file: file, line: line) { return false }
            }
        }
        XCTAssertEqual(MPMatchPhase.finished, net.fixture.phase, "the match must end", file: file, line: line)
        return net.fixture.phase == .finished
    }

    @MainActor private func assertResult(_ net: LinkTestNet, _ a: LinkTestClient, _ start: MPFixture,
                                         file: StaticString = #filePath, line: UInt = #line) throws {
        let m = net.fixture
        let referee = a.engine.referee.exportState()
        XCTAssertEqual(MPMatchPhase.finished, m.phase, file: file, line: line)
        XCTAssertEqual(["a"], net.mutations, "only the authority writes the result, once", file: file, line: line)
        XCTAssertEqual(referee.scores, m.scores, file: file, line: line)
        guard let winner = referee.winner, winner >= 0, winner < m.scores.count, winner < m.players.count else {
            XCTFail("the referee has no winner", file: file, line: line)
            return
        }
        XCTAssertEqual(net.session.target, m.scores[winner], file: file, line: line)
        let order = m.players.indices.sorted { (x: Int, y: Int) -> Bool in
            if referee.scores[x] != referee.scores[y] { return referee.scores[x] > referee.scores[y] }
            if referee.faults[x] != referee.faults[y] { return referee.faults[x] < referee.faults[y] }
            if referee.pointsWon[x] != referee.pointsWon[y] { return referee.pointsWon[x] > referee.pointsWon[y] }
            return x < y
        }
        let ranked = order.map { m.players[$0] }
        XCTAssertEqual(ranked, m.placement, file: file, line: line)
        XCTAssertEqual(m.players[winner], m.winner, file: file, line: line)
        XCTAssertEqual(m.winner, m.placement.first, file: file, line: line)
        XCTAssertTrue(MPRules.validPlacement(m, m.scores, m.placement), file: file, line: line)
        XCTAssertEqual(start.starts, m.starts, file: file, line: line)
        XCTAssertEqual(start.players, m.players, file: file, line: line)
        XCTAssertEqual(start.seed, m.seed, file: file, line: line)
        // The result followed the final checkpoint, which already held it.
        guard let atResult = net.atResult else {
            XCTFail("no checkpoint was stored when the result was written", file: file, line: line)
            return
        }
        let stored = try CrossState.read(MPCodec.map(atResult["engine"])).referee
        XCTAssertEqual(referee.scores, stored.scores, file: file, line: line)
        XCTAssertEqual(referee.winner, stored.winner, file: file, line: line)
    }

    // Kotlin: placementRanksByScoreThenFewerFaultsThenMorePointsWonThenSeat
    @MainActor func testPlacementRanksByScoreThenFewerFaultsThenMorePointsWonThenSeat() {
        func state(_ scores: [Int], _ faults: [Int], _ won: [Int]) -> CrossRefereeState {
            CrossRefereeState(scores: scores, server: 0, rallyId: 9, ralliesPlayed: 8, winner: nil, phase: .resolved, striker: 0, receiver: nil,
                              hits: 0, pointsWon: won, faults: faults, misses: Array(repeating: 0, count: scores.count))
        }
        let four = ["p0", "p1", "p2", "p3"]
        XCTAssertEqual(["p1", "p3", "p2", "p0"], CrossLink.placement(four, state([1, 3, 1, 1], [2, 0, 1, 1], [1, 4, 1, 2])))
        XCTAssertEqual(["p2", "p0", "p1", "p3"], CrossLink.placement(four, state([0, 0, 3, 0], [1, 1, 0, 1], [0, 0, 3, 0])))
        XCTAssertEqual(["p0", "p2", "p1"], CrossLink.placement(Array(four.prefix(3)), state([3, 0, 0], [0, 2, 0], [3, 0, 1])))
    }

    // Kotlin: seatsFollowTheFixtureAndTheAuthorityIsTheSmallestHuman
    @MainActor func testSeatsFollowTheFixtureAndTheAuthorityIsTheSmallestHuman() async throws {
        let time = LinkTestTime()
        let s = try table(["b", "bot_mia", "a", "bot_june"])
        guard let m = s.matches.values.first else {
            XCTFail("no fixture")
            return
        }
        let seats = CrossLink.seats(s, m, uid: "b")
        XCTAssertEqual(["b", "bot_mia", "a", "bot_june"], seats.map { $0.id })
        XCTAssertEqual([CrossSeatKind.local, .house, .remote, .house], seats.map { $0.kind })
        XCTAssertEqual("mia", seats[1].characterId)
        XCTAssertNotNil(seats[1].bot)
        XCTAssertEqual(Int(crossMod(m.seed, 4)), CrossLink.firstServer(m))
        let net = LinkTestNet(s, time)
        let a = LinkTestClient("a", net)
        let b = LinkTestClient("b", net)
        XCTAssertTrue(a.engine.authoritative)
        XCTAssertFalse(b.engine.authoritative)
        XCTAssertEqual(2, a.seat)
        XCTAssertEqual(0, b.seat)
        // Not ported: the two assertThrows(IllegalArgumentException) checks that a mismatched engine (reversed seat order, or a
        // first server one off) is refused by the CrossLink constructor: Swift CrossLink.init neither validates nor throws.
        await net.settle()
    }

    // Kotlin: authorityAndPeerStayInStepThroughWholeThreeAndFourPlayerMatches
    @MainActor func testAuthorityAndPeerStayInStepThroughWholeThreeAndFourPlayerMatches() async throws {
        let time = LinkTestTime()
        for order in [["b", "a", "bot_mia"], ["a", "bot_mia", "b", "bot_june"]] {
            let net = LinkTestNet(try table(order), time)
            net.manual = true
            let start = net.fixture
            let a = LinkTestClient("a", net)
            let b = LinkTestClient("b", net)
            await net.pump()
            XCTAssertTrue(a.link.ready && b.link.ready)
            guard await playToTheEnd(net, a, [b]) else { return }
            for _ in 0..<360 { await lockstep(net, [a, b]) }
            try assertResult(net, a, start)
            // Every strike b made went out once, under its own seat, and the authority applied each exactly once.
            let published = net.from("b")
            XCTAssertTrue(published.count >= 3, "\(order): b played \(published.count) strikes")
            let seatB = Int64(b.seat)
            let allOwn = published.allSatisfy({ MPCodec.number($0, "seat") == seatB && MPCodec.number($0, "protocol") == 2 })
            XCTAssertTrue(allOwn)
            let keys = Set(published.map { "\(MPCodec.number($0, "rallyId"))/\(MPCodec.number($0, "hitIndex"))" })
            XCTAssertEqual(published.count, keys.count)
            XCTAssertEqual(published.count, b.events.contacts(b.seat).count)
            XCTAssertEqual(published.count, a.events.contacts(b.seat).count)
            XCTAssertTrue(net.from("a").isEmpty)
            XCTAssertEqual(a.engine.referee.exportState(), b.engine.referee.exportState())
            XCTAssertEqual(a.engine.referee.winner == b.seat, b.engine.status == .youWon)
            XCTAssertTrue(a.failures.isEmpty, "\(a.failures)")
            XCTAssertTrue(b.failures.isEmpty, "\(b.failures)")
            // Nothing is written once the result stands.
            let writes = net.snapshotWrites
            for _ in 0..<360 { await lockstep(net, [a, b]) }
            XCTAssertEqual(writes, net.snapshotWrites)
            XCTAssertEqual(["a"], net.mutations)
        }
    }

    // Kotlin: delayedAndDuplicatedActionsStillMakeOneConsistentMatch
    @MainActor func testDelayedAndDuplicatedActionsStillMakeOneConsistentMatch() async throws {
        let time = LinkTestTime()
        for order in [["a", "b", "bot_june"], ["bot_mia", "b", "bot_june", "a"]] {
            let net = LinkTestNet(try table(order), time)
            net.manual = true
            net.duplicate = true
            let start = net.fixture
            let a = LinkTestClient("a", net)
            let b = LinkTestClient("b", net)
            await net.pump()
            var steps = 0
            while net.fixture.phase == .playing && steps < CrossLinkTests.limit {
                steps += 1
                a.tick()
                b.tick()
                await net.pump("snapshot")
                if steps % 36 == 0 { await net.pump() } // Strikes reach the authority up to 300 ms late, every one of them twice.
                time.advance()
            }
            XCTAssertEqual(MPMatchPhase.finished, net.fixture.phase, "the match must end")
            guard net.fixture.phase == .finished else { return }
            for _ in 0..<360 { await lockstep(net, [a, b]) }
            try assertResult(net, a, start)
            XCTAssertEqual(a.engine.referee.exportState(), b.engine.referee.exportState())
            let published = net.from("b")
            XCTAssertTrue(published.count >= 3, "\(order): b played \(published.count) strikes")
            XCTAssertTrue(net.deliveries >= 2 * published.count, "duplicates were delivered")
            XCTAssertEqual(published.count, b.events.contacts(b.seat).count)
            XCTAssertEqual(published.count, a.events.contacts(b.seat).count, "each strike applied exactly once")
            XCTAssertTrue(a.failures.isEmpty, "\(a.failures)")
            XCTAssertTrue(b.failures.isEmpty, "\(b.failures)")
        }
    }

    // Kotlin: repeatedStaleAndForgedActionsNeverApplyTwiceOrMoveTheScore
    @MainActor func testRepeatedStaleAndForgedActionsNeverApplyTwiceOrMoveTheScore() async throws {
        let time = LinkTestTime()
        let net = LinkTestNet(try table(["b", "c", "a", "bot_mia"]), time)
        net.manual = true
        let id = net.fixture.id
        let a = LinkTestClient("a", net)
        let b = LinkTestClient("b", net)
        let c = LinkTestClient("c", net)
        await net.pump()
        var steps = 0
        while net.from("b").count < 2 && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b, c])
            if !assertInStep(a, b) || !assertInStep(a, c) { return }
        }
        XCTAssertEqual(2, net.from("b").count)
        // RTDB hands every ring entry over again on each change: nothing is applied or acknowledged twice.
        a.events += a.engine.drainEvents()
        let before = a.engine.referee.exportState()
        let ball = a.engine.ballState
        var writes = net.snapshotWrites
        for _ in 0..<3 { net.redeliver() }
        await net.pump()
        XCTAssertEqual(before, a.engine.referee.exportState())
        XCTAssertEqual(ball, a.engine.ballState)
        XCTAssertFalse(a.engine.drainEvents().contains(where: linkTestIsContact))
        XCTAssertEqual(writes, net.snapshotWrites)
        // An old strike sent again under a new sequence is refused by the engine and only acknowledged.
        let resent = time.next("b")
        guard var old = net.from("b").first else {
            XCTFail("b sent nothing")
            return
        }
        old["sender"] = nil
        old["sequence"] = nil
        LinkTestPhone("b", net).send(id, resent, old)
        await net.pump()
        XCTAssertEqual(before, a.engine.referee.exportState())
        XCTAssertFalse(a.engine.drainEvents().contains(where: linkTestIsContact))
        XCTAssertEqual(writes + 1, net.snapshotWrites)
        XCTAssertEqual(resent, MPCodec.number(MPCodec.map(net.checkpoint["seen"]), "b"))
        // Wait for a ball c must return, then forge c's perfectly legal return.
        while !(a.engine.referee.phase == .receivable && a.engine.referee.receiver == c.seat) && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b, c])
        }
        a.events += a.engine.drainEvents()
        let referee = a.engine.referee.exportState()
        XCTAssertEqual(c.seat, referee.receiver)
        let g = a.engine.geometry
        let at = g.fromLocal(c.seat, 0.05, 1.0)
        let launch = CrossShots.targeted(g, a.engine.physics, from: at, height: 0.15, target: g.fromLocal(a.seat, 0, 0.8), pace: 0.9)
        let flight = CrossBallState(position: at, height: 0.15, velocity: launch.velocity, lift: launch.lift)
        let strike = CrossStrike(seat: c.seat, point: at, height: 0.15, ball: flight, serve: false, rallyId: referee.rallyId,
                                 hitIndex: referee.hits + 1)
        let body: (Int) -> MPWire = { seat in
            ["protocol": 2, "seat": seat, "rallyId": strike.rallyId, "hitIndex": strike.hitIndex, "strike": strike.wire()]
        }
        writes = net.snapshotWrites
        LinkTestPhone("b", net).send(id, time.next("b"), body(c.seat)) // b claims c's seat
        LinkTestPhone("b", net).send(id, time.next("b"), body(b.seat)) // b's seat, c's strike
        LinkTestPhone("mallory", net).send(id, 1, body(c.seat)) // nobody at this table
        await net.pump()
        XCTAssertEqual(referee, a.engine.referee.exportState())
        XCTAssertFalse(a.engine.drainEvents().contains(where: linkTestIsContact))
        XCTAssertEqual(writes + 2, net.snapshotWrites, "b's two actions are only acknowledged; mallory's is ignored")
        XCTAssertNil(MPCodec.map(net.checkpoint["seen"])["mallory"])
        // The very same strike from c itself is a legal return.
        LinkTestPhone("c", net).send(id, time.next("c"), body(c.seat))
        await net.pump()
        XCTAssertEqual(c.seat, a.engine.referee.striker)
        XCTAssertEqual(referee.hits + 1, a.engine.referee.hits)
        XCTAssertEqual(1, a.engine.drainEvents().contacts(c.seat).count)
        XCTAssertEqual(a.engine.referee.exportState(), b.engine.referee.exportState())
        XCTAssertEqual(a.engine.referee.exportState(), c.engine.referee.exportState())
        // Peers never write checkpoints, and a checkpoint the authority did not write changes nobody's score.
        writes = net.snapshotWrites
        b.link.checkpoint()
        c.link.checkpoint()
        await net.settle() // A Swift write would only reach the backend from its Task.
        XCTAssertEqual(writes, net.snapshotWrites)
        let truth = a.engine.referee.exportState()
        var fake = a.engine.exportState()
        fake.referee.scores = Array(repeating: 2, count: 4)
        LinkTestPhone("b", net).snapshot(id, ["protocol": 2, "kind": "friendlyRooms", "code": "ABC234", "engine": fake.wire(),
                                              "seen": [String: Int64]()])
        await net.pump()
        XCTAssertEqual(truth, a.engine.referee.exportState())
        XCTAssertEqual(truth, c.engine.referee.exportState())
        XCTAssertEqual(truth, b.engine.referee.exportState())
        a.link.checkpoint()
        await net.pump()
        XCTAssertEqual(truth, c.engine.referee.exportState())
        XCTAssertTrue(net.mutations.isEmpty)
        let failures = a.failures + b.failures + c.failures
        XCTAssertTrue(failures.isEmpty, "\(failures)")
    }

    // Kotlin: aDisconnectedHumanPausesTheWholeTableAndNobodyFaults
    @MainActor func testADisconnectedHumanPausesTheWholeTableAndNobodyFaults() async throws {
        let time = LinkTestTime()
        let net = LinkTestNet(try table(["a", "bot_mia", "b", "bot_june"]), time)
        net.manual = true
        let a = LinkTestClient("a", net)
        let b = LinkTestClient("b", net, missRate: 0)
        await net.pump()
        var steps = 0
        // Play until a ball has bounced legally on b's side: b has to return it.
        while !(a.engine.referee.phase == .receivable && a.engine.referee.receiver == b.seat) && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b])
        }
        let rally = a.engine.referee.rallyId
        net.connect("b", false) // b's phone went to the background
        await lockstep(net, [a, b])
        XCTAssertFalse(a.link.ready)
        XCTAssertFalse(b.link.ready)
        XCTAssertTrue(a.engine.paused && b.engine.paused)
        assertInStep(a, b)
        let referee = a.engine.referee.exportState()
        let ball = a.engine.ballState
        let writes = net.snapshotWrites
        for _ in 0..<(120 * 10) { await lockstep(net, [a, b]) } // ten seconds, far beyond a remote receiver's 0.8 s grace
        XCTAssertEqual(referee, a.engine.referee.exportState())
        XCTAssertEqual(ball, a.engine.ballState)
        assertInStep(a, b)
        XCTAssertFalse(a.events.rallies().contains(where: { $0.rallyId == rally }))
        XCTAssertEqual(writes, net.snapshotWrites, "no checkpoints while paused")
        // b is back: the same ball goes on and b's return counts.
        net.connect("b", true)
        await lockstep(net, [a, b])
        XCTAssertTrue(a.link.ready && b.link.ready)
        while a.engine.referee.rallyId == rally && a.engine.referee.striker != b.seat && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b])
            if !assertInStep(a, b) { return }
        }
        XCTAssertEqual(rally, a.engine.referee.rallyId)
        XCTAssertEqual(b.seat, a.engine.referee.striker)
        // Off screen or offline is not ready either.
        b.link.active = false
        XCTAssertFalse(b.link.ready)
        b.link.active = true
        a.link.networkAvailable = false
        XCTAssertFalse(a.link.ready)
        a.link.networkAvailable = true
        XCTAssertTrue(a.link.ready)
    }

    // Kotlin: aReopenedPeerAndARestartedAuthorityResumeTheSameScore
    @MainActor func testAReopenedPeerAndARestartedAuthorityResumeTheSameScore() async throws {
        let time = LinkTestTime()
        let net = LinkTestNet(try table(["b", "a", "bot_mia"]), time)
        net.manual = true
        let start = net.fixture
        var a = LinkTestClient("a", net)
        var b = LinkTestClient("b", net)
        await net.pump()
        var steps = 0
        while a.engine.referee.scores.allSatisfy({ $0 == 0 }) && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b])
        }
        // b leaves and its process dies; later a fresh engine and link open the match again.
        net.connect("b", false)
        await lockstep(net, [a, b])
        b.link.close()
        for _ in 0..<240 { await lockstep(net, [a]) }
        let paused = a.engine.referee.exportState()
        XCTAssertTrue(paused.scores.contains(where: { $0 > 0 }))
        b = LinkTestClient("b", net)
        await net.pump()
        XCTAssertFalse(b.link.ready)
        assertInStep(a, b, "reopened peer")
        net.connect("b", true)
        for _ in 0..<600 {
            await lockstep(net, [a, b])
            if !assertInStep(a, b, "after the peer's return") { return }
        }
        // The authority's process restarts the same way: a fresh engine restores the checkpoint and nothing is replayed.
        net.connect("a", false)
        await lockstep(net, [a, b])
        a.link.close()
        await net.settle() // Kotlin's close() writes its checkpoint synchronously: let the Swift write Task run now.
        let last = a.engine.referee.exportState()
        let lastBall = a.engine.ballState
        let writes = net.snapshotWrites
        a = LinkTestClient("a", net)
        await net.pump()
        XCTAssertEqual(last, a.engine.referee.exportState())
        XCTAssertEqual(lastBall, a.engine.ballState)
        XCTAssertFalse(a.engine.drainEvents().contains(where: linkTestIsReplay))
        XCTAssertEqual(writes, net.snapshotWrites, "old actions are neither applied nor acknowledged again")
        net.connect("a", true)
        await lockstep(net, [a, b])
        let checkpointed = try CrossState.read(MPCodec.map(net.checkpoint["engine"]))
        XCTAssertEqual(last.scores, checkpointed.referee.scores)
        guard await playToTheEnd(net, a, [b]) else { return }
        try assertResult(net, a, start)
        XCTAssertTrue(a.failures.isEmpty && b.failures.isEmpty, "\(a.failures) \(b.failures)")
    }

    // Kotlin: aStrikeWaitingWhileTheAuthorityRestartsIsAppliedOnceAfterItsCheckpoint
    @MainActor func testAStrikeWaitingWhileTheAuthorityRestartsIsAppliedOnceAfterItsCheckpoint() async throws {
        let time = LinkTestTime()
        let net = LinkTestNet(try table(["b", "a", "bot_mia"]), time)
        net.manual = true
        var a = LinkTestClient("a", net)
        let b = LinkTestClient("b", net, missRate: 0)
        await net.pump()
        var steps = 0
        while !(b.engine.referee.phase == .receivable && b.engine.referee.receiver == b.seat) && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b])
        }
        // b hits; its action stays in its ring while the authority's process dies.
        let sent = net.written.count
        while net.written.count == sent && steps < CrossLinkTests.limit {
            steps += 1
            a.tick()
            b.tick()
            await net.pump("snapshot")
            time.advance()
        }
        guard let strike = b.engine.localStrike() else {
            XCTFail("b has not hit")
            return
        }
        XCTAssertEqual(b.seat, strike.seat)
        net.connect("a", false)
        a.link.close()
        await net.settle() // Kotlin's close() writes its checkpoint synchronously: let the Swift write Task run now.
        a = LinkTestClient("a", net)
        await net.pump("action") // the ring arrives before the checkpoint: held until it is restored
        XCTAssertTrue(a.engine.drainEvents().isEmpty)
        XCTAssertEqual(1, a.engine.referee.rallyId)
        await net.pump()
        XCTAssertEqual(1, a.engine.drainEvents().contacts(b.seat).count)
        XCTAssertEqual(b.seat, a.engine.referee.striker)
        XCTAssertEqual(strike.hitIndex, a.engine.referee.hits)
        XCTAssertEqual(strike.ball, a.engine.ballState)
        net.connect("a", true)
        for _ in 0..<600 {
            await lockstep(net, [a, b])
            if !assertInStep(a, b) { return }
        }
        XCTAssertEqual(0, a.events.contacts(b.seat).filter({ $0.point == strike.point }).count)
    }

    // Kotlin: aPeerKeepsItsOwnHitUntilAcknowledgedOrFor850Ms
    @MainActor func testAPeerKeepsItsOwnHitUntilAcknowledgedOrFor850Ms() async throws {
        let time = LinkTestTime()
        let net = LinkTestNet(try table(["b", "a", "bot_mia"]), time)
        net.manual = true
        let a = LinkTestClient("a", net)
        let b = LinkTestClient("b", net, missRate: 0)
        await net.pump()
        var steps = 0
        while !(b.engine.referee.phase == .receivable && b.engine.referee.receiver == b.seat) && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b])
        }
        let sent = net.written.count
        while net.written.count == sent && steps < CrossLinkTests.limit {
            steps += 1
            a.tick()
            b.tick()
            await net.pump("snapshot")
            time.advance()
        }
        let mine = b.engine.referee.exportState()
        XCTAssertEqual(b.seat, mine.striker)
        // A checkpoint that has not seen the hit yet does not rewind it ...
        a.link.checkpoint()
        await net.pump("snapshot")
        XCTAssertEqual(mine, b.engine.referee.exportState())
        XCTAssertNotEqual(b.seat, a.engine.referee.striker)
        // ... until 850 ms have passed without an acknowledgement.
        time.elapse(CrossLink.ackWait)
        a.link.checkpoint()
        await net.pump("snapshot")
        XCTAssertEqual(a.engine.referee.exportState(), b.engine.referee.exportState())
        // The strike arrives: applied once, and its acknowledgement brings both phones together again.
        await net.pump()
        XCTAssertEqual(b.seat, a.engine.referee.striker)
        assertInStep(a, b)
        XCTAssertTrue(a.failures.isEmpty && b.failures.isEmpty, "\(a.failures) \(b.failures)")
    }

    // Kotlin: aServeTheAuthorityRefusedIsServedAndPublishedAgain
    @MainActor func testAServeTheAuthorityRefusedIsServedAndPublishedAgain() async throws {
        let time = LinkTestTime()
        let net = LinkTestNet(try table(["b", "a", "bot_mia"]), time)
        net.manual = true
        let a = LinkTestClient("a", net)
        let b = LinkTestClient("b", net)
        await net.pump()
        var steps = 0
        while !(a.engine.referee.phase == .resolved && a.engine.referee.lastOutcome?.nextServer == b.seat) && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b])
        }
        let rally = a.engine.referee.rallyId + 1
        let mark = a.events.count
        // The authority's phone stalls: b's point delay ends first and b serves before the authority's rally began.
        let sent = net.written.count
        while net.written.count == sent && steps < CrossLinkTests.limit {
            steps += 1
            b.tick()
            await net.pump()
            time.advance()
        }
        XCTAssertEqual(rally - 1, a.engine.referee.rallyId)
        XCTAssertEqual(a.engine.referee.exportState(), b.engine.referee.exportState(), "refused and rewound")
        // Both play on: b serves the same (rallyId, hit 0) again, which is a new strike and goes out again.
        while !(a.engine.referee.rallyId == rally && a.engine.referee.phase != .awaitingServe) && steps < CrossLinkTests.limit {
            steps += 1
            await lockstep(net, [a, b])
            if !assertInStep(a, b) { return }
        }
        let rallyWire = Int64(rally)
        let serves = net.from("b").filter({ MPCodec.number($0, "rallyId") == rallyWire && MPCodec.number($0, "hitIndex") == 0 })
        XCTAssertEqual(2, serves.count)
        XCTAssertEqual(b.seat, a.engine.referee.striker)
        for _ in 0..<240 {
            await lockstep(net, [a, b])
            if !assertInStep(a, b) { return }
        }
        let served = a.events.dropFirst(mark).compactMap { (e: CrossEvent) -> Int? in
            if case let .served(seat) = e { return seat }
            return nil
        }
        XCTAssertEqual([b.seat], served, "only the second serve was applied")
        XCTAssertTrue(a.failures.isEmpty && b.failures.isEmpty, "\(a.failures) \(b.failures)")
    }

    // Kotlin: otherProtocolsAreRejectedWithAClearMessage
    @MainActor func testOtherProtocolsAreRejectedWithAClearMessage() async throws {
        let time = LinkTestTime()
        let net = LinkTestNet(try table(["b", "a", "bot_mia"]), time)
        let id = net.fixture.id
        let b = LinkTestClient("b", net)
        LinkTestPhone("a", net).snapshot(id, ["protocol": 1, "kind": "friendlyRooms", "code": "ABC234", "engine": [String: Any]()])
        XCTAssertEqual([CrossLinkIssue.version], b.failures, "\(b.failures)")
        XCTAssertFalse(b.link.ready)
        // The authority rejects an action of another protocol the same way: acknowledged, never applied.
        let other = LinkTestNet(try table(["b", "a", "bot_mia"]), time)
        let a2 = LinkTestClient("a", other)
        await other.settle() // Kotlin writes a's opening checkpoint synchronously inside the constructor.
        let b2 = LinkTestClient("b", other)
        let writes = other.snapshotWrites
        LinkTestPhone("b", other).send(id, time.next("b"), ["protocol": 1, "rallies": 1, "hit": 0, "flight": [String: Any]()])
        await other.settle() // The acknowledging checkpoint is written from a Task.
        XCTAssertEqual([CrossLinkIssue.version], a2.failures, "\(a2.failures)")
        XCTAssertFalse(a2.engine.drainEvents().contains(where: linkTestIsContact))
        XCTAssertEqual(writes + 1, other.snapshotWrites)
        XCTAssertTrue(b2.failures.isEmpty, "\(b2.failures)")
    }
}
