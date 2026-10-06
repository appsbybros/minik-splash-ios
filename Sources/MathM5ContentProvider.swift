import Foundation

enum MathM5Operation: CaseIterable, Hashable, Sendable {
    case multiplication
    case division
}

enum MathM5ChoiceDirection: Hashable, Sendable {
    case promptToAnswer
    case answerToRepresentation
}

enum MathM5MistakeStrategy: CaseIterable, Hashable, Sendable {
    case addInsteadOfMultiply
    case nearbyFact
    case swappedDivisionTerms
    case nearbyAnswer
}

struct MathM5GenerationPolicy: Hashable, Sendable {
    static let production = MathM5GenerationPolicy(
        factFamilies: [1, 2, 3, 4, 5, 10],
        multiplicationWeight: 3,
        divisionWeight: 2
    )!

    let factFamilies: [Int]
    let multiplicationWeight: Int
    let divisionWeight: Int

    init?(factFamilies: [Int], multiplicationWeight: Int, divisionWeight: Int) {
        guard !factFamilies.isEmpty,
              factFamilies.allSatisfy({ $0 > 0 }),
              Set(factFamilies).count == factFamilies.count,
              multiplicationWeight > 0,
              divisionWeight > 0 else { return nil }
        self.factFamilies = factFamilies
        self.multiplicationWeight = multiplicationWeight
        self.divisionWeight = divisionWeight
    }
}

struct MathM5Problem: Hashable, Sendable {
    let id: String
    let operation: MathM5Operation
    let left: Int
    let right: Int
    let answer: Int
    let groupCount: Int
    let itemsPerGroup: Int

    init?(id: String, operation: MathM5Operation, left: Int, right: Int, answer: Int) {
        guard !id.isEmpty, left > 0, right > 0, answer > 0 else { return nil }
        switch operation {
        case .multiplication:
            guard left * right == answer else { return nil }
            groupCount = left
            itemsPerGroup = right
        case .division:
            guard left % right == 0, left / right == answer else { return nil }
            groupCount = right
            itemsPerGroup = answer
        }
        self.id = id
        self.operation = operation
        self.left = left
        self.right = right
        self.answer = answer
    }
}

struct MathM5ContentProvider: Sendable {
    static let policy = MathM5GenerationPolicy.production
    static let mistakeStrategies = MathM5MistakeStrategy.allCases
    static let problems: [MathM5Problem] = [
        MathM5Problem(id: "multiply.1.5", operation: .multiplication, left: 1, right: 5, answer: 5)!,
        MathM5Problem(id: "multiply.2.3", operation: .multiplication, left: 2, right: 3, answer: 6)!,
        MathM5Problem(id: "multiply.3.4", operation: .multiplication, left: 3, right: 4, answer: 12)!,
        MathM5Problem(id: "multiply.4.5", operation: .multiplication, left: 4, right: 5, answer: 20)!,
        MathM5Problem(id: "multiply.5.5", operation: .multiplication, left: 5, right: 5, answer: 25)!,
        MathM5Problem(id: "multiply.3.10", operation: .multiplication, left: 3, right: 10, answer: 30)!,
        MathM5Problem(id: "multiply.5.10", operation: .multiplication, left: 5, right: 10, answer: 50)!,
        MathM5Problem(id: "multiply.10.10", operation: .multiplication, left: 10, right: 10, answer: 100)!,
        MathM5Problem(id: "divide.8.2", operation: .division, left: 8, right: 2, answer: 4)!,
        MathM5Problem(id: "divide.15.3", operation: .division, left: 15, right: 3, answer: 5)!,
        MathM5Problem(id: "divide.20.4", operation: .division, left: 20, right: 4, answer: 5)!,
        MathM5Problem(id: "divide.30.5", operation: .division, left: 30, right: 5, answer: 6)!,
        MathM5Problem(id: "divide.50.10", operation: .division, left: 50, right: 10, answer: 5)!,
        MathM5Problem(id: "divide.10.1", operation: .division, left: 10, right: 1, answer: 10)!,
        MathM5Problem(id: "divide.100.10", operation: .division, left: 100, right: 10, answer: 10)!
    ]

