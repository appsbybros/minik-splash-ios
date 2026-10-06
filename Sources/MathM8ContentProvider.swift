import Foundation

enum MathM8Form: CaseIterable, Hashable, Sendable {
    case fraction
    case decimal
    case percent
    case ratio
    case percentBar
}

enum MathM8ChoiceDirection: Hashable, Sendable {
    case promptToAnswer
    case answerToRepresentation
}

struct MathM8Problem: Hashable, Sendable {
    let id: String
    let value: Rational
    let decimalText: String
    let percent: Int
    let ratioFirst: Int
    let ratioSecond: Int
    let form: MathM8Form
}

struct MathM8ContentProvider: Sendable {
    static let problems: [MathM8Problem] = [
        problem("half.fraction", 1, 2, "0.5", 50, .fraction),
        problem("quarter.decimal", 1, 4, "0.25", 25, .decimal),
        problem("three-quarters.percent", 3, 4, "0.75", 75, .percent),
        problem("fifth.ratio", 1, 5, "0.2", 20, .ratio),
        problem("two-fifths.bar", 2, 5, "0.4", 40, .percentBar),
        problem("three-fifths.fraction", 3, 5, "0.6", 60, .fraction),
        problem("tenth.decimal", 1, 10, "0.1", 10, .decimal),
        problem("three-tenths.percent", 3, 10, "0.3", 30, .percent),
        problem("four-fifths.ratio", 4, 5, "0.8", 80, .ratio),
        problem("nine-tenths.bar", 9, 10, "0.9", 90, .percentBar)
    ]

