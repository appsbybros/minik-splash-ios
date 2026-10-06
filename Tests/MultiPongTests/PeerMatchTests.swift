import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../PeerMatchTest.kt (MinikCrossPong 828c6fc): two real classic engines (Kotlin ModernEngine -> Swift
// MPEngine) linked by MPMatchLink over a delayed, duplicate-capable repository transport.
//
// Swift MPMatchLink calls the repository from main-actor Tasks (checkpoint, action, result) where Kotlin's fake completes
// synchronously, so the tests yield the main actor (`settle`) wherever Kotlin's calls would already have completed. Kotlin
// `snapshot`/`listenSnapshot` -> `checkpoint`/`watchLive(actions: false)`; `action`/`listenActions` -> `action`/
// `watchLive(actions: true)`; `link.session(s)` -> `update(_:)`; the link's sequence numbers come from MPPreferences.

/// Kotlin `Bus`: the shared room, the checkpoint and the action log; `deliver` hands every queued action to every action
/// listener twice.
private final class PeerMatchBus {
    var checkpoint: MPWire = [:]
    var snapshots: [(id: UUID, call: (MPWire) -> Void)] = []
    var actions: [(id: UUID, call: (MPWire) -> Void)] = []
    var queued: [MPWire] = []
    var allActions: [MPWire] = []
    var holdSnapshots = false
    var completions: [CheckedContinuation<Void, Never>] = []
    var snapshotWrites = 0
    var session: MPSession

    init(session: MPSession) { self.session = session }

    func deliver() {
        let work = queued
        queued.removeAll()
        for w in work {
            for listener in actions.map({ $0.call }) {
                listener(w)
                listener(w)
            }
        }
    }
}

/// Kotlin `Peer`: one phone's view of the bus.
@MainActor private final class PeerMatchRepository: MPRepository {
    let uid: String
    let online = true
    private let bus: PeerMatchBus

    init(_ uid: String, _ bus: PeerMatchBus) {
        self.uid = uid
        self.bus = bus
    }

    func connect() async throws -> String { uid }
    func profile(index: Int, hebrew: Bool, avatar: Int, character: String) async throws -> MPIdentity { MPIdentity(id: uid, name: uid) }
    func get(_ kind: MPSessionKind, _ code: String) async throws -> MPSession? { bus.session }
    func openRooms() async throws -> [(MPSessionKind, String)] { [] }
    func reserve(_ kind: MPSessionKind, _ code: String) async throws {}
    func create(_ session: MPSession) async throws -> MPSession { throw MPError.permission }   // Kotlin: error("not needed")

    func mutate(_ kind: MPSessionKind, _ code: String, _ change: @escaping (MPSession) throws -> MPSession) async throws -> MPSession {
        bus.session = try change(bus.session)
        return bus.session
    }

    func observe(_ kind: MPSessionKind, _ code: String, _ changed: @escaping (Result<MPSession, Error>) -> Void) -> MPSubscription { MPSubscription() }
    func presence(_ kind: MPSessionKind, _ code: String) -> MPSubscription { MPSubscription() }

    func connection(_ changed: @escaping (Bool) -> Void) -> MPSubscription {
        changed(true)
        return MPSubscription()
    }

    func watchLive(_ id: String, actions: Bool, _ changed: @escaping (MPWire) -> Void, _ failed: @escaping (Error) -> Void) -> MPSubscription {
        let b = bus
        let token = UUID()
        if actions {
            b.actions.append((id: token, call: changed))
            for w in b.allActions { changed(w) }
            return MPSubscription { b.actions.removeAll { $0.id == token } }
        }
        b.snapshots.append((id: token, call: changed))
        changed(b.checkpoint)
        return MPSubscription { b.snapshots.removeAll { $0.id == token } }
    }

    func checkpoint(_ id: String, _ value: MPWire) async throws {
        let b = bus
        b.snapshotWrites += 1
        if b.holdSnapshots {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                b.completions.append(continuation)
            }
        }
        var stored = value
        stored["revision"] = MPCodec.number(b.checkpoint, "revision") + 1
        b.checkpoint = stored
        for listener in b.snapshots.map({ $0.call }) { listener(stored) }
    }

    func action(_ id: String, _ sequence: Int64, _ value: MPWire) async throws {
        var w = value
        w["sender"] = uid
        w["sequence"] = sequence
        bus.queued.append(w)
        bus.allActions.append(w)
    }

    func leave(_ session: MPSession, delete: Bool) async throws {}   // Kotlin closeFriendly: no-op
    func cleanup() async throws {}
}

