import XCTest
@testable import MinikSplash

/// Port of Android core/SplashCoreTest.kt.
final class SplashCoreTests: XCTestCase {
    private var seq = 0

    private func roster(_ bots: Bool = false) -> [Member] {
        return Characters.all.prefix(6).enumerated().map { pair in
            Member("p\(pair.offset)", pair.element.id, team: pair.offset < 3 ? 0 : 1, bot: bots)
        }
    }

    private func world(_ mode: GameMode = .solo, bots: Bool = false, config: SplashConfig = SplashConfig()) -> SplashEngine {
        return SplashEngine(members: roster(bots), mode: mode, seed: 73, config: config)
    }

    @discardableResult
    private func send(_ e: SplashEngine, _ id: String, _ c: Command) -> Bool {
        seq += 1
        return e.command(id, "test-\(seq)", c)
    }

    private func take(_ e: SplashEngine, _ id: String, correct: Bool = true) {
        guard let a = e.actor(id), let q = a.question,
              let c = a.choices.first(where: { ($0.text == q.answer) == correct }) else {
            XCTFail("No choice")
            return
        }
        a.position = c.position
        XCTAssertTrue(send(e, id, .pickup(questionId: q.id, index: c.index)))
    }

    func testSixIndependentPlayersAndPrivacy() {
        let e = world(.teams)
        XCTAssertEqual(e.actors.count, 6)
        XCTAssertEqual(Set(e.actors.compactMap { $0.question?.id }).count, 6)
        let a = e.actors[0]
        a.position = a.choices[0].position
        e.tick(0.05)
        XCTAssertNil(a.held)
        XCTAssertFalse(send(e, a.member.id, .pickup(questionId: e.actors[1].question?.id ?? "", index: 0)))
    }

    func testReleaseImmediatelyAdvancesWhileOlderShotIsFlying() {
        let e = world()
        let a = e.actors[0]
        let q = a.question?.id
        take(e, "p0")
        send(e, "p0", .throwBalloon)
        XCTAssertNotEqual(q, a.question?.id)
        XCTAssertEqual(e.shots.count, 1)
        XCTAssertEqual(q, e.shots.first?.questionId)
        XCTAssertEqual(a.answers.count, 1)
        take(e, "p0")
        send(e, "p0", .throwBalloon)
        XCTAssertEqual(e.shots.count, 2)
        XCTAssertEqual(e.actors[1].sequence, 1)
    }

    func testWrongPopHasRealCostWithoutFakeOpponentScore() {
        let e = world()
        let a = e.actors[0]
        a.score = 4
        let old = a.question?.id
        let correct = a.question?.answer
        take(e, "p0", correct: false)
        send(e, "p0", .throwBalloon)
        XCTAssertEqual(a.score, 3)
        XCTAssertEqual(a.paint.count, 1)
        XCTAssertEqual(e.shots.count, 0)
        XCTAssertEqual(a.feedback?.answer, correct)
        XCTAssertEqual(a.feedback?.questionId, old)
        XCTAssertEqual(a.answers.count, 1)
        XCTAssertFalse(a.answers.first?.correct ?? true)
        XCTAssertNotEqual(old, a.question?.id)
        XCTAssertTrue(e.actors.dropFirst().allSatisfy { $0.score == 0 })
    }

    func testDuplicateEventsDoNotRepeatThrowOrScore() {
        let e = world()
        take(e, "p0")
        XCTAssertTrue(e.command("p0", "throw-1", .throwBalloon))
        XCTAssertFalse(e.command("p0", "throw-1", .throwBalloon))
        XCTAssertEqual(e.shots.count, 1)
    }

    func testOldExplosionDoesNotOverwriteNewQuestion() {
        let e = world()
        take(e, "p0")
        send(e, "p0", .throwBalloon)
        let a = e.actors[0]
        let next = a.question?.id
        for _ in 0..<600 { e.tick(1.0 / 120) }
        XCTAssertEqual(next, a.question?.id)
        XCTAssertEqual(a.answers.count, 1)
    }

    func testJumpingAndCrouchingHaveDifferentGeometry() {
        func hit(_ pose: Command?, _ h: Double) -> Bool {
            let e = world()
            let a = e.actors[1]
            a.position = V(6, 6)
            for other in e.actors where other !== a { other.position = V(1, 1) }
            if let pose = pose { send(e, "p1", pose) }
            if pose == .jump { for _ in 0..<20 { e.tick(0.02) } }
            e.shots.append(Shot(id: "s", owner: "p0", questionId: "q", answer: "1", explanation: "", color: 0, position: V(5.5, 6),
                                height: h, velocity: V(5, 0), vz: 0))
            for _ in 0..<5 { e.tick(0.02) }
            return !a.paint.isEmpty
        }
        XCTAssertTrue(hit(nil, 0.85))
        XCTAssertFalse(hit(.jump, 0.40))
        XCTAssertFalse(hit(.crouch, 1.35))
        XCTAssertTrue(hit(.crouch, 0.3))
    }

    func testFriendlyFireOffAndSingleHitPerBalloon() {
        let e = world(.teams)
        for a in e.actors { a.position = V(1, 1) }
        e.actors[1].position = V(5.5, 6)
        e.actors[3].position = V(6.5, 6)
        e.shots.append(Shot(id: "one", owner: "p0", questionId: "q", answer: "1", explanation: "", color: 1, position: V(5, 6),
                            height: 1.1, velocity: V(5, 0), vz: 0))
        for _ in 0..<50 { e.tick(0.02) }
        XCTAssertEqual(e.actors[1].paint.count, 0)
        XCTAssertEqual(e.actors[3].paint.count, 1)
        XCTAssertEqual(e.actors[0].score, 1)
        XCTAssertEqual(e.teamScores[0], 1)
        XCTAssertEqual(e.shots.count, 0)
    }

