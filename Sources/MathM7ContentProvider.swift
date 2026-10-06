import Foundation

enum MathM7Form: CaseIterable, Hashable, Sendable { case fraction, decimal, fractionBar, numberLine, comparison }
enum MathM7ChoiceDirection: Hashable, Sendable { case promptToAnswer, answerToRepresentation }

struct MathM7Problem: Hashable, Sendable {
    let id: String
    let value: Rational
    let decimalText: String
    let form: MathM7Form
}

struct MathM7ContentProvider: Sendable {
    static let problems: [MathM7Problem] = [
        .init(id: "half.fraction", value: Rational(numerator: 1, denominator: 2)!, decimalText: "0.5", form: .fraction),
        .init(id: "half.decimal", value: Rational(numerator: 1, denominator: 2)!, decimalText: "0.5", form: .decimal),
        .init(id: "three-tenths.bar", value: Rational(numerator: 3, denominator: 10)!, decimalText: "0.3", form: .fractionBar),
        .init(id: "four-tenths.line", value: Rational(numerator: 4, denominator: 10)!, decimalText: "0.4", form: .numberLine),
        .init(id: "seven-tenths.compare", value: Rational(numerator: 7, denominator: 10)!, decimalText: "0.7", form: .comparison),
        .init(id: "quarter.fraction", value: Rational(numerator: 1, denominator: 4)!, decimalText: "0.25", form: .fraction),
        .init(id: "quarter.decimal", value: Rational(numerator: 1, denominator: 4)!, decimalText: "0.25", form: .decimal),
        .init(id: "three-quarters.bar", value: Rational(numerator: 3, denominator: 4)!, decimalText: "0.75", form: .fractionBar),
        .init(id: "six-tenths.line", value: Rational(numerator: 6, denominator: 10)!, decimalText: "0.6", form: .numberLine),
        .init(id: "nine-tenths.compare", value: Rational(numerator: 9, denominator: 10)!, decimalText: "0.9", form: .comparison),
        .init(id: "twelve-hundredths", value: Rational(numerator: 12, denominator: 100)!, decimalText: "0.12", form: .decimal),
        .init(id: "sixty-five-hundredths", value: Rational(numerator: 65, denominator: 100)!, decimalText: "0.65", form: .numberLine)
    ]

    private static let difficulty = Difficulty(0.86)!
    private let fitGate: MathContentFitGate
    init(fitGate: MathContentFitGate = .production) { self.fitGate = fitGate }

    func balancedProblems(count: Int) -> [MathM7Problem] {
        guard count > 0 else { return [] }
        return (0..<count).map { Self.problems[$0 % Self.problems.count] }
    }

    func studyCards() -> [StudyCard] {
        balancedProblems(count: 10).compactMap { problem in
            let values = [promptRepresentation(problem), alternateRepresentation(problem)]
            guard fitGate.allows(values, for: .learn) else { return nil }
            return StudyCard(id: .init(rawValue: "m7.card.\(problem.id)"), representations: values,
                             primarySkill: skill(for: problem), secondarySkills: [],
                             curriculumStage: MathCurriculumLevelID.m7.curriculumStageID)
        }
    }

    func equivalenceSets(count: Int = 6) -> [EquivalenceSet] {
        Array(uniqueValues().prefix(count)).compactMap { problem in
            let values = [promptRepresentation(problem), alternateRepresentation(problem)]
            guard fitGate.allows(values, for: .matching) else { return nil }
            return EquivalenceSet(semanticValue: .rational(problem.value), representations: values)
        }
    }

