import Foundation

struct MathCountTokenID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty)
        self.rawValue = rawValue
    }
}

struct MathCountRound: Hashable, Sendable {
    let id: ChallengeID
    let target: Int
    let availableTokenIDs: [MathCountTokenID]
    let prompt: Representation
    let spokenPrompt: String
    let mathLevelID: MathCurriculumLevelID
    let skillID: SkillID

    init?(
        id: ChallengeID,
        target: Int,
        availableTokenIDs: [MathCountTokenID],
        prompt: Representation? = nil,
        spokenPrompt: String? = nil,
        mathLevelID: MathCurriculumLevelID = .m1,
        skillID: SkillID = MathSkillIDs.quantityToNumber
    ) {
        guard target >= 0,
              availableTokenIDs.count > target,
              Set(availableTokenIDs).count == availableTokenIDs.count else {
            return nil
        }
        self.id = id
        self.target = target
        self.availableTokenIDs = availableTokenIDs
        self.prompt = prompt ?? .math(.numeral(MathNumeralRepresentation(
            value: target,
            structureID: RepresentationStructureID(rawValue: "math.count.target.\(target)")
        )))
        self.spokenPrompt = spokenPrompt ?? String(target)
        self.mathLevelID = mathLevelID
        self.skillID = skillID
    }
}

enum MathCountConstructionResult: Hashable, Sendable {
    case correct
    case incorrect
}

struct MathCountConstructionSession: Sendable {
    let rounds: [MathCountRound]
    private(set) var currentRoundIndex = 0
    private(set) var selectedTokenIDs: [MathCountTokenID] = []
    private(set) var answerResult: MathCountConstructionResult?
    private(set) var submissionCount = 0
    private(set) var isComplete = false

    init?(rounds: [MathCountRound]) {
        guard !rounds.isEmpty else { return nil }
        self.rounds = rounds
    }

    var currentRound: MathCountRound { rounds[currentRoundIndex] }
    var roundCount: Int { rounds.count }
    var currentCount: Int { selectedTokenIDs.count }
    var availableTokenIDs: [MathCountTokenID] {
        let selected = Set(selectedTokenIDs)
        return currentRound.availableTokenIDs.filter { !selected.contains($0) }
    }

    mutating func add(_ tokenID: MathCountTokenID) {
        guard !isComplete,
              answerResult != .correct,
              !selectedTokenIDs.contains(tokenID),
              currentRound.availableTokenIDs.contains(tokenID) else { return }
        answerResult = nil
        selectedTokenIDs.append(tokenID)
    }

    mutating func remove(_ tokenID: MathCountTokenID) {
        guard !isComplete, answerResult != .correct,
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
    mutating func submit() -> MathCountConstructionResult? {
        guard !isComplete, answerResult != .correct else { return nil }
        submissionCount += 1
        answerResult = currentCount == currentRound.target ? .correct : .incorrect
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
