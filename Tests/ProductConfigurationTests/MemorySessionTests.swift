import XCTest
@testable import MinikPlus

final class MemorySessionTests: XCTestCase {
    func testEmptyOrInvalidInitializationFails() throws {
        let threeRepresentations = try XCTUnwrap(EquivalenceSet(
            semanticValue: .integer(1),
            representations: [representation("A"), representation("B"), representation("C")]
        ))
        let duplicateFirst = try makeSet(value: 2)
        let duplicateSecond = try XCTUnwrap(EquivalenceSet(
            semanticValue: .integer(2),
            representations: [representation("D"), representation("E")]
        ))

        XCTAssertNil(MemorySession(equivalenceSets: []))
        XCTAssertNil(MemorySession(equivalenceSets: [threeRepresentations]))
        XCTAssertNil(MemorySession(equivalenceSets: [duplicateFirst, duplicateSecond]))
    }

    func testFourGroupsCreateEightStableUniqueCards() throws {
        let sets = try makeSets(count: 4)
        let session = try XCTUnwrap(MemorySession(equivalenceSets: sets))

        XCTAssertEqual(session.cards.count, 8)
        XCTAssertEqual(Set(session.cards.map(\.id)).count, 8)
        XCTAssertEqual(Set(session.cards.map { $0.id.groupIndex }), Set(0 ..< 4))
    }

    func testIdenticalRepresentationsCreateDistinctMatchingCardInstances() throws {
        let image = Representation.imageAsset(AssetReference(rawValue: "apple"))
        let set = try XCTUnwrap(EquivalenceSet(
            semanticValue: .contentItem(ContentItemID(rawValue: "fruit.apple")),
            representations: [image, image]
        ))
        var session = try XCTUnwrap(MemorySession(equivalenceSets: [set]))

        XCTAssertEqual(session.cards.count, 2)
        XCTAssertNotEqual(session.cards[0].id, session.cards[1].id)
        XCTAssertEqual(session.cards[0].representation, session.cards[1].representation)

        session.selectCard(session.cards[0].id)
        session.selectCard(session.cards[1].id)

        XCTAssertEqual(session.attemptResult, .correct)
        XCTAssertEqual(session.matchedGroupIndices, [0])
    }

    func testMatchingUsesGroupIdentityInsteadOfRepresentationEquality() throws {
        let image = Representation.imageAsset(AssetReference(rawValue: "shared-image"))
        let firstSet = try XCTUnwrap(EquivalenceSet(
            semanticValue: .contentItem(ContentItemID(rawValue: "item.first")),
            representations: [image, image]
        ))
        let secondSet = try XCTUnwrap(EquivalenceSet(
            semanticValue: .contentItem(ContentItemID(rawValue: "item.second")),
            representations: [image, image]
        ))
        var session = try XCTUnwrap(MemorySession(
            equivalenceSets: [firstSet, secondSet]
        ))
        let firstCard = try XCTUnwrap(session.cards.first { $0.id.groupIndex == 0 })
        let secondCard = try XCTUnwrap(session.cards.first { $0.id.groupIndex == 1 })

        session.selectCard(firstCard.id)
        session.selectCard(secondCard.id)

        XCTAssertEqual(session.attemptResult, .incorrect)
        XCTAssertTrue(session.matchedGroupIndices.isEmpty)
    }

    func testAcceptedRevealsEmitOneCueAndIgnoredSelectionsEmitNone() throws {
        let sets = try makeSets(count: 2)
        let firstCue = LearningSpeechUtterance(text: "Apple", language: .english)
        let secondCue = LearningSpeechUtterance(text: "אגס", language: .hebrew)
        var session = try XCTUnwrap(MemorySession(
            equivalenceSets: sets,
            revealSpeechCues: [
                .integer(0): firstCue,
                .integer(1): secondCue
            ]
        ))
        let firstPair = session.cards.filter { $0.id.groupIndex == 0 }
        let secondPair = session.cards.filter { $0.id.groupIndex == 1 }
        let unknownID = MemoryCardID(groupIndex: 99, representationIndex: 0)

        XCTAssertEqual(session.selectCard(firstPair[0].id), firstCue)
        XCTAssertNil(session.selectCard(firstPair[0].id))
        XCTAssertNil(session.selectCard(unknownID))
        XCTAssertEqual(session.selectCard(secondPair[0].id), secondCue)
        XCTAssertNil(session.selectCard(secondPair[1].id))

        session.continueAfterAttempt()

        XCTAssertEqual(session.selectCard(firstPair[0].id), firstCue)
        XCTAssertEqual(session.selectCard(firstPair[1].id), firstCue)

        session.continueAfterAttempt()

        XCTAssertNil(session.selectCard(firstPair[0].id))
    }

