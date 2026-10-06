import Foundation

enum MathM3RelationshipCategory: String, CaseIterable, Hashable, Sendable {
    case missingAddend
    case missingSubtrahend
    case operationResult
    case equivalentExpressions
}

struct MathM3CategoryWeights: Equatable, Sendable {
    let missingAddend: Int
    let missingSubtrahend: Int
    let operationResult: Int
    let equivalentExpressions: Int

    static let production = MathM3CategoryWeights(
        missingAddend: 3,
        missingSubtrahend: 2,
        operationResult: 3,
        equivalentExpressions: 2
    )
}

enum MathM3MistakeStrategy: Hashable, Sendable {
    case offByOne
    case knownOperand
    case operationResult
    case complementWithinTwenty
}

struct MathM3Relationship: Hashable, Sendable {
    let id: String
    let category: MathM3RelationshipCategory
    let left: Int
    let operation: MathOperation
    let right: Int
    let result: Int
    let missingPosition: MathMissingPosition

    var answer: Int {
        switch missingPosition {
        case .leftOperand: return left
        case .rightOperand: return right
        case .result: return result
        }
    }

    init?(
        id: String,
        category: MathM3RelationshipCategory,
        left: Int,
        operation: MathOperation,
        right: Int,
        result: Int,
        missingPosition: MathMissingPosition
    ) {
        guard !id.isEmpty,
              (0...20).contains(left),
              (0...20).contains(right),
              (0...20).contains(result) else { return nil }
        switch operation {
        case .addition: guard left + right == result else { return nil }
        case .subtraction: guard right <= left, left - right == result else { return nil }
        case .multiplication, .division: return nil
        }
        self.id = id
        self.category = category
        self.left = left
        self.operation = operation
        self.right = right
        self.result = result
        self.missingPosition = missingPosition
    }
}

enum MathM3ChoiceDirection: Hashable, Sendable {
    case relationshipToAnswer
    case answerToRelationship
}

struct MathM3ContentProvider: Sendable {
    static let categoryWeights = MathM3CategoryWeights.production
    static let mistakeStrategies: [MathM3MistakeStrategy] = [
        .offByOne, .knownOperand, .operationResult, .complementWithinTwenty
    ]
    static let relationships: [MathM3Relationship] = [
        MathM3Relationship(id: "missing-add.2-5", category: .missingAddend, left: 2, operation: .addition, right: 5, result: 7, missingPosition: .rightOperand)!,
        MathM3Relationship(id: "missing-add.7-5", category: .missingAddend, left: 7, operation: .addition, right: 5, result: 12, missingPosition: .rightOperand)!,
        MathM3Relationship(id: "missing-add.8-7", category: .missingAddend, left: 8, operation: .addition, right: 7, result: 15, missingPosition: .rightOperand)!,
        MathM3Relationship(id: "missing-add.8-left", category: .missingAddend, left: 8, operation: .addition, right: 6, result: 14, missingPosition: .leftOperand)!,
        MathM3Relationship(id: "missing-subtract.12-7", category: .missingSubtrahend, left: 12, operation: .subtraction, right: 7, result: 5, missingPosition: .rightOperand)!,
        MathM3Relationship(id: "missing-subtract.18-9", category: .missingSubtrahend, left: 18, operation: .subtraction, right: 9, result: 9, missingPosition: .rightOperand)!,
        MathM3Relationship(id: "missing-subtract.20-12", category: .missingSubtrahend, left: 20, operation: .subtraction, right: 12, result: 8, missingPosition: .rightOperand)!,
        MathM3Relationship(id: "missing-subtract.15-11", category: .missingSubtrahend, left: 15, operation: .subtraction, right: 11, result: 4, missingPosition: .rightOperand)!,
        MathM3Relationship(id: "result.add.7-5", category: .operationResult, left: 7, operation: .addition, right: 5, result: 12, missingPosition: .result)!,
        MathM3Relationship(id: "result.add.9-8", category: .operationResult, left: 9, operation: .addition, right: 8, result: 17, missingPosition: .result)!,
        MathM3Relationship(id: "result.subtract.16-7", category: .operationResult, left: 16, operation: .subtraction, right: 7, result: 9, missingPosition: .result)!,
        MathM3Relationship(id: "result.subtract.20-6", category: .operationResult, left: 20, operation: .subtraction, right: 6, result: 14, missingPosition: .result)!,
        MathM3Relationship(id: "result.subtract.8-8", category: .operationResult, left: 8, operation: .subtraction, right: 8, result: 0, missingPosition: .result)!,
        MathM3Relationship(id: "equivalent.6-4", category: .equivalentExpressions, left: 6, operation: .addition, right: 4, result: 10, missingPosition: .result)!,
        MathM3Relationship(id: "equivalent.13-5", category: .equivalentExpressions, left: 13, operation: .subtraction, right: 5, result: 8, missingPosition: .result)!,
        MathM3Relationship(id: "equivalent.7-9", category: .equivalentExpressions, left: 7, operation: .addition, right: 9, result: 16, missingPosition: .result)!
    ]

