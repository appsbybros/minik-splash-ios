import Foundation

struct MathStructuredConstructionTokenID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty)
        self.rawValue = rawValue
    }
}

enum MathStructuredConstructionUnit: Hashable, Sendable {
    case placeValue(Int)
    case equalGroup(itemsPerGroup: Int)

    var semanticContribution: Int {
        switch self {
        case .placeValue(let value): return value
        case .equalGroup(let itemsPerGroup): return itemsPerGroup
        }
    }
}

struct MathStructuredConstructionToken: Hashable, Sendable {
    let id: MathStructuredConstructionTokenID
    let unit: MathStructuredConstructionUnit
}

struct MathStructuredConstructionRound: Hashable, Sendable {
    let id: ChallengeID
    let targetValue: Int
    let expectedUnitCounts: [MathStructuredConstructionUnit: Int]
    let availableTokens: [MathStructuredConstructionToken]
    let prompt: Representation
    let spokenPrompt: String
    let mathLevelID: MathCurriculumLevelID
    let skillID: SkillID

    init?(
        id: ChallengeID,
        targetValue: Int,
        expectedUnitCounts: [MathStructuredConstructionUnit: Int],
        availableTokens: [MathStructuredConstructionToken],
        prompt: Representation,
        spokenPrompt: String,
        mathLevelID: MathCurriculumLevelID,
        skillID: SkillID
    ) {
        let expectedValue = expectedUnitCounts.reduce(0) { partial, pair in
            partial + pair.key.semanticContribution * pair.value
        }
        let availableCounts = Dictionary(grouping: availableTokens, by: \.unit).mapValues(\.count)
        guard targetValue > 0,
              !expectedUnitCounts.isEmpty,
              expectedUnitCounts.values.allSatisfy({ $0 >= 0 }),
              expectedUnitCounts.values.contains(where: { $0 > 0 }),
              expectedValue == targetValue,
              Set(availableTokens.map(\.id)).count == availableTokens.count,
              availableTokens.count > expectedUnitCounts.values.reduce(0, +),
              expectedUnitCounts.allSatisfy({ availableCounts[$0.key, default: 0] >= $0.value }) else {
            return nil
        }
        self.id = id
        self.targetValue = targetValue
        self.expectedUnitCounts = expectedUnitCounts
        self.availableTokens = availableTokens
        self.prompt = prompt
        self.spokenPrompt = spokenPrompt
        self.mathLevelID = mathLevelID
        self.skillID = skillID
    }
}

enum MathStructuredConstructionResult: Hashable, Sendable {
    case correct
    case incorrect
}

struct MathStructuredConstructionSession: Sendable {
    let rounds: [MathStructuredConstructionRound]
    private(set) var currentRoundIndex = 0
    private(set) var selectedTokenIDs: [MathStructuredConstructionTokenID] = []
    private(set) var answerResult: MathStructuredConstructionResult?
    private(set) var submissionCount = 0
    private(set) var isComplete = false

    init?(rounds: [MathStructuredConstructionRound]) {
        guard !rounds.isEmpty else { return nil }
        self.rounds = rounds
    }

    var currentRound: MathStructuredConstructionRound { rounds[currentRoundIndex] }
    var roundCount: Int { rounds.count }

    var selectedTokens: [MathStructuredConstructionToken] {
        let byID = Dictionary(uniqueKeysWithValues: currentRound.availableTokens.map { ($0.id, $0) })
        return selectedTokenIDs.compactMap { byID[$0] }
    }

    var availableTokens: [MathStructuredConstructionToken] {
        let selected = Set(selectedTokenIDs)
        return currentRound.availableTokens.filter { !selected.contains($0.id) }
    }

    mutating func add(_ tokenID: MathStructuredConstructionTokenID) {
        guard !isComplete,
              answerResult != .correct,
              !selectedTokenIDs.contains(tokenID),
              currentRound.availableTokens.contains(where: { $0.id == tokenID }) else { return }
        answerResult = nil
        selectedTokenIDs.append(tokenID)
    }

    mutating func remove(_ tokenID: MathStructuredConstructionTokenID) {
        guard !isComplete,
              answerResult != .correct,
              let index = selectedTokenIDs.firstIndex(of: tokenID) else { return }
        answerResult = nil
        selectedTokenIDs.remove(at: index)
    }

    mutating func undo() {
        guard !isComplete, answerResult != .correct, !selectedTokenIDs.isEmpty else { return }
        answerResult = nil
        selectedTokenIDs.removeLast()
    }

    @discardableResult
    mutating func submit() -> MathStructuredConstructionResult? {
        guard !isComplete, answerResult != .correct else { return nil }
        submissionCount += 1
        let selectedCounts = Dictionary(grouping: selectedTokens, by: \.unit).mapValues(\.count)
        answerResult = selectedCounts == currentRound.expectedUnitCounts ? .correct : .incorrect
        return answerResult
    }

    mutating func nextRound() {
        guard !isComplete, answerResult == .correct else { return }
        if currentRoundIndex < rounds.count - 1 {
            currentRoundIndex += 1
            selectedTokenIDs = []
            answerResult = nil
            submissionCount = 0
        } else {
            isComplete = true
        }
    }
}
