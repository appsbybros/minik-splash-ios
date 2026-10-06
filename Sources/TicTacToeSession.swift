import Foundation

enum TicTacToeMark: String, Codable, CaseIterable, Hashable, Sendable {
    case cross = "X"
    case circle = "O"

    var opposite: TicTacToeMark {
        self == .cross ? .circle : .cross
    }
}

struct TicTacToePosition: Hashable, Sendable {
    let row: Int
    let column: Int

    init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }

    var isValid: Bool {
        (0..<3).contains(row) && (0..<3).contains(column)
    }

    var index: Int {
        row * 3 + column
    }

    static let all: [TicTacToePosition] = (0..<3).flatMap { row in
        (0..<3).map { column in
            TicTacToePosition(row: row, column: column)
        }
    }
}

enum TicTacToeOutcome: String, Codable, Equatable, Sendable {
    case childWin
    case minikWin
    case draw
}

enum TicTacToeDifficulty: Int, Codable, Equatable, Sendable {
    case easy
    case medium
    case hard
}

enum TicTacToeLevel: String, Codable, CaseIterable, Equatable, Sendable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
    case random = "RANDOM"
    case adaptive = "ADAPTIVE"
}

struct TicTacToeAdaptiveState: Codable, Equatable, Sendable {
    var baseline: TicTacToeDifficulty
    var hardChance: Double
    var wins: Int
    var losses: Int
    var draws: Int
    var winStreak: Int
    var lossStreak: Int
    var averageMoves: Double
    var gamesPlayed: Int

    static let androidDefault = TicTacToeAdaptiveState(
        baseline: .medium,
        hardChance: 0.15,
        wins: 0,
        losses: 0,
        draws: 0,
        winStreak: 0,
        lossStreak: 0,
        averageMoves: 0,
        gamesPlayed: 0
    )
}

/// Compatibility seam for the current Android production mismatch.
/// Android uses adaptive state for ADAPTIVE moves, but updates that state only
/// after RANDOM rounds. Keep the mismatch localized here for later correction.
struct TicTacToeCompatibilityPolicy: Equatable, Sendable {
    let levelThatUpdatesAdaptiveState: TicTacToeLevel

    static let androidProduction = TicTacToeCompatibilityPolicy(
        levelThatUpdatesAdaptiveState: .random
    )
}

struct TicTacToeMoveResolution: Equatable, Sendable {
    let childPosition: TicTacToePosition
    let minikPosition: TicTacToePosition?
    let outcome: TicTacToeOutcome?
}

struct TicTacToeSession: Sendable {
    private(set) var board: [TicTacToeMark?]
    private(set) var childMark: TicTacToeMark
    private(set) var hasRoundStarted: Bool
    private(set) var outcome: TicTacToeOutcome?
    private(set) var winningLine: [TicTacToePosition]
    private(set) var childScore: Int
    private(set) var minikScore: Int
    private(set) var movesInRound: Int
    private(set) var hardMovesInRound: Int
    private(set) var adaptiveState: TicTacToeAdaptiveState

    let level: TicTacToeLevel
    let compatibilityPolicy: TicTacToeCompatibilityPolicy

    init(
        level: TicTacToeLevel = .adaptive,
        adaptiveState: TicTacToeAdaptiveState = .androidDefault,
        compatibilityPolicy: TicTacToeCompatibilityPolicy = .androidProduction
    ) {
        self.board = Array(repeating: nil, count: 9)
        self.childMark = .cross
        self.hasRoundStarted = false
        self.outcome = nil
        self.winningLine = []
        self.childScore = 0
        self.minikScore = 0
        self.movesInRound = 0
        self.hardMovesInRound = 0
        self.adaptiveState = adaptiveState
        self.level = level
        self.compatibilityPolicy = compatibilityPolicy
    }

