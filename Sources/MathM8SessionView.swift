import SwiftUI

struct MathM8SessionView: View {
    let session: MathM8ActivitySession
    let sessionFactory: MathM8ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onComplete: () -> Void
    let onExit: () -> Void

    var body: some View {
        activityContent
            .mathActivityChrome(howTo: howToTopic)
    }

    /// Mixed practice has none of its own: each activity inside it explains itself.
    private var howToTopic: MathHowToTopic? {
        switch session {
        case .learn: return .learnMath
        case .pairs: return .mathPairs
        case .buildNumber: return .buildNumber
        case .buildQuantity: return .buildQuantityFraction
        case .visualToAnswer: return .visualToAnswer
        case .answerToRepresentation: return .answerToRepresentation
        case .buildMath: return .buildMath
        case .mixed: return nil
        case .cards: return .mathCards
        case .soccer: return .mathSoccer
        case .tower: return .mathTowerBlocks
        case .memory: return .mathMemory
        }
    }

    @ViewBuilder
    private var activityContent: some View {
        switch session {
        case .learn(let value):
            LearnView(session: value, onComplete: onComplete, onExit: onExit)
        case .pairs(let value):
            PairsView(session: value, mathActivityFamily: .pairs, mathLevelID: .m8,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildNumber(let value):
            BuildView(session: value, mathActivityFamily: .buildNumber, mathLevelID: .m8,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildQuantity(let value):
            MathFractionConstructionView(session: value, onAttempt: onAttempt,
                                         onComplete: onComplete, onExit: onExit)
        case .visualToAnswer(let value), .answerToRepresentation(let value):
            MultipleChoiceView(session: value, mathActivityFamily: .multipleChoice, mathLevelID: .m8,
                               onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .buildMath(let value):
            BuildView(session: value, mathActivityFamily: .buildMath, mathLevelID: .m8,
                      onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .mixed(let value):
            MathM8MixedPracticeView(coordinator: value, sessionFactory: sessionFactory,
                                    onAttempt: onAttempt, onExit: onExit)
        case .cards(let value):
            MathCardsView(session: value, onExit: onExit)
        case .soccer(let value):
            SoccerView(session: value, mathActivityFamily: .soccer, mathLevelID: .m8,
                       onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        case .tower(let value):
            BuildView(session: value, mathActivityFamily: .tower, mathLevelID: .m8,
                      presentation: .answerTokenTower, onAttempt: onAttempt,
                      onComplete: onComplete, onExit: onExit)
        case .memory(let value):
            MemoryView(session: value, mathActivityFamily: .memory, mathLevelID: .m8,
                       onAttempt: onAttempt, onComplete: onComplete, onExit: onExit)
        }
    }
}

private struct MathM8MixedPracticeView: View {
    @State private var coordinator: MathM8MixedSession
    @State private var childSession: MathM8ActivitySession?
    @State private var launchID = UUID()
    let sessionFactory: MathM8ActivitySessionFactory
    let onAttempt: (ActivityAttemptData) -> Void
    let onExit: () -> Void

    init(
        coordinator: MathM8MixedSession,
        sessionFactory: MathM8ActivitySessionFactory,
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
            AnyView(MathM8SessionView(
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
            activityFamily: .mixed, mathLevelID: .m8, skillID: attempt.skillID
        ) else { return }
        onAttempt(value)
    }

    private func advance() {
        coordinator.advance()
        childSession = sessionFactory.makeSession(for: coordinator.currentActivity)
        launchID = UUID()
    }
}
