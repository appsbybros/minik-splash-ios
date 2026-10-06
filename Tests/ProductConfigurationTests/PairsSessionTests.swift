import XCTest
@testable import MinikPlus

final class PairsSessionTests: XCTestCase {
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

        XCTAssertNil(PairsSession(equivalenceSets: []))
        XCTAssertNil(PairsSession(equivalenceSets: [threeRepresentations]))
        XCTAssertNil(PairsSession(equivalenceSets: [duplicateFirst, duplicateSecond]))
    }

    func testItemIdentitiesAreCompleteAndUnique() throws {
        let sets = try makeSets(count: 3)
        let session = try XCTUnwrap(PairsSession(equivalenceSets: sets))
        let allIDs = session.leftItems.map(\.id) + session.rightItems.map(\.id)

        XCTAssertEqual(session.leftItems.count, 3)
        XCTAssertEqual(session.rightItems.count, 3)
        XCTAssertEqual(Set(allIDs).count, 6)
        XCTAssertEqual(Set(allIDs.map(\.groupIndex)), Set(0 ..< 3))
    }

    func testPresentationOrdersAreStableAndNotRowAligned() throws {
        let sets = try makeSets(count: 3)
        var session = try XCTUnwrap(PairsSession(equivalenceSets: sets))
        let leftOrder = session.leftPresentationOrder
        let rightOrder = session.rightPresentationOrder

        XCTAssertEqual(Set(leftOrder), Set(session.leftItems.map(\.id)))
        XCTAssertEqual(Set(rightOrder), Set(session.rightItems.map(\.id)))
        XCTAssertNotEqual(leftOrder.map(\.groupIndex), rightOrder.map(\.groupIndex))

        session.selectItem(leftOrder[0])

        XCTAssertEqual(session.leftPresentationOrder, leftOrder)
        XCTAssertEqual(session.rightPresentationOrder, rightOrder)
    }

    func testUnknownAndDuplicateSideSelectionAreIgnored() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(PairsSession(equivalenceSets: sets))
        let firstLeft = session.leftItems[0].id
        let secondLeft = session.leftItems[1].id

        session.selectItem(firstLeft)
        session.selectItem(secondLeft)
        session.selectItem(PairsItemID(groupIndex: 99, side: .right))

        XCTAssertEqual(session.selectedLeftItemID, firstLeft)
        XCTAssertNil(session.selectedRightItemID)
        XCTAssertNil(session.attemptResult)
    }

    func testMatchingGroupIsRecognizedAsCorrect() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(PairsSession(equivalenceSets: sets))

        session.selectItem(session.rightItems[0].id)
        session.selectItem(session.leftItems[0].id)

        XCTAssertEqual(session.attemptResult, .correct)
        XCTAssertEqual(session.matchedGroupIndices, [0])
    }

    func testMismatchedGroupsResetWithoutBecomingMatched() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(PairsSession(equivalenceSets: sets))

        session.selectItem(session.leftItems[0].id)
        session.selectItem(session.rightItems[1].id)

        XCTAssertEqual(session.attemptResult, .incorrect)
        XCTAssertEqual(session.matchedGroupIndices, [])

        session.continueAfterAttempt()

        XCTAssertNil(session.selectedLeftItemID)
        XCTAssertNil(session.selectedRightItemID)
        XCTAssertNil(session.attemptResult)
        XCTAssertEqual(session.activeLeftItems.count, 2)
        XCTAssertEqual(session.activeRightItems.count, 2)
    }

    func testCorrectContinuationPreservesMatchAndRemovesGroupFromPlay() throws {
        let sets = try makeSets(count: 2)
        var session = try XCTUnwrap(PairsSession(equivalenceSets: sets))
        session.selectItem(session.leftItems[0].id)
        session.selectItem(session.rightItems[0].id)

        session.continueAfterAttempt()

        XCTAssertEqual(session.matchedGroupIndices, [0])
        XCTAssertEqual(session.activeLeftItems.map { $0.id.groupIndex }, [1])
        XCTAssertEqual(session.activeRightItems.map { $0.id.groupIndex }, [1])
        XCTAssertFalse(session.isComplete)
    }

    func testFinalCorrectContinuationCompletesAndActionsRemainSafe() throws {
        let set = try makeSet(value: 1)
        var session = try XCTUnwrap(PairsSession(equivalenceSets: [set]))
        let leftID = session.leftItems[0].id
        let rightID = session.rightItems[0].id
        session.selectItem(leftID)
        session.selectItem(rightID)

        session.continueAfterAttempt()
        session.selectItem(leftID)
        session.continueAfterAttempt()

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.matchedGroupIndices, [0])
        XCTAssertNil(session.selectedLeftItemID)
        XCTAssertNil(session.selectedRightItemID)
        XCTAssertNil(session.attemptResult)
    }

    func testAnyTwoTilesAcceptsArbitraryPhysicalCardsAndSupportsDeselection() throws {
        let sets = try makeSets(count: 2)
        let firstCue = LearningSpeechUtterance(text: "Apple", language: .english)
        let secondCue = LearningSpeechUtterance(text: "Ball", language: .english)
        let details = [
            [
                PairsItemDetails(accessibilityLabel: "Apple", speechUtterance: firstCue),
                PairsItemDetails(accessibilityLabel: "Apricot", speechUtterance: firstCue)
            ],
            [
                PairsItemDetails(accessibilityLabel: "Ball", speechUtterance: secondCue),
                PairsItemDetails(accessibilityLabel: "Book", speechUtterance: secondCue)
            ]
        ]
        var session = try XCTUnwrap(PairsSession(
            equivalenceSets: sets,
            selectionStyle: .anyTwoTiles,
            itemDetails: details
        ))
        let first = session.leftItems[0].id
        let secondOnSamePhysicalSide = session.leftItems[1].id

        XCTAssertEqual(session.selectItem(first), firstCue)
        XCTAssertTrue(session.isSelected(first))
        XCTAssertNil(session.selectItem(first))
        XCTAssertFalse(session.isSelected(first))

        XCTAssertEqual(session.selectItem(first), firstCue)
        XCTAssertEqual(session.selectItem(secondOnSamePhysicalSide), secondCue)
        XCTAssertEqual(session.attemptResult, .incorrect)
        XCTAssertEqual(session.attemptedSemanticValue, sets[0].semanticValue)

        session.continueAfterAttempt()
        XCTAssertEqual(session.selectItem(first), firstCue)
        XCTAssertEqual(session.selectItem(session.rightItems[0].id), firstCue)
        XCTAssertEqual(session.attemptResult, .correct)

        session.continueAfterAttempt()
        XCTAssertEqual(session.activeMixedItems.count, 2)
        XCTAssertEqual(session.selectItem(session.leftItems[1].id), secondCue)
        XCTAssertEqual(session.selectItem(session.rightItems[1].id), secondCue)
        session.continueAfterAttempt()
        XCTAssertTrue(session.isComplete)
        XCTAssertTrue(session.activeMixedItems.isEmpty)
    }

    func testAnyTwoPresentationContainsEveryPhysicalTileExactlyOnce() throws {
        let sets = try makeSets(count: 4)
        let session = try XCTUnwrap(PairsSession(
            equivalenceSets: sets,
            selectionStyle: .anyTwoTiles
        ))
        let expectedIDs = Set(session.leftItems.map(\.id) + session.rightItems.map(\.id))

        XCTAssertEqual(session.activeMixedItems.count, 8)
        XCTAssertEqual(Set(session.mixedPresentationOrder), expectedIDs)
        XCTAssertEqual(Set(session.activeMixedItems.map(\.id)), expectedIDs)
        XCTAssertEqual(expectedIDs.count, 8)
    }

    func testItemDetailsMustMatchEveryPhysicalTile() throws {
        let sets = try makeSets(count: 2)

        XCTAssertNil(PairsSession(
            equivalenceSets: sets,
            selectionStyle: .anyTwoTiles,
            itemDetails: [[PairsItemDetails()]]
        ))
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
                representation("Left \(value)"),
                representation("Right \(value)")
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
