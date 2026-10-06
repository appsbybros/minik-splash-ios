import Foundation

struct CardsSession: Sendable {
    private(set) var presentationID = UUID()
    private let sourceCards: [StudyCard]
    private(set) var presentationCards: [StudyCard]
    private(set) var currentCardIndex: Int

    init?(cards: [StudyCard]) {
        let cardIDs = cards.map(\.id)
        guard !cards.isEmpty,
              Set(cardIDs).count == cardIDs.count else {
            return nil
        }

        sourceCards = cards
        presentationCards = cards.shuffled()
        currentCardIndex = 0
    }

    var currentCard: StudyCard {
        presentationCards[currentCardIndex]
    }

    var cardCount: Int {
        presentationCards.count
    }

    var presentationCardIDs: [StudyCardID] {
        presentationCards.map(\.id)
    }

    mutating func advance() {
        presentationID = UUID()
        if currentCardIndex < presentationCards.count - 1 {
            currentCardIndex += 1
            return
        }

        let lastCardID = currentCard.id
        var nextCycle = sourceCards.shuffled()

        if nextCycle.count > 1, nextCycle.first?.id == lastCardID,
           let replacementIndex = nextCycle.firstIndex(where: { $0.id != lastCardID }) {
            nextCycle.swapAt(0, replacementIndex)
        }

        presentationCards = nextCycle
        currentCardIndex = 0
    }

    @discardableResult
    mutating func advance(ifCurrentCardID expectedCardID: StudyCardID) -> Bool {
        guard currentCard.id == expectedCardID else {
            return false
        }

        advance()
        return true
    }

    @discardableResult
    mutating func advance(ifPresentationID expectedID: UUID) -> Bool {
        guard presentationID == expectedID else { return false }
        advance()
        return true
    }

    mutating func shuffle() {
        presentationID = UUID()
        let currentID = currentCard.id
        var shuffled = sourceCards.shuffled()
        if shuffled.count > 1, shuffled.first?.id == currentID,
           let replacement = shuffled.firstIndex(where: { $0.id != currentID }) {
            shuffled.swapAt(0, replacement)
        }
        presentationCards = shuffled
        currentCardIndex = 0
    }
}
