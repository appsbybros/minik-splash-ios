import Foundation

enum MathSkillIDs {
    static let quantityToNumber = SkillID(rawValue: "math.quantityToNumber")
    static let composition = SkillID(rawValue: "math.composition")
    static let addition = SkillID(rawValue: "math.addition")
    static let subtraction = SkillID(rawValue: "math.subtraction")
    static let missingAddend = SkillID(rawValue: "math.missingAddend")
    static let orderValues = SkillID(rawValue: "math.orderValues")
    static let equivalentValues = SkillID(rawValue: "math.equivalentValues")
    static let placeValue = SkillID(rawValue: "math.placeValue")
    static let magnitude = SkillID(rawValue: "math.magnitude")
    static let multiplication = SkillID(rawValue: "math.multiplication")
    static let division = SkillID(rawValue: "math.division")
    static let equalGroups = SkillID(rawValue: "math.equalGroups")
    static let factors = SkillID(rawValue: "math.factors")
    static let multiples = SkillID(rawValue: "math.multiples")
    static let simpleFractions = SkillID(rawValue: "math.simpleFractions")
    static let decimalFractions = SkillID(rawValue: "math.decimalFractions")
    static let decimalMagnitude = SkillID(rawValue: "math.decimalMagnitude")
    static let fractionDecimalPercent = SkillID(rawValue: "math.fractionDecimalPercent")
    static let ratios = SkillID(rawValue: "math.ratios")
    static let signedNumbers = SkillID(rawValue: "math.signedNumbers")
    static let orderOfOperations = SkillID(rawValue: "math.orderOfOperations")
    static let powers = SkillID(rawValue: "math.powers")
    static let equations = SkillID(rawValue: "math.equations")
    static let proportionalReasoning = SkillID(rawValue: "math.proportionalReasoning")
    static let probability = SkillID(rawValue: "math.probability")
    static let geometry = SkillID(rawValue: "math.geometry")
    static let linearRelationships = SkillID(rawValue: "math.linearRelationships")
}

struct MathContentProvider: ContentProvider, StudyContentProviding, ComparableContentProviding, EquivalenceContentProviding, BuildContentProviding, SoccerContentProviding, Sendable {
    func challenge(for request: ChallengeRequest) -> Challenge? {
        guard request.activityType == .multipleChoice,
              request.interaction == .singleChoice,
              let choiceCount = resolvedChoiceCount(request.countRequirement),
              let bound = generationBound(for: request),
              let problem = generateProblem(for: request, bound: bound),
              let prompt = Prompt(representations: [problem.prompt]) else {
            return nil
        }

        let choiceValues = nearbyChoiceValues(
            correctAnswer: problem.answer,
            count: choiceCount,
            bound: bound
        )
        guard choiceValues.count == choiceCount else {
            return nil
        }

        let instanceID = UUID().uuidString
        let choices = choiceValues.shuffled().enumerated().map { index, value in
            Choice(
                id: ChoiceID(rawValue: "\(instanceID).choice.\(index)"),
                representation: numberRepresentation(value),
                semanticValue: .integer(value)
            )
        }

        return Challenge(
            id: ChallengeID(rawValue: instanceID),
            prompt: prompt,
            choices: choices,
            interaction: .singleChoice,
            validationRule: .numericEquivalence,
            expectedAnswer: .semanticValue(.integer(problem.answer)),
            primarySkill: request.primarySkill,
            secondarySkills: [],
            curriculumStage: request.curriculumStage,
            difficulty: request.difficulty
        )
    }

    func studyCards(for request: ChallengeRequest) -> [StudyCard] {
        guard request.activityType == .learn,
              request.interaction == nil,
              let bound = generationBound(for: request),
              let cardCount = resolvedStudyCardCount(
                  request.countRequirement,
                  availableTargetCount: bound + 1
              ) else {
            return []
        }

        let instanceID = UUID().uuidString
        let targets = Array(0 ... bound).shuffled().prefix(cardCount)
        var cards: [StudyCard] = []
        cards.reserveCapacity(cardCount)

        for (index, target) in targets.enumerated() {
            guard let conceptRepresentation = studyConceptRepresentation(
                      for: request,
                      target: target,
                      bound: bound
                  ),
                  let card = StudyCard(
                      id: StudyCardID(rawValue: "\(instanceID).study.\(index)"),
                      representations: [conceptRepresentation, numberRepresentation(target)],
                      primarySkill: request.primarySkill,
                      secondarySkills: [],
                      curriculumStage: request.curriculumStage
                  ) else {
                return []
            }
            cards.append(card)
        }

        return cards
    }