    init(
        level: TicTacToeLevel,
        adaptiveState: TicTacToeAdaptiveState = .androidDefault,
        compatibilityPolicy: TicTacToeCompatibilityPolicy = .androidProduction,
        board: [TicTacToeMark?],
        childMark: TicTacToeMark,
        hasRoundStarted: Bool = true,
        childScore: Int = 0,
        minikScore: Int = 0,
        movesInRound: Int? = nil,
        hardMovesInRound: Int = 0
    ) {
        precondition(board.count == 9)
        self.board = board
        self.childMark = childMark
        self.hasRoundStarted = hasRoundStarted
        self.outcome = nil
        self.winningLine = []
        self.childScore = childScore
        self.minikScore = minikScore
        self.movesInRound = movesInRound ?? board.compactMap { $0 }.count
        self.hardMovesInRound = hardMovesInRound
        self.adaptiveState = adaptiveState
        self.level = level
        self.compatibilityPolicy = compatibilityPolicy
    }

    var minikMark: TicTacToeMark {
        childMark.opposite
    }

    var isRoundComplete: Bool {
        outcome != nil
    }

    func mark(at position: TicTacToePosition) -> TicTacToeMark? {
        guard position.isValid else {
            return nil
        }
        return board[position.index]
    }

    @discardableResult
    mutating func selectChildMark(_ mark: TicTacToeMark) -> Bool {
        guard !hasRoundStarted, outcome == nil else {
            return false
        }
        childMark = mark
        return true
    }

    mutating func playChildMove<R: RandomNumberGenerator>(
        at position: TicTacToePosition,
        using random: inout R
    ) -> TicTacToeMoveResolution? {
        guard position.isValid,
              !isRoundComplete,
              board[position.index] == nil else {
            return nil
        }

        hasRoundStarted = true
        board[position.index] = childMark
        movesInRound += 1

        if let terminal = Self.terminalState(on: board, childMark: childMark) {
            finishRound(terminal)
            return TicTacToeMoveResolution(
                childPosition: position,
                minikPosition: nil,
                outcome: outcome
            )
        }

        let effectiveDifficulty = TicTacToeAI.effectiveDifficulty(
            level: level,
            movesInRound: movesInRound,
            hardMovesInRound: hardMovesInRound,
            adaptiveState: adaptiveState,
            using: &random
        )
        let minikPosition = TicTacToeAI.move(
            on: board,
            minikMark: minikMark,
            childMark: childMark,
            difficulty: effectiveDifficulty,
            level: level,
            using: &random
        )

        if let minikPosition {
            board[minikPosition.index] = minikMark
            movesInRound += 1
            if effectiveDifficulty == .hard {
                hardMovesInRound += 1
            }
        }

        if let terminal = Self.terminalState(on: board, childMark: childMark) {
            finishRound(terminal)
        }

        return TicTacToeMoveResolution(
            childPosition: position,
            minikPosition: minikPosition,
            outcome: outcome
        )
    }

    mutating func startNextRound() {
        board = Array(repeating: nil, count: 9)
        hasRoundStarted = false
        outcome = nil
        winningLine = []
        movesInRound = 0
        hardMovesInRound = 0
    }

    static func winningLine(
        on board: [TicTacToeMark?],
        for mark: TicTacToeMark
    ) -> [TicTacToePosition]? {
        guard board.count == 9 else {
            return nil
        }

        for line in winLines where line.allSatisfy({ board[$0.index] == mark }) {
            return line
        }
        return nil
    }

    static func terminalState(
        on board: [TicTacToeMark?],
        childMark: TicTacToeMark
    ) -> TicTacToeOutcome? {
        if winningLine(on: board, for: childMark) != nil {
            return .childWin
        }
        if winningLine(on: board, for: childMark.opposite) != nil {
            return .minikWin
        }
        if board.count == 9, board.allSatisfy({ $0 != nil }) {
            return .draw
        }
        return nil
    }