    private static let difficulty = Difficulty(0.65)!
    private let fitGate: MathContentFitGate

    init(fitGate: MathContentFitGate = .production) {
        self.fitGate = fitGate
    }

    func balancedRelationships(count: Int) -> [MathM3Relationship] {
        guard count > 0 else { return [] }
        let categories = interleavedCategories()
        var offsets = Dictionary(uniqueKeysWithValues: MathM3RelationshipCategory.allCases.map { ($0, 0) })
        return (0..<count).compactMap { index in
            let category = categories[index % categories.count]
            let candidates = Self.relationships.filter { $0.category == category }
            let offset = offsets[category, default: 0]
            offsets[category] = offset + 1
            return candidates.isEmpty ? nil : candidates[offset % candidates.count]
        }
    }

    func studyCards() -> [StudyCard] {
        balancedRelationships(count: 10).compactMap { relationship in
            let representations = [
                missingRepresentation(relationship),
                numeral(relationship.answer),
                equivalentExpression(for: relationship.answer, id: relationship.id)
            ]
            guard fitGate.allows(representations, for: .learn) else { return nil }
            return StudyCard(
                id: StudyCardID(rawValue: "m3.card.\(relationship.id)"),
                representations: representations,
                primarySkill: skill(for: relationship),
                curriculumStage: MathCurriculumLevelID.m3.curriculumStageID
            )
        }
    }

    func equivalenceSets(count: Int = 4) -> [EquivalenceSet] {
        balancedRelationships(count: count).compactMap { relationship in
            let representations: [Representation]
            if relationship.missingPosition == .result {
                representations = [
                    directExpression(relationship),
                    equivalentExpression(for: relationship.result, id: relationship.id)
                ]
            } else {
                representations = [missingRepresentation(relationship), numeral(relationship.answer)]
            }
            guard fitGate.allows(representations, for: .matching) else { return nil }
            return EquivalenceSet(
                semanticValue: .integer(relationship.answer),
                representations: representations
            )
        }
    }

