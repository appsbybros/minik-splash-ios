import Foundation

enum MathM4ProblemCategory: CaseIterable, Hashable, Sendable {
    case placeValue
    case addition
    case subtraction
}

enum MathM4ChoiceDirection: Hashable, Sendable {
    case promptToAnswer
    case answerToRepresentation
}

enum MathM4MistakeStrategy: CaseIterable, Hashable, Sendable {
    case swappedTensAndOnes
    case offByTen
    case nearbyNumber
    case operationMistake
}

struct MathM4CategoryWeights: Hashable, Sendable {
    let placeValue: Int
    let addition: Int
    let subtraction: Int
}

struct MathM4Problem: Hashable, Sendable {
    let id: String
    let category: MathM4ProblemCategory
    let left: Int?
    let operation: MathOperation?
    let right: Int?
    let answer: Int

    init?(
        id: String,
        category: MathM4ProblemCategory,
        left: Int? = nil,
        operation: MathOperation? = nil,
        right: Int? = nil,
        answer: Int
    ) {
        guard !id.isEmpty, (0...100).contains(answer) else { return nil }
        switch category {
        case .placeValue:
            guard left == nil, operation == nil, right == nil else { return nil }
        case .addition:
            guard operation == .addition,
                  let left, let right,
                  left >= 0, right >= 0,
                  left + right == answer else { return nil }
        case .subtraction:
            guard operation == .subtraction,
                  let left, let right,
                  left >= right, right >= 0,
                  left - right == answer else { return nil }
        }
        self.id = id
        self.category = category
        self.left = left
        self.operation = operation
        self.right = right
        self.answer = answer
    }
}

struct MathM4ContentProvider: Sendable {
    static let categoryWeights = MathM4CategoryWeights(placeValue: 4, addition: 3, subtraction: 3)
    static let mistakeStrategies = MathM4MistakeStrategy.allCases
    static let problems: [MathM4Problem] = [
        MathM4Problem(id: "place.24", category: .placeValue, answer: 24)!,
        MathM4Problem(id: "place.35", category: .placeValue, answer: 35)!,
        MathM4Problem(id: "place.47", category: .placeValue, answer: 47)!,
        MathM4Problem(id: "place.63", category: .placeValue, answer: 63)!,
        MathM4Problem(id: "place.80", category: .placeValue, answer: 80)!,
        MathM4Problem(id: "place.100", category: .placeValue, answer: 100)!,
        MathM4Problem(id: "add.18.24", category: .addition, left: 18, operation: .addition, right: 24, answer: 42)!,
        MathM4Problem(id: "add.36.12", category: .addition, left: 36, operation: .addition, right: 12, answer: 48)!,
        MathM4Problem(id: "add.27.30", category: .addition, left: 27, operation: .addition, right: 30, answer: 57)!,
        MathM4Problem(id: "add.45.19", category: .addition, left: 45, operation: .addition, right: 19, answer: 64)!,
        MathM4Problem(id: "add.58.15", category: .addition, left: 58, operation: .addition, right: 15, answer: 73)!,
        MathM4Problem(id: "add.75.10", category: .addition, left: 75, operation: .addition, right: 10, answer: 85)!,
        MathM4Problem(id: "add.9.9", category: .addition, left: 9, operation: .addition, right: 9, answer: 18)!,
        MathM4Problem(id: "subtract.57.21", category: .subtraction, left: 57, operation: .subtraction, right: 21, answer: 36)!,
        MathM4Problem(id: "subtract.90.32", category: .subtraction, left: 90, operation: .subtraction, right: 32, answer: 58)!,
        MathM4Problem(id: "subtract.100.30", category: .subtraction, left: 100, operation: .subtraction, right: 30, answer: 70)!,
        MathM4Problem(id: "subtract.54.33", category: .subtraction, left: 54, operation: .subtraction, right: 33, answer: 21)!,
        MathM4Problem(id: "subtract.30.18", category: .subtraction, left: 30, operation: .subtraction, right: 18, answer: 12)!,
        MathM4Problem(id: "subtract.74.11", category: .subtraction, left: 74, operation: .subtraction, right: 11, answer: 63)!
    ]

