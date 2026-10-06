import SwiftUI

struct MathM3SessionView: View {
    let session: MathM3ActivitySession
    let sessionFactory: MathM3ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onComplete: () -> Void
    let onExit: () -> Void

    @ViewBuilder
    var body: some View {
        switch session {
        case .learn(let value):
            LearnView(session: value, onComplete: onComplete, onExit: onExit)
        case .pairs(let value):
            PairsView(session: value, mathActivityFamily: .pairs, mathLevelID: .m3,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildNumber(let value):
            BuildView(session: value, mathActivityFamily: .buildNumber, mathLevelID: .m3,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildQuantity(let value):
            MathCountConstructionView(session: value, presentation: .quantity,
                                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .visualToAnswer(let value), .answerToRepresentation(let value):
            MultipleChoiceView(session: value, mathActivityFamily: .multipleChoice, mathLevelID: .m3,
                               onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildMath(let value):
            BuildView(session: value, mathActivityFamily: .buildMath, mathLevelID: .m3,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .mixed(let value):
            MathM3MixedPracticeView(coordinator: value, sessionFactory: sessionFactory,
                                    onAttempt: onAttempt, onExit: onExit)
        case .cards(let value):
            MathCardsView(session: value, onExit: onExit)
        case .soccer(let value):
            SoccerView(session: value, mathActivityFamily: .soccer, mathLevelID: .m3,
                       onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .tower(let value):
            MathCountConstructionView(session: value, presentation: .tower,
                                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .memory(let value):
            MemoryView(session: value, mathActivityFamily: .memory, mathLevelID: .m3,
                       onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        }
    }
}

private struct MathM3MixedPracticeView: View {
    @State private var coordinator: MathM3MixedSession
    @State private var childSession: MathM3ActivitySession?
    @State private var launchID = UUID()
    let sessionFactory: MathM3ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onExit: () -> Void

    init(
        coordinator: MathM3MixedSession,
        sessionFactory: MathM3ActivitySessionFactory,
        onAttempt: @escaping (ActivityAttemptData) -> Void,
        onExit: @escaping () -> Void
    ) {
        _coordinator = State(initialValue: coordinator)
        _childSession = State(initialValue: sessionFactory.makeSession(for: coordinator.currentActivity))
        self.sessionFactory = sessionFactory
        self.onAttempt = onAttempt
        self.onExit = onExit
    }

    @ViewBuilder
    var body: some View {
        if let childSession {
            AnyView(MathM3SessionView(
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
            mathLevelID: .m3,
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
