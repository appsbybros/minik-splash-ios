import Foundation

enum MathM9Form: CaseIterable, Hashable, Sendable {
    case signedNumberLine
    case orderOfOperations
    case power
    case ratio
    case equation
}

enum MathM9ChoiceDirection: Hashable, Sendable {
    case promptToAnswer
    case answerToRepresentation
}

struct MathM9Problem: Hashable, Sendable {
    let id: String
    let form: MathM9Form
    let answer: Rational
    let answerText: String
    let prompt: MathRepresentation
}

struct MathM9ContentProvider: Sendable {
    static let problems: [MathM9Problem] = [
        signedProblem("negative-four", value: -4),
        orderProblem("multiply-before-add", first: 2, firstOperation: .addition,
                     second: 3, secondOperation: .multiplication, third: 4, answer: 14),
        powerProblem("two-cubed", base: 2, exponent: 3, answer: 8),
        ratioProblem("two-to-three", first: 2, second: 3),
        equationProblem("plus-five", operation: .addition, operand: 5, result: 12, solution: 7),
        signedProblem("negative-seven", value: -7),
        orderProblem("divide-before-add", first: 18, firstOperation: .division,
                     second: 3, secondOperation: .addition, third: 2, answer: 8),
        powerProblem("three-squared", base: 3, exponent: 2, answer: 9),
        ratioProblem("three-to-five", first: 3, second: 5),
        equationProblem("times-three", operation: .multiplication, operand: 3, result: 18, solution: 6)
    ]

