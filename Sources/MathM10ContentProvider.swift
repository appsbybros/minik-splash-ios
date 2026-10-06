import Foundation

enum MathM10Form: CaseIterable, Hashable, Sendable {
    case equation
    case linearRelationship
    case proportion
    case probability
    case geometry
}

enum MathM10ChoiceDirection: Hashable, Sendable {
    case promptToAnswer
    case answerToRepresentation
}

struct MathM10Problem: Hashable, Sendable {
    let id: String
    let form: MathM10Form
    let answer: Rational
    let prompt: MathRepresentation
}

struct MathM10ContentProvider: Sendable {
    static let problems: [MathM10Problem] = [
        equation("three-x-plus-two", multiplier: 3, offset: 2, result: 20, solution: 6),
        linear("double-plus-three", input: 4, multiplier: 2, offset: 3, output: 11),
        proportion("three-fourths", leftNumerator: 3, leftDenominator: 4, rightNumerator: 6, solution: 8),
        probability("two-of-five", favorable: 2, total: 5),
        geometry("rectangle-area", measure: .rectangleArea, width: 4, height: 3, answer: 12),
        equation("two-x-minus-four", multiplier: 2, offset: -4, result: 10, solution: 7),
        linear("triple-minus-two", input: 5, multiplier: 3, offset: -2, output: 13),
        proportion("three-fifths", leftNumerator: 3, leftDenominator: 5, rightNumerator: 6, solution: 10),
        probability("three-of-four", favorable: 3, total: 4),
        geometry("rectangle-perimeter", measure: .rectanglePerimeter, width: 5, height: 2, answer: 14)
    ]