    func testGenericMathMemoryRemainsSilentWithoutRevealCues() throws {
        let set = try XCTUnwrap(EquivalenceSet(
            semanticValue: .integer(4),
            representations: [
                .mathExpression(MathExpressionRepresentation(
                    expression: "2 + 2",
                    structureID: RepresentationStructureID(rawValue: "addition.2-plus-2")
                )),
                .mathExpression(MathExpressionRepresentation(
                    expression: "1 + 3",
                    structureID: RepresentationStructureID(rawValue: "addition.1-plus-3")
                ))
            ]
        ))
        var session = try XCTUnwrap(MemorySession(equivalenceSets: [set]))

        XCTAssertNil(session.selectCard(session.cards[0].id))
        XCTAssertNil(session.selectCard(session.cards[1].id))
        XCTAssertEqual(session.attemptResult, .correct)
    }

    func testNewRoundPreservesGenericMathCardsAndSilentContract() throws {
        let set = try XCTUnwrap(EquivalenceSet(
            semanticValue: .integer(4),
            representations: [
                .mathExpression(MathExpressionRepresentation(
                    expression: "2 + 2",
                    structureID: RepresentationStructureID(rawValue: "addition.2-plus-2")
                )),
                .mathExpression(MathExpressionRepresentation(
                    expression: "1 + 3",
                    structureID: RepresentationStructureID(rawValue: "addition.1-plus-3")
                ))
            ]
        ))
        var session = try XCTUnwrap(MemorySession(equivalenceSets: [set]))
        let originalCards = session.cards

        session.selectCard(session.cards[0].id)
        session.selectCard(session.cards[1].id)
        session.continueAfterAttempt()
        session.startNewRound()

        XCTAssertEqual(session.cards, originalCards)
        XCTAssertTrue(session.cards.allSatisfy {
            session.state(for: $0.id) == .faceDown
        })
        XCTAssertNil(session.selectCard(session.presentedCards[0].id))
    }

    func testPresentationOrderContainsEveryCardOnceAndRemainsStable() throws {
        let sets = try makeSets(count: 4)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let order = session.cardPresentationOrder

        XCTAssertEqual(Set(order), Set(session.cards.map(\.id)))
        XCTAssertEqual(order.count, session.cards.count)

        session.selectCard(order[0])

        XCTAssertEqual(session.cardPresentationOrder, order)
    }

    func testFirstSelectionTurnsUpOneCardAndIgnoresDuplicateAndUnknown() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let firstID = session.cards[0].id
        let unknownID = MemoryCardID(groupIndex: 99, representationIndex: 0)

        session.selectCard(firstID)
        session.selectCard(firstID)
        session.selectCard(unknownID)

