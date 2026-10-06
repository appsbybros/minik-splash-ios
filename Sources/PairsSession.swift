enum PairsSide: Hashable, Sendable {
    case left
    case right
}

enum PairsSelectionStyle: Hashable, Sendable {
    case opposingColumns
    case anyTwoTiles
}

struct PairsItemDetails: Hashable, Sendable {
    let accessibilityLabel: String?
    let speechUtterance: LearningSpeechUtterance?

    init(
        accessibilityLabel: String? = nil,
        speechUtterance: LearningSpeechUtterance? = nil
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.speechUtterance = speechUtterance
    }
}

struct PairsItemID: Hashable, Sendable {
    let groupIndex: Int
    let side: PairsSide
}

struct PairsItem: Hashable, Sendable {
    let id: PairsItemID
    let representation: Representation
    let details: PairsItemDetails
}

enum PairsAttemptResult: Hashable, Sendable {
    case correct
    case incorrect
}

struct PairsSession: Sendable {
    let equivalenceSets: [EquivalenceSet]
    let selectionStyle: PairsSelectionStyle
    let leftItems: [PairsItem]
    let rightItems: [PairsItem]
    private(set) var leftPresentationOrder: [PairsItemID]
    private(set) var rightPresentationOrder: [PairsItemID]
    private(set) var mixedPresentationOrder: [PairsItemID]
    private(set) var selectedLeftItemID: PairsItemID?
    private(set) var selectedRightItemID: PairsItemID?
    private(set) var firstSelectedItemID: PairsItemID?
    private(set) var secondSelectedItemID: PairsItemID?
    private(set) var matchedGroupIndices: Set<Int>
    private(set) var attemptResult: PairsAttemptResult?
    private(set) var isComplete: Bool

    init?(
        equivalenceSets: [EquivalenceSet],
        selectionStyle: PairsSelectionStyle = .opposingColumns,
        itemDetails: [[PairsItemDetails]]? = nil
    ) {
        guard !equivalenceSets.isEmpty,
              equivalenceSets.allSatisfy({ $0.representations.count == 2 }),
              Set(equivalenceSets.map(\.semanticValue)).count == equivalenceSets.count,
              (itemDetails.map({ details in
                  details.count == equivalenceSets.count &&
                      details.allSatisfy { $0.count == 2 }
              }) ?? true) else {
            return nil
        }

        let resolvedDetails = itemDetails ?? Array(
            repeating: Array(repeating: PairsItemDetails(), count: 2),
            count: equivalenceSets.count
        )

        let leftItems = equivalenceSets.enumerated().map { index, set in
            PairsItem(
                id: PairsItemID(groupIndex: index, side: .left),
                representation: set.representations[0],
                details: resolvedDetails[index][0]
            )
        }
        let rightItems = equivalenceSets.enumerated().map { index, set in
            PairsItem(
                id: PairsItemID(groupIndex: index, side: .right),
                representation: set.representations[1],
                details: resolvedDetails[index][1]
            )
        }
        let leftOrder = leftItems.map(\.id).shuffled()
        var rightOrder = rightItems.map(\.id).shuffled()

        if rightOrder.count > 1,
           leftOrder.map(\.groupIndex) == rightOrder.map(\.groupIndex) {
            rightOrder.append(rightOrder.removeFirst())
        }

        self.equivalenceSets = equivalenceSets
        self.selectionStyle = selectionStyle
        self.leftItems = leftItems
        self.rightItems = rightItems
        self.leftPresentationOrder = leftOrder
        self.rightPresentationOrder = rightOrder
        self.mixedPresentationOrder = (leftItems + rightItems).map(\.id).shuffled()
        self.selectedLeftItemID = nil
        self.selectedRightItemID = nil
        self.firstSelectedItemID = nil
        self.secondSelectedItemID = nil
        self.matchedGroupIndices = []
        self.attemptResult = nil
        self.isComplete = false
    }

    var activeLeftItems: [PairsItem] {
        activeItems(items: leftItems, presentationOrder: leftPresentationOrder)
    }

    var activeRightItems: [PairsItem] {
        activeItems(items: rightItems, presentationOrder: rightPresentationOrder)
    }

