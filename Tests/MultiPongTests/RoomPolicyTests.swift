import XCTest
@testable import MinikMultiPingPong

// Android app/src/test/.../RoomPolicyTest.kt (MinikCrossPong 828c6fc): house-player tuning under room controls, nicknames,
// room inactivity and limits, duplicate house characters.
//
// Name map: Kotlin `RoomPolicy.warn/expired(s, now)` -> `MPSession.warning/expired(now)`; `RoomPolicy.canAdd(kind, rooms)` ->
// `MPController.hasSpace(kind)` over `rooms`; `Nicknames.candidate` -> `MPNames.candidate`; `ModernEngine(d, control, 7,
// botProfile, housePlayerControls = true)` -> `MPEngine(level:target:bot:houseControls: true)`; Kotlin STARTER/HARD ->
// MPLevel .easy/.superHard and the TAP/SWIPE control -> `MPLevel.pro`.

final class RoomPolicyTests: XCTestCase {
    private static let week: Int64 = 7 * 24 * 60 * 60 * 1000
    private static let now: Int64 = 30 * week

    private static let profileNumbers: [(String, KeyPath<MPProfile, Double>)] = [
        ("forehandServe", \MPProfile.forehandServe), ("serveSuccess", \MPProfile.serveSuccess), ("serveMiddle", \MPProfile.serveMiddle),
        ("serveSpeed", \MPProfile.serveSpeed), ("serveVariation", \MPProfile.serveVariation), ("answerDrop", \MPProfile.answerDrop),
        ("goodDrop", \MPProfile.goodDrop), ("backhandCrossGoodDrop", \MPProfile.backhandCrossGoodDrop),
        ("firstForehandSpeed", \MPProfile.firstForehandSpeed), ("firstBackhandSpeed", \MPProfile.firstBackhandSpeed),
        ("accelerateChance", \MPProfile.accelerateChance), ("maxSpeed", \MPProfile.maxSpeed),
    ]
    private static let profileChances: [(String, KeyPath<MPProfile, MPChance>)] = [
        ("forehandSame", \MPProfile.forehandSame), ("forehandCross", \MPProfile.forehandCross),
        ("backhandSame", \MPProfile.backhandSame), ("backhandCross", \MPProfile.backhandCross),
    ]
    private static let profileRanges: [(String, KeyPath<MPProfile, ClosedRange<Double>>)] = [
        ("forehandSpeedUp", \MPProfile.forehandSpeedUp), ("backhandSpeedUp", \MPProfile.backhandSpeedUp), ("speedDown", \MPProfile.speedDown),
    ]

    /// Kotlin data-class equality of `MinikProfile` (MPProfile and MPChance are not Equatable).
    private func assertSameProfile(_ p: MPProfile, _ q: MPProfile, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        for (name, path) in RoomPolicyTests.profileNumbers {
            XCTAssertEqual(p[keyPath: path], q[keyPath: path], accuracy: 0, "\(label) \(name)", file: file, line: line)
        }
        for (name, path) in RoomPolicyTests.profileChances {
            let a = p[keyPath: path]
            let b = q[keyPath: path]
            XCTAssertEqual(a.answer, b.answer, accuracy: 0, "\(label) \(name).answer", file: file, line: line)
            XCTAssertEqual(a.good, b.good, accuracy: 0, "\(label) \(name).good", file: file, line: line)
        }
        for (name, path) in RoomPolicyTests.profileRanges {
            XCTAssertEqual(p[keyPath: path], q[keyPath: path], "\(label) \(name)", file: file, line: line)
        }
        XCTAssertEqual(p.serveReceive.count, q.serveReceive.count, "\(label) serveReceive", file: file, line: line)
        for (index, pair) in zip(p.serveReceive, q.serveReceive).enumerated() {
            XCTAssertEqual(pair.0.answer, pair.1.answer, accuracy: 0, "\(label) serveReceive[\(index)].answer", file: file, line: line)
            XCTAssertEqual(pair.0.good, pair.1.good, accuracy: 0, "\(label) serveReceive[\(index)].good", file: file, line: line)
        }
    }

    /// Kotlin `room()`: a friendly pair created three weeks ago; Kotlin's create leaves lastActivityAt at 0 (Swift stamps it).
    private func room() -> MPSession {
        var s = MPSession(code: "ABC234", kind: .friendly, host: MPIdentity(id: "me", name: "GreenFrog"), capacity: 2, legs: 1,
                          winPoints: 3, difficulty: 0, target: 3)
        s.createdAt = RoomPolicyTests.now - 3 * RoomPolicyTests.week
        s.lastActivityAt = 0
        return s
    }

    private func house(_ id: String, _ name: String, _ character: MPHousePlayer) -> MPParticipant {
        MPParticipant(identity: MPIdentity(id: id, name: name), bot: character.profile)
    }

