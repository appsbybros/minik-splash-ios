import XCTest
@testable import MinikPlus

final class LanguagePairsPresentationTests: XCTestCase {
    func testMatchingAPairLeavesTwoEmptyPositionsWithoutMovingOtherPictures() throws {
        var session = try makeSession()
        let positions = session.mixedBoardItems.map(\.id)
        let first = PairsItemID(groupIndex: 2, side: .left)
        let second = PairsItemID(groupIndex: 2, side: .right)
        session.selectItem(first)
        session.selectItem(second)
        XCTAssertEqual(session.attemptResult, .correct)
        XCTAssertEqual(session.activeMixedItems.count, 6)
        XCTAssertEqual(session.mixedBoardItems.map(\.id), positions)
        session.continueAfterAttempt()
        XCTAssertEqual(session.mixedBoardItems.map(\.id), positions)
        XCTAssertEqual(session.mixedBoardItems.filter { session.matchedGroupIndices.contains($0.id.groupIndex) }.count, 2)
    }

    func testWrongPairAndDeselectionKeepEveryPictureAtItsOriginalPosition() throws {
        var session = try makeSession()
        let positions = session.mixedBoardItems.map(\.id)
        let first = PairsItemID(groupIndex: 0, side: .left)
        session.selectItem(first)
        session.selectItem(first)
        XCTAssertFalse(session.isSelected(first))
        XCTAssertNil(session.attemptResult)
        session.selectItem(first)
        session.selectItem(PairsItemID(groupIndex: 1, side: .left))
        XCTAssertEqual(session.attemptResult, .incorrect)
        session.continueAfterAttempt()
        XCTAssertEqual(session.mixedBoardItems.map(\.id), positions)
        XCTAssertEqual(session.activeMixedItems.count, 8)
        XCTAssertTrue(session.matchedGroupIndices.isEmpty)
    }

    func testCompletedBoardRetainsAllSlotsUntilTheNextRound() throws {
        var session = try makeSession()
        let positions = session.mixedBoardItems.map(\.id)
        for group in 0..<4 {
            session.selectItem(PairsItemID(groupIndex: group, side: .left))
            session.selectItem(PairsItemID(groupIndex: group, side: .right))
            session.continueAfterAttempt()
        }
        XCTAssertTrue(session.isComplete)
        XCTAssertTrue(session.activeMixedItems.isEmpty)
        XCTAssertEqual(session.mixedBoardItems.map(\.id), positions)
        XCTAssertEqual(session.matchedGroupIndices, Set(0..<4))
        let newRound = try makeSession()
        XCTAssertEqual(newRound.activeMixedItems.count, 8)
        XCTAssertTrue(newRound.matchedGroupIndices.isEmpty)
    }

    private func makeSession() throws -> PairsSession {
        let groups = try (0..<4).map { group in
            try XCTUnwrap(EquivalenceSet(
                semanticValue: .contentItem(ContentItemID(rawValue: "initial-\(group)")),
                representations: [
                    .imageAsset(AssetReference(rawValue: "picture-\(group)-a")),
                    .imageAsset(AssetReference(rawValue: "picture-\(group)-b"))
                ]
            ))
        }
        return try XCTUnwrap(PairsSession(equivalenceSets: groups, selectionStyle: .anyTwoTiles))
    }
}