    private static let difficulty = Difficulty(0.72)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) {
        self.fitGate = fitGate
    }

    func balancedProblems(count: Int) -> [MathM4Problem] {
        guard count > 0 else { return [] }
        let categories = interleavedCategories()
        var offsets = Dictionary(uniqueKeysWithValues: MathM4ProblemCategory.allCases.map { ($0, 0) })
        return (0..<count).compactMap { index in
            let category = categories[index % categories.count]
            let candidates = Self.problems.filter { $0.category == category }
            let offset = offsets[category, default: 0]
            offsets[category] = offset + 1
            return candidates.isEmpty ? nil : candidates[offset % candidates.count]
        }
    }

    func studyCards() -> [StudyCard] {
        var cards = balancedProblems(count: 8).compactMap { problem -> StudyCard? in
            let representations: [Representation]
            switch problem.category {
            case .placeValue:
                representations = [placeValue(problem.answer), expanded(problem.answer), numeral(problem.answer)]
            case .addition, .subtraction:
                representations = [promptRepresentation(problem), placeValue(problem.answer), numeral(problem.answer)]
            }
            guard fitGate.allows(representations, for: .learn) else { return nil }
            return StudyCard(
                id: StudyCardID(rawValue: "m4.card.\(problem.id)"),
                representations: representations,
                primarySkill: skill(for: problem),
                secondarySkills: [MathSkillIDs.placeValue],
                curriculumStage: MathCurriculumLevelID.m4.curriculumStageID
            )
        }
        let comparisons = [(24, 42), (63, 47)].compactMap { pair -> StudyCard? in
            let (left, right) = pair
            let representation = comparison(left: left, right: right)
            guard fitGate.allows([representation], for: .learn) else { return nil }
            return StudyCard(
                id: StudyCardID(rawValue: "m4.card.compare.\(left).\(right)"),
                representations: [representation],
                primarySkill: MathSkillIDs.magnitude,
                curriculumStage: MathCurriculumLevelID.m4.curriculumStageID
            )
        }
        cards.append(contentsOf: comparisons)
        return cards
    }

    func equivalenceSets(count: Int = 4) -> [EquivalenceSet] {
        balancedProblems(count: count).enumerated().compactMap { index, problem in
            let related = problem.category == .placeValue
                ? (index.isMultiple(of: 2) ? placeValue(problem.answer) : expanded(problem.answer))
                : promptRepresentation(problem)
            let representations = [numeral(problem.answer), related]
            guard fitGate.allows(representations, for: .matching) else { return nil }
            return EquivalenceSet(
                semanticValue: .integer(problem.answer),
                representations: representations
            )
        }
    }

    func choiceChallenge(
        problem preferred: MathM4Problem,
        direction: MathM4ChoiceDirection
    ) -> Challenge? {
        guard let problem = fitted(preferred, mechanic: .choice),
              let values = answerValues(for: problem) else { return nil }
        let id = "m4.choice.\(direction).\(problem.id).\(UUID().uuidString)"
        let promptRepresentationValue = direction == .promptToAnswer
            ? promptRepresentation(problem)
            : numeral(problem.answer)
        guard let prompt = Prompt(representations: [promptRepresentationValue]) else { return nil }

        let choices: [Choice]
        switch direction {
        case .promptToAnswer:
            choices = values.enumerated().map { index, value in
                Choice(
                    id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                    representation: numeral(value),
                    semanticValue: .integer(value)
                )
            }
        case .answerToRepresentation:
            let candidates = problems(forDistinctAnswers: values, preferred: problem)
            guard candidates.count == values.count else { return nil }
            choices = candidates.enumerated().map { index, candidate in
                Choice(
                    id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                    representation: candidate.category == .placeValue
                        ? placeValue(candidate.answer)
                        : promptRepresentation(candidate),
                    semanticValue: .integer(candidate.answer)
                )
            }
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return challenge(
            id: id,
            prompt: prompt,
            choices: choices,
            answer: problem.answer,
            problem: problem
        )
    }

    func buildNumberChallenge(problem preferred: MathM4Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build) else { return nil }
        return digitChallenge(
            id: "m4.build-number.\(problem.id).\(UUID().uuidString)",
            promptRepresentation: promptRepresentation(problem),
            answer: problem.answer,
            skill: skill(for: problem)
        )
    }

    func buildEquationChallenge(problem preferred: MathM4Problem) -> BuildChallenge? {
        guard let problem = fitted(preferred, mechanic: .build),
              let prompt = Prompt(representations: [promptRepresentation(problem)]) else { return nil }
        let id = "m4.build-equation.\(problem.id).\(UUID().uuidString)"
        let pieces: [String]
        if problem.category == .placeValue {
            let tens = (problem.answer / 10) * 10
            let ones = problem.answer % 10
            pieces = [String(problem.answer), "=", String(tens), "+", String(ones)]
        } else {
            pieces = [String(problem.left!), problem.operation!.symbol, String(problem.right!), "=", String(problem.answer)]
        }
        return tokenSequenceChallenge(
            id: id,
            prompt: prompt,
            pieces: pieces,
            distractor: String((problem.answer + 10) % 101),
            skill: skill(for: problem)
        )
    }

    func structuredRound(problem preferred: MathM4Problem) -> MathStructuredConstructionRound? {
        let candidates = Self.problems.filter { (10...99).contains($0.answer) }
        guard let problem = fitted(preferred, candidates: candidates, mechanic: .countConstruction) else { return nil }
        let tens = problem.answer / 10
        let ones = problem.answer % 10
        var expected: [MathStructuredConstructionUnit: Int] = [:]
        if tens > 0 { expected[.placeValue(10)] = tens }
        if ones > 0 { expected[.placeValue(1)] = ones }
        let id = "m4.structured.\(problem.id).\(UUID().uuidString)"
        var tokens: [MathStructuredConstructionToken] = []
        for index in 0..<(tens + 1) {
            tokens.append(.init(
                id: .init(rawValue: "\(id).ten.\(index)"),
                unit: .placeValue(10)
            ))
        }
        for index in 0..<(max(ones + 1, 2)) {
            tokens.append(.init(
                id: .init(rawValue: "\(id).one.\(index)"),
                unit: .placeValue(1)
            ))
        }
        let promptRepresentationValue = numeral(problem.answer)
        return MathStructuredConstructionRound(
            id: ChallengeID(rawValue: id),
            targetValue: problem.answer,
            expectedUnitCounts: expected,
            availableTokens: tokens.shuffled(),
            prompt: promptRepresentationValue,
            spokenPrompt: promptRepresentationValue.accessibilityDescription,
            mathLevelID: .m4,
            skillID: MathSkillIDs.placeValue
        )
    }

    func countRound(problem preferred: MathM4Problem) -> MathCountRound? {
        let candidates = Self.problems.filter { $0.answer <= 20 }
        guard let problem = fitted(preferred, candidates: candidates, mechanic: .countConstruction) else { return nil }
        let id = "m4.count.\(problem.id).\(UUID().uuidString)"
        let promptValue = promptRepresentation(problem)
        return MathCountRound(
            id: ChallengeID(rawValue: id),
            target: problem.answer,
            availableTokenIDs: (0..<(problem.answer + 3)).map {
                MathCountTokenID(rawValue: "\(id).token.\($0)")
            },
            prompt: promptValue,
            spokenPrompt: promptValue.accessibilityDescription,
            mathLevelID: .m4,
            skillID: skill(for: problem)
        )
    }

    func answerTokenTowerChallenge(problem preferred: MathM4Problem) -> BuildChallenge? {
        let candidates = Self.problems.filter { $0.answer > 20 }
        guard let problem = fitted(preferred, candidates: candidates, mechanic: .build) else { return nil }
        return digitChallenge(
            id: "m4.tower-token.\(problem.id).\(UUID().uuidString)",
            promptRepresentation: promptRepresentation(problem),
            answer: problem.answer,
            skill: skill(for: problem)
        )
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool else { return nil }
        let preferred = uniqueAnswerProblems().prefix(answerCount)
        guard preferred.count == answerCount else { return nil }
        let problems = preferred.compactMap { fitted($0, mechanic: .soccerPrompt) }
        guard problems.count == answerCount,
              Set(problems.map(\.answer)).count == answerCount else { return nil }
        let id = "m4.soccer.\(UUID().uuidString)"
        let balls = problems.enumerated().map { index, problem in
            SoccerAnswerBall(
                id: SoccerBallID(rawValue: "\(id).ball.\(index)"),
                representation: numeral(problem.answer),
                semanticValue: .integer(problem.answer)
            )
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(problems, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            let (problem, ball) = pair
            guard let prompt = Prompt(representations: [promptRepresentation(problem)]) else { return nil }
            return SoccerChallengeTarget(
                challenge: challenge(
                    id: "\(id).challenge.\(index)",
                    prompt: prompt,
                    choices: [],
                    answer: problem.answer,
                    problem: problem
                ),
                intendedBallID: ball.id
            )
        }
        guard targets.count == balls.count else { return nil }
        return SoccerRound(
            id: SoccerRoundID(rawValue: "\(id).round"),
            answerBalls: balls,
            challengeTargets: targets
        )
    }

    private func interleavedCategories() -> [MathM4ProblemCategory] {
        var remaining: [MathM4ProblemCategory: Int] = [
            .placeValue: Self.categoryWeights.placeValue,
            .addition: Self.categoryWeights.addition,
            .subtraction: Self.categoryWeights.subtraction
        ]
        var result: [MathM4ProblemCategory] = []
        while remaining.values.contains(where: { $0 > 0 }) {
            for category in MathM4ProblemCategory.allCases where remaining[category, default: 0] > 0 {
                result.append(category)
                remaining[category, default: 0] -= 1
            }
        }
        return result
    }

    private func fitted(
        _ preferred: MathM4Problem,
        candidates: [MathM4Problem]? = nil,
        mechanic: MathPresentationMechanic
    ) -> MathM4Problem? {
        let pool = candidates ?? Self.problems.filter { $0.category == preferred.category }
        guard !pool.isEmpty else { return nil }
        let start = pool.firstIndex(of: preferred) ?? 0
        var offset = 0
        let result = MathPresentationFitPolicy.resolvedCandidate(
            generate: {
                defer { offset += 1 }
                return pool[(start + offset) % pool.count]
            },
            isReadable: { fitGate.allows([promptRepresentation($0)], for: mechanic) }
        )
        switch result {
        case .candidate(let problem), .compactFallback(let problem): return problem
        case .unavailable: return nil
        }
    }

    private func answerValues(for problem: MathM4Problem) -> [Int]? {
        var values = [problem.answer]
        let domain = Set(Self.problems.map(\.answer))
        for strategy in Self.mistakeStrategies {
            let candidates: [Int]
            switch strategy {
            case .swappedTensAndOnes:
                candidates = [problem.answer % 10 * 10 + problem.answer / 10]
            case .offByTen:
                candidates = [problem.answer - 10, problem.answer + 10]
            case .nearbyNumber:
                candidates = [problem.answer - 1, problem.answer + 1]
            case .operationMistake:
                if let left = problem.left, let right = problem.right {
                    candidates = [abs(left - right), min(100, left + right)]
                } else {
                    candidates = []
                }
            }
            for candidate in candidates where domain.contains(candidate) && !values.contains(candidate) {
                values.append(candidate)
            }
        }
        for candidate in domain.sorted(by: { abs($0 - problem.answer) < abs($1 - problem.answer) })
        where values.count < 4 && !values.contains(candidate) {
            values.append(candidate)
        }
        return values.count >= 4 ? Array(values.prefix(4)).shuffled() : nil
    }

    private func problems(
        forDistinctAnswers values: [Int],
        preferred: MathM4Problem
    ) -> [MathM4Problem] {
        values.compactMap { value in
            value == preferred.answer
                ? preferred
                : Self.problems.first { $0.answer == value && $0.id != preferred.id }
        }
    }

    private func uniqueAnswerProblems() -> [MathM4Problem] {
        var seen = Set<Int>()
        return balancedProblems(count: Self.problems.count).filter { seen.insert($0.answer).inserted }
    }

    private func digitChallenge(
        id: String,
        promptRepresentation: Representation,
        answer: Int,
        skill: SkillID
    ) -> BuildChallenge? {
        guard let prompt = Prompt(representations: [promptRepresentation]) else { return nil }
        var expected = String(answer).enumerated().map { index, digit in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).expected.\(index)"),
                representation: token(String(digit), id: "\(id).digit.\(index)")
            )
        }
        let expectedIDs = expected.map(\.id)
        let distractors = [String((answer + 1) % 10), String((answer + 3) % 10)].enumerated().map { index, digit in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).distractor.\(index)"),
                representation: token(digit, id: "\(id).distractor-representation.\(index)")
            )
        }
        expected.append(contentsOf: distractors)
        guard fitGate.allows(expected.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: expected.shuffled(),
            expectedTokenSequence: expectedIDs,
            primarySkill: skill,
            secondarySkills: [MathSkillIDs.placeValue],
            curriculumStage: MathCurriculumLevelID.m4.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func tokenSequenceChallenge(
        id: String,
        prompt: Prompt,
        pieces: [String],
        distractor: String,
        skill: SkillID
    ) -> BuildChallenge? {
        var tokens = pieces.enumerated().map { index, piece in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).expected.\(index)"),
                representation: token(piece, id: "\(id).piece.\(index)")
            )
        }
        let expectedIDs = tokens.map(\.id)
        tokens.append(BuildToken(
            id: BuildTokenID(rawValue: "\(id).distractor"),
            representation: token(distractor, id: "\(id).distractor-representation")
        ))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: tokens.shuffled(),
            expectedTokenSequence: expectedIDs,
            primarySkill: skill,
            secondarySkills: [MathSkillIDs.placeValue],
            curriculumStage: MathCurriculumLevelID.m4.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func challenge(
        id: String,
        prompt: Prompt,
        choices: [Choice],
        answer: Int,
        problem: MathM4Problem
    ) -> Challenge {
        Challenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            choices: choices,
            interaction: .singleChoice,
            validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.integer(answer)),
            primarySkill: skill(for: problem),
            secondarySkills: [MathSkillIDs.placeValue],
            curriculumStage: MathCurriculumLevelID.m4.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func skill(for problem: MathM4Problem) -> SkillID {
        switch problem.category {
        case .placeValue: return MathSkillIDs.placeValue
        case .addition: return MathSkillIDs.addition
        case .subtraction: return MathSkillIDs.subtraction
        }
    }

    private func promptRepresentation(_ problem: MathM4Problem) -> Representation {
        switch problem.category {
        case .placeValue: return placeValue(problem.answer)
        case .addition, .subtraction:
            return arithmetic(left: problem.left!, operation: problem.operation!, right: problem.right!, id: problem.id)
        }
    }

    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(
            value: value,
            structureID: RepresentationStructureID(rawValue: "math.m4.numeral.\(value)")
        )))
    }

    private func placeValue(_ value: Int) -> Representation {
        var components: [MathPlaceValueComponent] = []
        if value == 100 {
            components.append(MathPlaceValueComponent(placeValue: 100, digit: 1)!)
            components.append(MathPlaceValueComponent(placeValue: 10, digit: 0)!)
            components.append(MathPlaceValueComponent(placeValue: 1, digit: 0)!)
        } else {
            components.append(MathPlaceValueComponent(placeValue: 10, digit: value / 10)!)
            components.append(MathPlaceValueComponent(placeValue: 1, digit: value % 10)!)
        }
        return .math(.placeValue(MathPlaceValueRepresentation(
            components: components,
            structureID: RepresentationStructureID(rawValue: "math.m4.place-value.\(value)")
        )!))
    }

    private func expanded(_ value: Int) -> Representation {
        let high = value == 100 ? 100 : (value / 10) * 10
        let low = value == 100 ? 0 : value % 10
        return arithmetic(left: high, operation: .addition, right: low, id: "expanded.\(value)")
    }

    private func arithmetic(left: Int, operation: MathOperation, right: Int, id: String) -> Representation {
        .math(.arithmeticExpression(MathArithmeticRepresentation(
            left: .integer(left),
            operation: operation,
            right: .integer(right),
            structureID: RepresentationStructureID(rawValue: "math.m4.expression.\(id)")
        )))
    }

    private func comparison(left: Int, right: Int) -> Representation {
        .math(.comparison(MathComparisonRepresentation(
            left: .integer(left),
            relation: left < right ? .lessThan : .greaterThan,
            right: .integer(right),
            structureID: RepresentationStructureID(rawValue: "math.m4.comparison.\(left).\(right)")
        )))
    }

    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(
            expression: text,
            structureID: RepresentationStructureID(rawValue: id)
        ))
    }
}