    func comparableSet(for request: ChallengeRequest) -> ComparableSet? {
        guard request.activityType == .tower,
              request.interaction == .orderedTokens,
              request.primarySkill == MathSkillIDs.orderValues,
              let itemCount = resolvedItemCount(request.countRequirement),
              let bound = comparableBound(for: request) else {
            return nil
        }

        let instanceID = UUID().uuidString
        let values = Array(0 ... bound).shuffled().prefix(itemCount)
        let items = values.enumerated().map { index, value in
            ComparableItem(
                id: ComparableItemID(rawValue: "\(instanceID).item.\(index)"),
                representation: comparableRepresentation(
                    for: value,
                    itemIndex: index,
                    stage: request.curriculumStage,
                    bound: bound
                ),
                comparisonValue: .integer(value)
            )
        }

        return ComparableSet(items: items)
    }

    func equivalenceSets(for request: ChallengeRequest) -> [EquivalenceSet] {
        guard request.activityType == .pairs || request.activityType == .memory,
              request.interaction == .matching,
              request.primarySkill == MathSkillIDs.equivalentValues,
              let setCount = resolvedItemCount(request.countRequirement),
              let bound = equivalenceBound(for: request) else {
            return []
        }

        let values = Array(0 ... bound).shuffled().prefix(setCount)
        var sets: [EquivalenceSet] = []
        sets.reserveCapacity(setCount)

        for (index, value) in values.enumerated() {
            let directNumber = numberRepresentation(value)
            let relatedRepresentation: Representation

            if request.curriculumStage.rawValue == "M1" ||
                request.curriculumStage.rawValue == "M2" {
                relatedRepresentation = quantityRepresentation(value)
            } else {
                relatedRepresentation = comparableRepresentation(
                    for: value,
                    itemIndex: index,
                    stage: request.curriculumStage,
                    bound: bound
                )
            }

            guard let set = EquivalenceSet(
                semanticValue: .integer(value),
                representations: [directNumber, relatedRepresentation]
            ) else {
                return []
            }
            sets.append(set)
        }

        return sets
    }

    func buildChallenge(for request: ChallengeRequest) -> BuildChallenge? {
        guard request.activityType == .build,
              request.interaction == .orderedTokens,
              request.countRequirement == nil,
              let bound = generationBound(for: request),
              request.curriculumStage.rawValue != "M1",
              let equation = generateBuildEquation(for: request, bound: bound),
              let prompt = Prompt(representations: [mathExpression(
                  equation.promptExpression,
                  structureID: equation.promptStructureID
              )]) else {
            return nil
        }

        let instanceID = UUID().uuidString
        let tokenRepresentations: [Representation] = [
            numberRepresentation(equation.lhs),
            operatorRepresentation(equation.operation),
            numberRepresentation(equation.rhs),
            mathExpression("=", structureID: "math.operator.equals"),
            numberRepresentation(equation.result)
        ]
        let tokens = tokenRepresentations.enumerated().map { index, representation in
            BuildToken(
                id: BuildTokenID(rawValue: "\(instanceID).token.\(index)"),
                representation: representation
            )
        }

        return BuildChallenge(
            id: ChallengeID(rawValue: instanceID),
            prompt: prompt,
            availableTokens: tokens,
            expectedTokenSequence: tokens.map(\.id),
            primarySkill: request.primarySkill,
            secondarySkills: [],
            curriculumStage: request.curriculumStage,
            difficulty: request.difficulty
        )
    }

    func soccerRound(for request: ChallengeRequest) -> SoccerRound? {
        guard request.activityType == .soccer,
              request.interaction == .singleChoice,
              let bound = generationBound(for: request),
              let roundSize = resolvedSoccerRoundSize(
                  request.countRequirement,
                  availableValueCount: bound + 1
              ) else {
            return nil
        }

        let windowStart = Int.random(in: 0 ... (bound - roundSize + 1))
        let answerValues = Array(windowStart ..< (windowStart + roundSize)).shuffled()
        let instanceID = UUID().uuidString
        let balls = answerValues.enumerated().map { index, value in
            SoccerAnswerBall(
                id: SoccerBallID(rawValue: "\(instanceID).ball.\(index)"),
                representation: numberRepresentation(value),
                semanticValue: .integer(value)
            )
        }

        var targets: [SoccerChallengeTarget] = []
        targets.reserveCapacity(roundSize)
        for (index, ball) in balls.enumerated() {
            guard case .integer(let targetAnswer) = ball.semanticValue,
                  let problem = generateSoccerProblem(
                      for: request,
                      bound: bound,
                      targetAnswer: targetAnswer
                  ),
                  problem.answer == targetAnswer,
                  let prompt = Prompt(representations: [problem.prompt]) else {
                return nil
            }

            let challenge = Challenge(
                id: ChallengeID(rawValue: "\(instanceID).challenge.\(index)"),
                prompt: prompt,
                choices: [],
                interaction: .singleChoice,
                validationRule: .numericEquivalence,
                expectedAnswer: .semanticValue(.integer(targetAnswer)),
                primarySkill: request.primarySkill,
                secondarySkills: [],
                curriculumStage: request.curriculumStage,
                difficulty: request.difficulty
            )
            targets.append(SoccerChallengeTarget(
                challenge: challenge,
                intendedBallID: ball.id
            ))
        }

        return SoccerRound(
            id: SoccerRoundID(rawValue: "\(instanceID).round"),
            answerBalls: balls,
            challengeTargets: targets
        )
    }