    private mutating func finishRound(_ newOutcome: TicTacToeOutcome) {
        outcome = newOutcome
        switch newOutcome {
        case .childWin:
            childScore += 1
            winningLine = Self.winningLine(on: board, for: childMark) ?? []
        case .minikWin:
            minikScore += 1
            winningLine = Self.winningLine(on: board, for: minikMark) ?? []
        case .draw:
            winningLine = []
        }

        if level == compatibilityPolicy.levelThatUpdatesAdaptiveState {
            adaptiveState.recordAndroidProductionResult(
                newOutcome,
                movesInRound: movesInRound
            )
        }
    }

    private static let winLines: [[TicTacToePosition]] = [
        [position(0, 0), position(0, 1), position(0, 2)],
        [position(1, 0), position(1, 1), position(1, 2)],
        [position(2, 0), position(2, 1), position(2, 2)],
        [position(0, 0), position(1, 0), position(2, 0)],
        [position(0, 1), position(1, 1), position(2, 1)],
        [position(0, 2), position(1, 2), position(2, 2)],
        [position(0, 0), position(1, 1), position(2, 2)],
        [position(0, 2), position(1, 1), position(2, 0)]
    ]

    private static func position(_ row: Int, _ column: Int) -> TicTacToePosition {
        TicTacToePosition(row: row, column: column)
    }
}

extension TicTacToeAdaptiveState {
    mutating func recordAndroidProductionResult(
        _ outcome: TicTacToeOutcome,
        movesInRound: Int
    ) {
        switch outcome {
        case .childWin:
            wins += 1
            winStreak += 1
            lossStreak = 0
        case .minikWin:
            losses += 1
            lossStreak += 1
            winStreak = 0
        case .draw:
            draws += 1
            winStreak = 0
            lossStreak = 0
        }

        let alpha = gamesPlayed < 5 ? 0.5 : 0.3
        averageMoves = gamesPlayed == 0
            ? Double(movesInRound)
            : alpha * Double(movesInRound) + (1 - alpha) * averageMoves
        gamesPlayed += 1

        let fast = Double(movesInRound) <= averageMoves * 0.75
        let lowerMediumBound = Int(averageMoves * 0.75)
        let upperMediumBound = Int(averageMoves * 1.1)
        let mediumSpeed = (lowerMediumBound...upperMediumBound).contains(movesInRound)

        func adjusted(_ value: Double, by delta: Double) -> Double {
            min(max(value + delta, 0), 0.7)
        }

        switch outcome {
        case .childWin:
            hardChance = adjusted(
                hardChance,
                by: fast ? 0.12 : (mediumSpeed ? 0.08 : 0.06)
            )
            if baseline == .easy, winStreak >= 2 {
                baseline = .medium
            }
        case .minikWin:
            hardChance = adjusted(
                hardChance,
                by: fast ? -0.15 : (mediumSpeed ? -0.10 : -0.08)
            )
            if baseline == .medium, lossStreak >= 2 {
                baseline = .easy
            }
        case .draw:
            hardChance = adjusted(hardChance, by: 0.02)
        }

        hardChance = min(max(hardChance * 0.98, 0), 0.7)
    }
}

enum TicTacToeAI {
    struct LevelProfile: Equatable, Sendable {
        let base: TicTacToeDifficulty
        let hardChanceMinimum: Double
        let hardChanceMaximum: Double
        let hardMoveCap: Int
        let hardMinimumPlacementCount: Int
    }

    struct MediumProfile: Equatable, Sendable {
        let winChance: Double
        let blockChance: Double
        let centerChance: Double
    }

    static func effectiveDifficulty<R: RandomNumberGenerator>(
        level: TicTacToeLevel,
        movesInRound: Int,
        hardMovesInRound: Int,
        adaptiveState: TicTacToeAdaptiveState,
        using random: inout R
    ) -> TicTacToeDifficulty {
        if level == .random {
            return [.easy, .medium, .hard][randomIndex(count: 3, using: &random)]
        }

        if level == .adaptive {
            if unitRandom(using: &random) < adaptiveState.hardChance {
                return .hard
            }
            if adaptiveState.baseline == .medium,
               unitRandom(using: &random) < 0.05 {
                return .easy
            }
            return adaptiveState.baseline
        }

        let profile = levelProfile(for: level)
        guard movesInRound >= profile.hardMinimumPlacementCount,
              hardMovesInRound < profile.hardMoveCap else {
            return profile.base
        }

        let hardChance = profile.hardChanceMinimum
            + unitRandom(using: &random)
            * (profile.hardChanceMaximum - profile.hardChanceMinimum)
        return unitRandom(using: &random) < hardChance ? .hard : profile.base
    }

