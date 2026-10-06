import Foundation

enum MathM6Category: CaseIterable, Hashable, Sendable {
    case multiplication
    case division
    case factor
    case multiple
    case fraction
}

enum MathM6ChoiceDirection: Hashable, Sendable {
    case promptToAnswer
    case answerToRepresentation
}

enum MathM6MistakeStrategy: CaseIterable, Hashable, Sendable {
    case nearbyValue
    case relatedFact
    case operationConfusion
    case fractionComplement
}

enum MathM6PromptKind: Hashable, Sendable {
    case multiplication(Int, Int)
    case division(dividend: Int, divisor: Int)
    case factor(product: Int, knownFactor: Int)
    case multiple(factor: Int, index: Int)
    case fraction(Rational)
}

struct MathM6Problem: Hashable, Sendable {
    let id: String
    let kind: MathM6PromptKind

    init?(id: String, kind: MathM6PromptKind) {
        guard !id.isEmpty else { return nil }
        switch kind {
        case .multiplication(let left, let right), .multiple(let left, let right):
            guard (1...10).contains(left), (1...10).contains(right) else { return nil }
        case .division(let dividend, let divisor):
            guard divisor > 0, dividend > 0, dividend % divisor == 0,
                  dividend / divisor <= 10 else { return nil }
        case .factor(let product, let knownFactor):
            guard knownFactor > 0, product > 0, product % knownFactor == 0,
                  product / knownFactor <= 10 else { return nil }
        case .fraction(let value):
            guard [2, 4].contains(value.denominator),
                  value.numerator > 0, value.numerator < value.denominator else { return nil }
        }
        self.id = id
        self.kind = kind
    }

    var category: MathM6Category {
        switch kind {
        case .multiplication: return .multiplication
        case .division: return .division
        case .factor: return .factor
        case .multiple: return .multiple
        case .fraction: return .fraction
        }
    }

    var answer: SemanticValue {
        switch kind {
        case .multiplication(let left, let right), .multiple(let left, let right):
            return .integer(left * right)
        case .division(let dividend, let divisor):
            return .integer(dividend / divisor)
        case .factor(let product, let knownFactor):
            return .integer(product / knownFactor)
        case .fraction(let value):
            return .rational(value)
        }
    }

    var integerAnswer: Int? {
        guard case .integer(let value) = answer else { return nil }
        return value
    }

    var answerText: String {
        switch answer {
        case .integer(let value): return String(value)
        case .rational(let value): return value.displayText
        case .contentItem: preconditionFailure("M6 answers are numeric.")
        }
    }
}

struct MathM6ContentProvider: Sendable {
    static let factFamilies = Array(1...10)
    static let mistakeStrategies = MathM6MistakeStrategy.allCases
    static let problems: [MathM6Problem] = [
        MathM6Problem(id: "multiply.6.7", kind: .multiplication(6, 7))!,
        MathM6Problem(id: "multiply.6.6", kind: .multiplication(6, 6))!,
        MathM6Problem(id: "multiply.8.8", kind: .multiplication(8, 8))!,
        MathM6Problem(id: "multiply.9.10", kind: .multiplication(9, 10))!,
        MathM6Problem(id: "multiply.10.10", kind: .multiplication(10, 10))!,
        MathM6Problem(id: "divide.42.6", kind: .division(dividend: 42, divisor: 6))!,
        MathM6Problem(id: "divide.72.8", kind: .division(dividend: 72, divisor: 8))!,
        MathM6Problem(id: "divide.90.10", kind: .division(dividend: 90, divisor: 10))!,
        MathM6Problem(id: "factor.24.6", kind: .factor(product: 24, knownFactor: 6))!,
        MathM6Problem(id: "factor.35.5", kind: .factor(product: 35, knownFactor: 5))!,
        MathM6Problem(id: "factor.54.9", kind: .factor(product: 54, knownFactor: 9))!,
        MathM6Problem(id: "multiple.4.6", kind: .multiple(factor: 4, index: 6))!,
        MathM6Problem(id: "multiple.7.5", kind: .multiple(factor: 7, index: 5))!,
        MathM6Problem(id: "multiple.8.5", kind: .multiple(factor: 8, index: 5))!,
        MathM6Problem(id: "fraction.half", kind: .fraction(Rational(numerator: 1, denominator: 2)!))!,
        MathM6Problem(id: "fraction.quarter", kind: .fraction(Rational(numerator: 1, denominator: 4)!))!,
        MathM6Problem(id: "fraction.three-quarters", kind: .fraction(Rational(numerator: 3, denominator: 4)!))!
    ]

