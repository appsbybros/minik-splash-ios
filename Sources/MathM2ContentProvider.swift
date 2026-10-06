import Foundation

enum MathM2FactCategory: String, CaseIterable, Hashable, Sendable {
    case composition
    case addition
    case subtraction
    case complementToTen
}

struct MathM2CategoryWeights: Equatable, Sendable {
    let composition: Int
    let addition: Int
    let subtraction: Int
    let complementToTen: Int

    static let production = MathM2CategoryWeights(
        composition: 2,
        addition: 3,
        subtraction: 3,
        complementToTen: 2
    )
}

struct MathM2Fact: Hashable, Sendable {
    let id: String
    let category: MathM2FactCategory
    let left: Int
    let operation: MathOperation
    let right: Int
    let result: Int

    init?(
        id: String,
        category: MathM2FactCategory,
        left: Int,
        operation: MathOperation,
        right: Int,
        result: Int
    ) {
        guard !id.isEmpty,
              (0...10).contains(left),
              (0...10).contains(right),
              (0...10).contains(result) else { return nil }
        switch operation {
        case .addition:
            guard left + right == result else { return nil }
        case .subtraction:
            guard right <= left, left - right == result else { return nil }
        case .multiplication, .division:
            return nil
        }
        if category == .complementToTen, result != 10 { return nil }
        self.id = id
        self.category = category
        self.left = left
        self.operation = operation
        self.right = right
        self.result = result
    }
}

enum MathM2ChoiceDirection: Hashable, Sendable {
    case operationToAnswer
    case answerToOperation
}

struct MathM2ContentProvider: Sendable {
    static let categoryWeights = MathM2CategoryWeights.production
    static let facts: [MathM2Fact] = [
        MathM2Fact(id: "compose.1-2", category: .composition, left: 1, operation: .addition, right: 2, result: 3)!,
        MathM2Fact(id: "compose.2-2", category: .composition, left: 2, operation: .addition, right: 2, result: 4)!,
        MathM2Fact(id: "compose.4-1", category: .composition, left: 4, operation: .addition, right: 1, result: 5)!,
        MathM2Fact(id: "add.2-4", category: .addition, left: 2, operation: .addition, right: 4, result: 6)!,
        MathM2Fact(id: "add.3-4", category: .addition, left: 3, operation: .addition, right: 4, result: 7)!,
        MathM2Fact(id: "add.3-5", category: .addition, left: 3, operation: .addition, right: 5, result: 8)!,
        MathM2Fact(id: "subtract.4-4", category: .subtraction, left: 4, operation: .subtraction, right: 4, result: 0)!,
        MathM2Fact(id: "subtract.6-5", category: .subtraction, left: 6, operation: .subtraction, right: 5, result: 1)!,
        MathM2Fact(id: "subtract.7-5", category: .subtraction, left: 7, operation: .subtraction, right: 5, result: 2)!,
        MathM2Fact(id: "subtract.8-5", category: .subtraction, left: 8, operation: .subtraction, right: 5, result: 3)!,
        MathM2Fact(id: "subtract.9-4", category: .subtraction, left: 9, operation: .subtraction, right: 4, result: 5)!,
        MathM2Fact(id: "complement.1-9", category: .complementToTen, left: 1, operation: .addition, right: 9, result: 10)!,
        MathM2Fact(id: "complement.2-8", category: .complementToTen, left: 2, operation: .addition, right: 8, result: 10)!,
        MathM2Fact(id: "complement.4-6", category: .complementToTen, left: 4, operation: .addition, right: 6, result: 10)!
    ]

