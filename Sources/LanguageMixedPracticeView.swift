import SwiftUI

struct LanguageMixedPracticeView: View {
    @State private var session: LanguageMixedPracticeSession

    private let sessionFactory: LanguageActivitySessionFactory
    private let learnedLanguage: LanguageIdentifier
    private let onAttempt: (ActivityAttemptData) -> Void
    private let onWordCompleted: (LanguageWordCompletion) -> Void
    private let onAdOpportunity: () -> Void
    private let onExit: () -> Void

    init(
        session: LanguageMixedPracticeSession,
        sessionFactory: LanguageActivitySessionFactory,
        learnedLanguage: LanguageIdentifier,
        onAttempt: @escaping (ActivityAttemptData) -> Void = { _ in },
        onWordCompleted: @escaping (LanguageWordCompletion) -> Void = { _ in },
        onAdOpportunity: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {}
    ) {
        _session = State(initialValue: session)
        self.sessionFactory = sessionFactory
        self.learnedLanguage = learnedLanguage
        self.onAttempt = onAttempt
        self.onWordCompleted = onWordCompleted
        self.onAdOpportunity = onAdOpportunity
        self.onExit = onExit
    }

    @ViewBuilder
    var body: some View {
        let childActivity = session.currentChildActivity

        switch childActivity.session {
        case .multipleChoice(let childSession):
            MultipleChoiceView(
                session: childSession,
                progressActivityFamily: .mixed,
                presentation: choicePresentation(for: childActivity.mode),
                onAttempt: mixedAttempt,
                onComplete: {
                    replaceCompletedChild(withID: childActivity.id)
                },
                onAdvance: {
                    recordAdvance(fromChildWithID: childActivity.id)
                },
                onExit: onExit
            )
            .id(childActivity.id)

        case .build(let childSession):
            BuildView(
                session: childSession,
                progressActivityFamily: .mixed,
                presentation: .word,
                onAttempt: mixedAttempt,
                onWordCompleted: onWordCompleted,
                onComplete: {
                    replaceCompletedChild(withID: childActivity.id)
                },
                onAdvance: {
                    recordAdvance(fromChildWithID: childActivity.id)
                },
                onExit: onExit
            )
            .id(childActivity.id)
        }
    }

    private func choicePresentation(
        for mode: LanguageMixedPracticeMode
    ) -> MultipleChoicePresentation {
        switch mode {
        case .wordToPicture:
            return .wordToPicture
        case .pictureToWord:
            return .pictureToWord
        case .wordBuild:
            preconditionFailure("Word Build must use the Mixed build child presentation.")
        }
    }

    private func recordAdvance(fromChildWithID childID: UUID) {
        let result = session.record(.advancedCurrentWord, fromChildWithID: childID) { mode in
            sessionFactory.makeMixedChildActivity(
                for: mode,
                language: learnedLanguage
            )
        }
        if result != .ignored {
            onAdOpportunity()
        }
    }

    private func replaceCompletedChild(withID childID: UUID) {
        session.replaceCompletedChild(withID: childID) { mode in
            sessionFactory.makeMixedChildActivity(
                for: mode,
                language: learnedLanguage
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
            skillID: attempt.skillID
        ) else { return }
        onAttempt(mixed)
    }
}
