import SwiftUI

struct MathM9SessionView: View {
    let session: MathM9ActivitySession
    let sessionFactory: MathM9ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onComplete: () -> Void
    let onExit: () -> Void

    @ViewBuilder
    var body: some View {
        switch session {
        case .learn(let value):
            LearnView(session: value, onComplete: onComplete, onExit: onExit)
        case .pairs(let value):
            PairsView(session: value, mathActivityFamily: .pairs, mathLevelID: .m9,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildNumber(let value):
            BuildView(session: value, mathActivityFamily: .buildNumber, mathLevelID: .m9,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildQuantity(let value):
            MathNumberLinePlacementView(session: value, onAttempt: onAttempt,
                                        onComplete: onComplete, onExit: onExit)
        case .visualToAnswer(let value), .answerToRepresentation(let value):
            MultipleChoiceView(session: value, mathActivityFamily: .multipleChoice, mathLevelID: .m9,
                               onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildMath(let value):
            BuildView(session: value, mathActivityFamily: .buildMath, mathLevelID: .m9,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .mixed(let value):
            MathM9MixedPracticeView(coordinator: value, sessionFactory: sessionFactory,
                                    onAttempt: onAttempt, onExit: onExit)
        case .cards(let value):
            MathCardsView(session: value, onExit: onExit)
        case .soccer(let value):
            SoccerView(session: value, mathActivityFamily: .soccer, mathLevelID: .m9,
                       onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .tower(let value):
            BuildView(session: value, mathActivityFamily: .tower, mathLevelID: .m9,
                      presentation: .answerTokenTower, onAttempt: onAttempt,
                      onComplete: onComplete, onExit: onExit)
        case .memory(let value):
            MemoryView(session: value, mathActivityFamily: .memory, mathLevelID: .m9,
                       onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        }
    }
}

private struct MathM9MixedPracticeView: View {
    @State private var coordinator: MathM9MixedSession
    @State private var childSession: MathM9ActivitySession?
    @State private var launchID = UUID()
    let sessionFactory: MathM9ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onExit: () -> Void

    init(
        coordinator: MathM9MixedSession,
        sessionFactory: MathM9ActivitySessionFactory,
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
            AnyView(MathM9SessionView(
                session: childSession, sessionFactory: sessionFactory,
                onAttempt: mixedAttempt, onComplete: advance, onExit: onExit
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
        guard let value = ActivityAttemptData(
            itemID: attempt.itemID, attemptIndex: attempt.attemptIndex,
            result: attempt.result, responseDurationSeconds: attempt.responseDurationSeconds,
            activityFamily: .mixed, mathLevelID: .m9, skillID: attempt.skillID
        ) else { return }
        onAttempt(value)
    }

    private func advance() {
        coordinator.advance()
        childSession = sessionFactory.makeSession(for: coordinator.currentActivity)
        launchID = UUID()
    }
}
