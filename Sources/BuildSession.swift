enum BuildAnswerResult: Hashable, Sendable {
    case correct
    case incorrect
}

struct BuildSession: Sendable {
    let challenges: [BuildChallenge]
    private(set) var currentChallengeIndex: Int
    private(set) var tokenPresentationOrder: [BuildTokenID]
    private(set) var selectedTokenIDs: [BuildTokenID]
    private(set) var lastSelectionResult: BuildAnswerResult?
    private(set) var hasIncorrectAttempt: Bool
    private(set) var answerResult: BuildAnswerResult?
    private(set) var isComplete: Bool

    init?(challenges: [BuildChallenge]) {
        guard !challenges.isEmpty else {
            return nil
        }

        self.challenges = challenges
        self.currentChallengeIndex = 0
        self.tokenPresentationOrder = Self.makeTokenPresentationOrder(for: challenges[0])
        self.selectedTokenIDs = []
        self.lastSelectionResult = nil
        self.hasIncorrectAttempt = false
        self.answerResult = nil
        self.isComplete = false
    }

    var currentChallenge: BuildChallenge {
        challenges[currentChallengeIndex]
    }

    var challengeCount: Int {
        challenges.count
    }

    var builtDisplayText: String? {
        guard let content = currentChallenge.languageWordContent else {
            return nil
        }

        let tokensByID = Dictionary(
            uniqueKeysWithValues: currentChallenge.availableTokens.map { ($0.id, $0) }
        )
        let selectedText = selectedTokenIDs.compactMap { tokenID -> String? in
            guard let token = tokensByID[tokenID],
                  case .learningText(let text) = token.representation else {
                return nil
            }
            return text.text
        }

        var display = ""
        var pendingWhitespace = ""
        var selectedIndex = 0
        for character in content.targetText.text {
            if character.isWhitespace {
                pendingWhitespace.append(character)
                continue
            }
            guard selectedText.indices.contains(selectedIndex) else {
                break
            }
            display.append(contentsOf: pendingWhitespace)
            pendingWhitespace = ""
            display.append(contentsOf: selectedText[selectedIndex])
            selectedIndex += 1
        }
        return display
    }

    mutating func selectToken(_ tokenID: BuildTokenID) {
        guard !isComplete,
              answerResult == nil,
              !selectedTokenIDs.contains(tokenID),
              currentChallenge.availableTokens.contains(where: { $0.id == tokenID }) else {
            return
        }

        switch currentChallenge.validationMode {
        case .submitSequence:
            selectedTokenIDs.append(tokenID)

        case .immediatePrefix:
            let expectedTokenID = currentChallenge.expectedTokenSequence[selectedTokenIDs.count]
            let selectedRepresentation = Self.representations(
                for: [tokenID],
                in: currentChallenge
            )?.first
            let expectedRepresentation = Self.representations(
                for: [expectedTokenID],
                in: currentChallenge
            )?.first

            guard selectedRepresentation == expectedRepresentation else {
                lastSelectionResult = .incorrect
                hasIncorrectAttempt = true
                return
            }

            selectedTokenIDs.append(tokenID)
            lastSelectionResult = .correct
            if selectedTokenIDs.count == currentChallenge.expectedTokenSequence.count {
                answerResult = .correct
            }
        }
    }

    mutating func undoLastToken() {
        guard !isComplete,
              answerResult == nil,
              currentChallenge.validationMode == .submitSequence,
              !selectedTokenIDs.isEmpty else {
            return
        }

        selectedTokenIDs.removeLast()
    }

    mutating func submit() {
        guard !isComplete,
              answerResult == nil,
              currentChallenge.validationMode == .submitSequence,
              selectedTokenIDs.count == currentChallenge.expectedTokenSequence.count else {
            return
        }

        let selectedRepresentations = Self.representations(
            for: selectedTokenIDs,
            in: currentChallenge
        )
        let expectedRepresentations = Self.representations(
            for: currentChallenge.expectedTokenSequence,
            in: currentChallenge
        )
        answerResult = selectedRepresentations != nil
            && selectedRepresentations == expectedRepresentations
            ? .correct
            : .incorrect
    }

    mutating func retryCurrentChallenge() {
        guard !isComplete,
              currentChallenge.validationMode == .submitSequence,
              answerResult == .incorrect else { return }
        selectedTokenIDs = []
        lastSelectionResult = nil
        answerResult = nil
    }

    mutating func nextChallenge() {
        let canSkipAfterIncorrectImmediateSelection =
            currentChallenge.validationMode == .immediatePrefix
                && hasIncorrectAttempt
        guard !isComplete,
              answerResult != nil || canSkipAfterIncorrectImmediateSelection else {
            return
        }

        if currentChallengeIndex < challenges.count - 1 {
            currentChallengeIndex += 1
            tokenPresentationOrder = Self.makeTokenPresentationOrder(for: currentChallenge)
            selectedTokenIDs = []
            lastSelectionResult = nil
            hasIncorrectAttempt = false
            answerResult = nil
        } else {
            isComplete = true
        }
    }

    private static func makeTokenPresentationOrder(
        for challenge: BuildChallenge
    ) -> [BuildTokenID] {
        var order = challenge.availableTokens.map(\.id).shuffled()

        if let presentedRepresentations = representations(for: order, in: challenge),
           let expectedRepresentations = representations(
               for: challenge.expectedTokenSequence,
               in: challenge
           ),
           presentedRepresentations == expectedRepresentations,
           let firstIndex = presentedRepresentations.indices.first,
           let differentIndex = presentedRepresentations.indices.dropFirst().first(where: {
               presentedRepresentations[$0] != presentedRepresentations[firstIndex]
           }) {
            order.swapAt(firstIndex, differentIndex)
        }

        return order
    }

    private static func representations(
        for tokenIDs: [BuildTokenID],
        in challenge: BuildChallenge
    ) -> [Representation]? {
        let tokensByID = Dictionary(
            uniqueKeysWithValues: challenge.availableTokens.map { ($0.id, $0) }
        )
        let resolved = tokenIDs.compactMap { tokensByID[$0]?.representation }
        return resolved.count == tokenIDs.count ? resolved : nil
    }
}