    private func resolvedChoiceCount(
        _ requirement: ContentCountRequirement?
    ) -> Int? {
        guard let requirement else {
            return 4
        }
        guard requirement.kind == .choices,
              (2 ... 4).contains(requirement.count) else {
            return nil
        }
        return requirement.count
    }

    private func resolvedItemCount(
        _ requirement: ContentCountRequirement?
    ) -> Int? {
        guard let requirement else {
            return 4
        }
        guard requirement.kind == .items,
              (2 ... 6).contains(requirement.count) else {
            return nil
        }
        return requirement.count
    }

    private func resolvedSoccerRoundSize(
        _ requirement: ContentCountRequirement?,
        availableValueCount: Int
    ) -> Int? {
        let count: Int
        if let requirement {
            guard requirement.kind == .items else {
                return nil
            }
            count = requirement.count
        } else {
            count = 6
        }

        guard (6 ... 8).contains(count), count <= availableValueCount else {
            return nil
        }
        return count
    }

    private func resolvedStudyCardCount(
        _ requirement: ContentCountRequirement?,
        availableTargetCount: Int
    ) -> Int? {
        let count: Int
        if let requirement {
            guard requirement.kind == .items else {
                return nil
            }
            count = requirement.count
        } else {
            count = 6
        }

        guard count <= availableTargetCount else {
            return nil
        }
        return count
    }

    private func generationBound(for request: ChallengeRequest) -> Int? {
        let stage = request.curriculumStage.rawValue
        let skill = request.primarySkill

        if stage == "M1", skill == MathSkillIDs.quantityToNumber {
            return tieredBound(difficulty: request.difficulty, low: 5, medium: 8, high: 10)
        }
        if stage == "M2",
           skill == MathSkillIDs.addition || skill == MathSkillIDs.subtraction {
            return tieredBound(difficulty: request.difficulty, low: 5, medium: 8, high: 10)
        }
        if stage == "M3",
           skill == MathSkillIDs.addition ||
           skill == MathSkillIDs.subtraction ||
           skill == MathSkillIDs.missingAddend {
            return tieredBound(difficulty: request.difficulty, low: 10, medium: 15, high: 20)
        }
        return nil
    }

    private func comparableBound(for request: ChallengeRequest) -> Int? {
        guard request.primarySkill == MathSkillIDs.orderValues else {
            return nil
        }

        switch request.curriculumStage.rawValue {
        case "M1":
            return tieredBound(difficulty: request.difficulty, low: 5, medium: 8, high: 10)
        case "M2":
            return tieredBound(difficulty: request.difficulty, low: 5, medium: 8, high: 10)
        case "M3":
            return tieredBound(difficulty: request.difficulty, low: 10, medium: 15, high: 20)
        default:
            return nil
        }
    }

    private func equivalenceBound(for request: ChallengeRequest) -> Int? {
        guard request.primarySkill == MathSkillIDs.equivalentValues else {
            return nil
        }

        switch request.curriculumStage.rawValue {
        case "M1":
            return tieredBound(difficulty: request.difficulty, low: 5, medium: 8, high: 10)
        case "M2":
            return tieredBound(difficulty: request.difficulty, low: 5, medium: 8, high: 10)
        case "M3":
            return tieredBound(difficulty: request.difficulty, low: 10, medium: 15, high: 20)
        default:
            return nil
        }
    }

    private func tieredBound(
        difficulty: Difficulty,
        low: Int,
        medium: Int,
        high: Int
    ) -> Int {
        if difficulty.value <= 0.33 {
            return low
        }
        if difficulty.value <= 0.66 {
            return medium
        }
        return high
    }

