struct SoccerSession: Sendable {
    let round: SoccerRound
    private(set) var currentTargetIndex: Int
    private(set) var selectedBallID: SoccerBallID?
    private(set) var educationalIsCorrect: Bool?
    private(set) var gameOutcome: GameOutcome?
    private(set) var childScore: Int
    private(set) var keeperScore: Int
    private(set) var consumedBallIDs: Set<SoccerBallID>
    private(set) var builtTokens: [LearningTextRepresentation]
    private(set) var isComplete: Bool

    init(round: SoccerRound) {
        self.round = round
        self.currentTargetIndex = 0
        self.selectedBallID = nil
        self.educationalIsCorrect = nil
        self.gameOutcome = nil
        self.childScore = 0
        self.keeperScore = 0
        self.consumedBallIDs = []
        self.builtTokens = []
        self.isComplete = false
    }

    var currentTarget: SoccerChallengeTarget {
        guard case .answerChoice = round.mechanic else {
            preconditionFailure("Ordered-token Soccer rounds do not use challenge targets.")
        }
        return round.challengeTargets[currentTargetIndex]
    }

    var targetCount: Int {
        switch round.mechanic {
        case .answerChoice:
            round.challengeTargets.count
        case .orderedTokens(let content):
            content.expectedTokenSequence.count
        }
    }

    var progressCount: Int {
        switch round.mechanic {
        case .answerChoice:
            min(currentTargetIndex + 1, targetCount)
        case .orderedTokens:
            currentTargetIndex
        }
    }

    var availableBalls: [SoccerAnswerBall] {
        round.answerBalls.filter { !consumedBallIDs.contains($0.id) }
    }

    var promptRepresentations: [Representation] {
        switch round.mechanic {
        case .answerChoice:
            return currentTarget.challenge.prompt.representations
        case .orderedTokens(let content):
            var representations: [Representation] = []
            if let image = content.image {
                representations.append(.imageAsset(image))
            }
            representations.append(.learningText(content.targetText))
            return representations
        }
    }

    var orderedTokenContent: SoccerOrderedTokenContent? {
        guard case .orderedTokens(let content) = round.mechanic else {
            return nil
        }
        return content
    }

    var currentExpectedToken: LearningTextRepresentation? {
        guard let content = orderedTokenContent,
              content.expectedTokenSequence.indices.contains(currentTargetIndex) else {
            return nil
        }
        return content.expectedTokenSequence[currentTargetIndex]
    }

    var builtDisplayText: String? {
        guard let content = orderedTokenContent else {
            return nil
        }

        var display = ""
        var pendingWhitespace = ""
        var builtTokenIndex = 0

        for character in content.targetText.text {
            if character.isWhitespace {
                pendingWhitespace.append(character)
                continue
            }
            guard builtTokens.indices.contains(builtTokenIndex) else {
                break
            }
            display.append(contentsOf: pendingWhitespace)
            pendingWhitespace = ""
            display.append(contentsOf: builtTokens[builtTokenIndex].text)
            builtTokenIndex += 1
        }
        return display
    }

    var selectedOrderedTokenSpeechCue: LearningSpeechUtterance? {
        guard orderedTokenContent != nil,
              let selectedBallID,
              let token = round.answerBalls.first(where: {
                  $0.id == selectedBallID
              })?.orderedToken,
              let language = token.language else {
            return nil
        }
        return LearningSpeechUtterance(
            text: token.speechText ?? token.text,
            language: language
        )
    }

    mutating func selectBall(_ ballID: SoccerBallID) {
        guard !isComplete,
              selectedBallID == nil,
              let ball = availableBalls.first(where: { $0.id == ballID }) else {
            return
        }

        selectedBallID = ballID
        switch round.mechanic {
        case .answerChoice:
            educationalIsCorrect = ballID == currentTarget.intendedBallID
        case .orderedTokens:
            educationalIsCorrect = ball.orderedToken == currentExpectedToken
        }
    }

    mutating func resolveShot(outcome: GameOutcome) {
        guard !isComplete,
              selectedBallID != nil,
              let educationalIsCorrect,
              gameOutcome == nil else {
            return
        }

        gameOutcome = outcome

        switch (educationalIsCorrect, outcome) {
        case (true, .goal):
            childScore += 1
        case (false, .miss), (false, .saved):
            keeperScore += 1
        case (true, .miss), (true, .saved), (false, .goal):
            break
        }

        guard case .orderedTokens = round.mechanic,
              educationalIsCorrect,
              let selectedBallID,
              let selectedBall = round.answerBalls.first(where: { $0.id == selectedBallID }),
              let token = selectedBall.orderedToken else {
            return
        }

        consumedBallIDs.insert(selectedBallID)
        builtTokens.append(token)
        currentTargetIndex += 1
        isComplete = currentTargetIndex == targetCount
    }

    mutating func nextTarget() {
        guard gameOutcome != nil else {
            return
        }

        switch round.mechanic {
        case .answerChoice:
            guard !isComplete else {
                return
            }
            if currentTargetIndex < round.challengeTargets.count - 1 {
                currentTargetIndex += 1
                clearAttempt()
            } else {
                isComplete = true
            }
        case .orderedTokens:
            guard !isComplete else {
                return
            }
            clearAttempt()
        }
    }

    mutating func prepareNextKick() {
        guard case .orderedTokens = round.mechanic,
              !isComplete,
              gameOutcome != nil else {
            return
        }
        clearAttempt()
    }

    mutating func cancelUnresolvedShot() {
        guard gameOutcome == nil else { return }
        clearAttempt()
    }

    private mutating func clearAttempt() {
        selectedBallID = nil
        educationalIsCorrect = nil
        gameOutcome = nil
    }
}
