import XCTest
@testable import MinikPlus

final class MathLevelProgressionTests: XCTestCase {
    func testFirstRunDefaultsToAutomaticM1() {
        let controller = MathLevelController()
        XCTAssertEqual(controller.state.mode, .automatic)
        XCTAssertEqual(controller.state.activeLevelID, .m1)
        XCTAssertEqual(controller.state.phase, .calibration)
    }

    func testDefaultReadinessPromotesCalibrationIntoM3ButNotM4() throws {
        var controller = MathLevelController()
        for index in 1...3 {
            controller.record(try attempt(index: index, result: .correct, level: .m1))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m3)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testCalibrationCanSkipTwoReadyLevelsAfterThreeCorrect() throws {
        var controller = MathLevelController(
            implementationReadyLevelIDs: [.m1, .m2, .m3]
        )
        for index in 1...3 {
            controller.record(try attempt(index: index, result: .correct, level: .m1))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m3)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testEightFirstAttemptCorrectPromotesAfterCalibrationSettles() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        var controller = MathLevelController(
            state: state,
            implementationReadyLevelIDs: [.m1, .m2]
        )
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m1))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m2)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testFourFailuresInSixAttemptProbationReverts() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m2
        state.previousLevelID = .m1
        state.phase = .promotionProbation
        var controller = MathLevelController(
            state: state,
            implementationReadyLevelIDs: [.m1, .m2]
        )
        let results: [GradedAttemptResult] = [
            .incorrect, .correct, .incorrect, .incorrect, .correct, .skipped
        ]
        for (offset, result) in results.enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m2))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m1)
        XCTAssertEqual(controller.state.cooldownRemaining, 10)
    }

    func testStableM2PromotesIntoM3AfterEightCorrectAttempts() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m2
        var controller = MathLevelController(state: state)
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m2))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m3)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testM3ProbationFailureFallsBackToM2() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m3
        state.previousLevelID = .m2
        state.phase = .promotionProbation
        var controller = MathLevelController(state: state)
        for (offset, result) in [
            GradedAttemptResult.incorrect, .incorrect, .correct,
            .incorrect, .correct, .incorrect
        ].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m3))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m2)
        XCTAssertEqual(controller.state.cooldownRemaining, 10)
    }

    func testStableM3PromotesIntoM4AfterEightCorrectAttempts() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m3
        var controller = MathLevelController(state: state)
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m3))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m4)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testM4ProbationFailureFallsBackToM3() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m4
        state.previousLevelID = .m3
        state.phase = .promotionProbation
        var controller = MathLevelController(state: state)
        for (offset, result) in [
            GradedAttemptResult.incorrect, .incorrect, .correct,
            .incorrect, .correct, .incorrect
        ].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m4))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m3)
        XCTAssertEqual(controller.state.cooldownRemaining, 10)
    }

    func testStableM4PromotesIntoM5AfterEightCorrectAttempts() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m4
        var controller = MathLevelController(state: state)
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m4))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m5)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testM5ProbationFailureFallsBackToM4() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m5
        state.previousLevelID = .m4
        state.phase = .promotionProbation
        var controller = MathLevelController(state: state)
        for (offset, result) in [
            GradedAttemptResult.incorrect, .incorrect, .correct,
            .incorrect, .correct, .incorrect
        ].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m5))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m4)
        XCTAssertEqual(controller.state.cooldownRemaining, 10)
    }

    func testStableM5PromotesIntoM6AfterEightCorrectAttempts() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m5
        var controller = MathLevelController(state: state)
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m5))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m6)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testM6ProbationFailureFallsBackToM5() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m6
        state.previousLevelID = .m5
        state.phase = .promotionProbation
        var controller = MathLevelController(state: state)
        for (offset, result) in [
            GradedAttemptResult.incorrect, .incorrect, .correct,
            .incorrect, .correct, .incorrect
        ].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m6))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m5)
        XCTAssertEqual(controller.state.cooldownRemaining, 10)
    }

    func testStableM6PromotesIntoM7AfterEightCorrectAttempts() throws {
        var state = MathLevelState.firstRun; state.phase = .stable; state.activeLevelID = .m6
        var controller = MathLevelController(state: state)
        for index in 1...8 { controller.record(try attempt(index: index, result: .correct, level: .m6)) }
        XCTAssertEqual(controller.state.activeLevelID, .m7)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testM7ProbationFailureFallsBackToM6() throws {
        var state = MathLevelState.firstRun; state.activeLevelID = .m7; state.previousLevelID = .m6; state.phase = .promotionProbation
        var controller = MathLevelController(state: state)
        for (offset, result) in [GradedAttemptResult.incorrect, .incorrect, .correct, .incorrect, .correct, .incorrect].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m7))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m6)
    }

    func testStableM7PromotesIntoM8AfterEightCorrectAttempts() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m7
        var controller = MathLevelController(
            state: state,
            implementationReadyLevelIDs: [.m1, .m2, .m3, .m4, .m5, .m6, .m7, .m8]
        )
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m7))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m8)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testM8ProbationFailureFallsBackToM7() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m8
        state.previousLevelID = .m7
        state.phase = .promotionProbation
        var controller = MathLevelController(
            state: state,
            implementationReadyLevelIDs: [.m1, .m2, .m3, .m4, .m5, .m6, .m7, .m8]
        )
        for (offset, result) in [
            GradedAttemptResult.incorrect, .incorrect, .correct,
            .incorrect, .correct, .incorrect
        ].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m8))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m7)
        XCTAssertEqual(controller.state.cooldownRemaining, 10)
    }

    func testStableM8PromotesIntoM9AfterEightCorrectAttempts() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m8
        var controller = MathLevelController(state: state)
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m8))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m9)
        XCTAssertEqual(controller.state.phase, .promotionProbation)
    }

    func testM9ProbationFailureFallsBackToM8() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m9
        state.previousLevelID = .m8
        state.phase = .promotionProbation
        var controller = MathLevelController(state: state)
        for (offset, result) in [
            GradedAttemptResult.incorrect, .incorrect, .correct,
            .incorrect, .correct, .incorrect
        ].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m9))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m8)
        XCTAssertEqual(controller.state.cooldownRemaining, 10)
    }

    func testStableM9PromotesIntoM10AndM10IsUpperBound() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m9
        var controller = MathLevelController(state: state)
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m9))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m10)
        XCTAssertEqual(controller.state.phase, .promotionProbation)

        state.activeLevelID = .m10
        state.phase = .stable
        controller = MathLevelController(state: state)
        for index in 1...8 {
            controller.record(try attempt(index: index, result: .correct, level: .m10))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m10)
        XCTAssertEqual(controller.state.phase, .stable)
    }

    func testM10ProbationFailureFallsBackToM9() throws {
        var state = MathLevelState.firstRun
        state.activeLevelID = .m10
        state.previousLevelID = .m9
        state.phase = .promotionProbation
        var controller = MathLevelController(state: state)
        for (offset, result) in [
            GradedAttemptResult.incorrect, .incorrect, .correct,
            .incorrect, .correct, .incorrect
        ].enumerated() {
            controller.record(try attempt(index: offset + 1, result: result, level: .m10))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m9)
    }

    func testManualModeNeverAdaptsAndBecomesAutomaticStartingPoint() throws {
        var controller = MathLevelController(
            implementationReadyLevelIDs: [.m1, .m2, .m3, .m4, .m5, .m6]
        )
        controller.setManualLevel(.m6)
        for index in 1...20 {
            controller.record(try attempt(index: index, result: .incorrect, level: .m6))
        }
        XCTAssertEqual(controller.state.activeLevelID, .m6)
        controller.returnToAutomatic()
        XCTAssertEqual(controller.state.activeLevelID, .m6)
        XCTAssertEqual(controller.state.phase, .calibration)
    }

    func testManualStateIsNotClampedByCurrentImplementationReadiness() {
        var state = MathLevelState.firstRun
        state.mode = .manual
        state.activeLevelID = .m6

        let controller = MathLevelController(state: state)

        XCTAssertEqual(controller.state.activeLevelID, .m6)
    }

    func testInstructionAndNonCurriculumFamiliesDoNotAdapt() throws {
        var controller = MathLevelController(
            implementationReadyLevelIDs: [.m1, .m2, .m3]
        )
        for family in [ActivityFamily.learn, .cards, .pingPong] {
            for index in 1...3 {
                controller.record(try attempt(
                    index: index,
                    result: .correct,
                    level: .m1,
                    family: family
                ))
            }
        }
        XCTAssertEqual(controller.state.phaseAttemptCount, 0)
        XCTAssertEqual(controller.state.activeLevelID, .m1)
    }

    func testSlowResponseIsRecordedButCannotDemoteByItself() throws {
        var state = MathLevelState.firstRun
        state.phase = .stable
        state.activeLevelID = .m2
        var controller = MathLevelController(
            state: state,
            implementationReadyLevelIDs: [.m1, .m2]
        )
        controller.record(try attempt(
            index: 1,
            result: .correct,
            level: .m2,
            seconds: 121
        ))
        XCTAssertEqual(controller.state.activeLevelID, .m2)
        XCTAssertEqual(controller.state.verySlowSignalCount, 1)
        XCTAssertEqual(controller.state.timeBaselines[.multipleChoice]?.sampleCount, 1)
    }

    func testRepositoryPersistsModeAndActiveLevel() {
        let suite = "MathLevelProgressionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = LocalMathLevelRepository(userDefaults: defaults, storageKey: "state")
        var state = MathLevelState.firstRun
        state.mode = .manual
        state.activeLevelID = .m4
        repository.save(state)

        XCTAssertEqual(repository.load(), state)
    }

    private func attempt(
        index: Int,
        result: GradedAttemptResult,
        level: MathCurriculumLevelID,
        family: ActivityFamily = .multipleChoice,
        seconds: Double? = nil
    ) throws -> ActivityAttemptData {
        try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "item-\(index)"),
            attemptIndex: 1,
            result: result,
            responseDurationSeconds: seconds,
            activityFamily: family,
            mathLevelID: level,
            skillID: MathSkillIDs.quantityToNumber
        ))
    }
}