    func choiceChallenge(
        relationship preferred: MathM3Relationship,
        direction: MathM3ChoiceDirection
    ) -> Challenge? {
        guard let relationship = fitted(preferred, mechanic: .choice),
              let values = answerValues(for: relationship),
              let prompt = Prompt(representations: [direction == .relationshipToAnswer
                    ? missingRepresentation(relationship)
                    : numeral(relationship.answer)]) else { return nil }
        let id = "m3.choice.\(direction).\(relationship.id).\(UUID().uuidString)"
        let choices: [Choice]
        switch direction {
        case .relationshipToAnswer:
            choices = values.enumerated().map { index, value in
                Choice(
                    id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                    representation: numeral(value),
                    semanticValue: .integer(value)
                )
            }
        case .answerToRelationship:
            let candidates = relationships(forDistinctAnswers: values, preferred: relationship)
            guard candidates.count == values.count else { return nil }
            choices = candidates.enumerated().map { index, candidate in
                Choice(
                    id: ChoiceID(rawValue: "\(id).choice.\(index)"),
                    representation: missingRepresentation(candidate),
                    semanticValue: .integer(candidate.answer)
                )
            }
        }
        guard fitGate.allows(choices.map(\.representation), for: .choice) else { return nil }
        return challenge(
            id: id,
            prompt: prompt,
            choices: choices,
            answer: relationship.answer,
            relationship: relationship
        )
    }

