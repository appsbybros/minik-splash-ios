import Foundation

struct LanguageTowerPracticeSession: Sendable {
    private let roundPool: [TowerOrderedTokenRound]
    private var remainingRounds: [TowerOrderedTokenRound]
    private(set) var currentSession: TowerSession
    private(set) var roundNumber: Int
    private(set) var presentationID: UUID
    private(set) var lastAdvanceBoundary: LanguageAutoPoolBoundary?
    private var didEmitCompletion: Bool
    private var poolTracker: LanguageAutoPoolTracker

    init?(
        rounds: [TowerOrderedTokenRound],
        evaluatedLevel: LanguageVocabularyLevel? = nil
    ) {
        let contentIDs = rounds.map { $0.content.contentItemID }
        let level = evaluatedLevel ?? rounds.first?.content.vocabularyLevel ?? .a
        let poolItems = rounds.map {
            LanguageAutoPoolItem(
                contentItemID: $0.content.contentItemID,
                vocabularyLevel: $0.content.vocabularyLevel ?? level
            )
        }
        guard !rounds.isEmpty,
              Set(contentIDs).count == rounds.count,
              let firstSession = TowerSession(orderedTokenRound: rounds[0]),
              let poolTracker = LanguageAutoPoolTracker(
                  activity: .tower,
                  evaluatedLevel: level,
                  items: poolItems
              ) else {
            return nil
        }

        self.roundPool = rounds
        self.remainingRounds = Array(rounds.dropFirst())
        self.currentSession = firstSession
        self.roundNumber = 1
        self.presentationID = UUID()
        self.lastAdvanceBoundary = nil
        self.didEmitCompletion = false
        self.poolTracker = poolTracker
    }

    var currentRoundID: TowerRoundID {
        guard let id = currentSession.orderedTokenRound?.id else {
            preconditionFailure("Language Tower practice requires an ordered-token round.")
        }
        return id
    }

    var currentContentItemID: ContentItemID {
        guard let id = currentSession.orderedTokenContent?.contentItemID else {
            preconditionFailure("Language Tower practice requires ordered-token content.")
        }
        return id
    }

    var currentSpeechCue: LearningSpeechUtterance {
        guard let cue = currentSession.orderedTokenContent?.speechCue else {
            preconditionFailure("Language Tower practice requires a target speech cue.")
        }
        return cue
    }

    var poolSize: Int {
        roundPool.count
    }

    @discardableResult
    mutating func placeBlock(_ blockID: TowerBlockID) -> TowerAnswerResult? {
        currentSession.placeOrderedBlock(blockID)
    }

    mutating func clearPlacementFeedback() {
        currentSession.clearOrderedPlacementFeedback()
    }

    mutating func takeCompletion() -> LanguageTowerCompletion? {
        guard currentSession.isComplete, !didEmitCompletion else {
            return nil
        }
        didEmitCompletion = true
        return LanguageTowerCompletion(
            id: presentationID,
            contentItemID: currentContentItemID
        )
    }

    @discardableResult
    mutating func advanceToNextRound(
        expectedPresentationID: UUID? = nil
    ) -> Bool {
        guard currentSession.isComplete,
              expectedPresentationID.map({ $0 == presentationID }) ?? true else {
            return false
        }

        lastAdvanceBoundary = nil
        if remainingRounds.isEmpty {
            lastAdvanceBoundary = poolTracker.takeBoundary(isExhausted: true)
            remainingRounds = replenishedRounds()
            poolTracker = LanguageAutoPoolTracker(
                activity: .tower,
                evaluatedLevel: poolTracker.evaluatedLevel,
                items: poolTracker.items
            )!
        }
        guard !remainingRounds.isEmpty,
              let nextSession = TowerSession(
                  orderedTokenRound: remainingRounds.removeFirst()
              ) else {
            return false
        }

        currentSession = nextSession
        roundNumber += 1
        presentationID = UUID()
        didEmitCompletion = false
        return true
    }

    private func replenishedRounds() -> [TowerOrderedTokenRound] {
        var rounds = roundPool.shuffled()
        guard rounds.count > 1,
              rounds[0].content.contentItemID == currentContentItemID,
              let replacementIndex = rounds.firstIndex(where: {
                  $0.content.contentItemID != currentContentItemID
              }) else {
            return rounds
        }
        rounds.swapAt(0, replacementIndex)
        return rounds
    }
}

struct LanguageTowerCompletion: Hashable, Sendable {
    let id: UUID
    let contentItemID: ContentItemID
}
