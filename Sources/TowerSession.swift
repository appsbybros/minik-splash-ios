enum TowerAnswerResult: Hashable, Sendable {
    case correct
    case incorrect
}

struct TowerSession: Sendable {
    let rounds: [ComparableSet]
    private let expectedOrders: [[ComparableItemID]]
    private(set) var orderedTokenRound: TowerOrderedTokenRound?
    private(set) var currentRoundIndex: Int
    private(set) var itemPresentationOrder: [ComparableItemID]
    private(set) var selectedItemIDs: [ComparableItemID]
    private(set) var acceptedBlockIDs: [TowerBlockID]
    private(set) var acceptedTokens: [LearningTextRepresentation]
    private(set) var lastPlacedBlockID: TowerBlockID?
    private(set) var answerResult: TowerAnswerResult?
    private(set) var isComplete: Bool

    init?(rounds: [ComparableSet]) {
        guard !rounds.isEmpty else {
            return nil
        }

        var expectedOrders: [[ComparableItemID]] = []
        expectedOrders.reserveCapacity(rounds.count)

        for round in rounds {
            let valuedItems = round.items.compactMap { item -> (ComparableItemID, Int)? in
                guard case .integer(let value) = item.comparisonValue else {
                    return nil
                }
                return (item.id, value)
            }
            let values = valuedItems.map(\.1)

            guard valuedItems.count == round.items.count,
                  Set(values).count == values.count else {
                return nil
            }

            expectedOrders.append(
                valuedItems.sorted { $0.1 < $1.1 }.map(\.0)
            )
        }

        self.rounds = rounds
        self.expectedOrders = expectedOrders
        self.orderedTokenRound = nil
        self.currentRoundIndex = 0
        self.itemPresentationOrder = Self.makePresentationOrder(
            for: rounds[0],
            expectedOrder: expectedOrders[0]
        )
        self.selectedItemIDs = []
        self.acceptedBlockIDs = []
        self.acceptedTokens = []
        self.lastPlacedBlockID = nil
        self.answerResult = nil
        self.isComplete = false
    }

    init?(orderedTokenRound: TowerOrderedTokenRound) {
        let content = orderedTokenRound.content
        guard let baseBlock = orderedTokenRound.blocks.first(where: {
            $0.orderedToken == content.expectedTokenSequence[0]
        }) else {
            return nil
        }

        self.rounds = []
        self.expectedOrders = []
        self.orderedTokenRound = orderedTokenRound
        self.currentRoundIndex = 0
        self.itemPresentationOrder = []
        self.selectedItemIDs = []
        self.acceptedBlockIDs = [baseBlock.id]
        self.acceptedTokens = [baseBlock.orderedToken]
        self.lastPlacedBlockID = nil
        self.answerResult = nil
        self.isComplete = content.expectedTokenSequence.count == 1
    }

    var mechanic: TowerRoundMechanic {
        orderedTokenRound?.mechanic ?? .valueOrdering
    }

    var currentRound: ComparableSet {
        guard orderedTokenRound == nil else {
            preconditionFailure("Ordered-token Tower rounds do not use comparable sets.")
        }
        return rounds[currentRoundIndex]
    }

    var roundCount: Int {
        orderedTokenRound == nil ? rounds.count : 1
    }

    var expectedAscendingItemIDs: [ComparableItemID] {
        guard orderedTokenRound == nil else {
            preconditionFailure("Ordered-token Tower rounds do not have ascending item IDs.")
        }
        return expectedOrders[currentRoundIndex]
    }

    var orderedTokenContent: TowerOrderedTokenContent? {
        orderedTokenRound?.content
    }

    var availableOrderedBlocks: [TowerBlock] {
        guard let orderedTokenRound else {
            return []
        }
        let accepted = Set(acceptedBlockIDs)
        return orderedTokenRound.blocks.filter { !accepted.contains($0.id) }
    }

    var acceptedOrderedBlocks: [TowerBlock] {
        guard let orderedTokenRound else {
            return []
        }
        let blocksByID = Dictionary(
            uniqueKeysWithValues: orderedTokenRound.blocks.map { ($0.id, $0) }
        )
        return acceptedBlockIDs.compactMap { blocksByID[$0] }
    }

