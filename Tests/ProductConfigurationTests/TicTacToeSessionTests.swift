import XCTest
@testable import MinikPlus

final class TicTacToeSessionTests: XCTestCase {
    func testInitialStateIsEmptyWithChildAsCrossAndUnlocked() {
        let session = TicTacToeSession()

        XCTAssertEqual(session.board.count, 9)
        XCTAssertTrue(session.board.allSatisfy { $0 == nil })
        XCTAssertEqual(session.childMark, .cross)
        XCTAssertEqual(session.minikMark, .circle)
        XCTAssertFalse(session.hasRoundStarted)
        XCTAssertFalse(session.isRoundComplete)
        XCTAssertEqual(session.childScore, 0)
        XCTAssertEqual(session.minikScore, 0)
    }

    func testChildStartsWhetherCrossOrCircleWasSelected() throws {
        for mark in TicTacToeMark.allCases {
            var session = TicTacToeSession(level: .a)
            XCTAssertTrue(session.selectChildMark(mark))
            var random = SequenceRandomNumberGenerator([0])

            let resolution = try XCTUnwrap(session.playChildMove(
                at: position(1, 1),
                using: &random
            ))

            XCTAssertEqual(session.mark(at: resolution.childPosition), mark)
            XCTAssertEqual(resolution.minikPosition.map { session.mark(at: $0) }, mark.opposite)
        }
    }

    func testMarkLocksAfterFirstMoveAndUnlocksNextRoundWithoutChangingSelection() {
        var session = TicTacToeSession(level: .a)
        XCTAssertTrue(session.selectChildMark(.circle))
        var random = SequenceRandomNumberGenerator([0])
        _ = session.playChildMove(at: position(1, 1), using: &random)

        XCTAssertFalse(session.selectChildMark(.cross))
        XCTAssertEqual(session.childMark, .circle)

        session.startNextRound()

        XCTAssertFalse(session.hasRoundStarted)
        XCTAssertEqual(session.childMark, .circle)
        XCTAssertTrue(session.selectChildMark(.cross))
    }

    func testInvalidAndOccupiedMovesAreIgnored() throws {
        var session = TicTacToeSession(level: .a)
        var random = SequenceRandomNumberGenerator([0])

        XCTAssertNil(session.playChildMove(at: position(-1, 0), using: &random))
        let first = try XCTUnwrap(session.playChildMove(at: position(1, 1), using: &random))
        XCTAssertNil(session.playChildMove(at: first.childPosition, using: &random))
        if let minikPosition = first.minikPosition {
            XCTAssertNil(session.playChildMove(at: minikPosition, using: &random))
        }
    }

    func testAllEightWinningLinesAreRecognized() {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]

