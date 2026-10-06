import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../FriendlyFlowTest.kt (MinikCrossPong 828c6fc): control choices, invitations and who may finish a
// friendly game.
//
// Name map: Kotlin `ControlChoice.normalize(v)` -> `MPLevel.control(v).rawValue` (Standard 0, Pro 3, Beginner 4);
// `MatchPhase.entries` -> every MPMatchPhase case (the Swift enum is not CaseIterable).

final class FriendlyFlowTests: XCTestCase {
    /// Kotlin `room()`: `PongRules.create("ABC234", FRIENDLY, Identity("a","A"), 2, 1, 3, 0, 4, 3)`; Kotlin's create leaves the
    /// creation and activity times at 0 (Swift stamps them).
    private func room() -> MPSession {
        var s = MPSession(code: "ABC234", kind: .friendly, host: MPIdentity(id: "a", name: "A"), capacity: 2, legs: 1,
                          winPoints: 3, difficulty: 4, target: 3)
        s.createdAt = 0
        s.lastActivityAt = 0
        return s
    }

    // Kotlin: legacyControlsKeepTheirMeaning
    func testLegacyControlsKeepTheirMeaning() {
        XCTAssertEqual(0, MPLevel.control(0).rawValue)
        XCTAssertEqual(0, MPLevel.control(1).rawValue)
        XCTAssertEqual(0, MPLevel.control(2).rawValue)
        XCTAssertEqual(3, MPLevel.control(3).rawValue)
        XCTAssertEqual(4, MPLevel.control(4).rawValue)
        XCTAssertEqual(4, MPLevel.control(-1).rawValue)
    }

    // Kotlin: inviteOnlyAppearsWhileASeatCanBeJoined
    func testInviteOnlyAppearsWhileASeatCanBeJoined() throws {
        let empty = room()
        XCTAssertTrue(MPRules.acceptsNewPlayer(empty))
        let full = try MPRules.join(empty, MPIdentity(id: "b", name: "B"))
        XCTAssertFalse(MPRules.acceptsNewPlayer(full))
        let active = try MPRules.start(full, actor: "a")
        XCTAssertFalse(MPRules.acceptsNewPlayer(active))
        XCTAssertThrowsError(try MPRules.join(active, MPIdentity(id: "c", name: "C")))
    }

    // Kotlin: eitherHumanCanFinishAtEveryFriendlyPhaseButOutsidersCannot
    func testEitherHumanCanFinishAtEveryFriendlyPhaseButOutsidersCannot() throws {
        let full = try MPRules.join(room(), MPIdentity(id: "b", name: "B"))
        let active = try MPRules.start(full, actor: "a")
        let phases: [MPMatchPhase] = [.waiting, .ready, .playing, .finished, .cancelled]
        for phase in phases {
            var s = active
            s.matches = active.matches.mapValues { m in
                var record = m
                record.phase = phase
                return record
            }
            XCTAssertTrue(MPRules.canFinishFriendly(s, actor: "a"), "\(phase)")
            XCTAssertTrue(MPRules.canFinishFriendly(s, actor: "b"), "\(phase)")
            XCTAssertFalse(MPRules.canFinishFriendly(s, actor: "outsider"), "\(phase)")
            var tournament = s
            tournament.kind = .tournament
            XCTAssertFalse(MPRules.canFinishFriendly(tournament, actor: "a"), "\(phase)")
        }
    }
}