    func testPaintCleaningPreservesSelection() {
        var config = SplashConfig()
        config.paintLayers = 1
        let e = world(config: config)
        let a = e.actors[1]
        take(e, "p1")
        let q = a.question?.id
        let held = a.held
        for other in e.actors { other.position = V(1, 1) }
        a.position = V(6, 6)
        e.shots.append(Shot(id: "s", owner: "p0", questionId: "old", answer: "1", explanation: "", color: 2, position: V(5.5, 6),
                            height: 1.1, velocity: V(5, 0), vz: 0))
        for _ in 0..<100 { e.tick(0.02) }
        XCTAssertEqual(q, a.question?.id)
        XCTAssertEqual(held, a.held)
        XCTAssertTrue(a.paint.isEmpty)
    }

    func testGeneratorsAreValidAcrossSeedsAndLevels() {
        for s in Skill.allCases {
            for l in 0...5 {
                for seed in 0...499 {
                    let q = QuestionBank.generate("\(seed)", s, l, KotlinRandom(seed: Int64(seed)), hebrew: seed % 2 == 0)
                    XCTAssertEqual(Set(q.options).count, 4)
                    XCTAssertEqual(q.options.filter { $0 == q.answer }.count, 1)
                    XCTAssertFalse(q.answer.contains("NaN"))
                    XCTAssertFalse(q.answer.contains("Infinity"))
                    XCTAssertTrue(q.isValid)
                    if s == .fraction {
                        let values = q.options.map { option -> Double in
                            let p = option.split(separator: "/").map { Double(String($0)) ?? 0 }
                            return p[0] / (p.count > 1 ? p[1] : 1)
                        }
                        XCTAssertEqual(Set(values).count, 4)
                    }
                }
            }
        }
    }

    func testAllMatchFormatsCompleteWithBots() {
        for mode in GameMode.allCases {
            let counts = mode == .teams ? [4, 6] : Array(2...6)
            for n in counts {
                let members = roster(true).prefix(n).enumerated().map { pair -> Member in
                    var m = pair.element
                    m.team = pair.offset < n / 2 ? 0 : 1
                    return m
                }
                var config = SplashConfig()
                config.duration = 25
                let e = SplashEngine(members: Array(members), mode: mode, seed: Int64(n), config: config)
                for _ in 0..<3200 { e.tick(1.0 / 120) }
                XCTAssertNotNil(e.result)
                XCTAssertEqual(e.result?.scores.count, n)
                XCTAssertTrue(e.actors.allSatisfy { $0.sequence > 1 })
            }
        }
    }

    func testMasteryIsPerSkillAndHintDoesNotCountIndependent() {
        let p = LearningProfile()
        for _ in 0..<3 { p.record(.add, correct: true, hint: false) }
        XCTAssertEqual(p.state(.add).level, 1)
        XCTAssertEqual(p.state(.english).level, 0)
        p.record(.add, correct: true, hint: true)
        XCTAssertEqual(p.state(.add).independent, 3)
        XCTAssertEqual(p.state(.add).assisted, 1)
    }

    func testPauseDoesNotAdvanceBattle() {
        let e = world()
        e.paused = true
        e.tick(0.1)
        XCTAssertEqual(e.time, 0.0)
    }

    func testGestureDoubleTapDoesNotFirstJumpOrThrow() {
        var events: [TouchAction] = []
        let g = Gestures { events.append($0) }
        let arc = TouchTarget(kind: .arc)
        g.down(0, 10, 10, 0, arc)
        g.up(0, 10, 10, 20)
        g.down(1, 10, 10, 100, arc)
        g.up(1, 10, 10, 130)
        g.flush(500)
        XCTAssertEqual(events.filter { $0.type == "tap" }.count, 0)
        XCTAssertEqual(events.filter { $0.type == "double" }.count, 1)
    }

    func testTwoPointersLockTargetsAndCancel() {
        var events: [TouchAction] = []
        let g = Gestures { events.append($0) }
        g.down(0, 10, 10, 0, TouchTarget(kind: .body))
        g.down(1, 100, 10, 1, TouchTarget(kind: .arc))
        g.move(0, 130, 40)
        g.move(1, 10, 40)
        XCTAssertEqual(events.first(where: { $0.type == "drag" && $0.pointer == 0 })?.target.kind, .body)
        XCTAssertEqual(events.first(where: { $0.type == "drag" && $0.pointer == 1 })?.target.kind, .arc)
        g.cancel()
        XCTAssertEqual(g.pointerCount, 0)
        g.flush(1000)
        XCTAssertEqual(events.filter { $0.type == "tap" }.count, 0)
    }

    func testTapDelayIsBounded() {
        var events: [TouchAction] = []
        let g = Gestures { events.append($0) }
        g.down(0, 1, 1, 0, TouchTarget(kind: .body))
        g.up(0, 1, 1, 20)
        g.flush(239)
        XCTAssertEqual(events.filter { $0.type == "tap" }.count, 0)
        g.flush(240)
        XCTAssertEqual(events.filter { $0.type == "tap" }.count, 1)
    }
}