        for indexes in lines {
            var board = emptyBoard
            for index in indexes {
                board[index] = .cross
            }
            XCTAssertEqual(
                Set(TicTacToeSession.winningLine(on: board, for: .cross) ?? []),
                Set(indexes.map { position(at: $0) })
            )
        }
    }

    func testFullBoardWithoutWinnerIsDraw() {
        let board: [TicTacToeMark?] = [
            .cross, .circle, .cross,
            .cross, .circle, .circle,
            .circle, .cross, .cross
        ]

        XCTAssertEqual(
            TicTacToeSession.terminalState(on: board, childMark: .cross),
            .draw
        )
    }

    func testTerminalChildMoveDoesNotReceiveAIResponse() throws {
        var session = TicTacToeSession(
            level: .e,
            board: [
                .cross, .cross, nil,
                .circle, .circle, nil,
                nil, nil, nil
            ],
            childMark: .cross
        )
        var random = SequenceRandomNumberGenerator([0])

        let resolution = try XCTUnwrap(session.playChildMove(
            at: position(0, 2),
            using: &random
        ))

        XCTAssertNil(resolution.minikPosition)
        XCTAssertEqual(resolution.outcome, .childWin)
        XCTAssertEqual(session.board.compactMap { $0 }.count, 5)
    }

    func testNonterminalChildMoveReceivesExactlyOneAIResponse() throws {
        var session = TicTacToeSession(level: .a)
        var random = SequenceRandomNumberGenerator([0])

        let resolution = try XCTUnwrap(session.playChildMove(
            at: position(1, 1),
            using: &random
        ))

        XCTAssertNotNil(resolution.minikPosition)
        XCTAssertEqual(session.board.compactMap { $0 }.count, 2)
        XCTAssertEqual(session.movesInRound, 2)
    }

    func testNewRoundCannotReceiveAStaleAIMoveFromThePriorAtomicResolution() throws {
        var session = TicTacToeSession(level: .a)
        var random = SequenceRandomNumberGenerator([0])

        let resolution = try XCTUnwrap(session.playChildMove(
            at: position(1, 1),
            using: &random
        ))
        XCTAssertNotNil(resolution.minikPosition)
        XCTAssertEqual(session.board.compactMap { $0 }.count, 2)

        session.startNextRound()

        XCTAssertTrue(session.board.allSatisfy { $0 == nil })
        XCTAssertEqual(session.movesInRound, 0)
        XCTAssertFalse(session.hasRoundStarted)
    }

    func testTerminalRoundIgnoresFurtherMoves() {
        var session = TicTacToeSession(
            level: .a,
            board: [.cross, .cross, nil, .circle, .circle, nil, nil, nil, nil],
            childMark: .cross
        )
        var random = SequenceRandomNumberGenerator([0])
        _ = session.playChildMove(at: position(0, 2), using: &random)
        let finishedBoard = session.board

        XCTAssertNil(session.playChildMove(at: position(2, 2), using: &random))
        XCTAssertEqual(session.board, finishedBoard)
    }

    func testEasyChoosesAnEmptySquareUsingInjectedRandomness() {
        let board: [TicTacToeMark?] = [
            .cross, nil, .circle,
            nil, .cross, nil,
            nil, .circle, nil
        ]
        var firstRandom = SequenceRandomNumberGenerator([0])
        var lastRandom = SequenceRandomNumberGenerator([4])

        let first = TicTacToeAI.move(
            on: board,
            minikMark: .circle,
            childMark: .cross,
            difficulty: .easy,
            level: .a,
            using: &firstRandom
        )
        let last = TicTacToeAI.move(
            on: board,
            minikMark: .circle,
            childMark: .cross,
            difficulty: .easy,
            level: .a,
            using: &lastRandom
        )

        XCTAssertEqual(first, position(0, 1))
        XCTAssertEqual(last, position(2, 2))
    }

    func testMediumPriorityWinBlockCenterCornerThenEdge() {
        let certain = TicTacToeAI.MediumProfile(
            winChance: 1,
            blockChance: 1,
            centerChance: 1
        )
        var random = SequenceRandomNumberGenerator(Array(repeating: 0, count: 20))

        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.circle, .circle, nil, .cross, nil, nil, .cross, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: certain,
                using: &random
            ),
            position(0, 2)
        )
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, .cross, nil, .circle, nil, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: certain,
                using: &random
            ),
            position(0, 2)
        )
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, nil, nil, nil, nil, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: certain,
                using: &random
            ),
            position(1, 1)
        )
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, nil, nil, nil, .circle, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: certain,
                using: &random
            ),
            position(0, 2)
        )
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, nil, .circle, nil, nil, nil, .circle, nil, .cross],
                minikMark: .circle,
                childMark: .cross,
                profile: .init(winChance: 0, blockChance: 0, centerChance: 0),
                using: &random
            ),
            position(0, 1)
        )
    }

    func testMediumProbabilityBoundariesCanTakeOrSkipTacticalMove() {
        let half = TicTacToeAI.MediumProfile(
            winChance: 0.5,
            blockChance: 0,
            centerChance: 0
        )
        let board: [TicTacToeMark?] = [
            .circle, .circle, nil,
            nil, .cross, nil,
            nil, nil, nil
        ]
        var takeRandom = SequenceRandomNumberGenerator([0])
        var skipRandom = SequenceRandomNumberGenerator([.max, 1])

        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: board,
                minikMark: .circle,
                childMark: .cross,
                profile: half,
                using: &takeRandom
            ),
            position(0, 2)
        )
        XCTAssertNotEqual(
            TicTacToeAI.mediumMove(
                on: board,
                minikMark: .circle,
                childMark: .cross,
                profile: half,
                using: &skipRandom
            ),
            position(0, 2)
        )

        let blockBoard: [TicTacToeMark?] = [
            .cross, .cross, nil,
            nil, .circle, nil,
            nil, nil, nil
        ]
        let blockHalf = TicTacToeAI.MediumProfile(
            winChance: 0,
            blockChance: 0.5,
            centerChance: 0
        )
        var blockRandom = SequenceRandomNumberGenerator([0])
        var skipBlockRandom = SequenceRandomNumberGenerator([.max, 1])
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: blockBoard,
                minikMark: .circle,
                childMark: .cross,
                profile: blockHalf,
                using: &blockRandom
            ),
            position(0, 2)
        )
        XCTAssertNotEqual(
            TicTacToeAI.mediumMove(
                on: blockBoard,
                minikMark: .circle,
                childMark: .cross,
                profile: blockHalf,
                using: &skipBlockRandom
            ),
            position(0, 2)
        )

        let centerHalf = TicTacToeAI.MediumProfile(
            winChance: 0,
            blockChance: 0,
            centerChance: 0.5
        )
        var centerRandom = SequenceRandomNumberGenerator([0])
        var skipCenterRandom = SequenceRandomNumberGenerator([.max, 1])
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, nil, nil, nil, nil, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: centerHalf,
                using: &centerRandom
            ),
            position(1, 1)
        )
        XCTAssertNotEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, nil, nil, nil, nil, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: centerHalf,
                using: &skipCenterRandom
            ),
            position(1, 1)
        )
    }

    func testUnitRandomUsesAHalfOpenIntervalAtBothSourceExtremes() {
        var minimumRandom = SequenceRandomNumberGenerator([0])
        var maximumRandom = SequenceRandomNumberGenerator([.max])

        XCTAssertEqual(TicTacToeAI.unitRandom(using: &minimumRandom), 0)
        let maximumResult = TicTacToeAI.unitRandom(using: &maximumRandom)
        XCTAssertGreaterThanOrEqual(maximumResult, 0)
        XCTAssertLessThan(maximumResult, 1)
    }

    func testMediumCertainProbabilitiesCannotBeSkippedByMaximumRandomValue() {
        let certain = TicTacToeAI.MediumProfile(
            winChance: 1,
            blockChance: 1,
            centerChance: 1
        )
        var winRandom = SequenceRandomNumberGenerator([.max])
        var blockRandom = SequenceRandomNumberGenerator([.max])
        var centerRandom = SequenceRandomNumberGenerator([.max])

        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.circle, .circle, nil, .cross, nil, nil, .cross, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: certain,
                using: &winRandom
            ),
            position(0, 2)
        )
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, .cross, nil, .circle, nil, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: certain,
                using: &blockRandom
            ),
            position(0, 2)
        )
        XCTAssertEqual(
            TicTacToeAI.mediumMove(
                on: [.cross, nil, nil, nil, nil, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                profile: certain,
                using: &centerRandom
            ),
            position(1, 1)
        )
    }

    func testLevelProfilesMatchAndroidThresholdsAndCaps() {
        XCTAssertEqual(
            TicTacToeAI.levelProfile(for: .a),
            .init(base: .easy, hardChanceMinimum: 0, hardChanceMaximum: 0, hardMoveCap: 0, hardMinimumPlacementCount: 4)
        )
        XCTAssertEqual(
            TicTacToeAI.levelProfile(for: .b),
            .init(base: .easy, hardChanceMinimum: 0.10, hardChanceMaximum: 0.20, hardMoveCap: 1, hardMinimumPlacementCount: 3)
        )
        XCTAssertEqual(
            TicTacToeAI.levelProfile(for: .c),
            .init(base: .medium, hardChanceMinimum: 0.30, hardChanceMaximum: 0.45, hardMoveCap: 2, hardMinimumPlacementCount: 2)
        )
        XCTAssertEqual(
            TicTacToeAI.levelProfile(for: .d),
            .init(base: .medium, hardChanceMinimum: 0.55, hardChanceMaximum: 0.75, hardMoveCap: 3, hardMinimumPlacementCount: 1)
        )
        XCTAssertEqual(
            TicTacToeAI.levelProfile(for: .e),
            .init(base: .medium, hardChanceMinimum: 0.85, hardChanceMaximum: 0.95, hardMoveCap: .max, hardMinimumPlacementCount: 0)
        )
    }

    func testLevelHardThresholdAndCapAreApplied() {
        var belowThreshold = SequenceRandomNumberGenerator([0, 0])
        XCTAssertEqual(
            TicTacToeAI.effectiveDifficulty(
                level: .b,
                movesInRound: 2,
                hardMovesInRound: 0,
                adaptiveState: .androidDefault,
                using: &belowThreshold
            ),
            .easy
        )

        var eligible = SequenceRandomNumberGenerator([0, 0])
        XCTAssertEqual(
            TicTacToeAI.effectiveDifficulty(
                level: .b,
                movesInRound: 3,
                hardMovesInRound: 0,
                adaptiveState: .androidDefault,
                using: &eligible
            ),
            .hard
        )

        var capped = SequenceRandomNumberGenerator([0, 0])
        XCTAssertEqual(
            TicTacToeAI.effectiveDifficulty(
                level: .b,
                movesInRound: 5,
                hardMovesInRound: 1,
                adaptiveState: .androidDefault,
                using: &capped
            ),
            .easy
        )
    }

    func testRandomCanSelectEveryEffectiveDifficulty() {
        for (raw, expected) in zip([UInt64(0), 1, 2], [TicTacToeDifficulty.easy, .medium, .hard]) {
            var random = SequenceRandomNumberGenerator([raw])
            XCTAssertEqual(
                TicTacToeAI.effectiveDifficulty(
                    level: .random,
                    movesInRound: 1,
                    hardMovesInRound: 0,
                    adaptiveState: .androidDefault,
                    using: &random
                ),
                expected
            )
        }
    }

    func testAdaptiveUsesPersistedHardChanceAndMediumMercyChance() {
        var state = TicTacToeAdaptiveState.androidDefault
        state.hardChance = 0.7
        var hardRandom = SequenceRandomNumberGenerator([0])
        XCTAssertEqual(
            TicTacToeAI.effectiveDifficulty(
                level: .adaptive,
                movesInRound: 1,
                hardMovesInRound: 0,
                adaptiveState: state,
                using: &hardRandom
            ),
            .hard
        )

        state.hardChance = 0
        state.baseline = .medium
        var mercyRandom = SequenceRandomNumberGenerator([.max, 0])
        XCTAssertEqual(
            TicTacToeAI.effectiveDifficulty(
                level: .adaptive,
                movesInRound: 1,
                hardMovesInRound: 0,
                adaptiveState: state,
                using: &mercyRandom
            ),
            .easy
        )
    }

    func testAndroidCompatibilityUpdatesAdaptiveStateForRandomButNotAdaptive() {
        let winningBoard: [TicTacToeMark?] = [
            .cross, .cross, nil,
            .circle, .circle, nil,
            nil, nil, nil
        ]
        var randomSession = TicTacToeSession(
            level: .random,
            board: winningBoard,
            childMark: .cross
        )
        var adaptiveSession = TicTacToeSession(
            level: .adaptive,
            board: winningBoard,
            childMark: .cross
        )
        var random = SequenceRandomNumberGenerator([0])

        _ = randomSession.playChildMove(at: position(0, 2), using: &random)
        _ = adaptiveSession.playChildMove(at: position(0, 2), using: &random)

        XCTAssertEqual(randomSession.adaptiveState.gamesPlayed, 1)
        XCTAssertEqual(adaptiveSession.adaptiveState, .androidDefault)
    }

    func testHardTakesImmediateWinAndBlocksImmediateLoss() {
        var random = SequenceRandomNumberGenerator([0])
        XCTAssertEqual(
            TicTacToeAI.hardMove(
                on: [.circle, .circle, nil, .cross, nil, nil, .cross, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                using: &random
            ),
            position(0, 2)
        )
        XCTAssertEqual(
            TicTacToeAI.hardMove(
                on: [.cross, .cross, nil, .circle, nil, nil, nil, nil, nil],
                minikMark: .circle,
                childMark: .cross,
                using: &random
            ),
            position(0, 2)
        )
    }

    func testHardCannotBeForcedToLoseFromEmptyBoard() {
        XCTAssertFalse(childCanForceWin(on: emptyBoard))
    }

    func testHardEqualScoreSelectionUsesInjectedRandomness() throws {
        var firstRandom = SequenceRandomNumberGenerator([0])
        var secondRandom = SequenceRandomNumberGenerator([1])

        let first = try XCTUnwrap(TicTacToeAI.hardMove(
            on: emptyBoard,
            minikMark: .circle,
            childMark: .cross,
            using: &firstRandom
        ))
        let second = try XCTUnwrap(TicTacToeAI.hardMove(
            on: emptyBoard,
            minikMark: .circle,
            childMark: .cross,
            using: &secondRandom
        ))

        XCTAssertNotEqual(first, second)
    }

    func testRoundResetPreservesCumulativeHiddenScore() {
        var session = TicTacToeSession(
            level: .a,
            board: [.cross, .cross, nil, .circle, .circle, nil, nil, nil, nil],
            childMark: .cross,
            childScore: 2,
            minikScore: 3
        )
        var random = SequenceRandomNumberGenerator([0])

        _ = session.playChildMove(at: position(0, 2), using: &random)
        XCTAssertEqual(session.childScore, 3)
        XCTAssertEqual(session.minikScore, 3)

        session.startNextRound()

        XCTAssertTrue(session.board.allSatisfy { $0 == nil })
        XCTAssertEqual(session.childScore, 3)
        XCTAssertEqual(session.minikScore, 3)
        XCTAssertFalse(session.hasRoundStarted)
        XCTAssertNil(session.outcome)
    }

    private var emptyBoard: [TicTacToeMark?] {
        Array(repeating: nil, count: 9)
    }

    private func position(_ row: Int, _ column: Int) -> TicTacToePosition {
        TicTacToePosition(row: row, column: column)
    }

    private func position(at index: Int) -> TicTacToePosition {
        position(index / 3, index % 3)
    }

    private func childCanForceWin(on board: [TicTacToeMark?]) -> Bool {
        for childPosition in TicTacToePosition.all where board[childPosition.index] == nil {
            var afterChild = board
            afterChild[childPosition.index] = .cross
            if TicTacToeSession.winningLine(on: afterChild, for: .cross) != nil {
                return true
            }
            if afterChild.allSatisfy({ $0 != nil }) {
                continue
            }

            var responses = Set<TicTacToePosition>()
            for raw in UInt64(0)...8 {
                var random = SequenceRandomNumberGenerator([raw])
                if let response = TicTacToeAI.hardMove(
                    on: afterChild,
                    minikMark: .circle,
                    childMark: .cross,
                    using: &random
                ) {
                    responses.insert(response)
                }
            }

            guard !responses.isEmpty else {
                continue
            }
            let childWinsAgainstEveryResponse = responses.allSatisfy { response in
                var afterMinik = afterChild
                afterMinik[response.index] = .circle
                if TicTacToeSession.winningLine(on: afterMinik, for: .circle) != nil {
                    return false
                }
                if afterMinik.allSatisfy({ $0 != nil }) {
                    return false
                }
                return childCanForceWin(on: afterMinik)
            }
            if childWinsAgainstEveryResponse {
                return true
            }
        }
        return false
    }
}

private struct SequenceRandomNumberGenerator: RandomNumberGenerator {
    private var values: [UInt64]
    private var index = 0

    init(_ values: [UInt64]) {
        self.values = values.isEmpty ? [0] : values
    }

    mutating func next() -> UInt64 {
        defer { index += 1 }
        return values[min(index, values.count - 1)]
    }
}