    var currentExpectedToken: LearningTextRepresentation? {
        guard let content = orderedTokenContent,
              content.expectedTokenSequence.indices.contains(acceptedTokens.count) else {
            return nil
        }
        return content.expectedTokenSequence[acceptedTokens.count]
    }

    var orderedProgressCount: Int {
        acceptedTokens.count
    }

    var orderedTargetCount: Int {
        orderedTokenContent?.expectedTokenSequence.count ?? 0
    }

    var builtDisplayText: String? {
        guard let content = orderedTokenContent else {
            return nil
        }

        var display = ""
        var acceptedIndex = 0

        for character in content.targetText.text {
            if character.isWhitespace {
                if acceptedIndex > 0 {
                    display.append(character)
                }
                continue
            }
            guard acceptedTokens.indices.contains(acceptedIndex) else {
                break
            }
            display.append(contentsOf: acceptedTokens[acceptedIndex].text)
            acceptedIndex += 1
        }
        return display
    }

    var lastAcceptedBlockSpeechCue: LearningSpeechUtterance? {
        guard answerResult == .correct,
              let lastPlacedBlockID,
              let token = orderedTokenRound?.blocks.first(where: {
                  $0.id == lastPlacedBlockID
              })?.orderedToken,
              let language = token.language else {
            return nil
        }
        return LearningSpeechUtterance(
            text: token.speechText ?? token.text,
            language: language
        )
    }

    mutating func selectItem(_ itemID: ComparableItemID) {
        guard orderedTokenRound == nil,
              !isComplete,
              answerResult == nil,
              !selectedItemIDs.contains(itemID),
              currentRound.items.contains(where: { $0.id == itemID }) else {
            return
        }

        selectedItemIDs.append(itemID)
    }

    mutating func undoLastItem() {
        guard orderedTokenRound == nil,
              !isComplete,
              answerResult == nil,
              !selectedItemIDs.isEmpty else {
            return
        }

        selectedItemIDs.removeLast()
    }

    mutating func submit() {
        guard orderedTokenRound == nil,
              !isComplete,
              answerResult == nil,
              selectedItemIDs.count == currentRound.items.count else {
            return
        }

        answerResult = selectedItemIDs == expectedAscendingItemIDs
            ? .correct
            : .incorrect
    }

    mutating func nextRound() {
        guard orderedTokenRound == nil,
              !isComplete,
              answerResult != nil else {
            return
        }

        if currentRoundIndex < rounds.count - 1 {
            currentRoundIndex += 1
            itemPresentationOrder = Self.makePresentationOrder(
                for: currentRound,
                expectedOrder: expectedAscendingItemIDs
            )
            selectedItemIDs = []
            answerResult = nil
        } else {
            isComplete = true
        }
    }

    @discardableResult
    mutating func placeOrderedBlock(_ blockID: TowerBlockID) -> TowerAnswerResult? {
        guard orderedTokenRound != nil,
              !isComplete,
              answerResult == nil,
              let block = availableOrderedBlocks.first(where: { $0.id == blockID }),
              let expected = currentExpectedToken else {
            return nil
        }

        lastPlacedBlockID = blockID
        guard block.orderedToken == expected else {
            answerResult = .incorrect
            return .incorrect
        }

        acceptedBlockIDs.append(blockID)
        acceptedTokens.append(block.orderedToken)
        answerResult = .correct
        isComplete = acceptedTokens.count == orderedTargetCount
        return .correct
    }

    mutating func clearOrderedPlacementFeedback() {
        guard orderedTokenRound != nil, !isComplete else {
            return
        }
        answerResult = nil
        lastPlacedBlockID = nil
    }

    private static func makePresentationOrder(
        for round: ComparableSet,
        expectedOrder: [ComparableItemID]
    ) -> [ComparableItemID] {
        var order = round.items.map(\.id).shuffled()

        if order.count > 1, order == expectedOrder {
            order.append(order.removeFirst())
        }

        return order
    }
}