    func choiceChallenge(problem preferred: MathM7Problem, direction: MathM7ChoiceDirection) -> Challenge? {
        guard let problem = fitted(preferred, mechanic: .choice),
              let candidates = answerCandidates(for: problem),
              let prompt = Prompt(representations: [direction == .promptToAnswer ? promptRepresentation(problem) : decimal(problem)]) else { return nil }
        let id = "m7.choice.\(problem.id).\(UUID().uuidString)"
        let choices = candidates.enumerated().map { index, candidate in
            Choice(id: .init(rawValue: "\(id).choice.\(index)"),
                   representation: direction == .promptToAnswer ? decimal(candidate) : promptRepresentation(candidate),
                   semanticValue: .rational(candidate.value))
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return Challenge(id: .init(rawValue: id), prompt: prompt, choices: choices, interaction: .singleChoice,
                         validationRule: .numericEquivalence, expectedAnswer: .semanticValue(.rational(problem.value)),
                         primarySkill: skill(for: problem), secondarySkills: [],
                         curriculumStage: MathCurriculumLevelID.m7.curriculumStageID, difficulty: Self.difficulty)
    }

    func buildNumberChallenge(problem preferred: MathM7Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return tokenChallenge(id: "m7.build-number.\(UUID().uuidString)", problem: problem, text: problem.decimalText)
    }

    func buildMathChallenge(problem preferred: MathM7Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build),
              let prompt = Prompt(representations: [fraction(problem)]) else { return nil }
        let id = "m7.build-math.\(UUID().uuidString)"
        var tokens = [
            BuildToken(id: .init(rawValue: "\(id).expected.0"), representation: fraction(problem)),
            BuildToken(id: .init(rawValue: "\(id).expected.1"), representation: token("=", id: "\(id).piece.1")),
            BuildToken(id: .init(rawValue: "\(id).expected.2"), representation: decimal(problem))
        ]
        let expected = tokens.map(\.id)
        tokens.append(BuildToken(id: .init(rawValue: "\(id).extra"), representation: token(nearbyText(problem), id: "\(id).extra.rep")))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(id: .init(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(), expectedTokenSequence: expected,
                              primarySkill: skill(for: problem), secondarySkills: [], curriculumStage: MathCurriculumLevelID.m7.curriculumStageID,
                              difficulty: Self.difficulty)
    }

    func fractionRound(problem preferred: MathM7Problem) -> MathFractionConstructionRound? {
        guard let problem = fitted(preferred, candidates: Self.problems.filter { $0.value.denominator <= 10 }, mechanic: .countConstruction) else { return nil }
        let prompt = decimal(problem)
        return MathFractionConstructionRound(id: .init(rawValue: "m7.fraction-build.\(UUID().uuidString)"),
            target: problem.value, prompt: prompt, spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m7, skillID: MathSkillIDs.decimalFractions)
    }

    func towerChallenge(problem preferred: MathM7Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return tokenChallenge(id: "m7.tower.\(UUID().uuidString)", problem: problem, text: problem.decimalText)
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        let candidates = uniqueValues().prefix(answerCount)
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool, candidates.count == answerCount else { return nil }
        let id = "m7.soccer.\(UUID().uuidString)"
        let balls = candidates.enumerated().map { index, problem in
            SoccerAnswerBall(id: .init(rawValue: "\(id).ball.\(index)"), representation: decimal(problem), semanticValue: .rational(problem.value))
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(candidates, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            guard let prompt = Prompt(representations: [promptRepresentation(pair.0)]) else { return nil }
            let challenge = Challenge(id: .init(rawValue: "\(id).challenge.\(index)"), prompt: prompt, choices: [], interaction: .singleChoice,
                validationRule: .numericEquivalence, expectedAnswer: .semanticValue(.rational(pair.0.value)),
                primarySkill: skill(for: pair.0), secondarySkills: [], curriculumStage: MathCurriculumLevelID.m7.curriculumStageID,
                difficulty: Self.difficulty)
            return SoccerChallengeTarget(challenge: challenge, intendedBallID: pair.1.id)
        }
        return targets.count == balls.count ? SoccerRound(id: .init(rawValue: "\(id).round"), answerBalls: balls, challengeTargets: targets) : nil
    }

    private func fitted(_ preferred: MathM7Problem, candidates: [MathM7Problem]? = nil, mechanic: MathPresentationMechanic) -> MathM7Problem? {
        let pool = candidates ?? Self.problems
        guard !pool.isEmpty else { return nil }
        let start = pool.firstIndex(of: preferred) ?? 0
        var offset = 0
        let result = MathPresentationFitPolicy.resolvedCandidate(generate: {
            defer { offset += 1 }; return pool[(start + offset) % pool.count]
        }, isReadable: { fitGate.allows([promptRepresentation($0)], for: mechanic) })
        switch result { case .candidate(let value), .compactFallback(let value): return value; case .unavailable: return nil }
    }

    private func answerCandidates(for problem: MathM7Problem) -> [MathM7Problem]? {
        var result = [problem]
        let nearby = Self.problems.sorted { distance($0.value, problem.value) < distance($1.value, problem.value) }
        for candidate in nearby where result.count < 4 {
            guard !result.contains(where: { $0.value == candidate.value }) else { continue }
            result.append(candidate)
        }
        return result.count == 4 ? result.shuffled() : nil
    }

    private func distance(_ first: Rational, _ second: Rational) -> Int {
        abs(first.numerator * second.denominator - second.numerator * first.denominator)
    }

    private func uniqueValues() -> [MathM7Problem] {
        var result: [MathM7Problem] = []
        for problem in Self.problems where !result.contains(where: { $0.value == problem.value }) { result.append(problem) }
        return result
    }

    private func promptRepresentation(_ problem: MathM7Problem) -> Representation {
        switch problem.form {
        case .fraction: return fraction(problem)
        case .decimal: return decimal(problem)
        case .fractionBar: return fraction(problem)
        case .numberLine: return numberLine(problem)
        case .comparison:
            let neighbor = Rational(numerator: max(0, problem.value.numerator - 1), denominator: problem.value.denominator)!
            return .math(.comparison(MathComparisonRepresentation(left: .rational(neighbor), relation: .lessThan,
                right: .rational(problem.value), structureID: .init(rawValue: "math.m7.compare.\(problem.id)"))))
        }
    }

    private func alternateRepresentation(_ problem: MathM7Problem) -> Representation {
        problem.form == .numberLine ? fraction(problem) : decimal(problem)
    }

    private func fraction(_ problem: MathM7Problem) -> Representation {
        .math(.fraction(MathFractionRepresentation(value: problem.value, structureID: .init(rawValue: "math.m7.fraction.\(problem.id)"))))
    }

    private func decimal(_ problem: MathM7Problem) -> Representation {
        .math(.decimal(MathDecimalRepresentation(displayText: problem.decimalText, exactValue: problem.value,
                                                  structureID: .init(rawValue: "math.m7.decimal.\(problem.id)"))))
    }

    private func numberLine(_ problem: MathM7Problem) -> Representation {
        .math(.numberLine(MathNumberLineRepresentation(lowerBound: Rational(numerator: 0, denominator: 1)!,
            upperBound: Rational(numerator: 1, denominator: 1)!, position: problem.value,
            structureID: .init(rawValue: "math.m7.line.\(problem.id)"))))
    }

    private func tokenChallenge(id: String, problem: MathM7Problem, text: String) -> BuildChallenge? {
        var tokens = text.enumerated().map { index, character in
            BuildToken(id: .init(rawValue: "\(id).expected.\(index)"), representation: token(String(character), id: "\(id).piece.\(index)"))
        }
        let expected = tokens.map(\.id)
        tokens.append(BuildToken(id: .init(rawValue: "\(id).extra"), representation: token(nearbyText(problem), id: "\(id).extra.rep")))
        let sourcePrompt = problem.form == .decimal ? fraction(problem) : promptRepresentation(problem)
        guard fitGate.allows(tokens.map(\.representation), for: .build), let prompt = Prompt(representations: [sourcePrompt]) else { return nil }
        return BuildChallenge(id: .init(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(), expectedTokenSequence: expected,
                              primarySkill: skill(for: problem), secondarySkills: [], curriculumStage: MathCurriculumLevelID.m7.curriculumStageID,
                              difficulty: Self.difficulty)
    }

    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(expression: text, structureID: .init(rawValue: id)))
    }
    private func nearbyText(_ problem: MathM7Problem) -> String { problem.decimalText == "0.5" ? "0.6" : "0.5" }
    private func skill(for problem: MathM7Problem) -> SkillID {
        problem.form == .comparison ? MathSkillIDs.decimalMagnitude : MathSkillIDs.decimalFractions
    }
}
