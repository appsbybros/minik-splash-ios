import Foundation
import XCTest
@testable import MinikPlus

final class ActivityOutcomeDispatcherTests: XCTestCase {
    func testDispatchWritesProgressBeforeOptionalRewardBoundary() throws {
        let sink = RecordingEventSink()
        var rewardedEventID: UUID?
        let dispatcher = ActivityOutcomeDispatcher(
            progressSink: sink,
            rewardHandler: { event in rewardedEventID = event.id }
        )
        let event = try XCTUnwrap(makeEvent())

        try dispatcher.dispatch(event)

        XCTAssertEqual(sink.events, [event])
        XCTAssertEqual(rewardedEventID, event.id)
    }

    func testMathCanPersistWithoutInventingRewardPolicy() throws {
        let sink = RecordingEventSink()
        let dispatcher = ActivityOutcomeDispatcher(progressSink: sink)
        let event = try XCTUnwrap(makeEvent())

        try dispatcher.dispatch(event)

        XCTAssertEqual(sink.events, [event])
    }

    private func makeEvent() -> ActivityEvent? {
        let attempt = ActivityAttemptData(
            itemID: ActivityItemID(rawValue: "m2.test"),
            attemptIndex: 1,
            result: .correct,
            activityFamily: .multipleChoice,
            mathLevelID: .m2,
            skillID: MathSkillIDs.addition
        )
        return attempt.flatMap {
            ActivityEvent(
                sessionID: ActivitySessionID(),
                context: ActivityEventContext(
                    product: .minikMath,
                    activityID: ProgressActivityID(rawValue: "math.multipleChoice"),
                    curriculumStageID: MathCurriculumLevelID.m2.curriculumStageID,
                    skillID: MathSkillIDs.addition
                ),
                kind: .gradedAttempt,
                occurredAt: Date(timeIntervalSince1970: 1),
                attemptData: $0
            )
        }
    }
}

private final class RecordingEventSink: ActivityEventSink {
    private(set) var events: [ActivityEvent] = []

    func record(_ event: ActivityEvent) throws {
        events.append(event)
    }
}