    func buildNumberChallenge(relationship preferred: MathM3Relationship) -> BuildChallenge? {
        guard let relationship = fitted(preferred, mechanic: .build),
              let prompt = Prompt(representations: [missingRepresentation(relationship)]) else { return nil }
        let id = "m3.build-number.\(relationship.id).\(UUID().uuidString)"
        let digits = String(relationship.answer).map(String.init)
        var expectedTokens = digits.enumerated().map { index, digit in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).expected.\(index)"),
                representation: token(digit, id: "\(id).digit.\(index)")
            )
        }
        let distractorDigits = [String((relationship.answer + 1) % 10), String((relationship.answer + 3) % 10)]
        let distractors = distractorDigits.enumerated().map { index, digit in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).distractor.\(index)"),
                representation: token(digit, id: "\(id).distractor-representation.\(index)")
            )
        }
        guard fitGate.allows((expectedTokens + distractors).map(\.representation), for: .build) else { return nil }
        let expectedIDs = expectedTokens.map(\.id)
        expectedTokens.append(contentsOf: distractors)
        return BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: expectedTokens.shuffled(),
            expectedTokenSequence: expectedIDs,
            primarySkill: skill(for: relationship),
            secondarySkills: [MathSkillIDs.equivalentValues],
            curriculumStage: MathCurriculumLevelID.m3.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func buildEquationChallenge(relationship preferred: MathM3Relationship) -> BuildChallenge? {
        guard let relationship = fitted(preferred, mechanic: .build),
              let prompt = Prompt(representations: [missingRepresentation(relationship)]) else { return nil }
        let id = "m3.build-equation.\(relationship.id).\(UUID().uuidString)"
        let pieces = [String(relationship.left), relationship.operation.symbol, String(relationship.right), "=", String(relationship.result)]
        var tokens = pieces.enumerated().map { index, piece in
            BuildToken(
                id: BuildTokenID(rawValue: "\(id).expected.\(index)"),
                representation: token(piece, id: "\(id).piece.\(index)")
            )
        }
        let expectedIDs = tokens.map(\.id)
        tokens.append(BuildToken(
            id: BuildTokenID(rawValue: "\(id).distractor"),
            representation: token(String((relationship.answer + 1) % 21), id: "\(id).distractor-representation")
        ))
        guard fitGate.allows(tokens.map(\.representation), for: .build) else { return nil }
        return BuildChallenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            availableTokens: tokens.shuffled(),
            expectedTokenSequence: expectedIDs,
            primarySkill: skill(for: relationship),
            secondarySkills: [MathSkillIDs.equivalentValues],
            curriculumStage: MathCurriculumLevelID.m3.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    func countRound(relationship preferred: MathM3Relationship) -> MathCountRound? {
        guard let relationship = fitted(preferred, mechanic: .countConstruction) else { return nil }
        let id = "m3.count.\(relationship.id).\(UUID().uuidString)"
        return MathCountRound(
            id: ChallengeID(rawValue: id),
            target: relationship.answer,
            availableTokenIDs: (0..<max(4, relationship.answer + 3)).map {
                MathCountTokenID(rawValue: "\(id).token.\($0)")
            },
            prompt: missingRepresentation(relationship),
            spokenPrompt: missingRepresentation(relationship).accessibilityDescription,
            mathLevelID: .m3,
            skillID: skill(for: relationship)
        )
    }

    func soccerRound(answerCount: Int = 6) -> SoccerRound? {
        guard answerCount >= MathPresentationFitPolicy.minimumSoccerAnswerPool else { return nil }
        let preferred = uniqueAnswerRelationships().prefix(answerCount)
        guard preferred.count == answerCount else { return nil }
        let relationships = preferred.compactMap { fitted($0, mechanic: .soccerPrompt) }
        guard relationships.count == answerCount,
              Set(relationships.map(\.answer)).count == answerCount else { return nil }
        let id = "m3.soccer.\(UUID().uuidString)"
        let balls = relationships.enumerated().map { index, relationship in
            SoccerAnswerBall(
                id: SoccerBallID(rawValue: "\(id).ball.\(index)"),
                representation: numeral(relationship.answer),
                semanticValue: .integer(relationship.answer)
            )
        }
        guard fitGate.allows(balls.map(\.representation), for: .soccerBall) else { return nil }
        let targets = zip(relationships, balls).enumerated().compactMap { index, pair -> SoccerChallengeTarget? in
            let (relationship, ball) = pair
            guard let prompt = Prompt(representations: [missingRepresentation(relationship)]) else { return nil }
            return SoccerChallengeTarget(
                challenge: challenge(
                    id: "\(id).challenge.\(index)",
                    prompt: prompt,
                    choices: [],
                    answer: relationship.answer,
                    relationship: relationship
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

    private func interleavedCategories() -> [MathM3RelationshipCategory] {
        var remaining: [MathM3RelationshipCategory: Int] = [
            .missingAddend: Self.categoryWeights.missingAddend,
            .missingSubtrahend: Self.categoryWeights.missingSubtrahend,
            .operationResult: Self.categoryWeights.operationResult,
            .equivalentExpressions: Self.categoryWeights.equivalentExpressions
        ]
        var result: [MathM3RelationshipCategory] = []
        while remaining.values.contains(where: { $0 > 0 }) {
            for category in MathM3RelationshipCategory.allCases where remaining[category, default: 0] > 0 {
                result.append(category)
                remaining[category, default: 0] -= 1
            }
        }
        return result
    }

    private func fitted(
        _ preferred: MathM3Relationship,
        mechanic: MathPresentationMechanic
    ) -> MathM3Relationship? {
        let sameCategory = Self.relationships.filter { $0.category == preferred.category }
        let start = sameCategory.firstIndex(of: preferred) ?? 0
        var offset = 0
        let result = MathPresentationFitPolicy.resolvedCandidate(
            generate: {
                defer { offset += 1 }
                return sameCategory[(start + offset) % sameCategory.count]
            },
            isReadable: { fitGate.allows([missingRepresentation($0)], for: mechanic) }
        )
        switch result {
        case .candidate(let relationship), .compactFallback(let relationship): return relationship
        case .unavailable: return nil
        }
    }

    private func answerValues(for relationship: MathM3Relationship) -> [Int]? {
        var values: [Int] = [relationship.answer]
        let answerDomain = Set(Self.relationships.map(\.answer))
        for strategy in Self.mistakeStrategies {
            let candidates: [Int]
            switch strategy {
            case .offByOne: candidates = [relationship.answer - 1, relationship.answer + 1]
            case .knownOperand: candidates = [relationship.left, relationship.right]
            case .operationResult: candidates = [relationship.result]
            case .complementWithinTwenty: candidates = [20 - relationship.answer]
            }
            for candidate in candidates where answerDomain.contains(candidate) && !values.contains(candidate) {
                values.append(candidate)
            }
        }
        let fallback = answerDomain.sorted {
            let firstDistance = abs($0 - relationship.answer)
            let secondDistance = abs($1 - relationship.answer)
            return firstDistance == secondDistance ? $0 < $1 : firstDistance < secondDistance
        }
        for candidate in fallback where values.count < 4 && !values.contains(candidate) {
            values.append(candidate)
        }
        return values.count >= 4 ? Array(values.prefix(4)).shuffled() : nil
    }

    private func relationships(
        forDistinctAnswers values: [Int],
        preferred: MathM3Relationship
    ) -> [MathM3Relationship] {
        values.compactMap { value in
            value == preferred.answer
                ? preferred
                : Self.relationships.first { $0.answer == value && $0.id != preferred.id }
        }
    }

    private func uniqueAnswerRelationships() -> [MathM3Relationship] {
        var seen = Set<Int>()
        return balancedRelationships(count: Self.relationships.count).filter {
            seen.insert($0.answer).inserted
        }
    }

    private func challenge(
        id: String,
        prompt: Prompt,
        choices: [Choice],
        answer: Int,
        relationship: MathM3Relationship
    ) -> Challenge {
        Challenge(
            id: ChallengeID(rawValue: id),
            prompt: prompt,
            choices: choices,
            interaction: .singleChoice,
            validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.integer(answer)),
            primarySkill: skill(for: relationship),
            secondarySkills: [MathSkillIDs.equivalentValues],
            curriculumStage: MathCurriculumLevelID.m3.curriculumStageID,
            difficulty: Self.difficulty
        )
    }

    private func skill(for relationship: MathM3Relationship) -> SkillID {
        switch relationship.category {
        case .missingAddend, .missingSubtrahend: return MathSkillIDs.missingAddend
        case .operationResult: return relationship.operation == .addition ? MathSkillIDs.addition : MathSkillIDs.subtraction
        case .equivalentExpressions: return MathSkillIDs.equivalentValues
        }
    }

    private func missingRepresentation(_ relationship: MathM3Relationship) -> Representation {
        .math(.missingValueExpression(MathMissingValueRepresentation(
            left: relationship.missingPosition == .leftOperand ? nil : .integer(relationship.left),
            operation: relationship.operation,
            right: relationship.missingPosition == .rightOperand ? nil : .integer(relationship.right),
            result: relationship.missingPosition == .result ? nil : .integer(relationship.result),
            missingPosition: relationship.missingPosition,
            structureID: RepresentationStructureID(rawValue: "math.m3.missing.\(relationship.id)")
        )!))
    }

    private func directExpression(_ relationship: MathM3Relationship) -> Representation {
        .math(.arithmeticExpression(MathArithmeticRepresentation(
            left: .integer(relationship.left),
            operation: relationship.operation,
            right: .integer(relationship.right),
            structureID: RepresentationStructureID(rawValue: "math.m3.expression.\(relationship.id)")
        )))
    }

    private func equivalentExpression(for value: Int, id: String) -> Representation {
        let left: Int
        let operation: MathOperation
        let right: Int
        if value == 0 {
            left = 4; operation = .subtraction; right = 4
        } else if value < 20 {
            left = value - 1; operation = .addition; right = 1
        } else {
            left = 20; operation = .subtraction; right = 0
        }
        return .math(.arithmeticExpression(MathArithmeticRepresentation(
            left: .integer(left),
            operation: operation,
            right: .integer(right),
            structureID: RepresentationStructureID(rawValue: "math.m3.equivalent.\(id).\(value)")
        )))
    }

    private func numeral(_ value: Int) -> Representation {
        .math(.numeral(MathNumeralRepresentation(
            value: value,
            structureID: RepresentationStructureID(rawValue: "math.m3.numeral.\(value)")
        )))
    }

    private func token(_ text: String, id: String) -> Representation {
        .mathExpression(MathExpressionRepresentation(
            expression: text,
            structureID: RepresentationStructureID(rawValue: id)
        ))
    }
}
