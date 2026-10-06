import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../LobbyPauseTest.kt (MinikCrossPong 828c6fc): lobby presence (MPSession.needsLobbyPresence) versus an
// active court connection, for every room kind and tournament format.
//
// Kotlin `connections` (uid -> set of presence tokens) -> Swift `[uid: [token: true]]`.

final class LobbyPauseTests: XCTestCase {
    /// Kotlin `PongRules.create("ABC234", kind, Identity("a","A"), capacity, 1, 3, 0, 0, 3, format)`; Kotlin's create leaves the
    /// creation and activity times at 0 (Swift stamps them), which seed a knockout draw.
    private func created(_ kind: MPSessionKind, _ capacity: Int, _ format: MPTournamentFormat = .roundRobin) -> MPSession {
        var s = MPSession(code: "ABC234", kind: kind, host: MPIdentity(id: "a", name: "A"), capacity: capacity, legs: 1,
                          winPoints: 3, difficulty: 0, target: 3, format: format)
        s.createdAt = 0
        s.lastActivityAt = 0
        return s
    }

    // Kotlin: readyStillStartsOnceButReturningToLobbyCannotKeepTheCourtReady
    func testReadyStillStartsOnceButReturningToLobbyCannotKeepTheCourtReady() throws {
        for kind in MPSessionKind.allCases {
            for format in MPTournamentFormat.allCases {
                let label = "\(kind) \(format)"
                var s = created(kind, 2, format)
                s = try MPRules.join(s, MPIdentity(id: "b", name: "B"))
                XCTAssertTrue(s.needsLobbyPresence("a"), label)
                XCTAssertTrue(s.needsLobbyPresence("b"), label)
                XCTAssertFalse(s.needsLobbyPresence("outsider"), label)
                s.connections = ["a": ["lobby": true], "b": ["lobby": true]]
                s = try MPRules.start(s, actor: "a")
                XCTAssertEqual(1, s.matches.count, label)
                let id = try XCTUnwrap(s.matches.keys.first)
                for uid in ["a", "b"] { s = try MPRules.ready(s, match: id, uid: uid, value: true) }
                XCTAssertTrue(s.needsLobbyPresence("a"), label)
                XCTAssertTrue(s.needsLobbyPresence("b"), label)
                s = MPRules.startReady(s, match: id)
                XCTAssertEqual(1, s.matches[id]?.starts, label)
                XCTAssertFalse(s.needsLobbyPresence("a"), label)
                XCTAssertFalse(s.needsLobbyPresence("b"), label)
                // Both courts publish presence. Back removes b's court subscription;
                // the lobby must not replace it. Resuming restores that connection.
                s.connections = ["a": ["court": true], "b": ["court": true]]
                XCTAssertTrue(s.connected("a") && s.connected("b"), label)
                s.connections["b"] = nil
                XCTAssertFalse(s.connected("b"), label)
                XCTAssertFalse(s.needsLobbyPresence("b"), label)
                s.connections["b"] = ["resumed-court": true]
                XCTAssertTrue(s.connected("b"), label)
                XCTAssertEqual(1, MPRules.startReady(s, match: id).matches[id]?.starts, label)
                let m = try XCTUnwrap(s.matches[id])
                s = try MPRules.finish(s, match: id, actor: s.authority(m), a: 3, b: 0)
                XCTAssertTrue(s.needsLobbyPresence("a"), label)
                XCTAssertTrue(s.needsLobbyPresence("b"), label)
            }
        }
    }

    // Kotlin: otherPlayersMatchDoesNotSuppressAnIdleTournamentPlayersPresence
    func testOtherPlayersMatchDoesNotSuppressAnIdleTournamentPlayersPresence() throws {
        var s = created(.tournament, 3)
        for uid in ["b", "c"] { s = try MPRules.join(s, MPIdentity(id: uid, name: uid)) }
        var connections: [String: [String: Bool]] = [:]
        for uid in s.participants.keys { connections[uid] = ["lobby": true] }
        s.connections = connections
        s = try MPRules.start(s, actor: "a")
        let pairs = s.matches.values.filter { $0.contains("a") && $0.contains("b") }
        XCTAssertEqual(1, pairs.count)
        let id = try XCTUnwrap(pairs.first).id
        for uid in ["a", "b"] { s = try MPRules.ready(s, match: id, uid: uid, value: true) }
        s = MPRules.startReady(s, match: id)
        XCTAssertFalse(s.needsLobbyPresence("a"))
        XCTAssertFalse(s.needsLobbyPresence("b"))
        XCTAssertTrue(s.needsLobbyPresence("c"))
    }
}
