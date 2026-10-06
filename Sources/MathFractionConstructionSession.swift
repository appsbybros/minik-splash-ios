import Foundation

struct MathFractionConstructionRound: Hashable, Sendable {
    let id: ChallengeID
    let target: Rational
    let prompt: Representation
    let spokenPrompt: String
    let mathLevelID: MathCurriculumLevelID
    let skillID: SkillID

    init?(
        id: ChallengeID,
        target: Rational,
        prompt: Representation,
        spokenPrompt: String,
        mathLevelID: MathCurriculumLevelID,
        skillID: SkillID
    ) {
        guard target.denominator > 1,
              target.numerator >= 0,
              target.numerator <= target.denominator else { return nil }
        self.id = id
        self.target = target
        self.prompt = prompt
        self.spokenPrompt = spokenPrompt
        self.mathLevelID = mathLevelID
        self.skillID = skillID
    }
}

enum MathFractionConstructionResult: Hashable, Sendable {
    case correct
    case incorrect
}

struct MathFractionConstructionSession: Sendable {
    let rounds: [MathFractionConstructionRound]
    private(set) var currentRoundIndex = 0
    private(set) var selectedPartCount = 0
    private(set) var answerResult: MathFractionConstructionResult?
    private(set) var submissionCount = 0
    private(set) var isComplete = false

    init?(rounds: [MathFractionConstructionRound]) {
        guard !rounds.isEmpty else { return nil }
        self.rounds = rounds
    }

    var currentRound: MathFractionConstructionRound { rounds[currentRoundIndex] }
    var roundCount: Int { rounds.count }

    mutating func addPart() {
        guard !isComplete, answerResult != .correct,
              selectedPartCount < currentRound.target.denominator else { return }
        answerResult = nil
        selectedPartCount += 1
    }

    mutating func removePart() {
        guard !isComplete, answerResult != .correct, selectedPartCount > 0 else { return }
        answerResult = nil
        selectedPartCount -= 1
    }

    @discardableResult
    mutating func submit() -> MathFractionConstructionResult? {
        guard !isComplete, answerResult != .correct else { return nil }
        submissionCount += 1
        answerResult = selectedPartCount == currentRound.target.numerator ? .correct : .incorrect
        return answerResult
    }

    mutating func nextRound() {
        guard !isComplete, answerResult == .correct else { return }
        if currentRoundIndex < rounds.count - 1 {
            currentRoundIndex += 1
            selectedPartCount = 0
            answerResult = nil
            submissionCount = 0
        } else {
            isComplete = true
        }
    }
}
