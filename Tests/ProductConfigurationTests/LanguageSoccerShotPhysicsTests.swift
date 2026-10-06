import XCTest
@testable import MinikPlus

final class LanguageSoccerShotPhysicsTests: XCTestCase {
    func testDragMustCrossAndroidReleaseThreshold() {
        XCTAssertFalse(LanguageSoccerLaunchPolicy.shouldLaunchDuringDrag(locationY: 279, releaseLineY: 280))
        XCTAssertTrue(LanguageSoccerLaunchPolicy.shouldLaunchDuringDrag(locationY: 278, releaseLineY: 280))
        XCTAssertFalse(LanguageSoccerLaunchPolicy.shouldLaunchOnRelease(locationY: 291, releaseLineY: 280))
        XCTAssertTrue(LanguageSoccerLaunchPolicy.shouldLaunchOnRelease(locationY: 290, releaseLineY: 280))
    }

    func testCancelledDragReturnsToIdleWithoutACompletedShot() {
        var lifecycle = LanguageSoccerShotLifecycle()
        let ball = SoccerBallID(rawValue: "letter.1")

        XCTAssertTrue(lifecycle.beginDragging(ballID: ball))
        lifecycle.cancelDrag(ballID: ball)

        XCTAssertEqual(lifecycle.phase, .idle)
        XCTAssertTrue(lifecycle.acceptsNewDrag)
    }

    func testLifecycleRejectsStaleAndDuplicateCallbacks() throws {
        var lifecycle = LanguageSoccerShotLifecycle()
        let ball = SoccerBallID(rawValue: "letter.1")
        let shot = UUID()
        let stale = UUID()

        XCTAssertTrue(lifecycle.beginDragging(ballID: ball))
        XCTAssertEqual(lifecycle.launch(ballID: ball, shotID: shot), shot)
        XCTAssertFalse(lifecycle.beginFlight(shotID: stale))
        XCTAssertTrue(lifecycle.beginFlight(shotID: shot))
        XCTAssertFalse(lifecycle.finalize(shotID: stale, outcome: .goal))
        XCTAssertTrue(lifecycle.finalize(shotID: shot, outcome: .goal))
        XCTAssertFalse(lifecycle.finalize(shotID: shot, outcome: .goal))
        XCTAssertTrue(lifecycle.resetAfterFinalized(shotID: shot))
    }

    func testOnlyOneShotCanLaunchAtATime() {
        var lifecycle = LanguageSoccerShotLifecycle()
        let first = SoccerBallID(rawValue: "letter.1")
        let second = SoccerBallID(rawValue: "letter.2")

        XCTAssertTrue(lifecycle.beginDragging(ballID: first))
        XCTAssertFalse(lifecycle.beginDragging(ballID: second))
        XCTAssertNotNil(lifecycle.launch(ballID: first))
        XCTAssertNil(lifecycle.launch(ballID: second))
    }

    func testLaunchCapturesTheSelectedPhysicalBallID() throws {
        var lifecycle = LanguageSoccerShotLifecycle()
        let ball = SoccerBallID(rawValue: "duplicate.physical.2")
        let shot = UUID()

        XCTAssertTrue(lifecycle.beginDragging(ballID: ball))
        XCTAssertEqual(lifecycle.launch(ballID: ball, shotID: shot), shot)
        XCTAssertEqual(lifecycle.phase, .launched(shotID: shot, ballID: ball))
    }

    func testMissFinalizesExactlyOnce() throws {
        var lifecycle = LanguageSoccerShotLifecycle()
        let ball = SoccerBallID(rawValue: "letter.1")
        let shot = UUID()

        XCTAssertTrue(lifecycle.beginDragging(ballID: ball))
        XCTAssertEqual(lifecycle.launch(ballID: ball, shotID: shot), shot)
        XCTAssertTrue(lifecycle.beginFlight(shotID: shot))
        XCTAssertTrue(lifecycle.finalize(shotID: shot, outcome: .miss))
        XCTAssertFalse(lifecycle.finalize(shotID: shot, outcome: .miss))
    }

