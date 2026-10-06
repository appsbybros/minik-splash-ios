import Foundation

enum MathDistractorStrategy: Hashable, Sendable {
    case offByOne
    case nearby(offsets: [Int])
    case operandConfusion(candidates: [ExactNumericValue])
    case wrongPlaceValue(candidates: [ExactNumericValue])
    case commonArithmeticMistake(candidates: [ExactNumericValue])
    case inverseOperationResult(ExactNumericValue)
    case symbolicallyNearby(candidates: [ExactNumericValue])
}

struct MathDistractorRequest: Hashable, Sendable {
    let correctAnswer: ExactNumericValue
    let choiceCount: Int
    let permittedDomain: Set<ExactNumericValue>
    let strategies: [MathDistractorStrategy]

    init?(
        correctAnswer: ExactNumericValue,
        choiceCount: Int = 4,
        permittedDomain: Set<ExactNumericValue>,
        strategies: [MathDistractorStrategy]
    ) {
        guard choiceCount >= 2,
              permittedDomain.containsNumerically(correctAnswer),
              !strategies.isEmpty else { return nil }
        self.correctAnswer = correctAnswer
        self.choiceCount = choiceCount
        self.permittedDomain = permittedDomain
        self.strategies = strategies
    }
}

enum MathDistractorGenerationError: Error, Hashable, Sendable {
    case insufficientUniqueCandidates(required: Int, available: Int)
}

struct MathDistractorEngine: Sendable {
    func generate<R: RandomNumberGenerator>(
        for request: MathDistractorRequest,
        using randomNumberGenerator: inout R
    ) -> Result<[ExactNumericValue], MathDistractorGenerationError> {
        let correctKey = request.correctAnswer.normalizedRational
        let permittedKeys = Set(request.permittedDomain.map(\.normalizedRational))
        var seen = Set<Rational>([correctKey])
        var distractors: [ExactNumericValue] = []

        for strategy in request.strategies {
            for candidate in candidates(for: strategy, correctAnswer: request.correctAnswer) {
                let key = candidate.normalizedRational
                guard key != correctKey,
                      permittedKeys.contains(key),
                      seen.insert(key).inserted else { continue }
                distractors.append(candidate)
            }
        }

        let requiredDistractors = request.choiceCount - 1
        guard distractors.count >= requiredDistractors else {
            return .failure(.insufficientUniqueCandidates(
                required: requiredDistractors,
                available: distractors.count
            ))
        }

        distractors.shuffle(using: &randomNumberGenerator)
        var choices = Array(distractors.prefix(requiredDistractors))
        choices.append(request.correctAnswer)
        choices.shuffle(using: &randomNumberGenerator)
        return .success(choices)
    }

    private func candidates(
        for strategy: MathDistractorStrategy,
        correctAnswer: ExactNumericValue
    ) -> [ExactNumericValue] {
        switch strategy {
        case .offByOne:
            guard case .integer(let value) = correctAnswer else { return [] }
            return [-1, 1].compactMap { offset in
                let (candidate, overflow) = value.addingReportingOverflow(offset)
                return overflow ? nil : .integer(candidate)
            }
        case .nearby(let offsets):
            guard case .integer(let value) = correctAnswer else { return [] }
            return offsets.compactMap { offset in
                let (candidate, overflow) = value.addingReportingOverflow(offset)
                return overflow ? nil : .integer(candidate)
            }
        case .operandConfusion(let candidates),
             .wrongPlaceValue(let candidates),
             .commonArithmeticMistake(let candidates),
             .symbolicallyNearby(let candidates):
            return candidates
        case .inverseOperationResult(let candidate):
            return [candidate]
        }
    }
}

struct SeededMathRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

private extension Set where Element == ExactNumericValue {
    func containsNumerically(_ value: ExactNumericValue) -> Bool {
        let key = value.normalizedRational
        return contains { $0.normalizedRational == key }
    }
}