    private func generateProblem(
        for request: ChallengeRequest,
        bound: Int
    ) -> GeneratedProblem? {
        if request.primarySkill == MathSkillIDs.quantityToNumber {
            let quantity = Int.random(in: 0 ... bound)
            return GeneratedProblem(
                prompt: quantityRepresentation(quantity),
                answer: quantity
            )
        }
        if request.primarySkill == MathSkillIDs.addition {
            let result = Int.random(in: 0 ... bound)
            let components = additionComponents(for: result)
            return GeneratedProblem(
                prompt: additionRepresentation(
                    lhs: components.lhs,
                    rhs: components.rhs
                ),
                answer: result
            )
        }
        if request.primarySkill == MathSkillIDs.subtraction {
            let result = Int.random(in: 0 ... bound)
            let components = subtractionComponents(for: result, bound: bound)
            return GeneratedProblem(
                prompt: subtractionRepresentation(
                    lhs: components.lhs,
                    rhs: components.rhs
                ),
                answer: result
            )
        }
        if request.primarySkill == MathSkillIDs.missingAddend {
            let components = randomMissingAddendComponents(bound: bound)
            return GeneratedProblem(
                prompt: missingAddendRepresentation(
                    knownAddend: components.knownAddend,
                    total: components.total
                ),
                answer: components.missingAddend
            )
        }
        return nil
    }

    private func studyConceptRepresentation(
        for request: ChallengeRequest,
        target: Int,
        bound: Int
    ) -> Representation? {
        if request.primarySkill == MathSkillIDs.quantityToNumber {
            return quantityRepresentation(target)
        }
        if request.primarySkill == MathSkillIDs.addition {
            let components = additionComponents(for: target)
            return additionRepresentation(lhs: components.lhs, rhs: components.rhs)
        }
        if request.primarySkill == MathSkillIDs.subtraction {
            let components = subtractionComponents(for: target, bound: bound)
            return subtractionRepresentation(lhs: components.lhs, rhs: components.rhs)
        }
        if request.primarySkill == MathSkillIDs.missingAddend {
            let components = missingAddendComponents(for: target, bound: bound)
            return missingAddendRepresentation(
                knownAddend: components.knownAddend,
                total: components.total
            )
        }
        return nil
    }

    private func generateBuildEquation(
        for request: ChallengeRequest,
        bound: Int
    ) -> GeneratedBuildEquation? {
        if request.primarySkill == MathSkillIDs.addition {
            let result = Int.random(in: 0 ... bound)
            let components = additionComponents(for: result)
            return GeneratedBuildEquation(
                lhs: components.lhs,
                operation: .addition,
                rhs: components.rhs,
                result: result,
                promptExpression: "\(components.lhs) + \(components.rhs) = \u{25A1}",
                promptStructureID: "math.equation.add.\(components.lhs).\(components.rhs).missingResult"
            )
        }
        if request.primarySkill == MathSkillIDs.subtraction {
            let result = Int.random(in: 0 ... bound)
            let components = subtractionComponents(for: result, bound: bound)
            return GeneratedBuildEquation(
                lhs: components.lhs,
                operation: .subtraction,
                rhs: components.rhs,
                result: result,
                promptExpression: "\(components.lhs) - \(components.rhs) = \u{25A1}",
                promptStructureID: "math.equation.subtract.\(components.lhs).\(components.rhs).missingResult"
            )
        }
        if request.primarySkill == MathSkillIDs.missingAddend {
            let components = randomMissingAddendComponents(bound: bound)
            return GeneratedBuildEquation(
                lhs: components.knownAddend,
                operation: .addition,
                rhs: components.missingAddend,
                result: components.total,
                promptExpression: "\(components.knownAddend) + \u{25A1} = \(components.total)",
                promptStructureID: "math.equation.missingAddend.\(components.knownAddend).\(components.total)"
            )
        }
        return nil
    }

    private func generateSoccerProblem(
        for request: ChallengeRequest,
        bound: Int,
        targetAnswer: Int
    ) -> GeneratedProblem? {
        if request.primarySkill == MathSkillIDs.quantityToNumber {
            return GeneratedProblem(
                prompt: quantityRepresentation(targetAnswer),
                answer: targetAnswer
            )
        }
        if request.primarySkill == MathSkillIDs.addition {
            let components = additionComponents(for: targetAnswer)
            return GeneratedProblem(
                prompt: additionRepresentation(
                    lhs: components.lhs,
                    rhs: components.rhs
                ),
                answer: targetAnswer
            )
        }
        if request.primarySkill == MathSkillIDs.subtraction {
            let components = subtractionComponents(for: targetAnswer, bound: bound)
            return GeneratedProblem(
                prompt: subtractionRepresentation(
                    lhs: components.lhs,
                    rhs: components.rhs
                ),
                answer: targetAnswer
            )
        }
        if request.primarySkill == MathSkillIDs.missingAddend {
            let components = missingAddendComponents(
                for: targetAnswer,
                bound: bound
            )
            return GeneratedProblem(
                prompt: missingAddendRepresentation(
                    knownAddend: components.knownAddend,
                    total: components.total
                ),
                answer: targetAnswer
            )
        }
        return nil
    }

