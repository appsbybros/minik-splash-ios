typealias LanguageSoccerPoolBoundary = LanguageAutoPoolBoundary

struct LanguageSoccerPracticeSession: Sendable {
    private let roundPool: [SoccerRound]
    private var remainingRounds: [SoccerRound]
    private(set) var currentSession: SoccerSession
    private(set) var roundNumber: Int
    private(set) var lastAdvanceBoundary: LanguageSoccerPoolBoundary?
    private var poolTracker: LanguageAutoPoolTracker

    init?(
        rounds: [SoccerRound],
        evaluatedLevel: LanguageVocabularyLevel? = nil
    ) {
        let contentIDs = rounds.compactMap(Self.contentItemID)
        let level = evaluatedLevel
            ?? rounds.first.flatMap(Self.orderedTokenContent)?.vocabularyLevel
            ?? .a
        let poolItems = rounds.compactMap { round -> LanguageAutoPoolItem? in
            guard let content = Self.orderedTokenContent(round) else { return nil }
            return LanguageAutoPoolItem(
                contentItemID: content.contentItemID,
                vocabularyLevel: content.vocabularyLevel ?? level
            )
        }
        guard !rounds.isEmpty,
              contentIDs.count == rounds.count,
              Set(contentIDs).count == rounds.count,
              poolItems.count == rounds.count,
              let poolTracker = LanguageAutoPoolTracker(
                  activity: .soccer,
                  evaluatedLevel: level,
                  items: poolItems
              ) else {
            return nil
        }

        self.roundPool = rounds
        self.remainingRounds = Array(rounds.dropFirst())
        self.currentSession = SoccerSession(round: rounds[0])
        self.roundNumber = 1
        self.lastAdvanceBoundary = nil
        self.poolTracker = poolTracker
    }

    var currentRoundID: SoccerRoundID {
        currentSession.round.id
    }

    var currentContentItemID: ContentItemID {
        guard let contentItemID = Self.contentItemID(currentSession.round) else {
            preconditionFailure("Language Soccer practice requires ordered-token rounds.")
        }
        return contentItemID
    }

    var poolSize: Int {
        roundPool.count
    }

    var currentSpeechCue: LearningSpeechUtterance {
        guard let cue = currentSession.orderedTokenContent?.speechCue else {
            preconditionFailure("Language Soccer practice requires a spoken target cue.")
        }
        return cue
    }

    mutating func selectBall(_ ballID: SoccerBallID) {
        currentSession.selectBall(ballID)
    }

    mutating func resolveShot(outcome: GameOutcome) {
        currentSession.resolveShot(outcome: outcome)
    }

    mutating func prepareNextKick() {
        currentSession.prepareNextKick()
    }

    mutating func cancelUnresolvedShot() {
        currentSession.cancelUnresolvedShot()
    }

    @discardableResult
    mutating func advanceToNextRound() -> Bool {
        guard currentSession.isComplete else {
            return false
        }

        lastAdvanceBoundary = nil
        if remainingRounds.isEmpty {
            lastAdvanceBoundary = poolTracker.takeBoundary(isExhausted: true)
            remainingRounds = replenishedRounds()
            poolTracker = LanguageAutoPoolTracker(
                activity: .soccer,
                evaluatedLevel: poolTracker.evaluatedLevel,
                items: poolTracker.items
            )!
        }
        guard !remainingRounds.isEmpty else {
            return false
        }

        currentSession = SoccerSession(round: remainingRounds.removeFirst())
        roundNumber += 1
        return true
    }

    private func replenishedRounds() -> [SoccerRound] {
        var rounds = roundPool.shuffled()
        guard rounds.count > 1,
              Self.contentItemID(rounds[0]) == currentContentItemID,
              let replacementIndex = rounds.firstIndex(where: {
                  Self.contentItemID($0) != currentContentItemID
              }) else {
            return rounds
        }
        rounds.swapAt(0, replacementIndex)
        return rounds
    }

    private static func contentItemID(_ round: SoccerRound) -> ContentItemID? {
        orderedTokenContent(round)?.contentItemID
    }

    private static func orderedTokenContent(
        _ round: SoccerRound
    ) -> SoccerOrderedTokenContent? {
        guard case .orderedTokens(let content) = round.mechanic else { return nil }
        return content
    }
}