private final class PeerMatchFailures {
    var items: [String] = []
}

final class PeerMatchTests: XCTestCase {
    /// Kotlin `Bus.session`: a friendly pair a/b, started, both connected, both Ready and PLAYING.
    private static func playingRoom() throws -> MPSession {
        var s = MPSession(code: "ABC234", kind: .friendly, host: MPIdentity(id: "a", name: "A"), capacity: 2, legs: 1,
                          winPoints: 3, difficulty: 0, target: 3)
        s.createdAt = 0
        s.lastActivityAt = 0
        s = try MPRules.join(s, MPIdentity(id: "b", name: "B"))
        s = try MPRules.start(s, actor: "a")
        let id = try XCTUnwrap(s.matches.keys.first)
        s.connections = ["a": ["one": true], "b": ["two": true]]
        s = try MPRules.ready(s, match: id, uid: "a", value: true)
        s = try MPRules.ready(s, match: id, uid: "b", value: true)
        return MPRules.startReady(s, match: id)
    }

    /// A private sequence store per phone (Kotlin passes `{ ++seq }`).
    private static func preferences() throws -> MPPreferences {
        MPPreferences(try XCTUnwrap(UserDefaults(suiteName: "PeerMatchTests.\(UUID().uuidString)")))
    }

    /// Lets the link's main-actor Tasks run to their next suspension (Kotlin's fake completes every call synchronously).
    @MainActor private func settle(_ turns: Int = 12) async {
        for _ in 0..<turns { await Task.yield() }
    }

    private static func childContacts(_ events: [MPEvent]) -> Int {
        var count = 0
        for event in events {
            if case .contact(.child, _, _, _) = event { count += 1 }
        }
        return count
    }

    // Kotlin: twoModernEnginesExchangeActualServesAndReturnsWithDelayAndDuplicates
    @MainActor func testTwoModernEnginesExchangeActualServesAndReturnsWithDelayAndDuplicates() async throws {
        let room = try PeerMatchTests.playingRoom()
        let bus = PeerMatchBus(session: room)
        let match = try XCTUnwrap(bus.session.matches.values.first)
        let a = MPEngine(level: .easy, target: 3, networked: true)
        let b = MPEngine(level: .easy, target: 3, networked: true, first: .minik)
        let failures = PeerMatchFailures()
        let preferencesA = try PeerMatchTests.preferences()
        let preferencesB = try PeerMatchTests.preferences()
        let linkA = MPMatchLink(repo: PeerMatchRepository("a", bus), session: bus.session, record: match, engine: a,
                                preferences: preferencesA, message: { failures.items.append(String(describing: $0)) })
        linkA.active = true
        linkA.open()
        await settle()
        let linkB = MPMatchLink(repo: PeerMatchRepository("b", bus), session: bus.session, record: match, engine: b,
                                preferences: preferencesB, message: { failures.items.append(String(describing: $0)) })
        linkB.active = true
        linkB.open()
        await settle()
        var contacts = 0
        let phones: [(MPEngine, MPMatchLink)] = [(a, linkA), (b, linkB)]
        for tick in 0..<7000 {
            for (e, l) in phones {
                if e.awaitingServe { e.touch(MPPoint(0.52, 0.28)) }
                if let f = e.flight, e.childReturnOpen, f.position.y >= 0.80, !e.childStroke.active { e.touch(f.position) }
                e.advance(1.0 / 120)
                let events = e.drainEvents()
                contacts += PeerMatchTests.childContacts(events)
                l.frame(events)
            }
            if tick % 108 == 0 { bus.deliver() }   // 0–900 ms action latency and every action duplicated.
            await settle(3)
        }
        bus.deliver()
        await settle()
        linkA.checkpoint()
        await settle()
        XCTAssertTrue(contacts >= 8, "Both users must contact real balls; contacts=\(contacts)")
        XCTAssertTrue(bus.allActions.count >= 3, "\(bus.allActions.count)")
        XCTAssertTrue(failures.items.isEmpty, "\(failures.items)")
        XCTAssertEqual(a.score.child, b.score.minik)
        XCTAssertEqual(a.score.minik, b.score.child)
        let checkpoint = try MPCodec.decode(MPState.self, bus.checkpoint["engine"])
        let restored = MPEngine(level: .easy, target: 3, networked: true)
        restored.restore(checkpoint)
        XCTAssertEqual(a.score, restored.score)
        XCTAssertEqual(a.flight, restored.flight)
        linkA.close()
        linkB.close()
    }