        XCTAssertEqual(session.firstSelectedCardID, firstID)
        XCTAssertNil(session.secondSelectedCardID)
        XCTAssertNil(session.attemptResult)
        XCTAssertTrue(session.matchedGroupIndices.isEmpty)
        XCTAssertEqual(session.state(for: firstID), .faceUp)
        XCTAssertNil(session.state(for: unknownID))
    }

    func testMatchingPairBecomesCorrectMatchedAndFaceUp() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let pair = session.cards.filter { $0.id.groupIndex == 0 }

        session.selectCard(pair[0].id)
        session.selectCard(pair[1].id)

        XCTAssertEqual(session.attemptResult, .correct)
        XCTAssertEqual(session.matchedGroupIndices, [0])
        XCTAssertEqual(session.state(for: pair[0].id), .matched)
        XCTAssertEqual(session.state(for: pair[1].id), .matched)
    }

    func testIncorrectPairReturnsFaceDownAfterContinueWithoutMatching() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let firstID = session.cards.first { $0.id.groupIndex == 0 }?.id
        let secondID = session.cards.first { $0.id.groupIndex == 1 }?.id
        let first = try XCTUnwrap(firstID)
        let second = try XCTUnwrap(secondID)
        session.selectCard(first)
        session.selectCard(second)

        XCTAssertEqual(session.attemptResult, .incorrect)
        XCTAssertEqual(session.state(for: first), .faceUp)
        XCTAssertEqual(session.state(for: second), .faceUp)

        session.continueAfterAttempt()

        XCTAssertEqual(session.matchedGroupIndices, [])
        XCTAssertEqual(session.state(for: first), .faceDown)
        XCTAssertEqual(session.state(for: second), .faceDown)
    }

    func testIncorrectPairResetDoesNotMoveAnyPhysicalCard() throws {
        let sets = try makeSets(count: 6)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let originalOrder = session.cardPresentationOrder
        let first = try XCTUnwrap(session.cards.first { $0.id.groupIndex == 0 })
        let second = try XCTUnwrap(session.cards.first { $0.id.groupIndex == 1 })

        session.selectCard(first.id)
        session.selectCard(second.id)
        session.continueAfterAttempt()

        XCTAssertEqual(session.cardPresentationOrder, originalOrder)
        XCTAssertEqual(session.presentedCards.map(\.id), originalOrder)
        XCTAssertTrue(session.presentedCards.allSatisfy {
            session.state(for: $0.id) == .faceDown
        })
    }

    func testCorrectContinuePreservesMatchedCardsAndAllowsFurtherPlay() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let firstPair = session.cards.filter { $0.id.groupIndex == 0 }
        let remainingCard = try XCTUnwrap(session.cards.first { $0.id.groupIndex == 1 })
        session.selectCard(firstPair[0].id)
        session.selectCard(firstPair[1].id)

        session.continueAfterAttempt()
        session.selectCard(remainingCard.id)

        XCTAssertEqual(session.state(for: firstPair[0].id), .matched)
        XCTAssertEqual(session.state(for: firstPair[1].id), .matched)
        XCTAssertEqual(session.firstSelectedCardID, remainingCard.id)
        XCTAssertFalse(session.isComplete)
        XCTAssertNil(session.selectCard(firstPair[0].id))
        XCTAssertEqual(session.firstSelectedCardID, remainingCard.id)
    }

    func testNewRoundClearsEveryRevealMatchAndCompletionState() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let originalPresentationID = session.presentationID
        let pair = session.cards.filter { $0.id.groupIndex == 0 }

        session.selectCard(pair[0].id)
        session.selectCard(pair[1].id)
        session.continueAfterAttempt()
        session.startNewRound()

        XCTAssertNotEqual(session.presentationID, originalPresentationID)
        XCTAssertNil(session.firstSelectedCardID)
        XCTAssertNil(session.secondSelectedCardID)
        XCTAssertNil(session.attemptResult)
        XCTAssertTrue(session.matchedGroupIndices.isEmpty)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(Set(session.cardPresentationOrder), Set(session.cards.map(\.id)))
        XCTAssertTrue(session.cards.allSatisfy {
            session.state(for: $0.id) == .faceDown
        })
    }

    func testStaleTransitionCannotMutateANewerRound() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: sets))
        let first = try XCTUnwrap(session.cards.first { $0.id.groupIndex == 0 })
        let second = try XCTUnwrap(session.cards.first { $0.id.groupIndex == 1 })

        session.selectCard(first.id)
        session.selectCard(second.id)
        let staleTransition = try XCTUnwrap(session.pendingTransition)
        session.startNewRound()

        XCTAssertFalse(session.continueAfterAttempt(matching: staleTransition))
        XCTAssertNil(session.attemptResult)
        XCTAssertTrue(session.matchedGroupIndices.isEmpty)
        XCTAssertTrue(session.cards.allSatisfy {
            session.state(for: $0.id) == .faceDown
        })
    }

    func testFinalCorrectContinueCompletesAndPostCompletionActionsAreSafe() throws {
        let set = try makeSet(value: 1)
        var session = try XCTUnwrap(MemorySession(equivalenceSets: [set]))
        let firstID = session.cards[0].id
        let secondID = session.cards[1].id
        session.selectCard(firstID)
        session.selectCard(secondID)

        XCTAssertFalse(session.isComplete)

        session.continueAfterAttempt()
        session.selectCard(firstID)
        session.continueAfterAttempt()

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.matchedGroupIndices, [0])
        XCTAssertEqual(session.state(for: firstID), .matched)
        XCTAssertEqual(session.state(for: secondID), .matched)
        XCTAssertNil(session.firstSelectedCardID)
        XCTAssertNil(session.secondSelectedCardID)
        XCTAssertNil(session.attemptResult)
    }

    private func makeSets(count: Int) throws -> [EquivalenceSet] {
        try (0 ..< count).map { index in
            try makeSet(value: index)
        }
    }

    private func makeSet(value: Int) throws -> EquivalenceSet {
        try XCTUnwrap(EquivalenceSet(
            semanticValue: .integer(value),
            representations: [
                representation("First \(value)"),
                representation("Second \(value)")
            ]
        ))
    }

    private func representation(_ text: String) -> Representation {
        .learningText(LearningTextRepresentation(
            text: text,
            language: nil,
            direction: nil
        ))
    }
}
