import XCTest
@testable import MinikPlus

final class ActivityProgressTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ActivityProgressTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEventCodableRoundTripPreservesTypedContext() throws {
        let event = try makeEvent(kind: .answeredCorrectly, seconds: 1.25)
        let data = try JSONEncoder().encode(event)
        XCTAssertEqual(try JSONDecoder().decode(ActivityEvent.self, from: data), event)
    }

    func testReducerAggregatesAttemptsOutcomesCompletionAndDuration() throws {
        var snapshot = ProgressSnapshot()
        for event in [
            try makeEvent(kind: .sessionStarted),
            try makeEvent(kind: .attempted),
            try makeEvent(kind: .answeredIncorrectly),
            try makeEvent(kind: .attempted),
            try makeEvent(kind: .answeredCorrectly),
            try makeEvent(kind: .skipped),
            try makeEvent(kind: .advanced),
            try makeEvent(kind: .completed, seconds: 12.5),
            try makeEvent(kind: .sessionEnded, seconds: 2.5)
        ] {
            snapshot.apply(event)
        }
        let summary = try XCTUnwrap(snapshot.summary(for: languageContext))
        XCTAssertEqual(summary.sessionsStarted, 1)
        XCTAssertEqual(summary.sessionsEnded, 1)
        XCTAssertEqual(summary.attempts, 2)
        XCTAssertEqual(summary.correctAnswers, 1)
        XCTAssertEqual(summary.incorrectAnswers, 1)
        XCTAssertEqual(summary.skips, 1)
        XCTAssertEqual(summary.advances, 1)
        XCTAssertEqual(summary.completions, 1)
        XCTAssertEqual(summary.practiceDurationSeconds, 15, accuracy: 0.001)
    }

    func testLocalRepositoryPersistsAndRestoresVersionedSnapshot() throws {
        let repository = LocalProgressRepository(userDefaults: defaults, storageKey: "test.progress")
        try repository.record(try makeEvent(kind: .attempted))
        try repository.record(try makeEvent(kind: .answeredCorrectly, seconds: 3))

        let restored = try LocalProgressRepository(
            userDefaults: defaults,
            storageKey: "test.progress"
        ).loadSnapshot()
        let summary = try XCTUnwrap(restored.summary(for: languageContext))
        XCTAssertEqual(summary.attempts, 1)
        XCTAssertEqual(summary.correctAnswers, 1)
        XCTAssertEqual(summary.practiceDurationSeconds, 3)
    }

    func testLanguageAndMathContextsRemainIndependent() throws {
        var snapshot = ProgressSnapshot()
        snapshot.apply(try makeEvent(kind: .answeredCorrectly))
        snapshot.apply(try XCTUnwrap(ActivityEvent(
            sessionID: ActivitySessionID(rawValue: fixedSessionID),
            context: mathContext,
            kind: .answeredIncorrectly,
            occurredAt: fixedDate
        )))
        XCTAssertEqual(snapshot.summaries.count, 2)
        XCTAssertEqual(snapshot.summary(for: languageContext)?.correctAnswers, 1)
        XCTAssertEqual(snapshot.summary(for: mathContext)?.incorrectAnswers, 1)
    }

    func testPingPongMatchHasNoFabricatedCurriculumOrSkill() throws {
        let context = ActivityEventContext(
            product: .minikPingPong,
            activityID: ProgressActivityID(rawValue: "pingPong")
        )
        let event = try XCTUnwrap(ActivityEvent(
            sessionID: ActivitySessionID(rawValue: fixedSessionID),
            context: context,
            kind: .matchCompleted,
            occurredAt: fixedDate,
            practiceDurationSeconds: 90
        ))
        var snapshot = ProgressSnapshot()
        snapshot.apply(event)
        let summary = try XCTUnwrap(snapshot.summary(for: context))
        XCTAssertNil(summary.context.curriculumStageID)
        XCTAssertNil(summary.context.skillID)
        XCTAssertEqual(summary.completedMatches, 1)
    }

    func testInvalidDurationIsRejected() {
        XCTAssertNil(ActivityEvent(
            sessionID: ActivitySessionID(rawValue: fixedSessionID),
            context: languageContext,
            kind: .sessionEnded,
            occurredAt: fixedDate,
            practiceDurationSeconds: -1
        ))
    }

    func testReplayingSameEventChangesProgressOnlyOnce() throws {
        let event = try makeEvent(kind: .answeredCorrectly)
        var snapshot = ProgressSnapshot()

        snapshot.apply(event)
        snapshot.apply(event)

        XCTAssertEqual(snapshot.summary(for: languageContext)?.correctAnswers, 1)
        XCTAssertEqual(snapshot.appliedEventIDs, Set([event.id]))
    }

    func testNewEventIDForRealRetryIsApplied() throws {
        let first = try gradedAttemptEvent(
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            attemptIndex: 1,
            result: .incorrect
        )
        let retry = try gradedAttemptEvent(
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            attemptIndex: 2,
            result: .correct
        )
        var snapshot = ProgressSnapshot()

        snapshot.apply(first)
        snapshot.apply(retry)

        let summary = try XCTUnwrap(snapshot.summary(for: mathContext))
        XCTAssertEqual(summary.gradedAttempts, 2)
        XCTAssertEqual(summary.incorrectAnswers, 1)
        XCTAssertEqual(summary.correctAnswers, 1)
        XCTAssertEqual(summary.firstAttemptIncorrectAnswers, 1)
        XCTAssertEqual(summary.firstAttemptCorrectAnswers, 0)
    }

    func testTypedAttemptPreservesFirstAttemptAndDuration() throws {
        let event = try gradedAttemptEvent(
            eventID: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            attemptIndex: 1,
            result: .correct,
            seconds: 4.25
        )
        let restored = try JSONDecoder().decode(
            ActivityEvent.self,
            from: JSONEncoder().encode(event)
        )

        XCTAssertEqual(restored.attemptData?.isFirstAttempt, true)
        XCTAssertEqual(restored.attemptData?.responseDurationSeconds, 4.25)
        XCTAssertEqual(restored.attemptData?.mathLevelID, .m1)
        XCTAssertEqual(restored.attemptData?.skillID, MathSkillIDs.quantityToNumber)
    }

    func testInvalidTypedAttemptDurationIsRejected() {
        XCTAssertNil(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "challenge-1"),
            attemptIndex: 1,
            result: .correct,
            responseDurationSeconds: .infinity,
            activityFamily: .multipleChoice,
            mathLevelID: .m1
        ))
    }

    func testLanguageAttemptRequiresNoMathLevel() throws {
        let attempt = try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "word-1"),
            attemptIndex: 1,
            result: .correct,
            activityFamily: .pairs,
            skillID: SkillID(rawValue: "language.wordRecognition")
        ))
        let event = try XCTUnwrap(ActivityEvent(
            sessionID: ActivitySessionID(rawValue: fixedSessionID),
            context: languageContext,
            kind: .gradedAttempt,
            occurredAt: fixedDate,
            attemptData: attempt
        ))

        XCTAssertNil(event.attemptData?.mathLevelID)
    }

    private var fixedDate: Date { Date(timeIntervalSince1970: 1_800_000_000) }
    private var fixedSessionID: UUID { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! }

    private var languageContext: ActivityEventContext {
        ActivityEventContext(
            product: .minikPlus,
            activityID: ProgressActivityID(rawValue: "language.multipleChoice"),
            curriculumStageID: CurriculumStageID(rawValue: "language.words"),
            skillID: SkillID(rawValue: "language.wordRecognition")
        )
    }

    private var mathContext: ActivityEventContext {
        ActivityEventContext(
            product: .minikMath,
            activityID: ProgressActivityID(rawValue: "math.visualToAnswer"),
            curriculumStageID: CurriculumStageID(rawValue: "math.m1"),
            skillID: SkillID(rawValue: "math.quantityToNumber")
        )
    }

    private func makeEvent(
        id: UUID = UUID(),
        kind: ActivityEventKind,
        seconds: Double? = nil
    ) throws -> ActivityEvent {
        try XCTUnwrap(ActivityEvent(
            id: id,
            sessionID: ActivitySessionID(rawValue: fixedSessionID),
            context: languageContext,
            kind: kind,
            occurredAt: fixedDate,
            practiceDurationSeconds: seconds
        ))
    }

    private func gradedAttemptEvent(
        eventID: UUID,
        attemptIndex: Int,
        result: GradedAttemptResult,
        seconds: Double? = nil
    ) throws -> ActivityEvent {
        let attempt = try XCTUnwrap(ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "challenge-1"),
            attemptIndex: attemptIndex,
            result: result,
            responseDurationSeconds: seconds,
            activityFamily: .multipleChoice,
            mathLevelID: .m1,
            skillID: MathSkillIDs.quantityToNumber
        ))
        return try XCTUnwrap(ActivityEvent(
            id: eventID,
            sessionID: ActivitySessionID(rawValue: fixedSessionID),
            context: mathContext,
            kind: .gradedAttempt,
            occurredAt: fixedDate,
            attemptData: attempt
        ))
    }
}
