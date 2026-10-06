import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../TournamentUpdateTest.kt (MinikCrossPong 828c6fc): a mixed round robin (two humans, two house
// players) — shared schedule, deletion, leaving and Ready/start transitions.
//
// Name map: Kotlin `canDeleteTournament` -> `MPRules.canDelete`; `leaveTournament` -> `MPRules.leave`; `humanMember` ->
// `MPSession.human`; `departed` set -> `[uid: true]`; RoomStartGate and LobbyEvents live in MPController as private state.

final class TournamentUpdateTests: XCTestCase {
    /// Kotlin `BotProfile(characterId = id)`: every stat 5.
    private func character(_ id: String) -> MPBot {
        MPBot(speed: 5, reaction: 5, accuracy: 5, power: 5, agility: 5, characterId: id, forehandSkill: 5, backhandSkill: 5, serveSkill: 5)
    }

    /// Kotlin `room()`: Alpha hosts, Beta joins, Minik and Flare fill the table; both humans connected. Kotlin's create leaves the
    /// creation and activity times at 0 (Swift stamps them).
    private func room() throws -> MPSession {
        var s = MPSession(code: "TST234", kind: .tournament, host: MPIdentity(id: "a", name: "Alpha"), capacity: 4, legs: 1,
                          winPoints: 3, difficulty: 0, target: 3)
        s.createdAt = 0
        s.lastActivityAt = 0
        s = try MPRules.join(s, MPIdentity(id: "b", name: "Beta"))
        s = try MPRules.addBot(s, actor: "a", bot: MPParticipant(identity: MPIdentity(id: "bot_1", name: "Minik"), bot: character("minik")))
        s = try MPRules.addBot(s, actor: "a", bot: MPParticipant(identity: MPIdentity(id: "bot_2", name: "Flare"), bot: character("flare")))
        s.connections = ["a": ["0": true], "b": ["0": true]]
        return s
    }

    /// The fixtures as Kotlin's MatchRecord sees them: Swift's extra stored `authorityUid` (Kotlin only writes it on the wire,
    /// recomputed from the current host) is cleared, because MPRules.leave rewrites it for every fixture.
    private func kotlinView(_ matches: [String: MPFixture]) -> [String: MPFixture] {
        matches.mapValues { m in
            var record = m
            record.authorityUid = nil
            return record
        }
    }

    // Kotlin: mixedRosterUsesOneSharedSchedule
    func testMixedRosterUsesOneSharedSchedule() throws {
        let base = try room()
        let s = try MPRules.start(base, actor: "a")
        XCTAssertEqual(6, s.matches.count)
        XCTAssertEqual(1, s.matches.values.filter { $0.phase == .finished }.count)
    }

    // Kotlin: deletionCountsConnectedHumansNotHousePlayersOrAwayMembers
    func testDeletionCountsConnectedHumansNotHousePlayersOrAwayMembers() throws {
        let s = try room()
        XCTAssertFalse(MPRules.canDelete(s, actor: "a"))
        var alone = s
        alone.connections = ["a": ["0": true]]
        XCTAssertTrue(MPRules.canDelete(alone, actor: "a"))
        XCTAssertFalse(MPRules.canDelete(s, actor: "outsider"))
    }

    // Kotlin: leavingWaitingRosterTransfersManagementAndKeepsOtherPlayers
    func testLeavingWaitingRosterTransfersManagementAndKeepsOtherPlayers() throws {
        let base = try room()
        let s = try MPRules.leave(base, actor: "a")
        XCTAssertEqual("b", s.host)
        XCTAssertNil(s.participants["a"])
        XCTAssertEqual(3, s.participants.count)
        XCTAssertEqual(["0": true], s.connections["b"] ?? [:])
    }

    // Kotlin: activeDepartureCancelsOnlyOwnUnfinishedFixturesAndKeepsResults
    func testActiveDepartureCancelsOnlyOwnUnfinishedFixturesAndKeepsResults() throws {
        let base = try room()
        var s = try MPRules.start(base, actor: "a")
        let m = try XCTUnwrap(s.matches.values.first(where: { $0.contains("a") && $0.contains("b") }))
        s = try MPRules.ready(s, match: m.id, uid: "a", value: true)
        s = try MPRules.ready(s, match: m.id, uid: "b", value: true)
        s = MPRules.startReady(s, match: m.id)
        s = try MPRules.finish(s, match: m.id, actor: "a", a: 3, b: 1)
        let left = try MPRules.leave(s, actor: "a")
        XCTAssertEqual("b", left.host)
        XCTAssertEqual(s.matches[m.id], left.matches[m.id])
        XCTAssertEqual(["a": true], left.departed)
        XCTAssertTrue(left.matches.values.filter { $0.contains("a") && $0.id != m.id }.allSatisfy { $0.phase == .cancelled })
        let untouchedBefore = s.matches.filter { !$0.value.contains("a") }
        let untouchedAfter = left.matches.filter { !$0.value.contains("a") }
        XCTAssertEqual(kotlinView(untouchedBefore), kotlinView(untouchedAfter))
        XCTAssertEqual(MPRules.standings(s), MPRules.standings(left))
        let wire: MPWire = try MPCodec.session(left)
        let decoded: MPSession = try MPCodec.session(wire)
        XCTAssertEqual(left, decoded)
        XCTAssertFalse(left.human("a"))
        XCTAssertFalse(left.connected("a"))
    }

    // Kotlin: departingDuringPlayCancelsWithoutInventingResult
    func testDepartingDuringPlayCancelsWithoutInventingResult() throws {
        let base = try room()
        let s = try MPRules.start(base, actor: "a")
        let m = try XCTUnwrap(s.matches.values.first(where: { $0.contains("a") && $0.contains("b") }))
        var playing = try MPRules.ready(s, match: m.id, uid: "a", value: true)
        playing = try MPRules.ready(playing, match: m.id, uid: "b", value: true)
        playing = MPRules.startReady(playing, match: m.id)
        let left = try MPRules.leave(playing, actor: "a")
        XCTAssertEqual(MPMatchPhase.cancelled, left.matches[m.id]?.phase)
        XCTAssertEqual(1, left.matches[m.id]?.starts)
        XCTAssertEqual("", left.matches[m.id]?.winner)
        XCTAssertEqual(left, MPRules.startReady(left, match: m.id))
        XCTAssertTrue(MPRules.canDelete(left, actor: "b"))
    }

    // Kotlin: lastConnectedHumanMustDeleteAndOutsidersCannotLeave
    func testLastConnectedHumanMustDeleteAndOutsidersCannotLeave() throws {
        var s = try room()
        s.connections = ["a": ["0": true]]
        XCTAssertThrowsError(try MPRules.leave(s, actor: "a"))
        let full = try room()
        XCTAssertThrowsError(try MPRules.leave(full, actor: "outsider"))
    }

    // Kotlin: pendingStartRechecksReadySnapshotReceivedBeforeTransactionCompletion
    // Partly ported: the RoomStartGate itself (observe/begin/pending/complete/reset) is MPController's private
    // gatePending/gateLatest state. The Ready snapshot the gate hands back must start exactly once.
    func testPendingStartRechecksReadySnapshotReceivedBeforeTransactionCompletion() throws {
        let base = try room()
        let s = try MPRules.start(base, actor: "a")
        let id = try XCTUnwrap(s.matches.values.first(where: { $0.contains("a") && $0.contains("b") })).id
        // Not ported: gate.observe(s); gate.begin() — private MPController state.
        let readyA = try MPRules.ready(s, match: id, uid: "a", value: true)
        let ready = try MPRules.ready(readyA, match: id, uid: "b", value: true)
        // Not ported: gate.observe(ready); assertTrue(gate.pending); gate.complete(); assertFalse(gate.pending) — private.
        let latest = ready   // Kotlin: the snapshot gate.complete() returns
        let start = MPRules.startReady(latest, match: id)
        XCTAssertEqual(MPMatchPhase.playing, start.matches[id]?.phase)
        XCTAssertEqual(1, start.matches[id]?.starts)
        XCTAssertEqual(start, MPRules.startReady(start, match: id))
        // Not ported: gate.reset(); assertNull(gate.complete()) — private MPController state.
    }

    // Not ported: joinReadySoundsFollowEventsNotRendersOrPresenceChurn — Kotlin LobbyEvents.accept/reset; the Swift equivalent
    // is MPController's private `lobbyCues(_:)` with its private `lobbyPrevious`, unreachable from tests.
}