    private static let difficulty = Difficulty(0.98)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) { self.fitGate = fitGate }

    func balancedProblems(count: Int) -> [MathM10Problem] {
        guard count > 0 else { return [] }
        return (0..<count).map { Self.problems[$0 % Self.problems.count] }
    }

    func studyCards() -> [StudyCard] {
        Self.problems.compactMap { problem in
            let values = [representation(problem.prompt), answerRepresentation(problem)]
            guard fitGate.allows(values, for: .learn) else { return nil }
            return StudyCard(
                id: .init(rawValue: "m10.card.\(problem.id)"), representations: values,
                primarySkill: skill(for: problem), secondarySkills: [],
                curriculumStage: MathCurriculumLevelID.m10.curriculumStageID
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

    func choiceChallenge(problem preferred: MathM10Problem, direction: MathM10ChoiceDirection) -> Challenge? {
        guard let problem = fitted(preferred, mechanic: .choice),
              let candidates = answerCandidates(for: problem) else { return nil }
        let promptValue = direction == .promptToAnswer
            ? representation(problem.prompt) : answerRepresentation(problem)
        guard let prompt = Prompt(representations: [promptValue]) else { return nil }
        let id = "m10.choice.\(problem.id).\(UUID().uuidString)"
        let choices = candidates.enumerated().map { index, candidate in
            Choice(
                id: .init(rawValue: "\(id).choice.\(index)"),
                representation: direction == .promptToAnswer
                    ? answerRepresentation(candidate) : representation(candidate.prompt),
                semanticValue: .rational(candidate.answer)
            )
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return Challenge(
            id: .init(rawValue: id), prompt: prompt, choices: choices,
            interaction: .singleChoice, validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.rational(problem.answer)),
            primarySkill: skill(for: problem), secondarySkills: [],
            curriculumStage: MathCurriculumLevelID.m10.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func buildNumberChallenge(problem preferred: MathM10Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return characterChallenge(
            id: "m10.build-number.\(UUID().uuidString)", problem: problem,
            text: problem.answer.displayText, promptRepresentation: representation(problem.prompt)
        )
    }

    func buildMathChallenge(problem preferred: MathM10Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        let id = "m10.build-math.\(UUID().uuidString)"
        let pieces: [Representation]
        switch problem.prompt {
        case .twoStepEquation(let equation):
            let offsetToken = equation.offset < 0 ? "−\(equation.offset.magnitude)" : "+\(equation.offset)"
            pieces = [token(String(equation.multiplier), id: "\(id).multiplier"),
                      token("x", id: "\(id).x"), token(offsetToken, id: "\(id).offset"),
                      token("=", id: "\(id).equals"), token(String(equation.result), id: "\(id).result")]
        case .proportion(let value):
            pieces = [token(String(value.leftNumerator), id: "\(id).ln"), token("/", id: "\(id).ls"),
                      token(String(value.leftDenominator), id: "\(id).ld"), token("=", id: "\(id).equals"),
                      token(String(value.rightNumerator), id: "\(id).rn"), token("/", id: "\(id).rs"),
                      token(String(value.missingDenominator), id: "\(id).rd")]
        default:
            pieces = [representation(problem.prompt), token("=", id: "\(id).equals"), answerRepresentation(problem)]
        }
        guard let prompt = Prompt(representations: [answerRepresentation(problem)]) else { return nil }
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
            curriculumStage: MathCurriculumLevelID.m10.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func probabilityRound(problem preferred: MathM10Problem) -> MathFractionConstructionRound? {
        guard preferred.form == .probability,
              fitGate.allows([representation(preferred.prompt)], for: .countConstruction),
              case .probability(let probability) = preferred.prompt else { return nil }
        let prompt = representation(preferred.prompt)
        return MathFractionConstructionRound(
            id: .init(rawValue: "m10.probability.\(UUID().uuidString)"),
            target: probability.exactValue, prompt: prompt,
            spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m10, skillID: MathSkillIDs.probability
        )
    }

    func towerChallenge(problem preferred: MathM10Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return characterChallenge(
            id: "m10.tower.\(UUID().uuidString)", problem: problem,
            text: problem.answer.displayText, promptRepresentation: representation(problem.prompt)
        )
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        let candidates = uniqueAnswerProblems(count: answerCount)
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool,
              candidates.count == answerCount else { return nil }
        let id = "m10.soccer.\(UUID().uuidString)"
        let balls = candidates.enumerated().map { index, problem in
            SoccerAnswerBall(id: .init(rawValue: "\(id).ball.\(index)"),
                             representation: answerRepresentation(problem),
                             semanticValue: .rational(problem.answer))
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(candidates, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            guard let prompt = Prompt(representations: [representation(pair.0.prompt)]) else { return nil }
            let challenge = Challenge(
                id: .init(rawValue: "\(id).challenge.\(index)"), prompt: prompt,
                choices: [], interaction: .singleChoice, validationRule: .numericEquivalence,
                expectedAnswer: .semanticValue(.rational(pair.0.answer)),
                primarySkill: skill(for: pair.0), secondarySkills: [],
                curriculumStage: MathCurriculumLevelID.m10.curriculumStageID,
                difficulty: Self.difficulty
            )
            return SoccerChallengeTarget(challenge: challenge, intendedBallID: pair.1.id)
        }
        return targets.count == balls.count
            ? SoccerRound(id: .init(rawValue: "\(id).round"), answerBalls: balls, challengeTargets: targets)
            : nil
    }

    private func fitted(_ preferred: MathM10Problem, mechanic: MathPresentationMechanic) -> MathM10Problem? {
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

    private func answerCandidates(for problem: MathM10Problem) -> [MathM10Problem]? {
        var result = [problem]
        for candidate in Self.problems where result.count < 4 {
            if !result.contains(where: { $0.answer == candidate.answer }) { result.append(candidate) }
        }
        return result.count == 4 ? result.shuffled() : nil
    }

    private func uniqueAnswerProblems(count: Int) -> [MathM10Problem] {
        var result: [MathM10Problem] = []
        for problem in Self.problems where result.count < count {
            if !result.contains(where: { $0.answer == problem.answer }) { result.append(problem) }
        }
        return result
    }

    private func characterChallenge(id: String, problem: MathM10Problem, text: String,
                                    promptRepresentation: Representation) -> BuildChallenge? {
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
            curriculumStage: MathCurriculumLevelID.m10.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func representation(_ value: MathRepresentation) -> Representation { .math(value) }
    private func answerRepresentation(_ problem: MathM10Problem) -> Representation {
        problem.answer.denominator == 1
            ? numeral(problem.answer.numerator)
            : .math(.fraction(MathFractionRepresentation(
                value: problem.answer, structureID: .init(rawValue: "math.m10.answer.\(problem.id)"))))
    }
    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(value: value,
                                                 structureID: .init(rawValue: "math.m10.numeral.\(value)"))))
    }
    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(expression: text, structureID: .init(rawValue: id)))
    }
    private func skill(for problem: MathM10Problem) -> SkillID {
        switch problem.form {
        case .equation: return MathSkillIDs.equations
        case .linearRelationship: return MathSkillIDs.linearRelationships
        case .proportion: return MathSkillIDs.proportionalReasoning
        case .probability: return MathSkillIDs.probability
        case .geometry: return MathSkillIDs.geometry
        }
    }

    private static func equation(_ id: String, multiplier: Int, offset: Int,
                                 result: Int, solution: Int) -> MathM10Problem {
        MathM10Problem(id: id, form: .equation, answer: Rational(numerator: solution, denominator: 1)!,
                       prompt: .twoStepEquation(MathTwoStepEquationRepresentation(
                        multiplier: multiplier, offset: offset, result: result, solution: solution,
                        structureID: .init(rawValue: "math.m10.equation.\(id)"))!))
    }
    private static func linear(_ id: String, input: Int, multiplier: Int,
                               offset: Int, output: Int) -> MathM10Problem {
        MathM10Problem(id: id, form: .linearRelationship,
                       answer: Rational(numerator: output, denominator: 1)!,
                       prompt: .linearRelationship(MathLinearRelationshipRepresentation(
                        input: input, multiplier: multiplier, offset: offset, output: output,
                        structureID: .init(rawValue: "math.m10.linear.\(id)"))!))
    }
    private static func proportion(_ id: String, leftNumerator: Int, leftDenominator: Int,
                                   rightNumerator: Int, solution: Int) -> MathM10Problem {
        MathM10Problem(id: id, form: .proportion,
                       answer: Rational(numerator: solution, denominator: 1)!,
                       prompt: .proportion(MathProportionRepresentation(
                        leftNumerator: leftNumerator, leftDenominator: leftDenominator,
                        rightNumerator: rightNumerator, missingDenominator: solution,
                        structureID: .init(rawValue: "math.m10.proportion.\(id)"))!))
    }
    private static func probability(_ id: String, favorable: Int, total: Int) -> MathM10Problem {
        let representation = MathProbabilityRepresentation(
            favorableCount: favorable, totalCount: total,
            structureID: .init(rawValue: "math.m10.probability.\(id)"))!
        return MathM10Problem(id: id, form: .probability, answer: representation.exactValue,
                              prompt: .probability(representation))
    }
    private static func geometry(_ id: String, measure: MathGeometryMeasure,
                                 width: Int, height: Int, answer: Int) -> MathM10Problem {
        MathM10Problem(id: id, form: .geometry, answer: Rational(numerator: answer, denominator: 1)!,
                       prompt: .geometry(MathGeometryRepresentation(
                        measure: measure, width: width, height: height, exactValue: answer,
                        structureID: .init(rawValue: "math.m10.geometry.\(id)"))!))
    }
}
