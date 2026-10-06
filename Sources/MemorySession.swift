import Foundation

struct MemoryCardID: Hashable, Sendable {
    let groupIndex: Int
    let representationIndex: Int
}

struct MemoryAttemptTransition: Hashable, Sendable {
    let presentationID: UUID
    let firstCardID: MemoryCardID
    let secondCardID: MemoryCardID
}

struct MemoryCard: Hashable, Sendable {
    let id: MemoryCardID
    let representation: Representation
}

enum MemoryAttemptResult: Hashable, Sendable {
    case correct
    case incorrect
}

enum MemoryCardState: Hashable, Sendable {
    case faceDown
    case faceUp
    case matched
}

struct MemorySession: Sendable {
    let equivalenceSets: [EquivalenceSet]
    let cards: [MemoryCard]
    private let revealSpeechCues: [SemanticValue: LearningSpeechUtterance]
    private(set) var cardPresentationOrder: [MemoryCardID]
    private(set) var firstSelectedCardID: MemoryCardID?
    private(set) var secondSelectedCardID: MemoryCardID?
    private(set) var matchedGroupIndices: Set<Int>
    private(set) var attemptResult: MemoryAttemptResult?
    private(set) var isComplete: Bool
    private(set) var presentationID: UUID

    init?(
        equivalenceSets: [EquivalenceSet],
        revealSpeechCues: [SemanticValue: LearningSpeechUtterance] = [:]
    ) {
        let semanticValues = Set(equivalenceSets.map(\.semanticValue))
        guard !equivalenceSets.isEmpty,
              equivalenceSets.allSatisfy({ $0.representations.count == 2 }),
              semanticValues.count == equivalenceSets.count,
              Set(revealSpeechCues.keys).isSubset(of: semanticValues) else {
            return nil
        }

        let cards = equivalenceSets.enumerated().flatMap { groupIndex, set in
            set.representations.enumerated().map { representationIndex, representation in
                MemoryCard(
                    id: MemoryCardID(
                        groupIndex: groupIndex,
                        representationIndex: representationIndex
                    ),
                    representation: representation
                )
            }
        }

        self.equivalenceSets = equivalenceSets
        self.cards = cards
        self.revealSpeechCues = revealSpeechCues
        self.cardPresentationOrder = cards.map(\.id).shuffled()
        self.firstSelectedCardID = nil
        self.secondSelectedCardID = nil
        self.matchedGroupIndices = []
        self.attemptResult = nil
        self.isComplete = false
        self.presentationID = UUID()
    }

    var presentedCards: [MemoryCard] {
        let cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        return cardPresentationOrder.compactMap { cardsByID[$0] }
    }

    var pendingTransition: MemoryAttemptTransition? {
        guard attemptResult != nil,
              let firstCardID = firstSelectedCardID,
              let secondCardID = secondSelectedCardID else {
            return nil
        }
        return MemoryAttemptTransition(
            presentationID: presentationID,
            firstCardID: firstCardID,
            secondCardID: secondCardID
        )
    }

    func state(for cardID: MemoryCardID) -> MemoryCardState? {
        guard cards.contains(where: { $0.id == cardID }) else {
            return nil
        }
        if matchedGroupIndices.contains(cardID.groupIndex) {
            return .matched
        }
        if firstSelectedCardID == cardID || secondSelectedCardID == cardID {
            return .faceUp
        }
        return .faceDown
    }

    @discardableResult
    mutating func selectCard(_ cardID: MemoryCardID) -> LearningSpeechUtterance? {
        guard !isComplete,
              attemptResult == nil,
              !matchedGroupIndices.contains(cardID.groupIndex),
              cards.contains(where: { $0.id == cardID }),
              firstSelectedCardID != cardID else {
            return nil
        }

        if firstSelectedCardID == nil {
            firstSelectedCardID = cardID
            return revealSpeechCue(for: cardID)
        }

        guard secondSelectedCardID == nil else {
            return nil
        }
        secondSelectedCardID = cardID
        evaluateAttempt()
        return revealSpeechCue(for: cardID)
    }

    mutating func continueAfterAttempt() {
        guard !isComplete, attemptResult != nil else {
            return
        }

        let matchedAllGroups = matchedGroupIndices.count == equivalenceSets.count
        firstSelectedCardID = nil
        secondSelectedCardID = nil
        attemptResult = nil

        if matchedAllGroups {
            isComplete = true
        }
    }

    @discardableResult
    mutating func continueAfterAttempt(
        matching transition: MemoryAttemptTransition
    ) -> Bool {
        guard pendingTransition == transition else {
            return false
        }
        continueAfterAttempt()
        return true
    }

    mutating func startNewRound() {
        presentationID = UUID()
        cardPresentationOrder = cards.map(\.id).shuffled()
        firstSelectedCardID = nil
        secondSelectedCardID = nil
        matchedGroupIndices = []
        attemptResult = nil
        isComplete = false
    }

    private mutating func evaluateAttempt() {
        guard let firstID = firstSelectedCardID,
              let secondID = secondSelectedCardID else {
            return
        }

        if firstID.groupIndex == secondID.groupIndex {
            matchedGroupIndices.insert(firstID.groupIndex)
            attemptResult = .correct
        } else {
            attemptResult = .incorrect
        }
    }

    private func revealSpeechCue(
        for cardID: MemoryCardID
    ) -> LearningSpeechUtterance? {
        revealSpeechCues[equivalenceSets[cardID.groupIndex].semanticValue]
    }
}