    /// Fixed board positions, including matched tiles that fade to empty spaces.
    var mixedBoardItems: [PairsItem] {
        let byID = Dictionary(uniqueKeysWithValues: (leftItems + rightItems).map { ($0.id, $0) })
        return mixedPresentationOrder.compactMap { byID[$0] }
    }

    var activeMixedItems: [PairsItem] {
        activeItems(items: leftItems + rightItems, presentationOrder: mixedPresentationOrder)
    }

    var attemptedSemanticValue: SemanticValue? {
        guard let groupIndex = attemptedGroupIndex,
              equivalenceSets.indices.contains(groupIndex) else {
            return nil
        }
        return equivalenceSets[groupIndex].semanticValue
    }

    func isSelected(_ itemID: PairsItemID) -> Bool {
        switch selectionStyle {
        case .opposingColumns:
            return selectedLeftItemID == itemID || selectedRightItemID == itemID
        case .anyTwoTiles:
            return firstSelectedItemID == itemID || secondSelectedItemID == itemID
        }
    }

    @discardableResult
    mutating func selectItem(_ itemID: PairsItemID) -> LearningSpeechUtterance? {
        guard !isComplete,
              attemptResult == nil,
              !matchedGroupIndices.contains(itemID.groupIndex),
              let item = item(for: itemID) else {
            return nil
        }

        if selectionStyle == .anyTwoTiles {
            if firstSelectedItemID == item.id {
                firstSelectedItemID = nil
                return nil
            }
            guard secondSelectedItemID == nil else {
                return nil
            }
            if firstSelectedItemID == nil {
                firstSelectedItemID = item.id
            } else {
                secondSelectedItemID = item.id
                evaluateAttemptIfReady()
            }
            return item.details.speechUtterance
        }

        // A second tap on the chosen card of a side unselects it, as on the
        // any-two board. Another card of a side that already has a choice is
        // ignored here; PairsView first unselects the old one to move the choice.
        switch item.id.side {
        case .left:
            if selectedLeftItemID == item.id {
                selectedLeftItemID = nil
                return nil
            }
            guard selectedLeftItemID == nil else {
                return nil
            }
            selectedLeftItemID = item.id
        case .right:
            if selectedRightItemID == item.id {
                selectedRightItemID = nil
                return nil
            }
            guard selectedRightItemID == nil else {
                return nil
            }
            selectedRightItemID = item.id
        }

        evaluateAttemptIfReady()
        return item.details.speechUtterance
    }

    mutating func continueAfterAttempt() {
        guard !isComplete, attemptResult != nil else {
            return
        }

        let matchedAllGroups = matchedGroupIndices.count == equivalenceSets.count
        selectedLeftItemID = nil
        selectedRightItemID = nil
        firstSelectedItemID = nil
        secondSelectedItemID = nil
        attemptResult = nil

        if matchedAllGroups {
            isComplete = true
        }
    }

    private func activeItems(
        items: [PairsItem],
        presentationOrder: [PairsItemID]
    ) -> [PairsItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return presentationOrder.compactMap { itemID in
            guard !matchedGroupIndices.contains(itemID.groupIndex) else {
                return nil
            }
            return itemsByID[itemID]
        }
    }

    private func item(for itemID: PairsItemID) -> PairsItem? {
        switch itemID.side {
        case .left:
            leftItems.first { $0.id == itemID }
        case .right:
            rightItems.first { $0.id == itemID }
        }
    }

    private mutating func evaluateAttemptIfReady() {
        if selectionStyle == .anyTwoTiles {
            guard let firstID = firstSelectedItemID,
                  let secondID = secondSelectedItemID else {
                return
            }

            if firstID.groupIndex == secondID.groupIndex {
                matchedGroupIndices.insert(firstID.groupIndex)
                attemptResult = .correct
            } else {
                attemptResult = .incorrect
            }
            return
        }

        guard let leftID = selectedLeftItemID,
              let rightID = selectedRightItemID else {
            return
        }

        if leftID.groupIndex == rightID.groupIndex {
            matchedGroupIndices.insert(leftID.groupIndex)
            attemptResult = .correct
        } else {
            attemptResult = .incorrect
        }
    }

    private var attemptedGroupIndex: Int? {
        switch selectionStyle {
        case .opposingColumns:
            return selectedLeftItemID?.groupIndex
        case .anyTwoTiles:
            return firstSelectedItemID?.groupIndex
        }
    }
}
