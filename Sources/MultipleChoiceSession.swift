enum MultipleChoiceAnswerResult: Hashable, Sendable {
    case correct
    case incorrect
}

enum MultipleChoiceProgressionPolicy: Hashable, Sendable {
    case manual
    case retryUntilCorrect
}

enum MultipleChoicePendingAction: Hashable, Sendable {
    case resetAfterIncorrect(challengeID: ChallengeID)
    case advanceAfterCorrect(challengeID: ChallengeID)
}

struct MultipleChoiceSession: Sendable {
    let challenges: [Challenge]
    let progressionPolicy: MultipleChoiceProgressionPolicy
    private(set) var currentChallengeIndex: Int
    private(set) var selectedChoiceID: ChoiceID?
    private(set) var answerResult: MultipleChoiceAnswerResult?
    private(set) var hasIncorrectAttempt: Bool
    private(set) var isComplete: Bool

    init?(
        challenges: [Challenge],
        progressionPolicy: MultipleChoiceProgressionPolicy = .manual
    ) {
        guard !challenges.isEmpty else {
            return nil
        }

        self.challenges = challenges
        self.progressionPolicy = progressionPolicy
        self.currentChallengeIndex = 0
        self.selectedChoiceID = nil
        self.answerResult = nil
        self.hasIncorrectAttempt = false
        self.isComplete = false
    }

    var currentChallenge: Challenge {
        challenges[currentChallengeIndex]
    }

    var challengeCount: Int {
        challenges.count
    }

    var canSelectChoices: Bool {
        !isComplete && answerResult == nil
    }

    var canAdvanceManually: Bool {
        guard !isComplete else {
            return false
        }

        switch progressionPolicy {
        case .manual:
            return answerResult != nil
        case .retryUntilCorrect:
            return hasIncorrectAttempt && answerResult != .correct
        }
    }

    var pendingAction: MultipleChoicePendingAction? {
        guard !isComplete else {
            return nil
        }

        switch (progressionPolicy, answerResult) {
        case (.retryUntilCorrect, .incorrect?):
            return .resetAfterIncorrect(challengeID: currentChallenge.id)
        case (.retryUntilCorrect, .correct?):
            return .advanceAfterCorrect(challengeID: currentChallenge.id)
        default:
            return nil
        }
    }

    mutating func selectChoice(_ choiceID: ChoiceID) {
        guard !isComplete,
              canSelectChoices,
              let choice = currentChallenge.choices.first(where: { $0.id == choiceID }) else {
            return
        }

        selectedChoiceID = choiceID
        if isCorrect(choice, for: currentChallenge) {
            answerResult = .correct
        } else {
            answerResult = .incorrect
            if progressionPolicy == .retryUntilCorrect {
                hasIncorrectAttempt = true
            }
        }
    }

    mutating func nextChallenge() {
        guard !isComplete, canAdvanceToNextChallenge else {
            return
        }

        if currentChallengeIndex < challenges.count - 1 {
            currentChallengeIndex += 1
            selectedChoiceID = nil
            answerResult = nil
            hasIncorrectAttempt = false
        } else {
            isComplete = true
        }
    }

    mutating func resetTransientIncorrectAttempt(for challengeID: ChallengeID) {
        guard !isComplete,
              progressionPolicy == .retryUntilCorrect,
              currentChallenge.id == challengeID,
              answerResult == .incorrect else {
            return
        }

        selectedChoiceID = nil
        answerResult = nil
    }

    mutating func advanceIfCurrentChallengeMatches(_ challengeID: ChallengeID) -> Bool {
        guard !isComplete, currentChallenge.id == challengeID else {
            return false
        }

        let wasComplete = isComplete
        nextChallenge()
        return !wasComplete && isComplete
    }

    private var canAdvanceToNextChallenge: Bool {
        switch progressionPolicy {
        case .manual:
            return answerResult != nil
        case .retryUntilCorrect:
            return answerResult == .correct || hasIncorrectAttempt
        }
    }

    private func isCorrect(_ choice: Choice, for challenge: Challenge) -> Bool {
        guard case .semanticValue(let expectedValue) = challenge.expectedAnswer else {
            return false
        }

        switch challenge.validationRule {
        case .exactIdentity:
            return choice.semanticValue == expectedValue
        case .numericEquivalence:
            return choice.semanticValue.isNumericallyEquivalent(to: expectedValue)
        default:
            return false
        }
    }
}
