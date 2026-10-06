import XCTest
@testable import MinikPlus

final class CardsSessionTests: XCTestCase {
    func testEmptyInitializationFailsSafely() {
        XCTAssertNil(CardsSession(cards: []))
    }

    func testDuplicateStudyCardIDsAreRejected() throws {
        let cards = try makeCards(count: 2)
        let duplicateIdentityCard = try XCTUnwrap(StudyCard(
            id: cards[0].id,
            representations: cards[1].representations,
            primarySkill: cards[1].primarySkill,
            secondarySkills: cards[1].secondarySkills,
            curriculumStage: cards[1].curriculumStage
        ))

        XCTAssertNil(CardsSession(cards: [cards[0], duplicateIdentityCard]))
    }

    func testInputCardsProduceOnePresentationIdentityEach() throws {
        let cards = try makeCards(count: 10)
        let session = try XCTUnwrap(CardsSession(cards: cards))

        XCTAssertEqual(session.cardCount, 10)
        XCTAssertEqual(Set(session.presentationCardIDs), Set(cards.map(\.id)))
        XCTAssertEqual(Set(session.presentationCardIDs).count, 10)
    }

    func testCurrentCardIsFirstPresentationEntry() throws {
        let session = try XCTUnwrap(CardsSession(cards: makeCards(count: 3)))

        XCTAssertEqual(session.currentCardIndex, 0)
        XCTAssertEqual(session.currentCard.id, session.presentationCardIDs[0])
    }

    func testAdvanceVisitsNextPresentationEntryWithoutRegeneratingOrder() throws {
        var session = try XCTUnwrap(CardsSession(cards: makeCards(count: 3)))
        let order = session.presentationCardIDs

        session.advance()

        XCTAssertEqual(session.currentCardIndex, 1)
        XCTAssertEqual(session.currentCard.id, order[1])
        XCTAssertEqual(session.presentationCardIDs, order)
    }

    func testAdvancingThroughCycleLosesOrDuplicatesNoCard() throws {
        let cards = try makeCards(count: 10)
        var session = try XCTUnwrap(CardsSession(cards: cards))
        var visited = [session.currentCard.id]

        for _ in 1 ..< cards.count {
            session.advance()
            visited.append(session.currentCard.id)
        }

        XCTAssertEqual(visited, session.presentationCardIDs)
        XCTAssertEqual(Set(visited), Set(cards.map(\.id)))
    }

    func testAdvanceAfterFinalCardStartsNewShuffledCycleAtFirstPosition() throws {
        let cards = try makeCards(count: 4)
        var session = try XCTUnwrap(CardsSession(cards: cards))
        for _ in 1 ..< cards.count {
            session.advance()
        }
        let priorFinalID = session.currentCard.id

        session.advance()

        XCTAssertEqual(session.currentCardIndex, 0)
        XCTAssertEqual(session.currentCard.id, session.presentationCardIDs[0])
        XCTAssertEqual(Set(session.presentationCardIDs), Set(cards.map(\.id)))
        XCTAssertNotEqual(session.currentCard.id, priorFinalID)
    }

    func testSingleCardSessionLoopsSafely() throws {
        let card = try XCTUnwrap(makeCards(count: 1).first)
        var session = try XCTUnwrap(CardsSession(cards: [card]))

        session.advance()
        session.advance()

        XCTAssertEqual(session.currentCardIndex, 0)
        XCTAssertEqual(session.currentCard, card)
        XCTAssertEqual(session.presentationCardIDs, [card.id])
    }

    func testManualAdvanceMakesStaleTimedAdvanceANoOpWithoutSkippingNextCard() throws {
        var session = try XCTUnwrap(CardsSession(cards: makeCards(count: 3)))
        let timedPresentationID = session.currentCard.id

        session.advance()
        let cardAfterManualAdvance = session.currentCard

        XCTAssertFalse(session.advance(ifCurrentCardID: timedPresentationID))
        XCTAssertEqual(session.currentCard, cardAfterManualAdvance)
        XCTAssertEqual(session.currentCardIndex, 1)
    }

    func testOnePresentationCanProduceAtMostOneIdentityGuardedAdvance() throws {
        var session = try XCTUnwrap(CardsSession(cards: makeCards(count: 3)))
        let presentationID = session.currentCard.id

        XCTAssertTrue(session.advance(ifCurrentCardID: presentationID))
        let nextCard = session.currentCard
        XCTAssertFalse(session.advance(ifCurrentCardID: presentationID))
        XCTAssertEqual(session.currentCard, nextCard)
    }

    func testCurrentTimedPresentationAdvancesNormally() throws {
        var session = try XCTUnwrap(CardsSession(cards: makeCards(count: 3)))
        let order = session.presentationCardIDs
        let presentationID = session.currentCard.id

        XCTAssertTrue(session.advance(ifCurrentCardID: presentationID))
        XCTAssertEqual(session.currentCard.id, order[1])
    }

    func testSingleCardLoopHasNewPresentationAndRejectsItsOldTimer() throws {
        var session = try XCTUnwrap(CardsSession(cards: makeCards(count: 1)))
        let oldID = session.presentationID
        let cardID = session.currentCard.id
        XCTAssertTrue(session.advance(ifPresentationID: oldID))
        XCTAssertEqual(session.currentCard.id, cardID)
        XCTAssertNotEqual(session.presentationID, oldID)
        let newID = session.presentationID
        XCTAssertFalse(session.advance(ifPresentationID: oldID))
        XCTAssertEqual(session.presentationID, newID)
    }

    func testARepeatedCardAfterAnotherBagDoesNotReviveAnOldTimer() throws {
        var session = try XCTUnwrap(CardsSession(cards: makeCards(count: 2)))
        let oldID = session.presentationID
        let cardID = session.currentCard.id
        repeat { session.advance() } while session.currentCard.id != cardID
        let currentID = session.presentationID
        XCTAssertFalse(session.advance(ifPresentationID: oldID))
        XCTAssertEqual(session.presentationID, currentID)
        XCTAssertTrue(session.advance(ifPresentationID: currentID))
    }

    private func makeCards(count: Int) throws -> [StudyCard] {
        try (0 ..< count).map { index in
            try XCTUnwrap(StudyCard(
                id: StudyCardID(rawValue: "study.cards.\(index)"),
                representations: [.learningText(LearningTextRepresentation(
                    text: "card-\(index)",
                    language: .english,
                    direction: .leftToRight
                ))],
                primarySkill: LanguageSkillIDs.wordRecognition,
                curriculumStage: LanguageCurriculumStageIDs.wordsLevelA
            ))
        }
    }
}