    func testKeeperAndFrameReboundsCannotFinalizeTwice() throws {
        for outcome in [GameOutcome.saved, .miss] {
            var lifecycle = LanguageSoccerShotLifecycle()
            let ball = SoccerBallID(rawValue: "letter.1")
            let shot = UUID()

            XCTAssertTrue(lifecycle.beginDragging(ballID: ball))
            XCTAssertEqual(lifecycle.launch(ballID: ball, shotID: shot), shot)
            XCTAssertTrue(lifecycle.beginFlight(shotID: shot))
            XCTAssertTrue(lifecycle.beginRebound(shotID: shot))
            XCTAssertTrue(lifecycle.finalize(shotID: shot, outcome: outcome))
            XCTAssertFalse(lifecycle.finalize(shotID: shot, outcome: outcome))
        }
    }

    func testDragDirectionControlsGoalAndMiss() {
        let geometry = geometry(keeper: .init(minX: 80, minY: 70, width: 30, height: 80))

        let straight = geometry.resolve(
            start: .init(x: 200, y: 520),
            dragVelocity: .init(dx: 0, dy: -900)
        )
        let wide = geometry.resolve(
            start: .init(x: 200, y: 520),
            dragVelocity: .init(dx: 900, dy: -500)
        )

        XCTAssertEqual(straight.outcome, .goal)
        XCTAssertEqual(wide.outcome, .miss)
    }

    func testKeeperCollisionProducesSaveAndRebound() {
        let resolution = geometry(keeper: .init(minX: 150, minY: 80, width: 100, height: 100)).resolve(
            start: .init(x: 200, y: 520),
            dragVelocity: .init(dx: 0, dy: -900)
        )

        XCTAssertEqual(resolution.outcome, .saved)
        XCTAssertEqual(resolution.collision, .keeper)
        XCTAssertNotNil(resolution.reboundPoint)
    }

    func testPostCollisionProducesMissAndRebound() {
        let resolution = geometry(keeper: .init(minX: 80, minY: 70, width: 30, height: 80)).resolve(
            start: .init(x: 80, y: 520),
            dragVelocity: .init(dx: 0, dy: -900)
        )

        XCTAssertEqual(resolution.outcome, .miss)
        XCTAssertEqual(resolution.collision, .leftPost)
        XCTAssertNotNil(resolution.reboundPoint)
    }

    func testCrossbarCollisionIsRepresented() {
        let resolution = geometry(keeper: .init(minX: 80, minY: 70, width: 30, height: 80)).resolve(
            start: .init(x: 200, y: 115),
            dragVelocity: .init(dx: 0, dy: -900)
        )

        XCTAssertEqual(resolution.outcome, .miss)
        XCTAssertEqual(resolution.collision, .crossbar)
    }

    func testVelocityNormalizationAlwaysTravelsTowardGoal() {
        let normalized = LanguageSoccerVector(dx: 1_000, dy: 1).normalizedTowardGoal()

        XCTAssertLessThanOrEqual(normalized.dy, -0.20)
        XCTAssertEqual(normalized.magnitude, 1, accuracy: 0.000_001)
    }

    func testLevelAFirstTwoKeepersAreStationaryThenThirdMoves() {
        let tuning = LanguageSoccerKeeperTuning(level: .a)

        XCTAssertFalse(tuning.shouldMove(atAttemptIndex: 1))
        XCTAssertFalse(tuning.shouldMove(atAttemptIndex: 2))
        XCTAssertTrue(tuning.shouldMove(atAttemptIndex: 3))
        XCTAssertFalse(tuning.shouldMove(atAttemptIndex: 4))
    }

    func testLevelBFirstKeeperIsStationaryThenMovementPersists() {
        let tuning = LanguageSoccerKeeperTuning(level: .b)

        XCTAssertFalse(tuning.shouldMove(atAttemptIndex: 1))
        XCTAssertTrue(tuning.shouldMove(atAttemptIndex: 2))
        XCTAssertTrue(tuning.shouldMove(atAttemptIndex: 3))
    }

