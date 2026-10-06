enum LearnProgressionPolicy: Equatable, Sendable {
    case completeAfterFinalCard
    case loopFromFinalCard
}

struct LearnSession: Sendable {
    let cards: [StudyCard]
    let progressionPolicy: LearnProgressionPolicy
    private(set) var currentCardIndex: Int
    private(set) var isComplete: Bool

    init?(
        cards: [StudyCard],
        progressionPolicy: LearnProgressionPolicy = .completeAfterFinalCard
    ) {
        guard !cards.isEmpty else {
            return nil
        }

        self.cards = cards
        self.progressionPolicy = progressionPolicy
        self.currentCardIndex = 0
        self.isComplete = false
    }

    var currentCard: StudyCard {
        cards[currentCardIndex]
    }

    var cardCount: Int {
        cards.count
    }

    var nextCardStartsOver: Bool {
        progressionPolicy == .loopFromFinalCard && currentCardIndex == cards.count - 1
    }

    mutating func nextCard() {
        guard !isComplete else {
            return
        }

        if currentCardIndex < cards.count - 1 {
            currentCardIndex += 1
        } else if progressionPolicy == .loopFromFinalCard {
            currentCardIndex = 0
        } else {
            isComplete = true
        }
    }
}