    private static let difficulty = Difficulty(0.93)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) {
        self.fitGate = fitGate
    }

    func balancedProblems(count: Int) -> [MathM9Problem] {
        guard count > 0 else { return [] }
        return (0..<count).map { Self.problems[$0 % Self.problems.count] }
    }

    func studyCards() -> [StudyCard] {
        Self.problems.compactMap { problem in
            let values = [representation(problem.prompt), answerRepresentation(problem)]
            guard fitGate.allows(values, for: .learn) else { return nil }
            return StudyCard(
                id: .init(rawValue: "m9.card.\(problem.id)"),
                representations: values,
                primarySkill: skill(for: problem), secondarySkills: [],
                curriculumStage: MathCurriculumLevelID.m9.curriculumStageID
            )
        }
    }

    func equivalenceSets(count: Int = 6) -> [EquivalenceSet] {
        Array(Self.problems.prefix(count)).compactMap { problem in
            let values = [representation(problem.prompt), answerRepresentation(problem)]
            guard fitGate.allows(values, for: .matching) else { return nil }
            return EquivalenceSet(semanticValue: .rational(problem.answer), representations: values)
        }
    }

    func choiceChallenge(problem preferred: MathM9Problem, direction: MathM9ChoiceDirection) -> Challenge? {
        guard let problem = fitted(preferred, mechanic: .choice),
              let candidates = answerCandidates(for: problem) else { return nil }
        let promptRepresentation = direction == .promptToAnswer
            ? representation(problem.prompt)
            : answerRepresentation(problem)
        guard let prompt = Prompt(representations: [promptRepresentation]) else { return nil }
        let id = "m9.choice.\(problem.id).\(UUID().uuidString)"
        let choices = candidates.enumerated().map { index, candidate in
            Choice(
                id: .init(rawValue: "\(id).choice.\(index)"),
                representation: direction == .promptToAnswer
                    ? answerRepresentation(candidate)
                    : representation(candidate.prompt),
                semanticValue: .rational(candidate.answer)
            )
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return Challenge(
            id: .init(rawValue: id), prompt: prompt, choices: choices,
            interaction: .singleChoice, validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.rational(problem.answer)),
            primarySkill: skill(for: problem), secondarySkills: [],
            curriculumStage: MathCurriculumLevelID.m9.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func buildNumberChallenge(problem preferred: MathM9Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return characterChallenge(
            id: "m9.build-number.\(UUID().uuidString)", problem: problem,
            text: problem.answerText, promptRepresentation: representation(problem.prompt)
        )
    }

    func buildMathChallenge(problem preferred: MathM9Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        let id = "m9.build-math.\(UUID().uuidString)"
        let pieces: [Representation]
        let promptRepresentation: Representation
        switch problem.prompt {
        case .oneStepEquation(let equation):
            pieces = [
                token("x", id: "\(id).x"),
                token(equation.operation.symbol, id: "\(id).operator"),
                token(String(equation.operand), id: "\(id).operand"),
                token("=", id: "\(id).equals"),
                token(String(equation.result), id: "\(id).result")
            ]
            promptRepresentation = numeral(equation.solution)
        case .numberLine:
            pieces = [answerRepresentation(problem), token("<", id: "\(id).less"), numeral(0)]
            promptRepresentation = representation(problem.prompt)
        default:
            pieces = [representation(problem.prompt), token("=", id: "\(id).equals"), answerRepresentation(problem)]
            promptRepresentation = representation(problem.prompt)
        }
        guard let prompt = Prompt(representations: [promptRepresentation]) else { return nil }
        var tokens = pieces.enumerated().map { index, piece in
            BuildToken(id: .init(rawValue: "\(id).expected.\(index)"), representation: piece)
        }
        let expected = tokens.map(\.id)
        tokens.append(BuildToken(id: .init(rawValue: "\(id).extra"),
                                 representation: token("≠", id: "\(id).extra.rep")))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: .init(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill(for: problem), secondarySkills: [],
            curriculumStage: MathCurriculumLevelID.m9.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func numberLineRound(problem preferred: MathM9Problem) -> MathNumberLinePlacementRound? {
        guard preferred.form == .signedNumberLine,
              preferred.answer.denominator == 1,
              fitGate.allows([representation(preferred.prompt)], for: .countConstruction) else { return nil }
        let problem = preferred
        let prompt = numeral(problem.answer.numerator)
        return MathNumberLinePlacementRound(
            id: .init(rawValue: "m9.number-line.\(UUID().uuidString)"),
            lowerBound: -10, upperBound: 10, target: problem.answer.numerator,
            prompt: prompt, spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m9, skillID: MathSkillIDs.signedNumbers
        )
    }

    func towerChallenge(problem preferred: MathM9Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return characterChallenge(
            id: "m9.tower.\(UUID().uuidString)", problem: problem,
            text: problem.answerText, promptRepresentation: representation(problem.prompt)
        )
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        let candidates = uniqueAnswerProblems(count: answerCount)
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool,
              candidates.count == answerCount else { return nil }
        let id = "m9.soccer.\(UUID().uuidString)"
        let balls = candidates.enumerated().map { index, problem in
            SoccerAnswerBall(
                id: .init(rawValue: "\(id).ball.\(index)"),
                representation: answerRepresentation(problem),
                semanticValue: .rational(problem.answer)
            )
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(candidates, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            guard let prompt = Prompt(representations: [representation(pair.0.prompt)]) else { return nil }
            let challenge = Challenge(
                id: .init(rawValue: "\(id).challenge.\(index)"), prompt: prompt,
                choices: [], interaction: .singleChoice, validationRule: .numericEquivalence,
                expectedAnswer: .semanticValue(.rational(pair.0.answer)),
                primarySkill: skill(for: pair.0), secondarySkills: [],
                curriculumStage: MathCurriculumLevelID.m9.curriculumStageID,
                difficulty: Self.difficulty
            )
            return SoccerChallengeTarget(challenge: challenge, intendedBallID: pair.1.id)
        }
        return targets.count == balls.count
            ? SoccerRound(id: .init(rawValue: "\(id).round"), answerBalls: balls, challengeTargets: targets)
            : nil
    }

    private func fitted(_ preferred: MathM9Problem, mechanic: MathPresentationMechanic) -> MathM9Problem? {
        let start = Self.problems.firstIndex(of: preferred) ?? 0
        var offset = 0
        let result = MathPresentationFitPolicy.resolvedCandidate(generate: {
            defer { offset += 1 }
            return Self.problems[(start + offset) % Self.problems.count]
        }, isReadable: { fitGate.allows([representation($0.prompt)], for: mechanic) })
        switch result {
        case .candidate(let problem), .compactFallback(let problem): return problem
        case .unavailable: return nil
        }
    }

    private func answerCandidates(for problem: MathM9Problem) -> [MathM9Problem]? {
        var result = [problem]
        for candidate in Self.problems where result.count < 4 {
            guard !result.contains(where: { $0.answer == candidate.answer }) else { continue }
            result.append(candidate)
        }
        return result.count == 4 ? result.shuffled() : nil
    }

    private func uniqueAnswerProblems(count: Int) -> [MathM9Problem] {
        var result: [MathM9Problem] = []
        for problem in Self.problems where result.count < count {
            if !result.contains(where: { $0.answer == problem.answer }) { result.append(problem) }
        }
        return result
    }

    private func characterChallenge(
        id: String,
        problem: MathM9Problem,
        text: String,
        promptRepresentation: Representation
    ) -> BuildChallenge? {
        var tokens = text.enumerated().map { index, character in
            BuildToken(id: .init(rawValue: "\(id).expected.\(index)"),
                       representation: token(String(character), id: "\(id).piece.\(index)"))
        }
        let expected = tokens.map(\.id)
        tokens.append(BuildToken(id: .init(rawValue: "\(id).extra"),
                                 representation: token("9", id: "\(id).extra.rep")))
        guard fitGate.allows(tokens.map(\.representation), for: .build),
              let prompt = Prompt(representations: [promptRepresentation]) else { return nil }
        return BuildChallenge(
            id: .init(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill(for: problem), secondarySkills: [],
            curriculumStage: MathCurriculumLevelID.m9.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func representation(_ value: MathRepresentation) -> Representation { .math(value) }

    private func answerRepresentation(_ problem: MathM9Problem) -> Representation {
        problem.answer.denominator == 1
            ? numeral(problem.answer.numerator)
            : .math(.fraction(MathFractionRepresentation(
                value: problem.answer,
                structureID: .init(rawValue: "math.m9.answer.fraction.\(problem.id)")
            )))
    }

    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(
            value: value,
            structureID: .init(rawValue: "math.m9.numeral.\(value)")
        )))
    }

    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(expression: text, structureID: .init(rawValue: id)))
    }

    private func skill(for problem: MathM9Problem) -> SkillID {
        switch problem.form {
        case .signedNumberLine: return MathSkillIDs.signedNumbers
        case .orderOfOperations: return MathSkillIDs.orderOfOperations
        case .power: return MathSkillIDs.powers
        case .ratio: return MathSkillIDs.ratios
        case .equation: return MathSkillIDs.equations
        }
    }

    private static func signedProblem(_ id: String, value: Int) -> MathM9Problem {
        let rational = Rational(numerator: value, denominator: 1)!
        return MathM9Problem(
            id: id, form: .signedNumberLine, answer: rational, answerText: String(value),
            prompt: .numberLine(MathNumberLineRepresentation(
                lowerBound: Rational(numerator: -10, denominator: 1)!,
                upperBound: Rational(numerator: 10, denominator: 1)!,
                position: rational, structureID: .init(rawValue: "math.m9.line.\(id)")
            ))
        )
    }

    private static func orderProblem(
        _ id: String,
        first: Int,
        firstOperation: MathOperation,
        second: Int,
        secondOperation: MathOperation,
        third: Int,
        answer: Int
    ) -> MathM9Problem {
        MathM9Problem(
            id: id, form: .orderOfOperations,
            answer: Rational(numerator: answer, denominator: 1)!, answerText: String(answer),
            prompt: .orderOfOperations(MathOrderOfOperationsRepresentation(
                first: first, firstOperation: firstOperation, second: second,
                secondOperation: secondOperation, third: third, exactValue: answer,
                structureID: .init(rawValue: "math.m9.order.\(id)")
            )!)
        )
    }

    private static func powerProblem(_ id: String, base: Int, exponent: Int, answer: Int) -> MathM9Problem {
        MathM9Problem(
            id: id, form: .power, answer: Rational(numerator: answer, denominator: 1)!,
            answerText: String(answer),
            prompt: .power(MathPowerRepresentation(
                base: base, exponent: exponent, exactValue: answer,
                structureID: .init(rawValue: "math.m9.power.\(id)")
            )!)
        )
    }

    private static func ratioProblem(_ id: String, first: Int, second: Int) -> MathM9Problem {
        let answer = Rational(numerator: first, denominator: second)!
        return MathM9Problem(
            id: id, form: .ratio, answer: answer, answerText: answer.displayText,
            prompt: .ratio(MathRatioRepresentation(
                first: first, second: second,
                structureID: .init(rawValue: "math.m9.ratio.\(id)")
            )!)
        )
    }

    private static func equationProblem(
        _ id: String,
        operation: MathOperation,
        operand: Int,
        result: Int,
        solution: Int
    ) -> MathM9Problem {
        MathM9Problem(
            id: id, form: .equation,
            answer: Rational(numerator: solution, denominator: 1)!, answerText: String(solution),
            prompt: .oneStepEquation(MathOneStepEquationRepresentation(
                operation: operation, operand: operand, result: result, solution: solution,
                structureID: .init(rawValue: "math.m9.equation.\(id)")
            )!)
        )
    }
}
