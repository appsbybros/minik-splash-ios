import XCTest
@testable import MinikPlus

final class EducationalProgressReadModelTests: XCTestCase {
    private let baseDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testEmptyStateReportsNoFabricatedHistory() {
        let model = EducationalProgressReadModelBuilder.make(
            snapshot: ProgressSnapshot(),
            product: .minikPlus
        )

        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.totalAttempts, 0)
        XCTAssertNil(model.firstAttemptAccuracy)
        XCTAssertEqual(model.practiceDurationSeconds, 0)
        XCTAssertTrue(model.activityRows.isEmpty)
        XCTAssertTrue(model.recentPractice.isEmpty)
    }

    func testOneAttemptProducesActualFirstAttemptMetrics() throws {
        var snapshot = ProgressSnapshot()
        snapshot.apply(try event(
            activityID: "math.visualToAnswer",
            itemID: "m3.visual.1",
            attemptIndex: 1,
            result: .correct,
            duration: 4.5,
            occurredAt: baseDate,
            levelID: .m3
        ))

        let model = EducationalProgressReadModelBuilder.make(
            snapshot: snapshot,
            product: .minikMath
        )

        XCTAssertEqual(model.totalAttempts, 1)
        XCTAssertEqual(model.firstAttemptCount, 1)
        XCTAssertEqual(model.firstAttemptCorrectCount, 1)
        XCTAssertEqual(model.firstAttemptAccuracy, 1)
        XCTAssertEqual(model.practiceDurationSeconds, 4.5)
        XCTAssertEqual(model.activityRows.map(\.activityID.rawValue), ["math.visualToAnswer"])
    }

    func testMultipleActivitiesUseDeterministicIdentifierOrdering() throws {
        var snapshot = ProgressSnapshot()
        snapshot.apply(try event(activityID: "math.visualToAnswer", itemID: "visual", occurredAt: baseDate))
        snapshot.apply(try event(activityID: "math.buildMath", itemID: "build", occurredAt: baseDate))
        snapshot.apply(try event(activityID: "math.mathPairs", itemID: "pairs", occurredAt: baseDate))

        let model = EducationalProgressReadModelBuilder.make(snapshot: snapshot, product: .minikMath)

        XCTAssertEqual(model.activityRows.map(\.activityID.rawValue), [
            "math.buildMath", "math.mathPairs", "math.visualToAnswer"
        ])
    }

    func testRetryCountsAsEffortWithoutChangingFirstAttemptMastery() throws {
        var snapshot = ProgressSnapshot()
        snapshot.apply(try event(
            activityID: "math.buildNumber",
            itemID: "same-item",
            attemptIndex: 1,
            result: .incorrect,
            duration: 3,
            occurredAt: baseDate
        ))
        snapshot.apply(try event(
            activityID: "math.buildNumber",
            itemID: "same-item",
            attemptIndex: 2,
            result: .correct,
            duration: 2,
            occurredAt: baseDate.addingTimeInterval(2)
        ))

        let model = EducationalProgressReadModelBuilder.make(snapshot: snapshot, product: .minikMath)

        XCTAssertEqual(model.totalAttempts, 2)
        XCTAssertEqual(model.firstAttemptCount, 1)
        XCTAssertEqual(model.firstAttemptCorrectCount, 0)
        XCTAssertEqual(model.firstAttemptAccuracy, 0)
        XCTAssertEqual(model.practiceDurationSeconds, 5)
    }

    func testReplayedEventDoesNotDoubleCount() throws {
        var snapshot = ProgressSnapshot()
        let replayed = try event(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            activityID: "math.mathMemory",
            itemID: "memory-pair",
            duration: 8,
            occurredAt: baseDate
        )

        snapshot.apply(replayed)
        snapshot.apply(replayed)

        let model = EducationalProgressReadModelBuilder.make(snapshot: snapshot, product: .minikMath)
        XCTAssertEqual(model.totalAttempts, 1)
        XCTAssertEqual(model.practiceDurationSeconds, 8)
    }

    func testPracticeTimeAggregatesOnlySelectedProduct() throws {
        var snapshot = ProgressSnapshot()
        snapshot.apply(try event(activityID: "math.mathSoccer", itemID: "math", duration: 12, occurredAt: baseDate))
        snapshot.apply(try event(
            product: .minikPlus,
            activityID: "language.imageToWord",
            itemID: "language",
            duration: 30,
            occurredAt: baseDate
        ))

        let math = EducationalProgressReadModelBuilder.make(snapshot: snapshot, product: .minikMath)
        let language = EducationalProgressReadModelBuilder.make(snapshot: snapshot, product: .minikPlus)

        XCTAssertEqual(math.practiceDurationSeconds, 12)
        XCTAssertEqual(language.practiceDurationSeconds, 30)
    }

    func testMathLevelAndModeAreReportedWithoutLanguageLevelLeakage() {
        let state = mathState(levelID: .m8, mode: .manual)

        let math = EducationalProgressReadModelBuilder.make(
            snapshot: ProgressSnapshot(),
            product: .minikMath,
            mathLevelState: state
        )
        let language = EducationalProgressReadModelBuilder.make(
            snapshot: ProgressSnapshot(),
            product: .minikPlus,
            mathLevelState: state
        )

        XCTAssertEqual(math.mathLevelID, .m8)
        XCTAssertEqual(math.mathLevelMode, .manual)
        XCTAssertNil(language.mathLevelID)
        XCTAssertNil(language.mathLevelMode)
    }

    func testLearnCardsAndGamesAreNotCountedAsMasteryAttempts() throws {
        var snapshot = ProgressSnapshot()
        for activityID in ["math.learnMath", "math.mathCards", "math.pingPong"] {
            snapshot.apply(try event(
                activityID: activityID,
                itemID: activityID,
                occurredAt: baseDate
            ))
        }

        let model = EducationalProgressReadModelBuilder.make(snapshot: snapshot, product: .minikMath)

        XCTAssertTrue(model.isEmpty)
        XCTAssertEqual(model.totalAttempts, 0)
    }

    func testRecentPracticeSortsNewestFirstAndUsesStableTieBreak() throws {
        var snapshot = ProgressSnapshot()
        snapshot.apply(try event(activityID: "math.visualToAnswer", itemID: "a", occurredAt: baseDate))
        snapshot.apply(try event(activityID: "math.buildMath", itemID: "b", occurredAt: baseDate.addingTimeInterval(10)))
        snapshot.apply(try event(activityID: "math.mathPairs", itemID: "c", occurredAt: baseDate.addingTimeInterval(10)))

        let model = EducationalProgressReadModelBuilder.make(
            snapshot: snapshot,
            product: .minikMath,
            recentLimit: 2
        )

        XCTAssertEqual(model.recentPractice.map(\.activityID.rawValue), [
            "math.buildMath", "math.mathPairs"
        ])
    }

    private func event(
        id: UUID = UUID(),
        product: ProductVariant = .minikMath,
        activityID: String,
        itemID: String,
        attemptIndex: Int = 1,
        result: GradedAttemptResult = .correct,
        duration: Double = 1,
        occurredAt: Date,
        levelID: MathCurriculumLevelID? = .m1
    ) throws -> ActivityEvent {
        let attempt = try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: itemID),
            attemptIndex: attemptIndex,
            result: result,
            responseDurationSeconds: duration,
            activityFamily: .multipleChoice,
            mathLevelID: product == .minikMath ? levelID : nil
        ))
        return try XCTUnwrap(ActivityEvent(
            id: id,
            sessionID: ActivitySessionID(rawValue: UUID()),
            context: ActivityEventContext(
                product: product,
                activityID: ProgressActivityID(rawValue: activityID),
                curriculumStageID: attempt.mathLevelID?.curriculumStageID
            ),
            kind: .gradedAttempt,
            occurredAt: occurredAt,
            attemptData: attempt
        ))
    }

    private func mathState(
        levelID: MathCurriculumLevelID,
        mode: MathLevelMode
    ) -> MathLevelState {
        MathLevelState(
            mode: mode,
            activeLevelID: levelID,
            phase: .stable,
            previousLevelID: nil,
            firstAttemptWindow: [],
            consecutiveCorrect: 0,
            consecutiveUnsuccessful: 0,
            phaseAttemptCount: 0,
            phaseFailureCount: 0,
            cooldownRemaining: 0,
            timeBaselines: [:],
            verySlowSignalCount: 0
        )
    }
}
