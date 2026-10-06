import XCTest
@testable import MinikPlus

final class PingPongMatchSessionTests: XCTestCase {
    func testMatchStartsAtZeroAndUsesDifficultyControlRules() {
        let starter = PingPongMatchSession(
            difficulty: .starter,
            controlMode: .swipe,
            targetScore: 7
        )
        XCTAssertEqual(starter.childScore, 0)
        XCTAssertEqual(starter.minikScore, 0)
        XCTAssertNil(starter.controlMode)
        XCTAssertEqual(starter.currentServer, .minik)

        let fullGame = PingPongMatchSession(
            difficulty: .medium,
            controlMode: .swipe,
            targetScore: 7
        )
        XCTAssertEqual(fullGame.controlMode, .swipe)
        XCTAssertEqual(fullGame.currentServer, .child)
    }

    func testStarterAndEasyAcceptSimpleTargetsAndDoNotRequireTwoPointLead() {
        for difficulty in [PingPongDifficulty.starter, .easy] {
            XCTAssertEqual(difficulty.allowedTargets, [3, 5, 7, 10])
            var match = PingPongMatchSession(difficulty: difficulty, targetScore: 7)
            award(6, to: .minik, in: &match)
            award(7, to: .child, in: &match)
            XCTAssertEqual(match.winner, .child)
        }
    }

    func testMediumAndHardRequireTwoPointLeadWithoutScoreCap() {
        for difficulty in [PingPongDifficulty.medium, .hard] {
            XCTAssertEqual(difficulty.allowedTargets, [3, 5, 7, 11])
            var match = PingPongMatchSession(difficulty: difficulty, targetScore: 7)
            award(6, to: .minik, in: &match)
            award(7, to: .child, in: &match)
            XCTAssertNil(match.winner)
            XCTAssertTrue(match.awardPoint(to: .child))
            XCTAssertEqual(match.winner, .child)

            var longMatch = PingPongMatchSession(difficulty: difficulty, targetScore: 11)
            award(10, to: .minik, in: &longMatch)
            award(11, to: .child, in: &longMatch)
            XCTAssertNil(longMatch.winner)
            XCTAssertTrue(longMatch.awardPoint(to: .child))
            XCTAssertEqual(longMatch.winner, .child)
            XCTAssertEqual(longMatch.childScore, 12)
        }
    }

    func testScoringStopsAfterTerminalMatch() {
        var match = PingPongMatchSession(difficulty: .easy, targetScore: 3)
        award(3, to: .minik, in: &match)
        XCTAssertEqual(match.winner, .minik)
        XCTAssertFalse(match.awardPoint(to: .child))
        XCTAssertEqual(match.childScore, 0)
        XCTAssertEqual(match.minikScore, 3)
    }

    func testEasyChildServesEveryRallyAndStarterMinikFeedsEveryRally() {
        var easy = PingPongMatchSession(difficulty: .easy, targetScore: 10)
        for scorer in [PingPongParticipant.child, .minik, .minik, .child] {
            XCTAssertTrue(easy.awardPoint(to: scorer))
            XCTAssertEqual(easy.currentServer, .child)
        }

        var starter = PingPongMatchSession(difficulty: .starter, targetScore: 10)
        for scorer in [PingPongParticipant.child, .minik, .child] {
            XCTAssertTrue(starter.awardPoint(to: scorer))
            XCTAssertEqual(starter.currentServer, .minik)
        }
    }

    func testMediumAndHardRotateTwoServesThenOneAtDeuce() {
        for difficulty in [PingPongDifficulty.medium, .hard] {
            var match = PingPongMatchSession(difficulty: difficulty, targetScore: 7)
            XCTAssertEqual(match.currentServer, .child)
            XCTAssertTrue(match.awardPoint(to: .child))
            XCTAssertEqual(match.currentServer, .child)
            XCTAssertTrue(match.awardPoint(to: .minik))
            XCTAssertEqual(match.currentServer, .minik)
            XCTAssertTrue(match.awardPoint(to: .child))
            XCTAssertEqual(match.currentServer, .minik)
            XCTAssertTrue(match.awardPoint(to: .minik))
            XCTAssertEqual(match.currentServer, .child)

            while match.childScore < 5 { XCTAssertTrue(match.awardPoint(to: .child)) }
            while match.minikScore < 5 { XCTAssertTrue(match.awardPoint(to: .minik)) }
            XCTAssertTrue(match.awardPoint(to: .child))
            let serverBeforeDeuce = match.currentServer
            XCTAssertTrue(match.awardPoint(to: .minik))
            XCTAssertEqual(match.childScore, 6)
            XCTAssertEqual(match.minikScore, 6)
            XCTAssertEqual(match.currentServer, serverBeforeDeuce.opponent)
            let deuceServer = match.currentServer
            XCTAssertTrue(match.awardPoint(to: .child))
            XCTAssertEqual(match.currentServer, deuceServer.opponent)
        }
    }

    func testPlayAgainResetsScoreAndServiceButPreservesSettings() {
        var match = PingPongMatchSession(
            difficulty: .hard,
            controlMode: .swipe,
            targetScore: 11
        )
        award(3, to: .child, in: &match)
        award(2, to: .minik, in: &match)
        match.startNextMatch()

        XCTAssertEqual(match.childScore, 0)
        XCTAssertEqual(match.minikScore, 0)
        XCTAssertEqual(match.currentServer, .child)
        XCTAssertNil(match.winner)
        XCTAssertEqual(match.difficulty, .hard)
        XCTAssertEqual(match.controlMode, .swipe)
        XCTAssertEqual(match.targetScore, 11)
    }

    private func award(
        _ count: Int,
        to participant: PingPongParticipant,
        in match: inout PingPongMatchSession
    ) {
        for _ in 0..<count {
            _ = match.awardPoint(to: participant)
        }
    }
}
