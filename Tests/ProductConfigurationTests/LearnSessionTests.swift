import XCTest
@testable import MinikPlus

final class LearnSessionTests: XCTestCase {
    func testEmptyCardArrayCannotInitializeSession() {
        XCTAssertNil(LearnSession(cards: []))
    }

    func testNonemptyInitializationSucceeds() throws {
        let cards = try makeCards(count: 1)

        XCTAssertNotNil(LearnSession(cards: cards))
    }

    func testInitialStateStartsOnFirstCardAndIsIncomplete() throws {
        let cards = try makeCards(count: 3)
        let session = try XCTUnwrap(LearnSession(cards: cards))

        XCTAssertEqual(session.currentCardIndex, 0)
        XCTAssertEqual(session.currentCard, cards[0])
        XCTAssertEqual(session.cardCount, 3)
        XCTAssertFalse(session.isComplete)
    }

    func testSuppliedCardOrderIsPreserved() throws {
        let cards = try makeCards(count: 3)
        let session = try XCTUnwrap(LearnSession(cards: cards))

        XCTAssertEqual(session.cards, cards)
    }

    func testNextCardAdvancesExactlyOneCard() throws {
        let cards = try makeCards(count: 3)
        var session = try XCTUnwrap(LearnSession(cards: cards))

        session.nextCard()

        XCTAssertEqual(session.currentCardIndex, 1)
        XCTAssertEqual(session.currentCard, cards[1])
        XCTAssertFalse(session.isComplete)
    }

    func testAdvancingThroughCardsPreservesSequence() throws {
        let cards = try makeCards(count: 3)
        var session = try XCTUnwrap(LearnSession(cards: cards))

        var visitedCards = [session.currentCard]
        session.nextCard()
        visitedCards.append(session.currentCard)
        session.nextCard()
        visitedCards.append(session.currentCard)

        XCTAssertEqual(visitedCards, cards)
    }

    func testReachingFinalCardDoesNotMarkCompletion() throws {
        let cards = try makeCards(count: 2)
        var session = try XCTUnwrap(LearnSession(cards: cards))

        session.nextCard()

        XCTAssertEqual(session.currentCardIndex, 1)
        XCTAssertEqual(session.currentCard, cards[1])
        XCTAssertFalse(session.isComplete)
    }

    func testAdvancingFromFinalCardMarksCompleteWithoutMoving() throws {
        let cards = try makeCards(count: 2)
        var session = try XCTUnwrap(LearnSession(cards: cards))
        session.nextCard()

        session.nextCard()

        XCTAssertEqual(session.currentCardIndex, 1)
        XCTAssertEqual(session.currentCard, cards[1])
        XCTAssertTrue(session.isComplete)
    }

    func testAdvancingAfterCompletionIsIdempotent() throws {
        let cards = try makeCards(count: 2)
        var session = try XCTUnwrap(LearnSession(cards: cards))
        session.nextCard()
        session.nextCard()

        session.nextCard()
        session.nextCard()

        XCTAssertEqual(session.currentCardIndex, 1)
        XCTAssertEqual(session.currentCard, cards[1])
        XCTAssertTrue(session.isComplete)
    }

    func testOneCardSessionCompletesOnFirstAdvanceAndKeepsCardCurrent() throws {
        let cards = try makeCards(count: 1)
        var session = try XCTUnwrap(LearnSession(cards: cards))

        XCTAssertEqual(session.currentCard, cards[0])
        XCTAssertFalse(session.isComplete)

        session.nextCard()

        XCTAssertEqual(session.currentCardIndex, 0)
        XCTAssertEqual(session.currentCard, cards[0])
        XCTAssertTrue(session.isComplete)
    }

    func testLoopingSessionReturnsToFirstCardFromFinalCard() throws {
        let cards = try makeCards(count: 3)
        var session = try XCTUnwrap(LearnSession(
            cards: cards,
            progressionPolicy: .loopFromFinalCard
        ))

        XCTAssertFalse(session.nextCardStartsOver)
        session.nextCard()
        session.nextCard()
        XCTAssertTrue(session.nextCardStartsOver)

        session.nextCard()

        XCTAssertEqual(session.currentCardIndex, 0)
        XCTAssertEqual(session.currentCard, cards[0])
        XCTAssertFalse(session.isComplete)
        XCTAssertFalse(session.nextCardStartsOver)
    }

    func testOneCardLoopingSessionNeverCompletes() throws {
        let cards = try makeCards(count: 1)
        var session = try XCTUnwrap(LearnSession(
            cards: cards,
            progressionPolicy: .loopFromFinalCard
        ))

        XCTAssertTrue(session.nextCardStartsOver)
        session.nextCard()
        session.nextCard()

        XCTAssertEqual(session.currentCardIndex, 0)
        XCTAssertEqual(session.currentCard, cards[0])
        XCTAssertFalse(session.isComplete)
    }

    func testNavigationDoesNotMutateOrReorderStudyCards() throws {
        let cards = try makeCards(count: 3)
        let originalCards = cards
        var session = try XCTUnwrap(LearnSession(cards: cards))

        session.nextCard()
        session.nextCard()
        session.nextCard()

        XCTAssertEqual(session.cards, originalCards)
        XCTAssertEqual(cards, originalCards)
    }

    private func makeCards(count: Int) throws -> [StudyCard] {
        try (0 ..< count).map { index in
            let representation = Representation.learningText(LearningTextRepresentation(
                text: "content-\(index)",
                language: nil,
                direction: nil
            ))
            return try XCTUnwrap(StudyCard(
                id: StudyCardID(rawValue: "study.\(index)"),
                representations: [representation],
                primarySkill: SkillID(rawValue: "skill.study"),
                curriculumStage: CurriculumStageID(rawValue: "stage.study")
            ))
        }
    }
}