    func testLevelCStartsMovingImmediately() {
        XCTAssertTrue(LanguageSoccerKeeperTuning(level: .c).shouldMove(atAttemptIndex: 1))
    }

    func testKeeperSizeAndBaseSpeedIncreaseFromAToC() {
        let a = LanguageSoccerKeeperTuning(level: .a)
        let b = LanguageSoccerKeeperTuning(level: .b)
        let c = LanguageSoccerKeeperTuning(level: .c)

        XCTAssertLessThan(a.referenceWidth, b.referenceWidth)
        XCTAssertLessThan(b.referenceWidth, c.referenceWidth)
        XCTAssertGreaterThan(a.oneWaySweepDuration(totalShots: 0, goals: 0), b.oneWaySweepDuration(totalShots: 0, goals: 0))
        XCTAssertGreaterThan(b.oneWaySweepDuration(totalShots: 0, goals: 0), c.oneWaySweepDuration(totalShots: 0, goals: 0))
    }

    func testProductionConfigurationConsumesThePersistedParentSoccerLevel() {
        for level in LanguageSoccerLevel.allCases {
            let configuration = LanguageSoccerProductionConfiguration(parentSoccerLevel: level)

            XCTAssertEqual(configuration.keeperTuning.level, level)
        }
    }

    func testAndroidPerformanceAdjustmentBeginsAfterTenShotsAndRespectsMinimum() {
        let tuning = LanguageSoccerKeeperTuning(level: .a)

        XCTAssertEqual(tuning.oneWaySweepDuration(totalShots: 9, goals: 9), 3.0)
        XCTAssertEqual(tuning.oneWaySweepDuration(totalShots: 10, goals: 5), 2.0)
        XCTAssertEqual(tuning.oneWaySweepDuration(totalShots: 10, goals: 10), 1.0)
    }

    func testKeeperSweepUsesOnlyTheGoalMouthRange() {
        let tuning = LanguageSoccerKeeperTuning(level: .c)
        let goal = LanguageSoccerRect(minX: 80, minY: 40, width: 240, height: 120)

        let left = tuning.keeperMinX(at: 0, isMoving: true, totalShots: 0, goals: 0, goal: goal, keeperWidth: 95)
        let right = tuning.keeperMinX(at: 0.8, isMoving: true, totalShots: 0, goals: 0, goal: goal, keeperWidth: 95)

        XCTAssertEqual(left, goal.minX, accuracy: 0.000_001)
        XCTAssertEqual(right, goal.maxX - 95, accuracy: 0.000_001)
    }

    func testOnlyLevelCStartsEachNewWordWithAMovingKeeper() {
        XCTAssertFalse(LanguageSoccerKeeperTuning(level: .a).initiallyMoves)
        XCTAssertFalse(LanguageSoccerKeeperTuning(level: .b).initiallyMoves)
        XCTAssertTrue(LanguageSoccerKeeperTuning(level: .c).initiallyMoves)
    }

    func testLevelASettlePolicyMatchesAndroidLastTenBuckets() {
        let tuning = LanguageSoccerKeeperTuning(level: .a)

        XCTAssertFalse(tuning.settlesToCenterAfterMovingShot(recentGoals: 2, windowSize: 10, randomBucket: 0))
        XCTAssertTrue(tuning.settlesToCenterAfterMovingShot(recentGoals: 2, windowSize: 10, randomBucket: 1))
        XCTAssertFalse(tuning.settlesToCenterAfterMovingShot(recentGoals: 9, windowSize: 10, randomBucket: 1))
        XCTAssertTrue(tuning.settlesToCenterAfterMovingShot(recentGoals: 9, windowSize: 10, randomBucket: 2))
    }

    private func geometry(keeper: LanguageSoccerRect) -> LanguageSoccerShotGeometry {
        LanguageSoccerShotGeometry(
            field: .init(minX: 0, minY: 0, width: 400, height: 600),
            goal: .init(minX: 80, minY: 40, width: 240, height: 120),
            keeper: keeper,
            ballRadius: 12,
            postThickness: 8
        )
    }
}