    static func move<R: RandomNumberGenerator>(
        on board: [TicTacToeMark?],
        minikMark: TicTacToeMark,
        childMark: TicTacToeMark,
        difficulty: TicTacToeDifficulty,
        level: TicTacToeLevel,
        using random: inout R
    ) -> TicTacToePosition? {
        switch difficulty {
        case .easy:
            return randomPosition(from: emptyPositions(on: board), using: &random)
        case .medium:
            return mediumMove(
                on: board,
                minikMark: minikMark,
                childMark: childMark,
                profile: mediumProfile(for: level),
                using: &random
            )
        case .hard:
            return hardMove(
                on: board,
                minikMark: minikMark,
                childMark: childMark,
                using: &random
            )
        }
    }

    static func mediumMove<R: RandomNumberGenerator>(
        on board: [TicTacToeMark?],
        minikMark: TicTacToeMark,
        childMark: TicTacToeMark,
        profile: MediumProfile,
        using random: inout R
    ) -> TicTacToePosition? {
        if let winning = immediateWinningMove(on: board, for: minikMark),
           unitRandom(using: &random) < profile.winChance {
            return winning
        }
        if let block = immediateWinningMove(on: board, for: childMark),
           unitRandom(using: &random) < profile.blockChance {
            return block
        }

        let center = TicTacToePosition(row: 1, column: 1)
        if board.indices.contains(center.index), board[center.index] == nil,
           unitRandom(using: &random) < profile.centerChance {
            return center
        }

        let corners = [
            TicTacToePosition(row: 0, column: 0),
            TicTacToePosition(row: 0, column: 2),
            TicTacToePosition(row: 2, column: 0),
            TicTacToePosition(row: 2, column: 2)
        ].filter { board[$0.index] == nil }
        if let corner = randomPosition(from: corners, using: &random) {
            return corner
        }

        let edges = [
            TicTacToePosition(row: 0, column: 1),
            TicTacToePosition(row: 1, column: 0),
            TicTacToePosition(row: 1, column: 2),
            TicTacToePosition(row: 2, column: 1)
        ].filter { board[$0.index] == nil }
        return randomPosition(from: edges, using: &random)
    }

    static func hardMove<R: RandomNumberGenerator>(
        on board: [TicTacToeMark?],
        minikMark: TicTacToeMark,
        childMark: TicTacToeMark,
        using random: inout R
    ) -> TicTacToePosition? {
        let empties = emptyPositions(on: board)
        guard !empties.isEmpty else {
            return nil
        }

        var scored: [(position: TicTacToePosition, score: Int)] = []
        for position in empties {
            var candidate = board
            candidate[position.index] = minikMark
            let score = minimax(
                board: candidate,
                depth: 0,
                maximizing: false,
                minikMark: minikMark,
                childMark: childMark
            )
            scored.append((position, score))
        }

        guard let bestScore = scored.map(\.score).max() else {
            return nil
        }
        return randomPosition(
            from: scored.filter { $0.score == bestScore }.map(\.position),
            using: &random
        )
    }

    static func immediateWinningMove(
        on board: [TicTacToeMark?],
        for mark: TicTacToeMark
    ) -> TicTacToePosition? {
        for position in emptyPositions(on: board) {
            var candidate = board
            candidate[position.index] = mark
            if TicTacToeSession.winningLine(on: candidate, for: mark) != nil {
                return position
            }
        }
        return nil
    }

