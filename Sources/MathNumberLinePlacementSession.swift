import Foundation

struct MathNumberLinePlacementRound: Hashable, Sendable {
    let id: ChallengeID
    let lowerBound: Int
    let upperBound: Int
    let target: Int
    let prompt: Representation
    let spokenPrompt: String
    let mathLevelID: MathCurriculumLevelID
    let skillID: SkillID

    init?(
        id: ChallengeID,
        lowerBound: Int,
        upperBound: Int,
        target: Int,
        prompt: Representation,
        spokenPrompt: String,
        mathLevelID: MathCurriculumLevelID,
        skillID: SkillID
    ) {
        guard lowerBound < upperBound, (lowerBound...upperBound).contains(target) else { return nil }
        self.id = id
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.target = target
        self.prompt = prompt
        self.spokenPrompt = spokenPrompt
        self.mathLevelID = mathLevelID
        self.skillID = skillID
    }
}

enum MathNumberLinePlacementResult: Hashable, Sendable {
    case correct
    case incorrect
}

struct MathNumberLinePlacementSession: Sendable {
    let rounds: [MathNumberLinePlacementRound]
    private(set) var currentRoundIndex = 0
    private(set) var selectedValue: Int
    private(set) var answerResult: MathNumberLinePlacementResult?
    private(set) var submissionCount = 0
    private(set) var isComplete = false

    init?(rounds: [MathNumberLinePlacementRound]) {
        guard let first = rounds.first else { return nil }
        self.rounds = rounds
        selectedValue = min(first.upperBound, max(first.lowerBound, 0))
    }

    var currentRound: MathNumberLinePlacementRound { rounds[currentRoundIndex] }
    var roundCount: Int { rounds.count }

    mutating func move(by offset: Int) {
        guard !isComplete, answerResult != .correct else { return }
        let moved = selectedValue.addingReportingOverflow(offset)
        let candidate = moved.overflow
            ? (offset < 0 ? currentRound.lowerBound : currentRound.upperBound)
            : moved.partialValue
        selectedValue = min(currentRound.upperBound, max(currentRound.lowerBound, candidate))
        answerResult = nil
    }

    @discardableResult
    mutating func submit() -> MathNumberLinePlacementResult? {
        guard !isComplete, answerResult != .correct else { return nil }
        submissionCount += 1
        answerResult = selectedValue == currentRound.target ? .correct : .incorrect
        return answerResult
    }

    mutating func nextRound() {
        guard !isComplete, answerResult == .correct else { return }
        if currentRoundIndex < rounds.count - 1 {
            currentRoundIndex += 1
            selectedValue = min(currentRound.upperBound, max(currentRound.lowerBound, 0))
            answerResult = nil
            submissionCount = 0
        } else {
            isComplete = true
        }
    }
}
