import XCTest
@testable import MinikSplash

/// Port of Android NetworkStateTest.kt.
final class NetworkStateTests: XCTestCase {
    private func engine() -> SplashEngine {
        let members = (0...5).map { i in Member("p\(i)", Characters.all[i].id, team: i / 3, bot: i != 0) }
        return SplashEngine(members: members, mode: .teams, seed: 880)
    }

    private func json(_ node: Node) -> String {
        guard let text = NodeJSON.string(node) else {
            XCTFail("Snapshot is not valid JSON")
            return ""
        }
        return text
    }

    func testSharedSnapshotContainsNoQuestionsOrSolutions() {
        let e = engine()
        let n = json(WorldCodec.shared(e))
        XCTAssertFalse(n.isEmpty)
        for a in e.actors {
            XCTAssertFalse(n.contains(a.question!.en))
            XCTAssertFalse(n.contains("\"options\""))
            XCTAssertFalse(n.contains("\"answer\""))
            XCTAssertFalse(n.contains("\"profile\""))
        }
    }

    func testCheckpointRestoresPrivateProgressAirborneShotsAndConsumedIds() {
        let e = engine()
        let a = e.actors[0]
        let c = a.choices.first { $0.text == a.question!.answer }!
        a.position = c.position
        XCTAssertTrue(e.command("p0", "pickup", .pickup(questionId: a.question!.id, index: c.index)))
        XCTAssertTrue(e.command("p0", "release", .throwBalloon))
        e.tick(0.05)
        let copy = engine()
        WorldCodec.restore(copy, WorldCodec.checkpoint(e))
        XCTAssertEqual(e.time, copy.time, accuracy: 0.000001)
        XCTAssertEqual(a.question, copy.actors[0].question)
        XCTAssertEqual(e.shots[0].answer, copy.shots[0].answer)
        XCTAssertEqual(a.answers, copy.actors[0].answers)
        XCTAssertFalse(copy.command("p0", "release", .throwBalloon))
        XCTAssertEqual(e.serialState(), copy.serialState())
    }

    /// The same checkpoint survives the JSON text used by saved battles (and Firebase).
    func testCheckpointSurvivesJsonRoundTrip() {
        let e = engine()
        let a = e.actors[0]
        let c = a.choices.first { $0.text == a.question!.answer }!
        a.position = c.position
        XCTAssertTrue(e.command("p0", "pickup", .pickup(questionId: a.question!.id, index: c.index)))
        XCTAssertTrue(e.command("p0", "release", .throwBalloon))
        e.tick(0.05)
        guard let node = NodeJSON.node(json(WorldCodec.checkpoint(e))) else {
            XCTFail("Round trip failed")
            return
        }
        let copy = engine()
        WorldCodec.restore(copy, node)
        XCTAssertEqual(copy.questionSecret(), e.questionSecret())
        XCTAssertEqual(a.question, copy.actors[0].question)
        XCTAssertEqual(a.choices.map { $0.text }, copy.actors[0].choices.map { $0.text })
        XCTAssertEqual(a.choices.map { $0.color }, copy.actors[0].choices.map { $0.color })
        for (mine, restored) in zip(a.choices, copy.actors[0].choices) {
            XCTAssertEqual(mine.position.x, restored.position.x, accuracy: 1e-9)
            XCTAssertEqual(mine.position.y, restored.position.y, accuracy: 1e-9)
        }
        XCTAssertEqual(e.shots.count, copy.shots.count)
        XCTAssertEqual(e.shots[0].answer, copy.shots[0].answer)
        XCTAssertFalse(copy.command("p0", "release", .throwBalloon))
    }

    func testPublicReplicaShowsHeldColorWithoutOtherChoices() {
        let e = engine()
        let a = e.actors[1]
        a.held = 2
        let copy = engine()
        for actor in copy.actors {
            actor.question = nil
            actor.choices = []
        }
        WorldCodec.applyShared(copy, WorldCodec.shared(e))
        XCTAssertEqual(a.choices[2].color, copy.actors[1].publicHeldColor)
        XCTAssertNil(copy.actors[1].question)
        XCTAssertTrue(copy.actors[1].choices.isEmpty)
        WorldCodec.applyPersonal(copy.actors[0], WorldCodec.personal(e.actors[0]))
        XCTAssertNotNil(copy.actors[0].question)
        XCTAssertNil(copy.actors[1].question)
    }

    func testCompletedResultSurvivesCheckpointWithoutNewAward() {
        let e = engine()
        e.actors[2].score = 9
        e.finish()
        let copy = engine()
        WorldCodec.restore(copy, WorldCodec.checkpoint(e))
        for _ in 0..<100 { copy.tick(0.05) }
        XCTAssertEqual(e.result, copy.result)
    }

    func testSavedBattleRestoresThroughLocalStore() {
        let store = LocalBattleStore()
        store.clear()
        let members = (0...3).map { i in Member("p\(i)", Characters.all[i].id, team: i / 2, bot: i != 0) }
        let e = SplashEngine(members: members, mode: .teams, seed: 4242)
        for _ in 0..<60 { e.tick(0.05) }
        XCTAssertNil(e.result)
        store.save(e, cupRound: 1, cupScores: ["p0": 3], cup: true)
        XCTAssertTrue(store.hasBattle())
        let saved = store.load()
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.engine.time ?? -1, e.time, accuracy: 0.000001)
        XCTAssertEqual(saved?.engine.members, e.members)
        XCTAssertEqual(saved?.cup, true)
        XCTAssertEqual(saved?.round, 1)
        XCTAssertEqual(saved?.scores, ["p0": 3])
        XCTAssertEqual(saved?.engine.actors[0].question, e.actors[0].question)
        store.clear()
        XCTAssertFalse(store.hasBattle())
    }
}