    private static let difficulty = Difficulty(0.9)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) {
        self.fitGate = fitGate
    }

    func balancedProblems(count: Int) -> [MathM8Problem] {
        guard count > 0 else { return [] }
        return (0..<count).map { Self.problems[$0 % Self.problems.count] }
    }

    func studyCards() -> [StudyCard] {
        balancedProblems(count: 10).compactMap { problem in
            let values = [promptRepresentation(problem), alternateRepresentation(problem), percent(problem)]
            guard fitGate.allows(values, for: .learn) else { return nil }
            return StudyCard(
                id: .init(rawValue: "m8.card.\(problem.id)"),
                representations: values,
                primarySkill: skill(for: problem),
                secondarySkills: secondarySkills(for: problem),
                curriculumStage: MathCurriculumLevelID.m8.curriculumStageID
            )
        }
    }

    func equivalenceSets(count: Int = 6) -> [EquivalenceSet] {
        Array(Self.problems.prefix(count)).compactMap { problem in
            let values = [promptRepresentation(problem), alternateRepresentation(problem)]
            guard fitGate.allows(values, for: .matching) else { return nil }
            return EquivalenceSet(semanticValue: .rational(problem.value), representations: values)
        }
    }

    func choiceChallenge(problem preferred: MathM8Problem, direction: MathM8ChoiceDirection) -> Challenge? {
        guard let problem = fitted(preferred, mechanic: .choice),
              let candidates = answerCandidates(for: problem) else { return nil }
        let promptRepresentation = direction == .promptToAnswer ? self.promptRepresentation(problem) : decimal(problem)
        guard let prompt = Prompt(representations: [promptRepresentation]) else { return nil }
        let id = "m8.choice.\(problem.id).\(UUID().uuidString)"
        let choices = candidates.enumerated().map { index, candidate in
            Choice(
                id: .init(rawValue: "\(id).choice.\(index)"),
                representation: direction == .promptToAnswer ? answerRepresentation(candidate) : self.promptRepresentation(candidate),
                semanticValue: .rational(candidate.value)
            )
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return Challenge(
            id: .init(rawValue: id), prompt: prompt, choices: choices,
            interaction: .singleChoice, validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.rational(problem.value)),
            primarySkill: skill(for: problem), secondarySkills: secondarySkills(for: problem),
            curriculumStage: MathCurriculumLevelID.m8.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func buildNumberChallenge(problem preferred: MathM8Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return characterChallenge(
            id: "m8.build-number.\(UUID().uuidString)",
            problem: problem,
            text: requestedAnswerText(problem),
            promptRepresentation: promptRepresentation(problem)
        )
    }

    func buildMathChallenge(problem preferred: MathM8Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build),
              let prompt = Prompt(representations: [promptRepresentation(problem)]) else { return nil }
        let id = "m8.build-math.\(UUID().uuidString)"
        let left = problem.form == .decimal ? decimal(problem) : fraction(problem)
        let right = problem.form == .ratio ? ratio(problem) : percent(problem)
        var tokens = [
            BuildToken(id: .init(rawValue: "\(id).expected.0"), representation: left),
            BuildToken(id: .init(rawValue: "\(id).expected.1"), representation: token("=", id: "\(id).equals")),
            BuildToken(id: .init(rawValue: "\(id).expected.2"), representation: right)
        ]
        let expected = tokens.map(\.id)
        tokens.append(BuildToken(
            id: .init(rawValue: "\(id).extra"),
            representation: token("≠", id: "\(id).not-equal")
        ))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: .init(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill(for: problem),
            secondarySkills: secondarySkills(for: problem),
            curriculumStage: MathCurriculumLevelID.m8.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func proportionRound(problem preferred: MathM8Problem) -> MathFractionConstructionRound? {
        guard let problem = fitted(preferred, mechanic: .countConstruction) else { return nil }
        let prompt = problem.form == .ratio ? ratio(problem) : percent(problem)
        return MathFractionConstructionRound(
            id: .init(rawValue: "m8.proportion.\(UUID().uuidString)"),
            target: problem.value, prompt: prompt,
            spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m8, skillID: skill(for: problem)
        )
    }

    func towerChallenge(problem preferred: MathM8Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return characterChallenge(
            id: "m8.tower.\(UUID().uuidString)",
            problem: problem,
            text: requestedAnswerText(problem),
            promptRepresentation: alternateRepresentation(problem)
        )
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        let candidates = Array(Self.problems.prefix(answerCount))
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool,
              candidates.count == answerCount else { return nil }
        let id = "m8.soccer.\(UUID().uuidString)"
        let balls = candidates.enumerated().map { index, problem in
            SoccerAnswerBall(
                id: .init(rawValue: "\(id).ball.\(index)"),
                representation: answerRepresentation(problem),
                semanticValue: .rational(problem.value)
            )
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(candidates, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            guard let prompt = Prompt(representations: [promptRepresentation(pair.0)]) else { return nil }
            let challenge = Challenge(
                id: .init(rawValue: "\(id).challenge.\(index)"), prompt: prompt,
                choices: [], interaction: .singleChoice, validationRule: .numericEquivalence,
                expectedAnswer: .semanticValue(.rational(pair.0.value)),
                primarySkill: skill(for: pair.0), secondarySkills: secondarySkills(for: pair.0),
                curriculumStage: MathCurriculumLevelID.m8.curriculumStageID,
                difficulty: Self.difficulty
            )
            return SoccerChallengeTarget(challenge: challenge, intendedBallID: pair.1.id)
        }
        return targets.count == balls.count
            ? SoccerRound(id: .init(rawValue: "\(id).round"), answerBalls: balls, challengeTargets: targets)
            : nil
    }

    private func fitted(_ preferred: MathM8Problem, mechanic: MathPresentationMechanic) -> MathM8Problem? {
        let start = Self.problems.firstIndex(of: preferred) ?? 0
        var offset = 0
        let result = MathPresentationFitPolicy.resolvedCandidate(generate: {
            defer { offset += 1 }
            return Self.problems[(start + offset) % Self.problems.count]
        }, isReadable: { fitGate.allows([promptRepresentation($0)], for: mechanic) })
        switch result {
        case .candidate(let problem), .compactFallback(let problem): return problem
        case .unavailable: return nil
        }
    }

    private func answerCandidates(for problem: MathM8Problem) -> [MathM8Problem]? {
        var result = [problem]
        for candidate in Self.problems where result.count < 4 && candidate.value != problem.value {
            result.append(candidate)
        }
        return result.count == 4 ? result.shuffled() : nil
    }

    private func promptRepresentation(_ problem: MathM8Problem) -> Representation {
        switch problem.form {
        case .fraction: return fraction(problem)
        case .decimal: return decimal(problem)
        case .percent, .percentBar: return percent(problem)
        case .ratio: return ratio(problem)
        }
    }

    private func alternateRepresentation(_ problem: MathM8Problem) -> Representation {
        switch problem.form {
        case .fraction, .ratio: return decimal(problem)
        case .decimal, .percentBar: return fraction(problem)
        case .percent: return ratio(problem)
        }
    }

    private func answerRepresentation(_ problem: MathM8Problem) -> Representation {
        switch problem.form {
        case .fraction, .ratio, .percentBar: return percent(problem)
        case .decimal, .percent: return fraction(problem)
        }
    }

    private func fraction(_ problem: MathM8Problem) -> Representation {
        .math(.fraction(MathFractionRepresentation(
            value: problem.value,
            structureID: .init(rawValue: "math.m8.fraction.\(problem.id)")
        )))
    }

    private func decimal(_ problem: MathM8Problem) -> Representation {
        .math(.decimal(MathDecimalRepresentation(
            displayText: problem.decimalText, exactValue: problem.value,
            structureID: .init(rawValue: "math.m8.decimal.\(problem.id)")
        )))
    }

    private func percent(_ problem: MathM8Problem) -> Representation {
        .math(.percent(MathPercentRepresentation(
            percentValue: Rational(numerator: problem.percent, denominator: 1)!,
            structureID: .init(rawValue: "math.m8.percent.\(problem.id)")
        )))
    }

    private func ratio(_ problem: MathM8Problem) -> Representation {
        .math(.ratio(MathRatioRepresentation(
            first: problem.ratioFirst, second: problem.ratioSecond,
            structureID: .init(rawValue: "math.m8.ratio.\(problem.id)")
        )!))
    }

    private func requestedAnswerText(_ problem: MathM8Problem) -> String {
        switch problem.form {
        case .fraction, .percentBar: return "\(problem.percent)%"
        case .decimal: return problem.value.displayText
        case .percent: return problem.decimalText
        case .ratio: return "\(problem.ratioFirst):\(problem.ratioSecond)"
        }
    }

    private func characterChallenge(
        id: String,
        problem: MathM8Problem,
        text: String,
        promptRepresentation: Representation
    ) -> BuildChallenge? {
        var tokens = text.enumerated().map { index, character in
            BuildToken(
                id: .init(rawValue: "\(id).expected.\(index)"),
                representation: token(String(character), id: "\(id).piece.\(index)")
            )
        }
        let expected = tokens.map(\.id)
        let extraCharacter = text.contains("9") ? "7" : "9"
        tokens.append(BuildToken(
            id: .init(rawValue: "\(id).extra"),
            representation: token(extraCharacter, id: "\(id).extra.rep")
        ))
        guard fitGate.allows(tokens.map(\.representation), for: .build),
              let prompt = Prompt(representations: [promptRepresentation]) else { return nil }
        return BuildChallenge(
            id: .init(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill(for: problem),
            secondarySkills: secondarySkills(for: problem),
            curriculumStage: MathCurriculumLevelID.m8.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(
            expression: text,
            structureID: .init(rawValue: id)
        ))
    }

    private func skill(for problem: MathM8Problem) -> SkillID {
        problem.form == .ratio ? MathSkillIDs.ratios : MathSkillIDs.fractionDecimalPercent
    }

    private func secondarySkills(for problem: MathM8Problem) -> Set<SkillID> {
        problem.form == .ratio ? [MathSkillIDs.fractionDecimalPercent] : []
    }

    private static func problem(
        _ id: String,
        _ numerator: Int,
        _ denominator: Int,
        _ decimalText: String,
        _ percent: Int,
        _ form: MathM8Form
    ) -> MathM8Problem {
        MathM8Problem(
            id: id,
            value: Rational(numerator: numerator, denominator: denominator)!,
            decimalText: decimalText,
            percent: percent,
            ratioFirst: numerator,
            ratioSecond: denominator,
            form: form
        )
    }
}