    private static let difficulty = Difficulty(0.82)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) {
        self.fitGate = fitGate
    }

    func balancedProblems(count: Int) -> [MathM6Problem] {
        guard count > 0 else { return [] }
        let pattern: [MathM6Category] = [
            .multiplication, .division, .factor, .multiple,
            .fraction, .multiplication, .division, .fraction
        ]
        var offsets = Dictionary(uniqueKeysWithValues: MathM6Category.allCases.map { ($0, 0) })
        return (0..<count).compactMap { index in
            let category = pattern[index % pattern.count]
            let candidates = Self.problems.filter { $0.category == category }
            let offset = offsets[category, default: 0]
            offsets[category] = offset + 1
            return candidates.isEmpty ? nil : candidates[offset % candidates.count]
        }
    }

    func studyCards() -> [StudyCard] {
        let source = coverageProblems(count: 10)
        return source.compactMap { problem in
            let values = [promptRepresentation(problem), answerRepresentation(problem)]
            guard fitGate.allows(values, for: .learn) else { return nil }
            return StudyCard(
                id: StudyCardID(rawValue: "m6.card.\(problem.id)"),
                representations: values,
                primarySkill: skill(for: problem),
                secondarySkills: secondarySkills(for: problem),
                curriculumStage: MathCurriculumLevelID.m6.curriculumStageID
            )
        }
    }

    func equivalenceSets(count: Int = 5) -> [EquivalenceSet] {
        coverageProblems(count: count).compactMap { problem in
            let values = [promptRepresentation(problem), answerRepresentation(problem)]
            guard fitGate.allows(values, for: .matching) else { return nil }
            return EquivalenceSet(semanticValue: problem.answer, representations: values)
        }
    }

    func choiceChallenge(problem preferred: MathM6Problem, direction: MathM6ChoiceDirection) -> Challenge? {
        guard let problem = fitted(preferred, mechanic: .choice),
              let candidates = answerCandidates(for: problem),
              let prompt = Prompt(representations: [
                direction == .promptToAnswer ? promptRepresentation(problem) : answerRepresentation(problem)
              ]) else { return nil }
        let id = "m6.choice.\(problem.id).\(UUID().uuidString)"
        let choices = candidates.enumerated().map { index, candidate in
            Choice(
                id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                representation: direction == .promptToAnswer
                    ? answerRepresentation(candidate)
                    : promptRepresentation(candidate),
                semanticValue: candidate.answer
            )
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return challenge(id: id, prompt: prompt, choices: choices, problem: problem)
    }

    func buildNumberChallenge(problem preferred: MathM6Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return answerTokenChallenge(id: "m6.build-number.\(problem.id).\(UUID().uuidString)", problem: problem)
    }

    func buildMathChallenge(problem preferred: MathM6Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build),
              let prompt = Prompt(representations: [promptRepresentation(problem)]) else { return nil }
        let pieces: [String]
        switch problem.kind {
        case .multiplication(let left, let right), .multiple(let left, let right):
            pieces = [String(left), MathOperation.multiplication.symbol, String(right), "=", problem.answerText]
        case .division(let dividend, let divisor):
            pieces = [String(dividend), MathOperation.division.symbol, String(divisor), "=", problem.answerText]
        case .factor(let product, let knownFactor):
            pieces = [String(knownFactor), MathOperation.multiplication.symbol, problem.answerText, "=", String(product)]
        case .fraction(let value):
            let decimal = value == Rational(numerator: 1, denominator: 2)! ? "0.5"
                : value == Rational(numerator: 1, denominator: 4)! ? "0.25" : "0.75"
            pieces = [String(value.numerator), "/", String(value.denominator), "=", decimal]
        }
        return sequenceChallenge(
            id: "m6.build-math.\(problem.id).\(UUID().uuidString)", prompt: prompt,
            pieces: pieces, distractor: nearbyText(for: problem), skill: skill(for: problem)
        )
    }

    func structuredRound(problem preferred: MathM6Problem) -> MathStructuredConstructionRound? {
        let source = Self.problems.filter { $0.category == .multiplication && ($0.integerAnswer ?? 101) <= 50 }
        guard let problem = fitted(preferred, candidates: source, mechanic: .countConstruction),
              case .multiplication(let groups, let items) = problem.kind,
              let target = problem.integerAnswer else { return nil }
        let unit = MathStructuredConstructionUnit.equalGroup(itemsPerGroup: items)
        let wrong = MathStructuredConstructionUnit.equalGroup(itemsPerGroup: max(1, items - 1))
        let id = "m6.structured.\(problem.id).\(UUID().uuidString)"
        let correctTokens = (0..<(groups + 1)).map {
            MathStructuredConstructionToken(id: .init(rawValue: "\(id).group.\($0)"), unit: unit)
        }
        let distractors = (0..<2).map {
            MathStructuredConstructionToken(id: .init(rawValue: "\(id).wrong.\($0)"), unit: wrong)
        }
        let prompt = answerRepresentation(problem)
        return MathStructuredConstructionRound(
            id: ChallengeID(rawValue: id), targetValue: target,
            expectedUnitCounts: [unit: groups], availableTokens: (correctTokens + distractors).shuffled(),
            prompt: prompt, spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m6, skillID: MathSkillIDs.equalGroups
        )
    }

    func fractionRound(problem preferred: MathM6Problem) -> MathFractionConstructionRound? {
        let source = Self.problems.filter { $0.category == .fraction }
        guard let problem = fitted(preferred, candidates: source, mechanic: .countConstruction),
              case .fraction(let target) = problem.kind else { return nil }
        let prompt = token(problem.answerText, id: "m6.fraction.prompt.\(problem.id)")
        return MathFractionConstructionRound(
            id: ChallengeID(rawValue: "m6.fraction-build.\(problem.id).\(UUID().uuidString)"),
            target: target, prompt: prompt, spokenPrompt: answerRepresentation(problem).accessibilityDescription,
            mathLevelID: .m6, skillID: MathSkillIDs.simpleFractions
        )
    }

    func countRound(problem preferred: MathM6Problem) -> MathCountRound? {
        let source = Self.problems.filter { ($0.integerAnswer ?? 101) <= 20 }
        guard let problem = fitted(preferred, candidates: source, mechanic: .countConstruction),
              let target = problem.integerAnswer else { return nil }
        let id = "m6.count.\(problem.id).\(UUID().uuidString)"
        let prompt = promptRepresentation(problem)
        return MathCountRound(
            id: ChallengeID(rawValue: id), target: target,
            availableTokenIDs: (0..<(target + 3)).map { .init(rawValue: "\(id).token.\($0)") },
            prompt: prompt, spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m6, skillID: skill(for: problem)
        )
    }

    func answerTokenTowerChallenge(problem preferred: MathM6Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return answerTokenChallenge(id: "m6.tower.\(problem.id).\(UUID().uuidString)", problem: problem)
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool else { return nil }
        let preferred = uniqueAnswerProblems().prefix(answerCount)
        guard preferred.count == answerCount else { return nil }
        let problems = preferred.compactMap { fitted($0, mechanic: .soccerPrompt) }
        guard problems.count == answerCount, numericallyUnique(problems.map(\.answer)) else { return nil }
        let id = "m6.soccer.\(UUID().uuidString)"
        let balls = problems.enumerated().map { index, problem in
            SoccerAnswerBall(id: .init(rawValue: "\(id).ball.\(index)"),
                             representation: answerRepresentation(problem), semanticValue: problem.answer)
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(problems, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            guard let prompt = Prompt(representations: [promptRepresentation(pair.0)]) else { return nil }
            return SoccerChallengeTarget(
                challenge: challenge(id: "\(id).challenge.\(index)", prompt: prompt, choices: [], problem: pair.0),
                intendedBallID: pair.1.id
            )
        }
        return targets.count == balls.count
            ? SoccerRound(id: .init(rawValue: "\(id).round"), answerBalls: balls, challengeTargets: targets) : nil
    }

    private func coverageProblems(count: Int) -> [MathM6Problem] {
        let categories: [MathM6Category] = [.multiplication, .division, .factor, .multiple, .fraction]
        var result: [MathM6Problem] = []
        var offset = 0
        while result.count < count {
            let category = categories[offset % categories.count]
            let values = Self.problems.filter { $0.category == category }
            result.append(values[(offset / categories.count) % values.count])
            offset += 1
        }
        return result
    }

    private func fitted(
        _ preferred: MathM6Problem,
        candidates: [MathM6Problem]? = nil,
        mechanic: MathPresentationMechanic
    ) -> MathM6Problem? {
        let pool = candidates ?? Self.problems.filter { $0.category == preferred.category }
        guard !pool.isEmpty else { return nil }
        let start = pool.firstIndex(of: preferred) ?? 0
        var offset = 0
        let result = MathPresentationFitPolicy.resolvedCandidate(
            generate: { defer { offset += 1 }; return pool[(start + offset) % pool.count] },
            isReadable: { fitGate.allows([promptRepresentation($0)], for: mechanic) }
        )
        switch result {
        case .candidate(let value), .compactFallback(let value): return value
        case .unavailable: return nil
        }
    }

    private func answerCandidates(for problem: MathM6Problem) -> [MathM6Problem]? {
        var result = [problem]
        for strategy in Self.mistakeStrategies {
            for candidateAnswer in plausibleAnswers(for: problem, strategy: strategy) {
                guard let candidate = Self.problems.first(where: { candidate in
                    candidate.answer.isNumericallyEquivalent(to: candidateAnswer)
                        && !result.contains(where: { existing in
                            existing.answer.isNumericallyEquivalent(to: candidate.answer)
                        })
                }) else { continue }
                result.append(candidate)
            }
        }
        for candidate in Self.problems where result.count < 4 {
            guard !result.contains(where: { $0.answer.isNumericallyEquivalent(to: candidate.answer) }) else { continue }
            result.append(candidate)
        }
        return result.count == 4 ? result.shuffled() : nil
    }

    private func plausibleAnswers(
        for problem: MathM6Problem,
        strategy: MathM6MistakeStrategy
    ) -> [SemanticValue] {
        switch (strategy, problem.kind) {
        case (.nearbyValue, _):
            guard let value = problem.integerAnswer else { return [] }
            return [.integer(max(1, value - 1)), .integer(min(100, value + 1))]
        case (.relatedFact, .multiplication(let left, let right)),
             (.relatedFact, .multiple(let left, let right)):
            return [.integer(left + right)]
        case (.relatedFact, .division(_, let divisor)):
            return [.integer(divisor)]
        case (.relatedFact, .factor(_, let knownFactor)):
            return [.integer(knownFactor)]
        case (.operationConfusion, .multiplication(let left, let right)),
             (.operationConfusion, .multiple(let left, let right)):
            return [.integer(abs(left - right)), .integer(left + right)]
        case (.operationConfusion, .division(let dividend, let divisor)):
            return [.integer(dividend - divisor)]
        case (.operationConfusion, .factor(let product, let knownFactor)):
            return [.integer(product - knownFactor)]
        case (.fractionComplement, .fraction(let value)):
            return Rational(numerator: value.denominator - value.numerator, denominator: value.denominator)
                .map { [.rational($0)] } ?? []
        default:
            return []
        }
    }

    private func uniqueAnswerProblems() -> [MathM6Problem] {
        var result: [MathM6Problem] = []
        for problem in coverageProblems(count: Self.problems.count) {
            if !result.contains(where: { $0.answer.isNumericallyEquivalent(to: problem.answer) }) { result.append(problem) }
        }
        return result
    }

    private func numericallyUnique(_ values: [SemanticValue]) -> Bool {
        for (index, value) in values.enumerated() {
            if values.dropFirst(index + 1).contains(where: { value.isNumericallyEquivalent(to: $0) }) { return false }
        }
        return true
    }

    private func answerTokenChallenge(id: String, problem: MathM6Problem) -> BuildChallenge? {
        guard let prompt = Prompt(representations: [promptRepresentation(problem)]) else { return nil }
        var tokens = problem.answerText.enumerated().map { index, character in
            BuildToken(id: .init(rawValue: "\(id).expected.\(index)"),
                       representation: token(String(character), id: "\(id).piece.\(index)"))
        }
        let expected = tokens.map(\.id)
        tokens += [nearbyText(for: problem), "0"].enumerated().map { index, value in
            BuildToken(id: .init(rawValue: "\(id).extra.\(index)"),
                       representation: token(value, id: "\(id).extra-representation.\(index)"))
        }
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill(for: problem),
            secondarySkills: secondarySkills(for: problem), curriculumStage: MathCurriculumLevelID.m6.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func sequenceChallenge(id: String, prompt: Prompt, pieces: [String], distractor: String, skill: SkillID) -> BuildChallenge? {
        var tokens = pieces.enumerated().map { index, piece in
            BuildToken(id: .init(rawValue: "\(id).expected.\(index)"),
                       representation: token(piece, id: "\(id).piece.\(index)"))
        }
        let expected = tokens.map(\.id)
        tokens.append(BuildToken(id: .init(rawValue: "\(id).extra"),
                                 representation: token(distractor, id: "\(id).extra-representation")))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill,
            secondarySkills: [], curriculumStage: MathCurriculumLevelID.m6.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func challenge(id: String, prompt: Prompt, choices: [Choice], problem: MathM6Problem) -> Challenge {
        Challenge(
            id: ChallengeID(rawValue: id), prompt: prompt, choices: choices, interaction: .singleChoice,
            validationRule: .numericEquivalence, expectedAnswer: .semanticValue(problem.answer),
            primarySkill: skill(for: problem), secondarySkills: secondarySkills(for: problem),
            curriculumStage: MathCurriculumLevelID.m6.curriculumStageID, difficulty: Self.difficulty
        )
    }

    private func skill(for problem: MathM6Problem) -> SkillID {
        switch problem.category {
        case .multiplication: return MathSkillIDs.multiplication
        case .division: return MathSkillIDs.division
        case .factor: return MathSkillIDs.factors
        case .multiple: return MathSkillIDs.multiples
        case .fraction: return MathSkillIDs.simpleFractions
        }
    }

    private func secondarySkills(for problem: MathM6Problem) -> Set<SkillID> {
        problem.category == .fraction ? [] : [MathSkillIDs.equalGroups]
    }

    private func promptRepresentation(_ problem: MathM6Problem) -> Representation {
        switch problem.kind {
        case .multiplication(let left, let right): return arithmetic(left, .multiplication, right, problem.id)
        case .division(let dividend, let divisor): return arithmetic(dividend, .division, divisor, problem.id)
        case .factor(let product, let known):
            return .math(.missingValueExpression(MathMissingValueRepresentation(
                left: .integer(known), operation: .multiplication, right: nil,
                result: .integer(product), missingPosition: .rightOperand,
                structureID: .init(rawValue: "math.m6.factor.\(problem.id)")
            )!))
        case .multiple(let factor, let index): return arithmetic(factor, .multiplication, index, problem.id)
        case .fraction(let value): return fraction(value, id: problem.id)
        }
    }

    private func answerRepresentation(_ problem: MathM6Problem) -> Representation {
        switch problem.answer {
        case .integer(let value):
            return .math(.numeral(MathNumeralRepresentation(value: value, structureID: .init(rawValue: "math.m6.numeral.\(problem.id)"))))
        case .rational(let value): return fraction(value, id: "answer.\(problem.id)")
        case .contentItem: preconditionFailure("M6 answers are numeric.")
        }
    }

    private func arithmetic(_ left: Int, _ operation: MathOperation, _ right: Int, _ id: String) -> Representation {
        .math(.arithmeticExpression(MathArithmeticRepresentation(
            left: .integer(left), operation: operation, right: .integer(right),
            structureID: .init(rawValue: "math.m6.expression.\(id)")
        )))
    }

    private func fraction(_ value: Rational, id: String) -> Representation {
        .math(.fraction(MathFractionRepresentation(value: value, structureID: .init(rawValue: "math.m6.fraction.\(id)"))))
    }

    private func token(_ value: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(expression: value, structureID: .init(rawValue: id)))
    }

    private func nearbyText(for problem: MathM6Problem) -> String {
        if let value = problem.integerAnswer { return String(value == 100 ? 90 : value + 1) }
        return problem.answerText == "1/2" ? "1/4" : "1/2"
    }
}