    private static let difficulty = Difficulty(0.78)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) {
        self.fitGate = fitGate
    }

    func balancedProblems(count: Int) -> [MathM5Problem] {
        guard count > 0 else { return [] }
        let pattern = Array(repeating: MathM5Operation.multiplication, count: Self.policy.multiplicationWeight)
            + Array(repeating: MathM5Operation.division, count: Self.policy.divisionWeight)
        var offsets: [MathM5Operation: Int] = [.multiplication: 0, .division: 0]
        return (0..<count).compactMap { index in
            let operation = pattern[index % pattern.count]
            let candidates = Self.problems.filter { $0.operation == operation }
            let offset = offsets[operation, default: 0]
            offsets[operation] = offset + 1
            return candidates.isEmpty ? nil : candidates[offset % candidates.count]
        }
    }

    func studyCards() -> [StudyCard] {
        balancedProblems(count: 10).compactMap { problem in
            let representations: [Representation]
            switch problem.operation {
            case .multiplication:
                representations = [groups(problem), expression(problem), numeral(problem.answer)]
            case .division:
                representations = [groups(problem), expression(problem), numeral(problem.answer)]
            }
            guard fitGate.allows(representations, for: .learn) else { return nil }
            return StudyCard(
                id: StudyCardID(rawValue: "m5.card.\(problem.id)"),
                representations: representations,
                primarySkill: skill(for: problem),
                secondarySkills: [MathSkillIDs.equalGroups],
                curriculumStage: MathCurriculumLevelID.m5.curriculumStageID
            )
        }
    }

    func equivalenceSets(count: Int = 4) -> [EquivalenceSet] {
        balancedProblems(count: count).compactMap { problem in
            let related = problem.operation == .multiplication ? groups(problem) : expression(problem)
            let representations = [related, numeral(problem.answer)]
            guard fitGate.allows(representations, for: .matching) else { return nil }
            return EquivalenceSet(semanticValue: .integer(problem.answer), representations: representations)
        }
    }

    func choiceChallenge(problem preferred: MathM5Problem, direction: MathM5ChoiceDirection) -> Challenge? {
        guard let problem = fitted(preferred, mechanic: .choice),
              let values = answerValues(for: problem),
              let prompt = Prompt(representations: [
                direction == .promptToAnswer ? promptRepresentation(problem) : numeral(problem.answer)
              ]) else { return nil }
        let candidates = problems(forDistinctAnswers: values, preferred: problem)
        guard candidates.count == values.count else { return nil }
        let id = "m5.choice.\(problem.id).\(UUID().uuidString)"
        let choices = candidates.enumerated().map { index, candidate in
            Choice(
                id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                representation: direction == .promptToAnswer
                    ? numeral(candidate.answer)
                    : promptRepresentation(candidate),
                semanticValue: .integer(candidate.answer)
            )
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return challenge(id: id, prompt: prompt, choices: choices, problem: problem)
    }

    func buildNumberChallenge(problem preferred: MathM5Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return digitChallenge(id: "m5.build-number.\(problem.id).\(UUID().uuidString)", problem: problem)
    }

    func buildEquationChallenge(problem preferred: MathM5Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build),
              let prompt = Prompt(representations: [promptRepresentation(problem)]) else { return nil }
        let symbol = problem.operation == .multiplication
            ? MathOperation.multiplication.symbol
            : MathOperation.division.symbol
        let pieces = [String(problem.left), symbol, String(problem.right), "=", String(problem.answer)]
        return sequenceChallenge(
            id: "m5.build-math.\(problem.id).\(UUID().uuidString)",
            prompt: prompt,
            pieces: pieces,
            distractor: String(problem.answer + 1),
            skill: skill(for: problem)
        )
    }

    func structuredRound(problem preferred: MathM5Problem) -> MathStructuredConstructionRound? {
        let candidates = Self.problems.filter { $0.operation == .multiplication && $0.answer <= 50 }
        guard let problem = fitted(preferred, candidates: candidates, mechanic: .countConstruction) else { return nil }
        let correctUnit = MathStructuredConstructionUnit.equalGroup(itemsPerGroup: problem.itemsPerGroup)
        let distractorSize = problem.itemsPerGroup == 1 ? 2 : problem.itemsPerGroup - 1
        let distractorUnit = MathStructuredConstructionUnit.equalGroup(itemsPerGroup: distractorSize)
        let id = "m5.structured.\(problem.id).\(UUID().uuidString)"
        let correctTokens = (0..<(problem.groupCount + 1)).map {
            MathStructuredConstructionToken(id: .init(rawValue: "\(id).correct.\($0)"), unit: correctUnit)
        }
        let distractors = (0..<2).map {
            MathStructuredConstructionToken(id: .init(rawValue: "\(id).distractor.\($0)"), unit: distractorUnit)
        }
        let prompt = numeral(problem.answer)
        return MathStructuredConstructionRound(
            id: ChallengeID(rawValue: id),
            targetValue: problem.answer,
            expectedUnitCounts: [correctUnit: problem.groupCount],
            availableTokens: (correctTokens + distractors).shuffled(),
            prompt: prompt,
            spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m5,
            skillID: MathSkillIDs.equalGroups
        )
    }

    func countRound(problem preferred: MathM5Problem) -> MathCountRound? {
        let candidates = Self.problems.filter { $0.answer <= 20 }
        guard let problem = fitted(preferred, candidates: candidates, mechanic: .countConstruction) else { return nil }
        let id = "m5.count.\(problem.id).\(UUID().uuidString)"
        let prompt = promptRepresentation(problem)
        return MathCountRound(
            id: ChallengeID(rawValue: id), target: problem.answer,
            availableTokenIDs: (0..<(problem.answer + 3)).map { .init(rawValue: "\(id).token.\($0)") },
            prompt: prompt, spokenPrompt: prompt.accessibilityDescription,
            mathLevelID: .m5, skillID: skill(for: problem)
        )
    }

    func answerTokenTowerChallenge(problem preferred: MathM5Problem) -> BuildChallenge? {
        let candidates = Self.problems.filter { $0.answer > 20 }
        guard let problem = fitted(preferred, candidates: candidates, mechanic: .build) else { return nil }
        return digitChallenge(id: "m5.tower-token.\(problem.id).\(UUID().uuidString)", problem: problem)
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool else { return nil }
        let preferred = uniqueAnswerProblems().prefix(answerCount)
        guard preferred.count == answerCount else { return nil }
        let problems = preferred.compactMap { fitted($0, mechanic: .soccerPrompt) }
        guard problems.count == answerCount, Set(problems.map(\.answer)).count == answerCount else { return nil }
        let id = "m5.soccer.\(UUID().uuidString)"
        let balls = problems.enumerated().map { index, problem in
            SoccerAnswerBall(
                id: SoccerBallID(rawValue: "\(id).ball.\(index)"),
                representation: numeral(problem.answer), semanticValue: .integer(problem.answer)
            )
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
            ? SoccerRound(id: SoccerRoundID(rawValue: "\(id).round"), answerBalls: balls, challengeTargets: targets)
            : nil
    }

    private func fitted(
        _ preferred: MathM5Problem,
        candidates: [MathM5Problem]? = nil,
        mechanic: MathPresentationMechanic
    ) -> MathM5Problem? {
        let pool = candidates ?? Self.problems.filter { $0.operation == preferred.operation }
        guard !pool.isEmpty else { return nil }
        let start = pool.firstIndex(of: preferred) ?? 0
        var offset = 0
        let result = MathPresentationFitPolicy.resolvedCandidate(
            generate: { defer { offset += 1 }; return pool[(start + offset) % pool.count] },
            isReadable: { fitGate.allows([promptRepresentation($0)], for: mechanic) }
        )
        switch result {
        case .candidate(let problem), .compactFallback(let problem): return problem
        case .unavailable: return nil
        }
    }

    private func answerValues(for problem: MathM5Problem) -> [Int]? {
        var values = [problem.answer]
        let domain = Set(Self.problems.map(\.answer))
        for strategy in Self.mistakeStrategies {
            let candidates: [Int]
            switch strategy {
            case .addInsteadOfMultiply: candidates = [problem.left + problem.right]
            case .nearbyFact: candidates = [problem.answer - problem.right, problem.answer + problem.right]
            case .swappedDivisionTerms: candidates = [problem.right]
            case .nearbyAnswer: candidates = [problem.answer - 1, problem.answer + 1]
            }
            for candidate in candidates where domain.contains(candidate) && !values.contains(candidate) {
                values.append(candidate)
            }
        }
        for candidate in domain.sorted(by: { abs($0 - problem.answer) < abs($1 - problem.answer) })
        where values.count < 4 && !values.contains(candidate) { values.append(candidate) }
        return values.count >= 4 ? Array(values.prefix(4)).shuffled() : nil
    }

    private func problems(forDistinctAnswers values: [Int], preferred: MathM5Problem) -> [MathM5Problem] {
        values.compactMap { value in
            value == preferred.answer ? preferred : Self.problems.first { $0.answer == value }
        }
    }

    private func uniqueAnswerProblems() -> [MathM5Problem] {
        var seen = Set<Int>()
        return balancedProblems(count: Self.problems.count).filter { seen.insert($0.answer).inserted }
    }

    private func digitChallenge(id: String, problem: MathM5Problem) -> BuildChallenge? {
        guard let prompt = Prompt(representations: [promptRepresentation(problem)]) else { return nil }
        var tokens = String(problem.answer).enumerated().map { index, digit in
            BuildToken(id: .init(rawValue: "\(id).expected.\(index)"), representation: token(String(digit), id: "\(id).digit.\(index)"))
        }
        let expected = tokens.map(\.id)
        tokens += [1, 3].enumerated().map { index, offset in
            BuildToken(id: .init(rawValue: "\(id).distractor.\(index)"), representation: token(String((problem.answer + offset) % 10), id: "\(id).distractor-representation.\(index)"))
        }
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill(for: problem),
            secondarySkills: [MathSkillIDs.equalGroups], curriculumStage: MathCurriculumLevelID.m5.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func sequenceChallenge(id: String, prompt: Prompt, pieces: [String], distractor: String, skill: SkillID) -> BuildChallenge? {
        var tokens = pieces.enumerated().map { index, piece in
            BuildToken(id: .init(rawValue: "\(id).expected.\(index)"), representation: token(piece, id: "\(id).piece.\(index)"))
        }
        let expected = tokens.map(\.id)
        tokens.append(BuildToken(id: .init(rawValue: "\(id).distractor"), representation: token(distractor, id: "\(id).distractor-representation")))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id), prompt: prompt, availableTokens: tokens.shuffled(),
            expectedTokenSequence: expected, primarySkill: skill,
            secondarySkills: [MathSkillIDs.equalGroups], curriculumStage: MathCurriculumLevelID.m5.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func challenge(id: String, prompt: Prompt, choices: [Choice], problem: MathM5Problem) -> Challenge {
        Challenge(
            id: ChallengeID(rawValue: id), prompt: prompt, choices: choices, interaction: .singleChoice,
            validationRule: .numericEquivalence, expectedAnswer: .semanticValue(.integer(problem.answer)),
            primarySkill: skill(for: problem), secondarySkills: [MathSkillIDs.equalGroups],
            curriculumStage: MathCurriculumLevelID.m5.curriculumStageID, difficulty: Self.difficulty
        )
    }

    private func skill(for problem: MathM5Problem) -> SkillID {
        problem.operation == .multiplication ? MathSkillIDs.multiplication : MathSkillIDs.division
    }

    private func promptRepresentation(_ problem: MathM5Problem) -> Representation {
        problem.operation == .multiplication ? groups(problem) : expression(problem)
    }

    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(value: value, structureID: .init(rawValue: "math.m5.numeral.\(value)"))))
    }

    private func groups(_ problem: MathM5Problem) -> Representation {
        .math(.equalGroups(MathEqualGroupsRepresentation(
            groupCount: problem.groupCount, itemsPerGroup: problem.itemsPerGroup,
            structureID: .init(rawValue: "math.m5.groups.\(problem.groupCount).\(problem.itemsPerGroup)")
        )!))
    }

    private func expression(_ problem: MathM5Problem) -> Representation {
        .math(.arithmeticExpression(MathArithmeticRepresentation(
            left: .integer(problem.left),
            operation: problem.operation == .multiplication ? .multiplication : .division,
            right: .integer(problem.right), structureID: .init(rawValue: "math.m5.expression.\(problem.id)")
        )))
    }

    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(expression: text, structureID: .init(rawValue: id)))
    }
}