    // Kotlin: roomControlDifficultyDoesNotChangeHousePlayerSkillOrPace
    func testRoomControlDifficultyDoesNotChangeHousePlayerSkillOrPace() {
        for c in MPRoster.all {
            let easy = MPEngine(level: .easy, target: 7, bot: c.profile, houseControls: true)
            let real = MPEngine(level: .superHard, target: 7, bot: c.profile, houseControls: true)
            XCTAssertFalse(easy.level.pro, c.id)    // Kotlin Control.TAP
            XCTAssertTrue(real.level.pro, c.id)     // Kotlin Control.SWIPE
            assertSameProfile(easy.tuning.profile, real.tuning.profile, c.id)
            XCTAssertEqual(easy.tuning.minikReactionInterval, real.tuning.minikReactionInterval, accuracy: 0, c.id)
            XCTAssertEqual(easy.tuning.ballBaseSpeed, real.tuning.ballBaseSpeed, accuracy: 0, c.id)
            XCTAssertEqual(MPTuning.values(.superHard).swipeCollisionForgiveness, real.tuning.swipeCollisionForgiveness, accuracy: 0, c.id)
            XCTAssertTrue(easy.tuning.swipeCollisionForgiveness > real.tuning.swipeCollisionForgiveness, c.id)
        }
    }

    // Kotlin: oneHundredUniqueCuteNamesInEachLanguageWithValidSuffixes
    func testOneHundredUniqueCuteNamesInEachLanguageWithValidSuffixes() {
        for he in [false, true] {
            // Kotlin Nicknames.choices(he): the 100 suffix-free names.
            let choices = (0..<100).map { MPNames.candidate($0, hebrew: he) }
            XCTAssertEqual(100, Set(choices).count)
            for i in 0..<100 {
                for suffix in [0, 1, 22, 9999] {
                    let name = MPNames.candidate(i, hebrew: he, suffix: suffix)
                    // Not ported: assertTrue(Nicknames.allowed(name)) — Swift has no nickname validator.
                    XCTAssertTrue(name.utf16.count <= 18, name)
                }
            }
        }
        XCTAssertEqual("GreenFrog22", MPNames.candidate(0, hebrew: false, suffix: 22))
        // Not ported: assertFalse(Nicknames.allowed(...)) for "Free text", "Player", "GreenFrog-1", "GreenFrog000", "<script>" —
        // Swift has no nickname validator (names are only generated from MPNames.candidate).
    }

    // Kotlin: anyParticipantActivityResetsBothThresholds
    func testAnyParticipantActivityResetsBothThresholds() {
        let now = RoomPolicyTests.now
        let week = RoomPolicyTests.week
        var s = room()
        s.lastActivityAt = now - week
        XCTAssertTrue(s.warning(now))
        XCTAssertFalse(s.expired(now))
        var active = s
        active.lastActivityAt = now
        XCTAssertFalse(active.warning(now))
        var idle = s
        idle.lastActivityAt = now - 2 * week
        XCTAssertTrue(idle.expired(now))
        XCTAssertTrue(room().expired(now))   // legacy records use creation time
        var fresh = room()
        fresh.createdAt = now
        fresh.lastActivityAt = 0
        XCTAssertFalse(fresh.expired(now))
    }

    // Kotlin: threeOpenPerCategoryWithFinishedGamesExcluded
    @MainActor
    func testThreeOpenPerCategoryWithFinishedGamesExcluded() throws {
        let suite = "RoomPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = MPController(experience: .full, preferences: MPPreferences(defaults),
                                      repository: MPLocalRepository(defaults: defaults), onClose: { _ in })
        var rooms: [MPSession] = []
        for i in 0..<3 {
            var r = room()
            r.code = "CODE\(i)"
            rooms.append(r)
        }
        controller.rooms = rooms
        XCTAssertFalse(controller.hasSpace(.friendly))
        XCTAssertTrue(controller.hasSpace(.tournament))
        var oneFinished = rooms
        oneFinished[2].state = "FINISHED"
        controller.rooms = oneFinished
        XCTAssertTrue(controller.hasSpace(.friendly))
    }

    // Kotlin: duplicateHouseCharactersAreNumberedInTournamentsAndRejectedInFriendlies
    // (a tournament may repeat a house character, numbered "Flare 2"; a friendly room seats it once)
    func testDuplicateHouseCharactersAreNumberedInTournamentsAndRejectedInFriendlies() throws {
        var s = room()
        s.kind = .tournament
        s.capacity = 4
        let flare = try XCTUnwrap(MPRoster.find("flare"))
        let kyra = try XCTUnwrap(MPRoster.find("kyra"))
        let added = try MPRules.addBot(s, actor: "me", bot: house("bot_one", "Flare", flare))
        let twice = try MPRules.addBot(added, actor: "me", bot: house("bot_two", "Flare", flare))
        XCTAssertEqual("Flare 2", twice.participants["bot_two"]?.identity.name)
        XCTAssertEqual("Flare 2", twice.participants["bot_two"]?.name(hebrew: true))
        XCTAssertThrowsError(try MPRules.addBot(added, actor: "me", bot: house("bot_one", "Flare", flare)))   // the same id twice
        XCTAssertEqual(3, try MPRules.addBot(added, actor: "me", bot: house("bot_three", "Kyra", kyra)).participants.count)
        var friendlyRoom = room()
        friendlyRoom.capacity = 4
        friendlyRoom.tableSize = 4
        let friendly = try MPRules.addBot(friendlyRoom, actor: "me", bot: house("bot_one", "Flare", flare))
        XCTAssertThrowsError(try MPRules.addBot(friendly, actor: "me", bot: house("bot_two", "Flare", flare)))
    }

    // Not ported: noticesUseStableMatchIdsAndNewInactivityPeriods — Kotlin RoomPolicy.otherResults/resultId/warningId feed the
    // Android notice book; iOS retired those notices (MPPreferences: "routine news notices ... are retired") and has no
    // equivalent API.
}