    static func levelProfile(for level: TicTacToeLevel) -> LevelProfile {
        switch level {
        case .a:
            return LevelProfile(
                base: .easy,
                hardChanceMinimum: 0,
                hardChanceMaximum: 0,
                hardMoveCap: 0,
                hardMinimumPlacementCount: 4
            )
        case .b:
            return LevelProfile(
                base: .easy,
                hardChanceMinimum: 0.10,
                hardChanceMaximum: 0.20,
                hardMoveCap: 1,
                hardMinimumPlacementCount: 3
            )
        case .c:
            return LevelProfile(
                base: .medium,
                hardChanceMinimum: 0.30,
                hardChanceMaximum: 0.45,
                hardMoveCap: 2,
                hardMinimumPlacementCount: 2
            )
        case .d:
            return LevelProfile(
                base: .medium,
                hardChanceMinimum: 0.55,
                hardChanceMaximum: 0.75,
                hardMoveCap: 3,
                hardMinimumPlacementCount: 1
            )
        case .e:
            return LevelProfile(
                base: .medium,
                hardChanceMinimum: 0.85,
                hardChanceMaximum: 0.95,
                hardMoveCap: .max,
                hardMinimumPlacementCount: 0
            )
        case .random, .adaptive:
            return LevelProfile(
                base: .medium,
                hardChanceMinimum: 0,
                hardChanceMaximum: 0,
                hardMoveCap: 0,
                hardMinimumPlacementCount: .max
            )
        }
    }

    static func mediumProfile(for level: TicTacToeLevel) -> MediumProfile {
        switch level {
        case .a:
            return MediumProfile(winChance: 0.10, blockChance: 0.18, centerChance: 0.20)
        case .b:
            return MediumProfile(winChance: 0.35, blockChance: 0.55, centerChance: 0.55)
        case .c, .random, .adaptive:
            return MediumProfile(winChance: 1, blockChance: 1, centerChance: 0.90)
        case .d, .e:
            return MediumProfile(winChance: 1, blockChance: 1, centerChance: 1)
        }
    }

    private static func minimax(
        board: [TicTacToeMark?],
        depth: Int,
        maximizing: Bool,
        minikMark: TicTacToeMark,
        childMark: TicTacToeMark
    ) -> Int {
        if TicTacToeSession.winningLine(on: board, for: minikMark) != nil {
            return 10 - depth
        }
        if TicTacToeSession.winningLine(on: board, for: childMark) != nil {
            return depth - 10
        }

        let empties = emptyPositions(on: board)
        guard !empties.isEmpty else {
            return 0
        }

        if maximizing {
            var best = Int.min
            for position in empties {
                var candidate = board
                candidate[position.index] = minikMark
                best = max(
                    best,
                    minimax(
                        board: candidate,
                        depth: depth + 1,
                        maximizing: false,
                        minikMark: minikMark,
                        childMark: childMark
                    )
                )
            }
            return best
        }

        var best = Int.max
        for position in empties {
            var candidate = board
            candidate[position.index] = childMark
            best = min(
                best,
                minimax(
                    board: candidate,
                    depth: depth + 1,
                    maximizing: true,
                    minikMark: minikMark,
                    childMark: childMark
                )
            )
        }
        return best
    }

    private static func emptyPositions(on board: [TicTacToeMark?]) -> [TicTacToePosition] {
        TicTacToePosition.all.filter { position in
            board.indices.contains(position.index) && board[position.index] == nil
        }
    }

    private static func randomPosition<R: RandomNumberGenerator>(
        from positions: [TicTacToePosition],
        using random: inout R
    ) -> TicTacToePosition? {
        guard !positions.isEmpty else {
            return nil
        }
        return positions[randomIndex(count: positions.count, using: &random)]
    }

    private static func randomIndex<R: RandomNumberGenerator>(
        count: Int,
        using random: inout R
    ) -> Int {
        Int(random.next() % UInt64(count))
    }

    static func unitRandom<R: RandomNumberGenerator>(using random: inout R) -> Double {
        let value = random.next() >> 11
        let bucketCount = Double((UInt64.max >> 11) + 1)
        return Double(value) / bucketCount
    }
}