    private func mathExpression(
        _ expression: String,
        structureID: String
    ) -> Representation {
        .mathExpression(MathExpressionRepresentation(
            expression: expression,
            structureID: RepresentationStructureID(rawValue: structureID)
        ))
    }

    private func numberRepresentation(_ value: Int) -> Representation {
        mathExpression(String(value), structureID: "math.number.\(value)")
    }

    private func quantityRepresentation(_ value: Int) -> Representation {
        .visualQuantity(VisualQuantityRepresentation(
            quantity: value,
            structureID: RepresentationStructureID(rawValue: "math.quantity.\(value)")
        ))
    }

    private func additionRepresentation(lhs: Int, rhs: Int) -> Representation {
        mathExpression(
            "\(lhs) + \(rhs)",
            structureID: "math.add.\(lhs).\(rhs)"
        )
    }

    private func subtractionRepresentation(lhs: Int, rhs: Int) -> Representation {
        mathExpression(
            "\(lhs) - \(rhs)",
            structureID: "math.subtract.\(lhs).\(rhs)"
        )
    }

    private func missingAddendRepresentation(
        knownAddend: Int,
        total: Int
    ) -> Representation {
        mathExpression(
            "\(knownAddend) + \u{25A1} = \(total)",
            structureID: "math.missingAddend.\(knownAddend).\(total)"
        )
    }

    private func operatorRepresentation(_ operation: BuildOperation) -> Representation {
        switch operation {
        case .addition:
            return mathExpression("+", structureID: "math.operator.add")
        case .subtraction:
            return mathExpression("-", structureID: "math.operator.subtract")
        }
    }

    private func comparableRepresentation(
        for value: Int,
        itemIndex: Int,
        stage: CurriculumStageID,
        bound: Int
    ) -> Representation {
        if stage.rawValue == "M1" {
            return quantityRepresentation(value)
        }

        guard stage.rawValue == "M3" else {
            return numberRepresentation(value)
        }

        if itemIndex.isMultiple(of: 2) {
            let components = additionComponents(for: value)
            return additionRepresentation(
                lhs: components.lhs,
                rhs: components.rhs
            )
        }

        let components = subtractionComponents(for: value, bound: bound)
        return subtractionRepresentation(
            lhs: components.lhs,
            rhs: components.rhs
        )
    }

    private func additionComponents(for target: Int) -> (lhs: Int, rhs: Int) {
        let lhs = Int.random(in: 0 ... target)
        return (lhs, target - lhs)
    }

    private func subtractionComponents(
        for target: Int,
        bound: Int
    ) -> (lhs: Int, rhs: Int) {
        let rhs = Int.random(in: 0 ... (bound - target))
        return (target + rhs, rhs)
    }

    private func missingAddendComponents(
        for target: Int,
        bound: Int
    ) -> (knownAddend: Int, total: Int) {
        let knownAddend = Int.random(in: 0 ... (bound - target))
        return (knownAddend, knownAddend + target)
    }

    private func randomMissingAddendComponents(
        bound: Int
    ) -> (knownAddend: Int, missingAddend: Int, total: Int) {
        let total = Int.random(in: 0 ... bound)
        let knownAddend = Int.random(in: 0 ... total)
        return (knownAddend, total - knownAddend, total)
    }

    private func nearbyChoiceValues(
        correctAnswer: Int,
        count: Int,
        bound: Int
    ) -> [Int] {
        var values = [correctAnswer]
        var distance = 1

        while values.count < count, distance <= bound {
            let lower = correctAnswer - distance
            let upper = correctAnswer + distance

            if lower >= 0 {
                values.append(lower)
            }
            if values.count < count, upper <= bound {
                values.append(upper)
            }
            distance += 1
        }

        return values
    }
}

private struct GeneratedProblem {
    let prompt: Representation
    let answer: Int
}

private enum BuildOperation {
    case addition
    case subtraction
}

private struct GeneratedBuildEquation {
    let lhs: Int
    let operation: BuildOperation
    let rhs: Int
    let result: Int
    let promptExpression: String
    let promptStructureID: String
}