    // Kotlin: pendingNetworkMissCanRecoverAcrossCheckpoint
    func testPendingNetworkMissCanRecoverAcrossCheckpoint() throws {
        let a = MPEngine(level: .easy, target: 3, networked: true)
        a.touch(MPPoint(0.5, 0.28))
        for _ in 0..<1000 where a.snapshot().pendingFault == nil { a.advance(1.0 / 120) }
        let snapshot = a.snapshot()
        XCTAssertNotNil(snapshot.pendingFault)
        let wire = try MPCodec.encode(snapshot)
        let state = try MPCodec.decode(MPState.self, wire)
        let recovered = MPEngine(level: .easy, target: 3, networked: true)
        recovered.restore(state)
        for _ in 0..<260 { recovered.advance(1.0 / 120) }
        XCTAssertEqual(1, recovered.score.child)
        XCTAssertEqual(1, recovered.score.rallies)
    }

    // Kotlin: finalResultWaitsForLastSnapshotAndBackDoesNotWriteAfterFinish
    @MainActor func testFinalResultWaitsForLastSnapshotAndBackDoesNotWriteAfterFinish() async throws {
        let room = try PeerMatchTests.playingRoom()
        let bus = PeerMatchBus(session: room)
        XCTAssertEqual(1, bus.session.matches.count)
        let m = try XCTUnwrap(bus.session.matches.values.first)
        let engine = MPEngine(level: .easy, target: 3, networked: true)
        let failures = PeerMatchFailures()
        let sequences = try PeerMatchTests.preferences()
        let link = MPMatchLink(repo: PeerMatchRepository("a", bus), session: bus.session, record: m, engine: engine,
                               preferences: sequences, message: { failures.items.append(String(describing: $0)) })
        link.active = true
        link.open()
        await settle()   // Kotlin's first (empty-checkpoint) snapshot completes inside open()
        bus.holdSnapshots = true
        link.checkpoint()
        await settle()
        // Kotlin: repeat(3) { engine.match.award(Player.CHILD) }. MPEngine.score is private(set): the same three awards are
        // made on the engine's own snapshot, which is restored.
        var state = engine.snapshot()
        for _ in 0..<3 { _ = state.score.award(.child, level: engine.level, target: engine.target, first: engine.first) }
        engine.restore(state)
        link.frame([])
        await settle()
        XCTAssertEqual(MPMatchPhase.playing, bus.session.matches[m.id]?.phase)
        guard !bus.completions.isEmpty else {
            XCTFail("the held snapshot never reached the repository")
            return
        }
        bus.completions.removeFirst().resume()   // Previous snapshot finishes; final snapshot follows.
        await settle()
        link.frame([])
        await settle()
        XCTAssertEqual(MPMatchPhase.playing, bus.session.matches[m.id]?.phase)
        guard !bus.completions.isEmpty else {
            XCTFail("the final snapshot never reached the repository")
            return
        }
        bus.completions.removeFirst().resume()
        await settle()
        link.frame([])
        await settle()
        XCTAssertEqual(MPMatchPhase.finished, bus.session.matches[m.id]?.phase)
        let writes = bus.snapshotWrites
        link.update(bus.session)
        link.close()
        await settle()
        XCTAssertEqual(writes, bus.snapshotWrites)
        XCTAssertTrue(failures.items.isEmpty, "\(failures.items)")
        XCTAssertTrue(bus.completions.isEmpty)
    }
}
