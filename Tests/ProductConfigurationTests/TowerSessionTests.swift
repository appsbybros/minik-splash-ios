import XCTest
@testable import MinikPlus

final class TowerSessionTests: XCTestCase {
    func testEmptyInitializationFails() {
        XCTAssertNil(TowerSession(rounds: []))
    }

    func testUnsupportedOrAmbiguousRoundFailsSafely() throws {
        let oneHalf = try XCTUnwrap(Rational(numerator: 1, denominator: 2))
        let rationalRound = try makeRound(values: [
            ("half", .rational(oneHalf)),
            ("one", .integer(1))
        ])
        let duplicateRound = try makeRound(values: [
            ("first", .integer(2)),
            ("second", .integer(2))
        ])

        XCTAssertNil(TowerSession(rounds: [rationalRound]))
        XCTAssertNil(TowerSession(rounds: [duplicateRound]))
    }

    func testExpectedAscendingOrderUsesIntegerValuesNotInputOrder() throws {
        let round = try integerRound(id: "round.1", values: [7, 2, 5])
        let session = try XCTUnwrap(TowerSession(rounds: [round]))
        let expectedIDs = [round.items[1].id, round.items[2].id, round.items[0].id]

        XCTAssertEqual(session.expectedAscendingItemIDs, expectedIDs)
    }

    func testPresentationOrderIsCompleteUniqueNoncanonicalAndStable() throws {
        let round = try integerRound(id: "round.1", values: [1, 2, 3])
        var session = try XCTUnwrap(TowerSession(rounds: [round]))
        let presentationOrder = session.itemPresentationOrder
        let availableIDs = round.items.map(\.id)

        XCTAssertEqual(Set(presentationOrder), Set(availableIDs))
        XCTAssertEqual(presentationOrder.count, availableIDs.count)
        XCTAssertNotEqual(presentationOrder, session.expectedAscendingItemIDs)

        session.selectItem(presentationOrder[0])
        session.undoLastItem()
        for itemID in session.expectedAscendingItemIDs {
            session.selectItem(itemID)
        }
        session.submit()

        XCTAssertEqual(session.itemPresentationOrder, presentationOrder)
    }

    func testSelectionPreservesOrderAndRejectsDuplicateAndUnknownIDs() throws {
        let round = try integerRound(id: "round.1", values: [1, 2, 3])
        var session = try XCTUnwrap(TowerSession(rounds: [round]))
        let first = round.items[1].id
        let second = round.items[0].id

        session.selectItem(first)
        session.selectItem(second)
        session.selectItem(first)
        session.selectItem(ComparableItemID(rawValue: "missing"))

        XCTAssertEqual(session.selectedItemIDs, [first, second])
    }

    func testUndoAndSubmitGuards() throws {
        let round = try integerRound(id: "round.1", values: [1, 2, 3])
        var session = try XCTUnwrap(TowerSession(rounds: [round]))
        session.undoLastItem()
        session.selectItem(round.items[0].id)

        session.submit()

        XCTAssertEqual(session.selectedItemIDs, [round.items[0].id])
        XCTAssertNil(session.answerResult)

        session.undoLastItem()

        XCTAssertEqual(session.selectedItemIDs, [])
    }

    func testCorrectAndIncorrectOrdersAreDetected() throws {
        let round = try integerRound(id: "round.1", values: [3, 1, 2])
        var correctSession = try XCTUnwrap(TowerSession(rounds: [round]))
        var incorrectSession = try XCTUnwrap(TowerSession(rounds: [round]))

        for itemID in correctSession.expectedAscendingItemIDs {
            correctSession.selectItem(itemID)
        }
        for itemID in incorrectSession.expectedAscendingItemIDs.reversed() {
            incorrectSession.selectItem(itemID)
        }
        correctSession.submit()
        incorrectSession.submit()

        XCTAssertEqual(correctSession.answerResult, .correct)
        XCTAssertEqual(incorrectSession.answerResult, .incorrect)
    }

    func testNextClearsStateAndFinalNextCompletesSafely() throws {
        let firstRound = try integerRound(id: "round.1", values: [2, 1])
        let secondRound = try integerRound(id: "round.2", values: [4, 3])
        var session = try XCTUnwrap(TowerSession(rounds: [firstRound, secondRound]))
        for itemID in session.expectedAscendingItemIDs {
            session.selectItem(itemID)
        }
        session.submit()

        session.nextRound()

        XCTAssertEqual(session.currentRoundIndex, 1)
        XCTAssertEqual(session.selectedItemIDs, [])
        XCTAssertNil(session.answerResult)
        XCTAssertEqual(Set(session.itemPresentationOrder), Set(secondRound.items.map(\.id)))
        XCTAssertNotEqual(session.itemPresentationOrder, session.expectedAscendingItemIDs)

        for itemID in session.expectedAscendingItemIDs {
            session.selectItem(itemID)
        }
        session.submit()
        session.nextRound()
        let completedSelection = session.selectedItemIDs
        let completedResult = session.answerResult

        session.undoLastItem()
        session.selectItem(secondRound.items[0].id)
        session.submit()
        session.nextRound()

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.currentRoundIndex, 1)
        XCTAssertEqual(session.selectedItemIDs, completedSelection)
        XCTAssertEqual(session.answerResult, completedResult)
    }

    func testOrderedBlockPlacementDoesNotChangeMathValueOrderingState() throws {
        let round = try integerRound(id: "round.1", values: [3, 1, 2])
        var session = try XCTUnwrap(TowerSession(rounds: [round]))
        let presentationOrder = session.itemPresentationOrder

        XCTAssertEqual(session.mechanic, .valueOrdering)
        XCTAssertNil(session.placeOrderedBlock(TowerBlockID(rawValue: "language.block")))

        XCTAssertEqual(session.currentRound, round)
        XCTAssertEqual(session.itemPresentationOrder, presentationOrder)
        XCTAssertTrue(session.selectedItemIDs.isEmpty)
        XCTAssertNil(session.answerResult)
        XCTAssertFalse(session.isComplete)
    }

    private func integerRound(id: String, values: [Int]) throws -> ComparableSet {
        let numericValues: [(String, ExactNumericValue)] = values.enumerated().map { index, value in
            ("\(id).item.\(index)", .integer(value))
        }
        return try makeRound(values: numericValues)
    }

    private func makeRound(
        values: [(String, ExactNumericValue)]
    ) throws -> ComparableSet {
        let items = values.map { entry in
            ComparableItem(
                id: ComparableItemID(rawValue: entry.0),
                representation: .learningText(LearningTextRepresentation(
                    text: "Item \(entry.0)",
                    language: nil,
                    direction: nil
                )),
                comparisonValue: entry.1
            )
        }
        return try XCTUnwrap(ComparableSet(items: items))
    }
}
