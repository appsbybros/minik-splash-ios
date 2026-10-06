import SwiftUI

struct MathM1SessionView: View {
    let session: MathM1ActivitySession
    let sessionFactory: MathM1ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onComplete: () -> Void
    let onExit: () -> Void

    @ViewBuilder
    var body: some View {
        switch session {
        case .learn(let value):
            LearnView(session: value, onComplete: onComplete, onExit: onExit)
        case .pairs(let value):
            PairsView(
                session: value,
                mathActivityFamily: .pairs,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .buildNumber(let value):
            BuildView(
                session: value,
                mathActivityFamily: .buildNumber,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .buildQuantity(let value):
            MathCountConstructionView(
                session: value,
                presentation: .quantity,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .visualToAnswer(let value):
            MultipleChoiceView(
                session: value,
                mathActivityFamily: .multipleChoice,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .answerToRepresentation(let value):
            MultipleChoiceView(
                session: value,
                mathActivityFamily: .multipleChoice,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .buildMath(let value):
            BuildView(
                session: value,
                mathActivityFamily: .buildMath,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .mixed(let value):
            MathM1MixedPracticeView(
                coordinator: value,
                sessionFactory: sessionFactory,
                onAttempt: onAttempt,
                onExit: onExit
            )
        case .cards(let value):
            MathCardsView(session: value, onExit: onExit)
        case .soccer(let value):
            SoccerView(
                session: value,
                mathActivityFamily: .soccer,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .tower(let value):
            MathCountConstructionView(
                session: value,
                presentation: .tower,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        case .memory(let value):
            MemoryView(
                session: value,
                mathActivityFamily: .memory,
                onAttempt: onAttempt,
                onComplete: onComplete,
                onExit: onExit
            )
        }
    }
}

private struct MathM1MixedPracticeView: View {
    @State private var coordinator: MathM1MixedSession
    @State private var childSession: MathM1ActivitySession?
    @State private var launchID = UUID()
    let sessionFactory: MathM1ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onExit: () -> Void

    init(
        coordinator: MathM1MixedSession,
        sessionFactory: MathM1ActivitySessionFactory,
        onAttempt: @escaping (ActivityAttemptData) -> Void,
        onExit: @escaping () -> Void
    ) {
        _coordinator = State(initialValue: coordinator)
        _childSession = State(
            initialValue: sessionFactory.makeSession(for: coordinator.currentActivity)
        )
        self.sessionFactory = sessionFactory
        self.onAttempt = onAttempt
        self.onExit = onExit
    }

    @ViewBuilder
    var body: some View {
        if let childSession {
            AnyView(MathM1SessionView(
                session: childSession,
                sessionFactory: sessionFactory,
                onAttempt: mixedAttempt,
                onComplete: advance,
                onExit: onExit
            ))
            .id(launchID)
        } else {
            MinikHomeUnavailableView(
                title: String(localized: "Practice is unavailable right now"),
                message: String(localized: "Please try another activity."),
                onBack: onExit
            )
        }
    }

    private func mixedAttempt(_ attempt: ActivityAttemptData) {
        guard let mixed = ActivityAttemptData(
            itemID: attempt.itemID,
            attemptIndex: attempt.attemptIndex,
            result: attempt.result,
            responseDurationSeconds: attempt.responseDurationSeconds,
            activityFamily: .mixed,
            mathLevelID: attempt.mathLevelID,
            skillID: attempt.skillID
        ) else { return }
        onAttempt(mixed)
    }

    private func advance() {
        coordinator.advance()
        childSession = sessionFactory.makeSession(for: coordinator.currentActivity)
        launchID = UUID()
    }
}
