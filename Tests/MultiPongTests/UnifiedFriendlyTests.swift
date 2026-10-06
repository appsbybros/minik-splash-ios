import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../UnifiedFriendlyTest.kt (MinikCrossPong 828c6fc): a friendly room's house player shares the room's
// one table, competes with human joins for the seat, and the host's Start is its Ready.

final class UnifiedFriendlyTests: XCTestCase {
    /// Kotlin `house`: Participant(Identity("bot_minik","Minik"), BotProfile(characterId = "minik")) — every stat 5.
    private var house: MPParticipant {
        MPParticipant(identity: MPIdentity(id: "bot_minik", name: "Minik"),
                      bot: MPBot(speed: 5, reaction: 5, accuracy: 5, power: 5, agility: 5, characterId: "minik",
                                 forehandSkill: 5, backhandSkill: 5, serveSkill: 5))
    }

    /// Kotlin `room()`: a friendly pair hosted by GreenFrog, the host connected. Kotlin's create leaves the creation and activity
    /// times at 0 (Swift stamps them).
    private func room() -> MPSession {
        var s = MPSession(code: "ABCDEF", kind: .friendly, host: MPIdentity(id: "host", name: "GreenFrog"), capacity: 2, legs: 1,
                          winPoints: 3, difficulty: 0, target: 3)
        s.createdAt = 0
        s.lastActivityAt = 0
        s.connections = ["host": ["0": true]]
        return s
    }

    // Kotlin: housePlayerUsesTheSharedRoomAndStartsOnceAfterStart
    func testHousePlayerUsesTheSharedRoomAndStartsOnceAfterStart() throws {
        let chosen = try MPRules.addFriendlyHousePlayer(room(), actor: "host", bot: house)
        XCTAssertEqual("ABCDEF", chosen.code)
        XCTAssertEqual(2, chosen.participants.count)
        let scheduled = try MPRules.start(chosen, actor: "host")
        let ready = MPRules.friendlyHouseReady(scheduled, actor: "host")
        XCTAssertEqual(1, ready.matches.count)
        let id = try XCTUnwrap(ready.matches.keys.first)
        XCTAssertEqual(Set(["host"]), ready.matches[id]?.readySet)
        let playing = MPRules.startReady(ready, match: id)
        XCTAssertEqual(MPMatchPhase.playing, playing.matches[id]?.phase)
        XCTAssertEqual(1, playing.matches[id]?.starts)
        XCTAssertEqual(playing, MPRules.friendlyHouseReady(playing, actor: "host"))
        XCTAssertEqual(playing, MPRules.startReady(playing, match: id))
    }

    // Kotlin: aHumanJoiningWinsTheSeatWithoutBeingReplacedOrAutomaticallyReadied
    func testAHumanJoiningWinsTheSeatWithoutBeingReplacedOrAutomaticallyReadied() throws {
        let joined = try MPRules.join(room(), MPIdentity(id: "guest", name: "BlueTiger"))
        XCTAssertEqual(joined, try MPRules.addFriendlyHousePlayer(joined, actor: "host", bot: house))
        let scheduled = try MPRules.start(joined, actor: "host")
        XCTAssertEqual(scheduled, MPRules.friendlyHouseReady(scheduled, actor: "host"))
        XCTAssertEqual(1, scheduled.matches.count)
        let id = try XCTUnwrap(scheduled.matches.keys.first)
        XCTAssertEqual(scheduled, MPRules.startReady(scheduled, match: id))
    }

    // Kotlin: choosingHousePlayerPreventsThirdParticipantAndNonhostChoice
    func testChoosingHousePlayerPreventsThirdParticipantAndNonhostChoice() throws {
        let chosen = try MPRules.addFriendlyHousePlayer(room(), actor: "host", bot: house)
        XCTAssertThrowsError(try MPRules.join(chosen, MPIdentity(id: "guest", name: "BlueTiger")))
        XCTAssertThrowsError(try MPRules.addFriendlyHousePlayer(room(), actor: "guest", bot: house))
    }
}