    private static let difficulty = Difficulty(0.55)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) {
        self.fitGate = fitGate
    }

    func balancedFacts(count: Int) -> [MathM2Fact] {
        guard count > 0 else { return [] }
        let weightedCategories = interleavedWeightedCategories()
        var offsets = Dictionary(uniqueKeysWithValues: MathM2FactCategory.allCases.map { ($0, 0) })
        return (0..<count).compactMap { index in
            let category = weightedCategories[index % weightedCategories.count]
            let candidates = Self.facts.filter { $0.category == category }
            let offset = offsets[category, default: 0]
            offsets[category] = offset + 1
            return candidates.isEmpty ? nil : candidates[offset % candidates.count]
        }
    }

    private func interleavedWeightedCategories() -> [MathM2FactCategory] {
        var remaining: [MathM2FactCategory: Int] = [
            .composition: Self.categoryWeights.composition,
            .addition: Self.categoryWeights.addition,
            .subtraction: Self.categoryWeights.subtraction,
            .complementToTen: Self.categoryWeights.complementToTen
        ]
        var result: [MathM2FactCategory] = []
        while remaining.values.contains(where: { $0 > 0 }) {
            for category in MathM2FactCategory.allCases where remaining[category, default: 0] > 0 {
                result.append(category)
                remaining[category, default: 0] -= 1
            }
        }
        return result
    }

    func studyCards() -> [StudyCard] {
        balancedFacts(count: 10).compactMap { fact in
            guard fitGate.allows(cardRepresentations(for: fact), for: .learn) else { return nil }
            return StudyCard(
                id: StudyCardID(rawValue: "m2.card.\(fact.id)"),
                representations: cardRepresentations(for: fact),
                primarySkill: skill(for: fact),
                curriculumStage: MathCurriculumLevelID.m2.curriculumStageID
            )
        }
    }

    func equivalenceSets(count: Int = 4) -> [EquivalenceSet] {
        balancedFacts(count: count).compactMap { fact in
            let secondary = fact.category == .composition || fact.category == .complementToTen
                ? groupedOrQuantity(for: fact)
                : numeral(fact.result)
            let representations = [expression(fact), secondary]
            guard fitGate.allows(representations, for: .matching) else { return nil }
            return EquivalenceSet(
                semanticValue: .integer(fact.result),
                representations: representations
            )
        }
    }

    func choiceChallenge(
        fact preferredFact: MathM2Fact,
        direction: MathM2ChoiceDirection
    ) -> Challenge? {
        guard let fact = fittedFact(preferredFact, mechanic: .choice),
              let answerValues = distinctAnswerValues(for: fact.result),
              let prompt = Prompt(representations: [direction == .operationToAnswer
                    ? expression(fact)
                    : numeral(fact.result)]) else { return nil }
        let id = "m2.choice.\(direction).\(fact.id).\(UUID().uuidString)"
        let choices: [Choice]
        switch direction {
        case .operationToAnswer:
            choices = answerValues.enumerated().map { index, value in
                Choice(
                    id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                    representation: numeral(value),
                    semanticValue: .integer(value)
                )
            }
        case .answerToOperation:
            let candidateFacts = factsForDistinctResults(answerValues, preferred: fact)
            guard candidateFacts.count == answerValues.count else { return nil }
            choices = candidateFacts.enumerated().map { index, candidate in
                Choice(
                    id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                    representation: expression(candidate),
                    semanticValue: .integer(candidate.result)
                )
            }
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return Challenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            choices: choices,
            interaction: .singleChoice,
            validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.integer(fact.result)),
            primarySkill: skill(for: fact),
            secondarySkills: [MathSkillIDs.equivalentValues],
            curriculumStage: MathCurriculumLevelID.m2.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func buildNumberChallenge(fact preferredFact: MathM2Fact) -> BuildChallenge? {
        guard let fact = fittedFact(preferredFact, mechanic: .build),
              let values = distinctAnswerValues(for: fact.result),
              let prompt = Prompt(representations: [expression(fact)]) else { return nil }
        let id = "m2.build-number.\(fact.id).\(UUID().uuidString)"
        let tokens = values.enumerated().map { index, value in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).token.\(index)"),
                representation: numeral(value)
            )
        }
        guard let correct = values.firstIndex(of: fact.result) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: tokens,
            expectedTokenSequence: [tokens[correct].id],
            primarySkill: skill(for: fact),
            secondarySkills: [MathSkillIDs.equivalentValues],
            curriculumStage: MathCurriculumLevelID.m2.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func buildEquationChallenge(fact preferredFact: MathM2Fact) -> BuildChallenge? {
        guard let fact = fittedFact(preferredFact, mechanic: .build),
              let prompt = Prompt(representations: [expression(fact)]) else { return nil }
        let id = "m2.build-equation.\(fact.id).\(UUID().uuidString)"
        let pieces = [String(fact.left), fact.operation.symbol, String(fact.right), "=", String(fact.result)]
        var tokens = pieces.enumerated().map { index, piece in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).expected.\(index)"),
                representation: token(piece, id: "\(id).piece.\(index)")
            )
        }
        let distractor = fact.result == 10 ? 9 : fact.result + 1
        tokens.append(BuildToken(
            id: BuildTokenID(rawValue: "\(id).distractor"),
            representation: token(String(distractor), id: "\(id).distractor.representation")
        ))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: tokens.shuffled(),
            expectedTokenSequence: Array(tokens.prefix(pieces.count).map(\.id)),
            primarySkill: skill(for: fact),
            secondarySkills: [MathSkillIDs.equivalentValues],
            curriculumStage: MathCurriculumLevelID.m2.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func countRound(fact preferredFact: MathM2Fact) -> MathCountRound? {
        guard let fact = fittedFact(preferredFact, mechanic: .countConstruction) else { return nil }
        let id = "m2.count.\(fact.id).\(UUID().uuidString)"
        return MathCountRound(
            id: ChallengeID(rawValue: id),
            target: fact.result,
            availableTokenIDs: (0..<max(4, fact.result + 3)).map {
                MathCountTokenID(rawValue: "\(id).token.\($0)")
            },
            prompt: expression(fact),
            spokenPrompt: factDisplayText(fact),
            mathLevelID: .m2,
            skillID: skill(for: fact)
        )
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool else { return nil }
        let preferredFacts = uniqueResultFacts().prefix(answerCount)
        guard preferredFacts.count == answerCount else { return nil }
        let uniqueFacts = preferredFacts.compactMap {
            fittedFact($0, mechanic: .soccerPrompt)
        }
        guard uniqueFacts.count == answerCount,
              Set(uniqueFacts.map(\.result)).count == answerCount else { return nil }
        let id = "m2.soccer.\(UUID().uuidString)"
        let balls = uniqueFacts.enumerated().map { index, fact in
            SoccerAnswerBall(
                id: SoccerBallID(rawValue: "\(id).ball.\(index)"),
                representation: numeral(fact.result),
                semanticValue: .integer(fact.result)
            )
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(uniqueFacts, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            let (fact, ball) = pair
            let promptRepresentation = expression(fact)
            guard let prompt = Prompt(representations: [promptRepresentation]) else { return nil }
            let challenge = Challenge(
                id: ChallengeID(rawValue: "\(id).challenge.\(index)"),
                prompt: prompt,
                choices: [],
                interaction: .singleChoice,
                validationRule: .numericEquivalence,
                expectedAnswer: .semanticValue(.integer(fact.result)),
                primarySkill: skill(for: fact),
                secondarySkills: [MathSkillIDs.equivalentValues],
                curriculumStage: MathCurriculumLevelID.m2.curriculumStageID,
                difficulty: Self.difficulty
            )
            return SoccerChallengeTarget(challenge: challenge, intendedBallID: ball.id)
        }
        guard targets.count == balls.count else { return nil }
        return SoccerRound(
            id: SoccerRoundID(rawValue: "\(id).round"),
            answerBalls: balls,
            challengeTargets: targets
        )
    }

    private func fittedFact(
        _ preferred: MathM2Fact,
        mechanic: MathPresentationMechanic
    ) -> MathM2Fact? {
        var offset = 0
        let sameCategory = Self.facts.filter { $0.category == preferred.category }
        let start = sameCategory.firstIndex(of: preferred) ?? 0
        let result = MathPresentationFitPolicy.resolvedCandidate(
            generate: {
                defer { offset += 1 }
                return sameCategory[(start + offset) % sameCategory.count]
            },
            isReadable: { fact in
                fitGate.allows([expression(fact)], for: mechanic)
            }
        )
        switch result {
        case .candidate(let fact), .compactFallback(let fact): return fact
        case .unavailable: return nil
        }
    }

    private func distinctAnswerValues(for correct: Int) -> [Int]? {
        let domain = Set(Self.facts.map(\.result))
        let values = domain.sorted {
            let firstDistance = abs($0 - correct)
            let secondDistance = abs($1 - correct)
            return firstDistance == secondDistance ? $0 < $1 : firstDistance < secondDistance
        }
        guard values.count >= 4 else { return nil }
        return Array(values.prefix(4)).shuffled()
    }

    private func factsForDistinctResults(
        _ values: [Int],
        preferred: MathM2Fact
    ) -> [MathM2Fact] {
        values.compactMap { value in
            value == preferred.result
                ? preferred
                : Self.facts.first { $0.result == value && $0.id != preferred.id }
        }
    }

    private func uniqueResultFacts() -> [MathM2Fact] {
        var seen = Set<Int>()
        return balancedFacts(count: Self.facts.count).filter { seen.insert($0.result).inserted }
    }

    private func cardRepresentations(for fact: MathM2Fact) -> [Representation] {
        [expression(fact), groupedOrQuantity(for: fact), numeral(fact.result)]
    }

    private func groupedOrQuantity(for fact: MathM2Fact) -> Representation {
        if fact.operation == .addition, fact.left > 0, fact.right > 0 {
            return .math(.groupedQuantity(MathGroupedQuantityRepresentation(
                groupCounts: [fact.left, fact.right],
                structureID: RepresentationStructureID(rawValue: "math.m2.grouped.\(fact.id)")
            )!))
        }
        return quantity(fact.result)
    }

    private func expression(_ fact: MathM2Fact) -> Representation {
        .math(.arithmeticExpression(MathArithmeticRepresentation(
            left: .integer(fact.left),
            operation: fact.operation,
            right: .integer(fact.right),
            structureID: RepresentationStructureID(rawValue: "math.m2.expression.\(fact.id)")
        )))
    }

    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(
            value: value,
            structureID: RepresentationStructureID(rawValue: "math.m2.numeral.\(value)")
        )))
    }

    private func quantity(_ value: Int) -> Representation {
        .math(.quantity(MathQuantityRepresentation(
            count: value,
            structureID: RepresentationStructureID(rawValue: "math.m2.quantity.\(value)")
        )!))
    }

    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(
            expression: text,
            structureID: RepresentationStructureID(rawValue: id)
        ))
    }

    private func factDisplayText(_ fact: MathM2Fact) -> String {
        "\(fact.left) \(fact.operation.symbol) \(fact.right)"
    }

    private func skill(for fact: MathM2Fact) -> SkillID {
        switch fact.category {
        case .composition, .complementToTen: return MathSkillIDs.composition
        case .addition: return MathSkillIDs.addition
        case .subtraction: return MathSkillIDs.subtraction
        }
    }
}
