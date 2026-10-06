import XCTest
@testable import MinikPlus

final class MathContentProviderTests: XCTestCase {
    private let provider = MathContentProvider()

    func testMathContentProviderConformsToContentProvider() {
        assertContentProvider(provider)
    }

    func testMathContentProviderConformsToStudyContentProviding() {
        assertStudyContentProvider(provider)
    }

    func testMathContentProviderConformsToComparableContentProviding() {
        assertComparableContentProvider(provider)
    }

    func testMathContentProviderConformsToEquivalenceContentProviding() {
        assertEquivalenceContentProvider(provider)
    }

    func testMathContentProviderConformsToBuildContentProviding() {
        assertBuildContentProvider(provider)
    }

    func testMathContentProviderConformsToSoccerContentProviding() {
        assertSoccerContentProvider(provider)
    }

    func testStudyRejectsUnsupportedRequestShapes() throws {
        let nonLearnRequest = try makeStudyRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            activityType: .multipleChoice
        )
        let interactiveRequest = try makeStudyRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            interaction: .singleChoice
        )
        let unsupportedStageRequest = try makeStudyRequest(
            stage: "M4",
            skill: MathSkillIDs.addition
        )
        let unsupportedSkillRequest = try makeStudyRequest(
            stage: "M2",
            skill: MathSkillIDs.missingAddend
        )
        let orderingSkillRequest = try makeStudyRequest(
            stage: "M2",
            skill: MathSkillIDs.orderValues
        )
        let equivalenceSkillRequest = try makeStudyRequest(
            stage: "M3",
            skill: MathSkillIDs.equivalentValues
        )

        XCTAssertEqual(provider.studyCards(for: nonLearnRequest), [])
        XCTAssertEqual(provider.studyCards(for: interactiveRequest), [])
        XCTAssertEqual(provider.studyCards(for: unsupportedStageRequest), [])
        XCTAssertEqual(provider.studyCards(for: unsupportedSkillRequest), [])
        XCTAssertEqual(provider.studyCards(for: orderingSkillRequest), [])
        XCTAssertEqual(provider.studyCards(for: equivalenceSkillRequest), [])
    }

    func testStudySupportedStageSkillMatrix() throws {
        let supported: [(String, SkillID)] = [
            ("M1", MathSkillIDs.quantityToNumber),
            ("M2", MathSkillIDs.addition),
            ("M2", MathSkillIDs.subtraction),
            ("M3", MathSkillIDs.addition),
            ("M3", MathSkillIDs.subtraction),
            ("M3", MathSkillIDs.missingAddend)
        ]

        for (stage, skill) in supported {
            let request = try makeStudyRequest(stage: stage, skill: skill)
            XCTAssertFalse(provider.studyCards(for: request).isEmpty)
        }
    }

    func testStudyCountRequirementsAreValidatedAgainstAvailableTargets() throws {
        let defaultRequest = try makeStudyRequest(
            stage: "M2",
            skill: MathSkillIDs.addition
        )
        let eightItems = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 8))
        let explicitRequest = try makeStudyRequest(
            stage: "M3",
            skill: MathSkillIDs.addition,
            countRequirement: eightItems
        )
        let choices = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 6))
        let choicesRequest = try makeStudyRequest(
            stage: "M3",
            skill: MathSkillIDs.addition,
            countRequirement: choices
        )
        let sevenItems = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 7))
        let unsatisfiableRequest = try makeStudyRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            difficulty: 0.2,
            countRequirement: sevenItems
        )

        XCTAssertEqual(provider.studyCards(for: defaultRequest).count, 6)
        XCTAssertEqual(provider.studyCards(for: explicitRequest).count, 8)
        XCTAssertEqual(provider.studyCards(for: choicesRequest), [])
        XCTAssertEqual(provider.studyCards(for: unsatisfiableRequest), [])
    }

    func testStudyCardsPreserveIdentityMetadataAndDistinctBoundedTargets() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 8))
        let request = try makeStudyRequest(
            stage: "M3",
            skill: MathSkillIDs.addition,
            difficulty: 0.5,
            countRequirement: count
        )
        let cards = provider.studyCards(for: request)
        let directValues = try cards.map { try studyDirectNumber(from: $0).value }

        XCTAssertEqual(cards.count, 8)
        XCTAssertEqual(Set(cards.map(\.id)).count, cards.count)
        XCTAssertEqual(Set(directValues).count, directValues.count)
        XCTAssertTrue(directValues.allSatisfy((0 ... 15).contains))

        for card in cards {
            let direct = try studyDirectNumber(from: card)
            XCTAssertEqual(card.representations.count, 2)
            XCTAssertEqual(card.primarySkill, request.primarySkill)
            XCTAssertTrue(card.secondarySkills.isEmpty)
            XCTAssertEqual(card.curriculumStage, request.curriculumStage)
            XCTAssertNotEqual(card.id.rawValue, direct.representation.expression)
            XCTAssertNotEqual(card.id.rawValue, direct.representation.structureID.rawValue)
        }
    }

    func testM1StudyCardsPairQuantityWithDirectNumber() throws {
        let request = try makeStudyRequest(
            stage: "M1",
            skill: MathSkillIDs.quantityToNumber,
            difficulty: 0.2
        )
        let cards = provider.studyCards(for: request)

        for card in cards {
            let direct = try studyDirectNumber(from: card)
            guard case .visualQuantity(let quantity) = card.representations[0] else {
                return XCTFail("Expected quantity as the first M1 Study representation.")
            }
            XCTAssertEqual(quantity.quantity, direct.value)
            XCTAssertEqual(quantity.structureID.rawValue, "math.quantity.\(direct.value)")
            XCTAssertEqual(direct.representation.expression, String(direct.value))
            XCTAssertEqual(direct.representation.structureID.rawValue, "math.number.\(direct.value)")
        }
    }

    func testAdditionStudyCardsMatchDirectSemanticValues() throws {
        let request = try makeStudyRequest(
            stage: "M3",
            skill: MathSkillIDs.addition,
            difficulty: 1
        )

        for _ in 0 ..< 25 {
            let cards = provider.studyCards(for: request)
            for card in cards {
                let direct = try studyDirectNumber(from: card)
                let expression = try studyConceptExpression(from: card)
                let components = try ordinaryBinaryComponents(
                    from: expression,
                    operation: "add"
                )
                XCTAssertEqual(components.lhs + components.rhs, direct.value)
                XCTAssertEqual(expression.expression, "\(components.lhs) + \(components.rhs)")
            }
        }
    }

    func testSubtractionStudyCardsMatchDirectSemanticValuesAndBounds() throws {
        let request = try makeStudyRequest(
            stage: "M2",
            skill: MathSkillIDs.subtraction,
            difficulty: 0.5
        )

        for _ in 0 ..< 25 {
            let cards = provider.studyCards(for: request)
            for card in cards {
                let direct = try studyDirectNumber(from: card)
                let expression = try studyConceptExpression(from: card)
                let components = try ordinaryBinaryComponents(
                    from: expression,
                    operation: "subtract"
                )
                XCTAssertGreaterThanOrEqual(components.lhs, components.rhs)
                XCTAssertEqual(components.lhs - components.rhs, direct.value)
                XCTAssertTrue((0 ... 8).contains(components.lhs))
                XCTAssertTrue((0 ... 8).contains(components.rhs))
                XCTAssertEqual(expression.expression, "\(components.lhs) - \(components.rhs)")
            }
        }
    }

    func testMissingAddendStudyCardsUseDirectNumberAsMissingOperand() throws {
        let request = try makeStudyRequest(
            stage: "M3",
            skill: MathSkillIDs.missingAddend,
            difficulty: 1
        )

        for _ in 0 ..< 25 {
            let cards = provider.studyCards(for: request)
            for card in cards {
                let direct = try studyDirectNumber(from: card)
                let expression = try studyConceptExpression(from: card)
                let parts = expression.structureID.rawValue.split(separator: ".")
                guard parts.count == 4,
                      parts[0] == "math",
                      parts[1] == "missingAddend",
                      let knownAddend = Int(parts[2]),
                      let total = Int(parts[3]) else {
                    throw TestError.unexpectedStructure
                }

                XCTAssertEqual(knownAddend + direct.value, total)
                XCTAssertTrue((0 ... 20).contains(total))
                XCTAssertEqual(expression.expression, "\(knownAddend) + \u{25A1} = \(total)")
                XCTAssertTrue(expression.expression.contains("\u{25A1}"))
            }
        }
    }

    func testEquivalenceUnsupportedStageReturnsEmpty() throws {
        let request = try makeEquivalenceRequest(stage: "M4")

        XCTAssertEqual(provider.equivalenceSets(for: request), [])
    }

    func testEquivalenceUnsupportedSkillStageCombinationReturnsEmpty() throws {
        let request = try makeEquivalenceRequest(stage: "M2", skill: MathSkillIDs.addition)

        XCTAssertEqual(provider.equivalenceSets(for: request), [])
    }

    func testEquivalenceRejectsUnsupportedActivity() throws {
        let request = try makeEquivalenceRequest(stage: "M2", activityType: .tower)

        XCTAssertEqual(provider.equivalenceSets(for: request), [])
    }

    func testEquivalenceRejectsUnsupportedInteraction() throws {
        let request = try makeEquivalenceRequest(stage: "M2", interaction: .orderedTokens)

        XCTAssertEqual(provider.equivalenceSets(for: request), [])
    }

    func testPairsAndMemoryAreAccepted() throws {
        for activity in [ActivityType.pairs, .memory] {
            let request = try makeEquivalenceRequest(stage: "M2", activityType: activity)
            XCTAssertFalse(provider.equivalenceSets(for: request).isEmpty)
        }
    }

    func testMissingEquivalenceCountDefaultsToFourSets() throws {
        let request = try makeEquivalenceRequest(stage: "M2")
        let sets = provider.equivalenceSets(for: request)

        XCTAssertEqual(sets.count, 4)
    }

    func testExplicitEquivalenceItemCountIsHonored() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 6))
        let request = try makeEquivalenceRequest(
            stage: "M3",
            countRequirement: count
        )
        let sets = provider.equivalenceSets(for: request)

        XCTAssertEqual(sets.count, 6)
    }

    func testEquivalenceRejectsChoiceCountRequirement() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 4))
        let request = try makeEquivalenceRequest(stage: "M2", countRequirement: count)

        XCTAssertEqual(provider.equivalenceSets(for: request), [])
    }

    func testEquivalenceRejectsItemCountBelowTwo() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 1))
        let request = try makeEquivalenceRequest(stage: "M2", countRequirement: count)

        XCTAssertEqual(provider.equivalenceSets(for: request), [])
    }

    func testEquivalenceRejectsItemCountAboveSix() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 7))
        let request = try makeEquivalenceRequest(stage: "M3", countRequirement: count)

        XCTAssertEqual(provider.equivalenceSets(for: request), [])
    }

    func testGeneratedEquivalenceSemanticValuesAreDistinct() throws {
        for _ in 0 ..< 75 {
            let request = try makeEquivalenceRequest(stage: "M3")
            let sets = provider.equivalenceSets(for: request)
            XCTAssertEqual(Set(sets.map(\.semanticValue)).count, sets.count)
        }
    }

    func testEveryEquivalenceSetContainsTwoDistinctRepresentations() throws {
        let request = try makeEquivalenceRequest(stage: "M3")
        let sets = provider.equivalenceSets(for: request)

        for set in sets {
            XCTAssertEqual(set.representations.count, 2)
            XCTAssertEqual(Set(set.representations).count, 2)
        }
    }

    func testM2EquivalenceUsesDirectNumberAndVisualQuantity() throws {
        let request = try makeEquivalenceRequest(stage: "M2")
        let sets = provider.equivalenceSets(for: request)

        for set in sets {
            let value = try semanticInteger(from: set)
            guard case .mathExpression(let direct) = set.representations[0],
                  case .visualQuantity(let quantity) = set.representations[1] else {
                return XCTFail("Expected direct-number and visual-quantity representations.")
            }
            XCTAssertEqual(direct.expression, String(value))
            XCTAssertEqual(direct.structureID.rawValue, "math.number.\(value)")
            XCTAssertEqual(quantity.quantity, value)
            XCTAssertEqual(quantity.structureID.rawValue, "math.quantity.\(value)")
        }
    }

    func testM2EquivalenceValuesStayInsideDifficultyBounds() throws {
        let cases: [(Double, Int)] = [(0.2, 5), (0.5, 8), (1, 10)]

        for (difficulty, bound) in cases {
            for _ in 0 ..< 50 {
                let request = try makeEquivalenceRequest(
                    stage: "M2",
                    difficulty: difficulty
                )
                let sets = provider.equivalenceSets(for: request)
                for set in sets {
                    XCTAssertTrue((0 ... bound).contains(try semanticInteger(from: set)))
                }
            }
        }
    }

    func testM3EquivalenceUsesDirectAndArithmeticExpressions() throws {
        let request = try makeEquivalenceRequest(stage: "M3")
        let sets = provider.equivalenceSets(for: request)

        for set in sets {
            let value = try semanticInteger(from: set)
            guard case .mathExpression(let direct) = set.representations[0],
                  case .mathExpression(let arithmetic) = set.representations[1] else {
                return XCTFail("Expected direct-number and arithmetic representations.")
            }
            XCTAssertEqual(direct.structureID.rawValue, "math.number.\(value)")
            XCTAssertTrue(
                arithmetic.structureID.rawValue.hasPrefix("math.add.") ||
                arithmetic.structureID.rawValue.hasPrefix("math.subtract.")
            )
        }
    }

    func testM3EquivalenceAdditionComponentsMatchSemanticValue() throws {
        for _ in 0 ..< 50 {
            let request = try makeEquivalenceRequest(stage: "M3")
            let sets = provider.equivalenceSets(for: request)
            let set = try XCTUnwrap(sets.first { hasArithmeticPrefix($0, "math.add.") })
            let operands = try equivalenceArithmeticComponents(from: set, prefix: "math.add")

            XCTAssertEqual(operands.first + operands.second, try semanticInteger(from: set))
        }
    }

    func testM3EquivalenceSubtractionComponentsMatchSemanticValue() throws {
        for _ in 0 ..< 50 {
            let request = try makeEquivalenceRequest(stage: "M3")
            let sets = provider.equivalenceSets(for: request)
            let set = try XCTUnwrap(sets.first { hasArithmeticPrefix($0, "math.subtract.") })
            let operands = try equivalenceArithmeticComponents(from: set, prefix: "math.subtract")
            let semanticValue = try semanticInteger(from: set)

            XCTAssertEqual(operands.first - operands.second, semanticValue)
            XCTAssertGreaterThanOrEqual(semanticValue, 0)
        }
    }

    func testM3EquivalenceOperandsStayInsideDifficultyBound() throws {
        let request = try makeEquivalenceRequest(
            stage: "M3",
            difficulty: 0.5
        )
        let sets = provider.equivalenceSets(for: request)

        for set in sets {
            let operands = try equivalenceArithmeticComponents(from: set)
            XCTAssertTrue((0 ... 15).contains(operands.first))
            XCTAssertTrue((0 ... 15).contains(operands.second))
        }
    }

    func testM3RequestContainsAdditionAndSubtractionFormsDeterministically() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 2))
        let request = try makeEquivalenceRequest(
            stage: "M3",
            countRequirement: count
        )
        let sets = provider.equivalenceSets(for: request)

        XCTAssertTrue(sets.contains { hasArithmeticPrefix($0, "math.add.") })
        XCTAssertTrue(sets.contains { hasArithmeticPrefix($0, "math.subtract.") })
    }

    func testTowerUnsupportedStageReturnsNil() throws {
        let request = try makeTowerRequest(stage: "M4")

        XCTAssertNil(provider.comparableSet(for: request))
    }

    func testTowerUnsupportedSkillStageCombinationReturnsNil() throws {
        let request = try makeTowerRequest(stage: "M2", skill: MathSkillIDs.addition)

        XCTAssertNil(provider.comparableSet(for: request))
    }

    func testComparableSetRejectsNonTowerActivity() throws {
        let request = try makeTowerRequest(stage: "M2", activityType: .multipleChoice)

        XCTAssertNil(provider.comparableSet(for: request))
    }

    func testComparableSetRejectsUnsupportedInteraction() throws {
        let request = try makeTowerRequest(stage: "M2", interaction: .singleChoice)

        XCTAssertNil(provider.comparableSet(for: request))
    }

    func testMissingTowerItemCountDefaultsToFour() throws {
        let request = try makeTowerRequest(stage: "M2")
        let set = try XCTUnwrap(provider.comparableSet(for: request))

        XCTAssertEqual(set.items.count, 4)
    }

    func testExplicitTowerItemCountIsHonored() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 5))
        let request = try makeTowerRequest(
            stage: "M3",
            countRequirement: count
        )
        let set = try XCTUnwrap(provider.comparableSet(for: request))

        XCTAssertEqual(set.items.count, 5)
    }

    func testTowerRejectsChoiceCountRequirement() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 4))
        let request = try makeTowerRequest(stage: "M2", countRequirement: count)

        XCTAssertNil(provider.comparableSet(for: request))
    }

    func testTowerRejectsItemCountBelowTwo() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 1))
        let request = try makeTowerRequest(stage: "M2", countRequirement: count)

        XCTAssertNil(provider.comparableSet(for: request))
    }

    func testTowerRejectsItemCountAboveSix() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 7))
        let request = try makeTowerRequest(stage: "M3", countRequirement: count)

        XCTAssertNil(provider.comparableSet(for: request))
    }

    func testComparableItemIDsAreUnique() throws {
        for _ in 0 ..< 75 {
            let request = try makeTowerRequest(stage: "M3")
            let set = try XCTUnwrap(provider.comparableSet(for: request))
            XCTAssertEqual(Set(set.items.map(\.id)).count, set.items.count)
        }
    }

    func testComparableValuesAreUnique() throws {
        for _ in 0 ..< 75 {
            let request = try makeTowerRequest(stage: "M3")
            let set = try XCTUnwrap(provider.comparableSet(for: request))
            XCTAssertEqual(Set(set.items.map(\.comparisonValue)).count, set.items.count)
        }
    }

    func testComparableValuesStayInsideDifficultyBounds() throws {
        let cases: [(String, Double, Int)] = [
            ("M2", 0.2, 5),
            ("M2", 0.5, 8),
            ("M2", 1, 10),
            ("M3", 0.2, 10),
            ("M3", 0.5, 15),
            ("M3", 1, 20)
        ]

        for (stage, difficulty, bound) in cases {
            for _ in 0 ..< 50 {
                let request = try makeTowerRequest(
                    stage: stage,
                    difficulty: difficulty
                )
                let set = try XCTUnwrap(provider.comparableSet(for: request))
                for item in set.items {
                    XCTAssertTrue((0 ... bound).contains(try integerValue(from: item)))
                }
            }
        }
    }

    func testM2ComparableRepresentationsAreDirectNumbers() throws {
        let request = try makeTowerRequest(stage: "M2")
        let set = try XCTUnwrap(provider.comparableSet(for: request))

        for item in set.items {
            let value = try integerValue(from: item)
            let expression = try expression(from: item)
            XCTAssertEqual(expression.expression, String(value))
            XCTAssertEqual(expression.structureID.rawValue, "math.number.\(value)")
        }
    }

    func testM2ComparisonValueCarriesMeaningWithoutExpressionParsing() throws {
        let request = try makeTowerRequest(stage: "M2")
        let set = try XCTUnwrap(provider.comparableSet(for: request))

        for item in set.items {
            guard case .integer(let value) = item.comparisonValue else {
                return XCTFail("Expected an exact integer comparison value.")
            }
            XCTAssertTrue(value >= 0)
        }
    }

    func testM3UsesArithmeticExpressionRepresentations() throws {
        let request = try makeTowerRequest(stage: "M3")
        let set = try XCTUnwrap(provider.comparableSet(for: request))

        for item in set.items {
            let structure = try expression(from: item).structureID.rawValue
            XCTAssertTrue(structure.hasPrefix("math.add.") || structure.hasPrefix("math.subtract."))
        }
    }

    func testM3AdditionComponentsProduceComparisonValue() throws {
        for _ in 0 ..< 50 {
            let request = try makeTowerRequest(stage: "M3")
            let set = try XCTUnwrap(provider.comparableSet(for: request))
            let addition = try XCTUnwrap(set.items.first { hasStructurePrefix($0, "math.add.") })
            let components = try structureComponents(from: addition, prefix: "math.add")

            XCTAssertEqual(components.first + components.second, try integerValue(from: addition))
        }
    }

    func testM3SubtractionComponentsProduceComparisonValue() throws {
        for _ in 0 ..< 50 {
            let request = try makeTowerRequest(stage: "M3")
            let set = try XCTUnwrap(provider.comparableSet(for: request))
            let subtraction = try XCTUnwrap(set.items.first {
                hasStructurePrefix($0, "math.subtract.")
            })
            let components = try structureComponents(from: subtraction, prefix: "math.subtract")

            XCTAssertEqual(components.first - components.second, try integerValue(from: subtraction))
        }
    }

    func testM3SubtractionNeverRepresentsNegativeResult() throws {
        let request = try makeTowerRequest(stage: "M3")
        let set = try XCTUnwrap(provider.comparableSet(for: request))

        for item in set.items where hasStructurePrefix(item, "math.subtract.") {
            XCTAssertGreaterThanOrEqual(try integerValue(from: item), 0)
        }
    }

    func testM3OperandsStayInsideGenerationBound() throws {
        let request = try makeTowerRequest(
            stage: "M3",
            difficulty: 0.5
        )
        let set = try XCTUnwrap(provider.comparableSet(for: request))

        for item in set.items {
            let components = try structureComponents(from: item)
            XCTAssertTrue((0 ... 15).contains(components.first))
            XCTAssertTrue((0 ... 15).contains(components.second))
        }
    }

    func testUnsupportedCurriculumStageReturnsNil() throws {
        let request = try makeRequest(stage: "M4", skill: MathSkillIDs.addition)

        XCTAssertNil(provider.challenge(for: request))
    }

    func testUnsupportedSkillStageCombinationReturnsNil() throws {
        let request = try makeRequest(stage: "M1", skill: MathSkillIDs.addition)

        XCTAssertNil(provider.challenge(for: request))
    }

    func testUnsupportedActivityTypeReturnsNil() throws {
        let request = try makeRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            activityType: .soccer
        )

        XCTAssertNil(provider.challenge(for: request))
    }

    func testUnsupportedInteractionReturnsNil() throws {
        let request = try makeRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            interaction: .numericInput
        )

        XCTAssertNil(provider.challenge(for: request))
    }

    func testItemCountRequirementIsRejected() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 3))
        let request = try makeRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            countRequirement: count
        )

        XCTAssertNil(provider.challenge(for: request))
    }

    func testChoiceCountBelowTwoIsRejected() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 1))
        let request = try makeRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            countRequirement: count
        )

        XCTAssertNil(provider.challenge(for: request))
    }

    func testMissingChoiceCountDefaultsToFour() throws {
        let request = try makeRequest(stage: "M2", skill: MathSkillIDs.addition)
        let challenge = try XCTUnwrap(provider.challenge(for: request))

        XCTAssertEqual(challenge.choices.count, 4)
    }

    func testExplicitValidChoiceCountIsHonored() throws {
        let count = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 3))
        let request = try makeRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            countRequirement: count
        )
        let challenge = try XCTUnwrap(provider.challenge(for: request))

        XCTAssertEqual(challenge.choices.count, 3)
    }

    func testGeneratedChoiceIDsAreUnique() throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: "M3",
                skill: MathSkillIDs.addition,
                difficulty: 1
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            XCTAssertEqual(Set(challenge.choices.map(\.id)).count, challenge.choices.count)
        }
    }

    func testGeneratedChoiceSemanticValuesAreUnique() throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: "M3",
                skill: MathSkillIDs.subtraction,
                difficulty: 1
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            XCTAssertEqual(Set(challenge.choices.map(\.semanticValue)).count, challenge.choices.count)
        }
    }

    func testGeneratedChoicesUseDistinctNumericRepresentations() throws {
        let request = try makeRequest(
            stage: "M2",
            skill: MathSkillIDs.addition
        )
        let challenge = try XCTUnwrap(provider.challenge(for: request))
        var displayedValues = Set<String>()

        for choice in challenge.choices {
            guard case .mathExpression(let representation) = choice.representation else {
                return XCTFail("Expected a numeric Math representation.")
            }
            displayedValues.insert(representation.expression)
        }

        XCTAssertEqual(displayedValues.count, challenge.choices.count)
    }

    func testExpectedAnswerAppearsExactlyOnceAmongChoices() throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: "M3",
                skill: MathSkillIDs.missingAddend,
                difficulty: 1
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            let expected = try expectedInteger(from: challenge)
            XCTAssertEqual(
                challenge.choices.filter { $0.semanticValue == .integer(expected) }.count,
                1
            )
        }
    }

    func testQuantityToNumberUsesVisualQuantityPrompt() throws {
        let request = try makeRequest(
            stage: "M1",
            skill: MathSkillIDs.quantityToNumber
        )
        let challenge = try XCTUnwrap(provider.challenge(for: request))

        guard case .visualQuantity(let visual) = challenge.prompt.representations.first else {
            return XCTFail("Expected a visual quantity prompt.")
        }
        XCTAssertEqual(try expectedInteger(from: challenge), visual.quantity)
    }

    func testM1LowDifficultyDoesNotExceedFive() throws {
        try assertGeneratedAnswers(
            stage: "M1",
            skill: MathSkillIDs.quantityToNumber,
            difficulty: 0.2,
            areWithin: 0 ... 5
        )
    }

    func testM1HighDifficultyDoesNotExceedTen() throws {
        try assertGeneratedAnswers(
            stage: "M1",
            skill: MathSkillIDs.quantityToNumber,
            difficulty: 1,
            areWithin: 0 ... 10
        )
    }

    func testM2AdditionResultStaysWithinDifficultyBound() throws {
        try assertGeneratedAnswers(
            stage: "M2",
            skill: MathSkillIDs.addition,
            difficulty: 0.2,
            areWithin: 0 ... 5
        )
    }

    func testM2SubtractionNeverProducesNegativeAnswer() throws {
        try assertGeneratedAnswers(
            stage: "M2",
            skill: MathSkillIDs.subtraction,
            difficulty: 1,
            areWithin: 0 ... 10
        )
    }

    func testM3ArithmeticRespectsHighDifficultyBound() throws {
        try assertGeneratedAnswers(
            stage: "M3",
            skill: MathSkillIDs.addition,
            difficulty: 1,
            areWithin: 0 ... 20
        )
        try assertGeneratedAnswers(
            stage: "M3",
            skill: MathSkillIDs.subtraction,
            difficulty: 1,
            areWithin: 0 ... 20
        )
    }

    func testM3MissingAddendAnswerIsMissingOperandRatherThanTotal() throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: "M3",
                skill: MathSkillIDs.missingAddend,
                difficulty: 1
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            let structure = try mathStructure(from: challenge)
            let components = structure.rawValue.split(separator: ".")
            let knownAddend = try XCTUnwrap(Int(components[2]))
            let total = try XCTUnwrap(Int(components[3]))

            XCTAssertEqual(try expectedInteger(from: challenge), total - knownAddend)
        }
    }

    func testOrdinaryAdditionPromptMatchesStructureAndSemanticAnswer() throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: "M3",
                skill: MathSkillIDs.addition,
                difficulty: 1
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            let prompt = try ordinaryMathPrompt(from: challenge)
            let components = try ordinaryBinaryComponents(
                from: prompt,
                operation: "add"
            )

            XCTAssertEqual(components.lhs + components.rhs, try expectedInteger(from: challenge))
            XCTAssertEqual(prompt.expression, "\(components.lhs) + \(components.rhs)")
        }
    }

    func testOrdinarySubtractionPromptMatchesStructureAndSemanticAnswer() throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: "M3",
                skill: MathSkillIDs.subtraction,
                difficulty: 1
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            let prompt = try ordinaryMathPrompt(from: challenge)
            let components = try ordinaryBinaryComponents(
                from: prompt,
                operation: "subtract"
            )

            XCTAssertGreaterThanOrEqual(components.lhs, components.rhs)
            XCTAssertEqual(components.lhs - components.rhs, try expectedInteger(from: challenge))
            XCTAssertEqual(prompt.expression, "\(components.lhs) - \(components.rhs)")
        }
    }

    func testOrdinaryMissingAddendPromptMatchesStructureAndSemanticAnswer() throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: "M3",
                skill: MathSkillIDs.missingAddend,
                difficulty: 1
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            let prompt = try ordinaryMathPrompt(from: challenge)
            let parts = prompt.structureID.rawValue.split(separator: ".")
            guard parts.count == 4,
                  parts[0] == "math",
                  parts[1] == "missingAddend",
                  let knownAddend = Int(parts[2]),
                  let total = Int(parts[3]) else {
                throw TestError.unexpectedStructure
            }
            let missingAddend = try expectedInteger(from: challenge)

            XCTAssertEqual(knownAddend + missingAddend, total)
            XCTAssertEqual(prompt.expression, "\(knownAddend) + \u{25A1} = \(total)")
            XCTAssertTrue(prompt.expression.contains("\u{25A1}"))
        }
    }

    func testGeneratedArithmeticUsesNumericEquivalenceValidation() throws {
        for skill in [
            MathSkillIDs.addition,
            MathSkillIDs.subtraction,
            MathSkillIDs.missingAddend
        ] {
            let request = try makeRequest(
                stage: "M3",
                skill: skill
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            XCTAssertEqual(challenge.validationRule, .numericEquivalence)
        }
    }

    func testGeneratedArithmeticUsesSemanticExpectedAnswer() throws {
        for skill in [
            MathSkillIDs.addition,
            MathSkillIDs.subtraction,
            MathSkillIDs.missingAddend
        ] {
            let request = try makeRequest(
                stage: "M3",
                skill: skill
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            guard case .semanticValue(.integer) = challenge.expectedAnswer else {
                return XCTFail("Expected an integer semantic answer.")
            }
        }
    }

    func testGeneratedChallengePreservesRequestedMetadata() throws {
        let difficulty = try XCTUnwrap(Difficulty(0.52))
        let request = ChallengeRequest(
            activityType: .multipleChoice,
            curriculumStage: CurriculumStageID(rawValue: "M3"),
            primarySkill: MathSkillIDs.subtraction,
            difficulty: difficulty,
            interaction: .singleChoice,
            countRequirement: nil
        )
        let challenge = try XCTUnwrap(provider.challenge(for: request))

        XCTAssertEqual(challenge.primarySkill, request.primarySkill)
        XCTAssertEqual(challenge.curriculumStage, request.curriculumStage)
        XCTAssertEqual(challenge.difficulty, request.difficulty)
    }

    func testDistractorsRemainNonnegativeAndInsideGenerationRange() throws {
        let cases: [(String, SkillID, Double, Int)] = [
            ("M1", MathSkillIDs.quantityToNumber, 0.2, 5),
            ("M2", MathSkillIDs.addition, 0.5, 8),
            ("M2", MathSkillIDs.subtraction, 1, 10),
            ("M3", MathSkillIDs.addition, 0.2, 10),
            ("M3", MathSkillIDs.subtraction, 1, 20),
            ("M3", MathSkillIDs.missingAddend, 0.5, 15)
        ]

        for (stage, skill, difficulty, bound) in cases {
            for _ in 0 ..< 50 {
                let request = try makeRequest(
                    stage: stage,
                    skill: skill,
                    difficulty: difficulty
                )
                let challenge = try XCTUnwrap(provider.challenge(for: request))
                for choice in challenge.choices {
                    guard case .integer(let value) = choice.semanticValue else {
                        return XCTFail("Expected integer choice semantics.")
                    }
                    XCTAssertTrue((0 ... bound).contains(value))
                }
            }
        }
    }

    func testBuildRejectsUnsupportedStage() throws {
        let request = try makeBuildRequest(
            stage: "M4",
            skill: MathSkillIDs.addition
        )
        XCTAssertNil(provider.buildChallenge(for: request))
    }

    func testBuildRejectsUnsupportedStageSkillCombination() throws {
        let request = try makeBuildRequest(
            stage: "M2",
            skill: MathSkillIDs.missingAddend
        )
        XCTAssertNil(provider.buildChallenge(for: request))
    }

    func testBuildRejectsNonBuildActivity() throws {
        let request = try makeBuildRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            activityType: .multipleChoice
        )
        XCTAssertNil(provider.buildChallenge(for: request))
    }

    func testBuildRejectsUnsupportedInteraction() throws {
        let request = try makeBuildRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            interaction: .singleChoice
        )
        XCTAssertNil(provider.buildChallenge(for: request))
    }

    func testBuildRejectsAnyCountRequirement() throws {
        for kind in [ContentCountKind.items, .choices] {
            let requirement = try XCTUnwrap(ContentCountRequirement(kind: kind, count: 4))
            let request = try makeBuildRequest(
                stage: "M2",
                skill: MathSkillIDs.addition,
                countRequirement: requirement
            )
            XCTAssertNil(provider.buildChallenge(for: request))
        }
    }

    func testSupportedBuildStageSkillMatrix() throws {
        let supported: [(String, SkillID)] = [
            ("M2", MathSkillIDs.addition),
            ("M2", MathSkillIDs.subtraction),
            ("M3", MathSkillIDs.addition),
            ("M3", MathSkillIDs.subtraction),
            ("M3", MathSkillIDs.missingAddend)
        ]

        for (stage, skill) in supported {
            let request = try makeBuildRequest(
                stage: stage,
                skill: skill
            )
            XCTAssertNotNil(provider.buildChallenge(for: request))
        }
    }

    func testBuildChallengeHasFiveUniqueTokensAndExpectedIDs() throws {
        let request = try makeBuildRequest(
            stage: "M3",
            skill: MathSkillIDs.addition
        )
        let challenge = try XCTUnwrap(provider.buildChallenge(for: request))
        let availableIDs = Set(challenge.availableTokens.map(\.id))

        XCTAssertEqual(challenge.availableTokens.count, 5)
        XCTAssertEqual(availableIDs.count, 5)
        XCTAssertEqual(challenge.expectedTokenSequence.count, 5)
        XCTAssertEqual(Set(challenge.expectedTokenSequence).count, 5)
        XCTAssertTrue(challenge.expectedTokenSequence.allSatisfy(availableIDs.contains))
    }

    func testBuildTokensUseMathExpressionsAndStableOperatorStructures() throws {
        let request = try makeBuildRequest(
            stage: "M2",
            skill: MathSkillIDs.addition
        )
        let addition = try XCTUnwrap(provider.buildChallenge(for: request))
        let additionTokens = try orderedBuildExpressions(from: addition)
        XCTAssertEqual(additionTokens[1].expression, "+")
        XCTAssertEqual(additionTokens[1].structureID.rawValue, "math.operator.add")
        XCTAssertEqual(additionTokens[3].expression, "=")
        XCTAssertEqual(additionTokens[3].structureID.rawValue, "math.operator.equals")
        XCTAssertTrue([0, 2, 4].allSatisfy {
            additionTokens[$0].structureID.rawValue.hasPrefix("math.number.")
        })

        let request2 = try makeBuildRequest(
            stage: "M2",
            skill: MathSkillIDs.subtraction
        )
        let subtraction = try XCTUnwrap(provider.buildChallenge(for: request2))
        let subtractionTokens = try orderedBuildExpressions(from: subtraction)
        XCTAssertEqual(subtractionTokens[1].expression, "-")
        XCTAssertEqual(subtractionTokens[1].structureID.rawValue, "math.operator.subtract")
    }

    func testAdditionBuildSequenceCarriesCorrectArithmetic() throws {
        for stage in ["M2", "M3"] {
            for _ in 0 ..< 50 {
                let request = try makeBuildRequest(
                    stage: stage,
                    skill: MathSkillIDs.addition
                )
                let challenge = try XCTUnwrap(provider.buildChallenge(for: request))
                let equation = try buildEquationValues(from: challenge)
                let prompt = try buildPromptExpression(from: challenge)

                XCTAssertEqual(equation.operation, "math.operator.add")
                XCTAssertEqual(equation.lhs + equation.rhs, equation.result)
                XCTAssertEqual(
                    prompt.structureID.rawValue,
                    "math.equation.add.\(equation.lhs).\(equation.rhs).missingResult"
                )
                XCTAssertTrue(prompt.expression.hasSuffix("= \u{25A1}"))
            }
        }
    }

    func testSubtractionBuildSequenceCarriesNonnegativeCorrectArithmetic() throws {
        for stage in ["M2", "M3"] {
            for _ in 0 ..< 50 {
                let request = try makeBuildRequest(
                    stage: stage,
                    skill: MathSkillIDs.subtraction
                )
                let challenge = try XCTUnwrap(provider.buildChallenge(for: request))
                let equation = try buildEquationValues(from: challenge)
                let prompt = try buildPromptExpression(from: challenge)

                XCTAssertEqual(equation.operation, "math.operator.subtract")
                XCTAssertEqual(equation.lhs - equation.rhs, equation.result)
                XCTAssertGreaterThanOrEqual(equation.result, 0)
                XCTAssertEqual(
                    prompt.structureID.rawValue,
                    "math.equation.subtract.\(equation.lhs).\(equation.rhs).missingResult"
                )
                XCTAssertTrue(prompt.expression.hasSuffix("= \u{25A1}"))
            }
        }
    }

    func testBuildValuesStayInsideActiveDifficultyBounds() throws {
        let cases: [(String, SkillID, Double, Int)] = [
            ("M2", MathSkillIDs.addition, 0.2, 5),
            ("M2", MathSkillIDs.subtraction, 0.5, 8),
            ("M3", MathSkillIDs.addition, 0.2, 10),
            ("M3", MathSkillIDs.subtraction, 1, 20),
            ("M3", MathSkillIDs.missingAddend, 0.5, 15)
        ]

        for (stage, skill, difficulty, bound) in cases {
            for _ in 0 ..< 50 {
                let request = try makeBuildRequest(
                    stage: stage,
                    skill: skill,
                    difficulty: difficulty
                )
                let challenge = try XCTUnwrap(provider.buildChallenge(for: request))
                let equation = try buildEquationValues(from: challenge)
                XCTAssertTrue((0 ... bound).contains(equation.lhs))
                XCTAssertTrue((0 ... bound).contains(equation.rhs))
                XCTAssertTrue((0 ... bound).contains(equation.result))
            }
        }
    }

    func testMissingAddendPromptAndSequenceCarryCorrectStructure() throws {
        for _ in 0 ..< 50 {
            let request = try makeBuildRequest(
                stage: "M3",
                skill: MathSkillIDs.missingAddend
            )
            let challenge = try XCTUnwrap(provider.buildChallenge(for: request))
            let prompt = try buildPromptExpression(from: challenge)
            let equation = try buildEquationValues(from: challenge)

            XCTAssertTrue(prompt.expression.contains("\u{25A1}"))
            XCTAssertTrue(prompt.structureID.rawValue.hasPrefix("math.equation.missingAddend."))
            XCTAssertEqual(equation.operation, "math.operator.add")
            XCTAssertEqual(equation.lhs + equation.rhs, equation.result)
            XCTAssertEqual(
                prompt.structureID.rawValue,
                "math.equation.missingAddend.\(equation.lhs).\(equation.result)"
            )
        }
    }

    func testBuildPromptStructureIsMathematicalAndExcludesActivityName() throws {
        for skill in [MathSkillIDs.addition, MathSkillIDs.subtraction] {
            let request = try makeBuildRequest(
                stage: "M3",
                skill: skill
            )
            let challenge = try XCTUnwrap(provider.buildChallenge(for: request))
            let prompt = try buildPromptExpression(from: challenge)

            XCTAssertTrue(prompt.structureID.rawValue.hasPrefix("math.equation."))
            XCTAssertFalse(prompt.structureID.rawValue.localizedCaseInsensitiveContains("build"))
            XCTAssertNotEqual(challenge.id.rawValue, prompt.expression)
        }
    }

    func testSoccerRejectsUnsupportedStageAndStageSkillCombination() throws {
        let request = try makeSoccerRequest(
            stage: "M4",
            skill: MathSkillIDs.addition
        )
        XCTAssertNil(provider.soccerRound(for: request))
        let request2 = try makeSoccerRequest(
            stage: "M2",
            skill: MathSkillIDs.missingAddend
        )
        XCTAssertNil(provider.soccerRound(for: request2))
    }

    func testSoccerRejectsUnsupportedActivityAndInteraction() throws {
        let request = try makeSoccerRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            activityType: .multipleChoice
        )
        XCTAssertNil(provider.soccerRound(for: request))
        let request2 = try makeSoccerRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            interaction: .orderedTokens
        )
        XCTAssertNil(provider.soccerRound(for: request2))
    }

    func testSoccerMissingCountDefaultsToSixBallsAndChallenges() throws {
        let request = try makeSoccerRequest(
            stage: "M2",
            skill: MathSkillIDs.addition
        )
        let round = try XCTUnwrap(provider.soccerRound(for: request))

        XCTAssertEqual(round.answerBalls.count, 6)
        XCTAssertEqual(round.challengeTargets.count, 6)
    }

    func testSoccerExplicitValidItemCountsAreHonored() throws {
        for count in [6, 8] {
            let requirement = try XCTUnwrap(ContentCountRequirement(kind: .items, count: count))
            let request = try makeSoccerRequest(
                stage: "M3",
                skill: MathSkillIDs.addition,
                difficulty: 1,
                countRequirement: requirement
            )
            let round = try XCTUnwrap(provider.soccerRound(for: request))
            XCTAssertEqual(round.answerBalls.count, count)
            XCTAssertEqual(round.challengeTargets.count, count)
        }
    }

    func testSoccerRejectsInvalidCountRequirements() throws {
        let choices = try XCTUnwrap(ContentCountRequirement(kind: .choices, count: 6))
        let tooFew = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 5))
        let tooMany = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 9))

        for requirement in [choices, tooFew, tooMany] {
            let request = try makeSoccerRequest(
                stage: "M3",
                skill: MathSkillIDs.addition,
                difficulty: 1,
                countRequirement: requirement
            )
            XCTAssertNil(provider.soccerRound(for: request))
        }
    }

    func testSoccerRejectsRoundSizeThatExceedsActiveValueRange() throws {
        let sevenItems = try XCTUnwrap(ContentCountRequirement(kind: .items, count: 7))

        let request = try makeSoccerRequest(
            stage: "M2",
            skill: MathSkillIDs.addition,
            difficulty: 0.2,
            countRequirement: sevenItems
        )
        XCTAssertNil(provider.soccerRound(for: request))
    }

    func testSoccerBallsHaveUniqueIDsSemanticsAndNumericRepresentations() throws {
        let request = try makeSoccerRequest(
            stage: "M3",
            skill: MathSkillIDs.subtraction,
            difficulty: 1
        )
        let round = try XCTUnwrap(provider.soccerRound(for: request))
        XCTAssertEqual(Set(round.answerBalls.map(\.id)).count, round.answerBalls.count)
        XCTAssertEqual(Set(round.answerBalls.map(\.semanticValue)).count, round.answerBalls.count)

        for ball in round.answerBalls {
            let value = try soccerBallInteger(ball)
            guard case .mathExpression(let representation) = ball.representation else {
                return XCTFail("Expected a numeric Math expression on each answer ball.")
            }
            XCTAssertEqual(representation.expression, String(value))
            XCTAssertEqual(representation.structureID.rawValue, "math.number.\(value)")
            XCTAssertTrue((0 ... 20).contains(value))
        }
    }

    func testSoccerAnswerValuesFormACompactDistinctWindow() throws {
        for _ in 0 ..< 50 {
            let request = try makeSoccerRequest(
                stage: "M3",
                skill: MathSkillIDs.addition,
                difficulty: 1
            )
            let round = try XCTUnwrap(provider.soccerRound(for: request))
            let values = try round.answerBalls.map { try soccerBallInteger($0) }.sorted()

            XCTAssertEqual(Set(values).count, values.count)
            XCTAssertEqual(values.last! - values.first!, values.count - 1)
        }
    }

    func testSoccerChallengeContractsAndOneToOneBallMapping() throws {
        let request = try makeSoccerRequest(stage: "M3", skill: MathSkillIDs.addition)
        let round = try XCTUnwrap(provider.soccerRound(for: request))
        let ballsByID = Dictionary(uniqueKeysWithValues: round.answerBalls.map { ($0.id, $0) })

        XCTAssertEqual(Set(round.challengeTargets.map(\.challenge.id)).count, round.challengeTargets.count)
        XCTAssertEqual(Set(round.challengeTargets.map(\.intendedBallID)), Set(round.answerBalls.map(\.id)))

        for target in round.challengeTargets {
            let ball = try XCTUnwrap(ballsByID[target.intendedBallID])
            XCTAssertEqual(target.challenge.interaction, .singleChoice)
            XCTAssertEqual(target.challenge.validationRule, .numericEquivalence)
            XCTAssertTrue(target.challenge.choices.isEmpty)
            XCTAssertEqual(target.challenge.primarySkill, request.primarySkill)
            XCTAssertTrue(target.challenge.secondarySkills.isEmpty)
            XCTAssertEqual(target.challenge.curriculumStage, request.curriculumStage)
            XCTAssertEqual(target.challenge.difficulty, request.difficulty)
            XCTAssertEqual(try soccerExpectedInteger(target.challenge), try soccerBallInteger(ball))
        }
    }

    func testM1SoccerQuantityPromptMatchesIntendedBall() throws {
        let request = try makeSoccerRequest(
            stage: "M1",
            skill: MathSkillIDs.quantityToNumber,
            difficulty: 0.2
        )
        let round = try XCTUnwrap(provider.soccerRound(for: request))
        let ballsByID = Dictionary(uniqueKeysWithValues: round.answerBalls.map { ($0.id, $0) })

        for target in round.challengeTargets {
            let ball = try XCTUnwrap(ballsByID[target.intendedBallID])
            let value = try soccerBallInteger(ball)
            guard case .visualQuantity(let quantity) = target.challenge.prompt.representations.first else {
                return XCTFail("Expected an M1 visual-quantity prompt.")
            }
            XCTAssertEqual(quantity.quantity, value)
            XCTAssertEqual(quantity.structureID.rawValue, "math.quantity.\(value)")
            XCTAssertTrue((0 ... 5).contains(value))
        }
    }

    func testSoccerAdditionProblemsMatchTargetsAndBounds() throws {
        for (stage, difficulty, bound) in [("M2", 0.2, 5), ("M3", 1.0, 20)] {
            for _ in 0 ..< 25 {
                let request = try makeSoccerRequest(
                    stage: stage,
                    skill: MathSkillIDs.addition,
                    difficulty: difficulty
                )
                let round = try XCTUnwrap(provider.soccerRound(for: request))
                for target in round.challengeTargets {
                    let components = try soccerArithmeticComponents(
                        target.challenge,
                        operation: "add"
                    )
                    let answer = try soccerExpectedInteger(target.challenge)
                    XCTAssertEqual(components.first + components.second, answer)
                    XCTAssertTrue((0 ... bound).contains(components.first))
                    XCTAssertTrue((0 ... bound).contains(components.second))
                    XCTAssertTrue((0 ... bound).contains(answer))
                }
            }
        }
    }

    func testSoccerSubtractionProblemsMatchTargetsAndBounds() throws {
        for (stage, difficulty, bound) in [("M2", 0.5, 8), ("M3", 1.0, 20)] {
            for _ in 0 ..< 25 {
                let request = try makeSoccerRequest(
                    stage: stage,
                    skill: MathSkillIDs.subtraction,
                    difficulty: difficulty
                )
                let round = try XCTUnwrap(provider.soccerRound(for: request))
                for target in round.challengeTargets {
                    let components = try soccerArithmeticComponents(
                        target.challenge,
                        operation: "subtract"
                    )
                    let answer = try soccerExpectedInteger(target.challenge)
                    XCTAssertEqual(components.first - components.second, answer)
                    XCTAssertGreaterThanOrEqual(answer, 0)
                    XCTAssertTrue((0 ... bound).contains(components.first))
                    XCTAssertTrue((0 ... bound).contains(components.second))
                }
            }
        }
    }

    func testM3SoccerMissingAddendUsesBallAsMissingOperand() throws {
        for _ in 0 ..< 50 {
            let request = try makeSoccerRequest(
                stage: "M3",
                skill: MathSkillIDs.missingAddend,
                difficulty: 1
            )
            let round = try XCTUnwrap(provider.soccerRound(for: request))
            for target in round.challengeTargets {
                let prompt = try soccerPromptExpression(target.challenge)
                let parts = prompt.structureID.rawValue.split(separator: ".")
                guard parts.count == 4,
                      parts[0] == "math",
                      parts[1] == "missingAddend",
                      let known = Int(parts[2]),
                      let total = Int(parts[3]) else {
                    throw TestError.unexpectedStructure
                }
                let missing = try soccerExpectedInteger(target.challenge)

                XCTAssertTrue(prompt.expression.contains("\u{25A1}"))
                XCTAssertEqual(known + missing, total)
                XCTAssertTrue((0 ... 20).contains(known))
                XCTAssertTrue((0 ... 20).contains(total))
            }
        }
    }

    func testSoccerInstanceIDsAreNotRenderedMathText() throws {
        let request = try makeSoccerRequest(
            stage: "M3",
            skill: MathSkillIDs.addition
        )
        let round = try XCTUnwrap(provider.soccerRound(for: request))

        for (ball, target) in zip(round.answerBalls, round.challengeTargets) {
            guard case .mathExpression(let ballRepresentation) = ball.representation else {
                return XCTFail("Expected numeric ball representation.")
            }
            let prompt = try soccerPromptExpression(target.challenge)
            XCTAssertNotEqual(round.id.rawValue, prompt.expression)
            XCTAssertNotEqual(ball.id.rawValue, ballRepresentation.expression)
            XCTAssertNotEqual(target.challenge.id.rawValue, prompt.expression)
        }
    }

    private func assertContentProvider<T: ContentProvider>(_ provider: T) {}

    private func assertStudyContentProvider<T: StudyContentProviding>(_ provider: T) {}

    private func assertComparableContentProvider<T: ComparableContentProviding>(_ provider: T) {}

    private func assertEquivalenceContentProvider<T: EquivalenceContentProviding>(_ provider: T) {}

    private func assertBuildContentProvider<T: BuildContentProviding>(_ provider: T) {}

    private func assertSoccerContentProvider<T: SoccerContentProviding>(_ provider: T) {}

    private func makeRequest(
        stage: String,
        skill: SkillID,
        difficulty: Double = 0.5,
        activityType: ActivityType = .multipleChoice,
        interaction: Interaction? = .singleChoice,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: CurriculumStageID(rawValue: stage),
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(difficulty)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private func makeStudyRequest(
        stage: String,
        skill: SkillID,
        difficulty: Double = 0.5,
        activityType: ActivityType = .learn,
        interaction: Interaction? = nil,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: CurriculumStageID(rawValue: stage),
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(difficulty)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private func studyDirectNumber(
        from card: StudyCard
    ) throws -> (value: Int, representation: MathExpressionRepresentation) {
        guard card.representations.count == 2,
              case .mathExpression(let representation) = card.representations[1] else {
            throw TestError.unexpectedStudyRepresentation
        }
        let parts = representation.structureID.rawValue.split(separator: ".")
        guard parts.count == 3,
              parts[0] == "math",
              parts[1] == "number",
              let value = Int(parts[2]) else {
            throw TestError.unexpectedStructure
        }
        return (value, representation)
    }

    private func studyConceptExpression(
        from card: StudyCard
    ) throws -> MathExpressionRepresentation {
        guard card.representations.count == 2,
              case .mathExpression(let representation) = card.representations[0] else {
            throw TestError.unexpectedStudyRepresentation
        }
        return representation
    }

    private func makeTowerRequest(
        stage: String,
        skill: SkillID = MathSkillIDs.orderValues,
        difficulty: Double = 0.5,
        activityType: ActivityType = .tower,
        interaction: Interaction? = .orderedTokens,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: CurriculumStageID(rawValue: stage),
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(difficulty)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private func makeEquivalenceRequest(
        stage: String,
        skill: SkillID = MathSkillIDs.equivalentValues,
        difficulty: Double = 0.5,
        activityType: ActivityType = .pairs,
        interaction: Interaction? = .matching,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: CurriculumStageID(rawValue: stage),
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(difficulty)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private func makeBuildRequest(
        stage: String,
        skill: SkillID,
        difficulty: Double = 0.5,
        activityType: ActivityType = .build,
        interaction: Interaction? = .orderedTokens,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: CurriculumStageID(rawValue: stage),
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(difficulty)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private func makeSoccerRequest(
        stage: String,
        skill: SkillID,
        difficulty: Double = 0.5,
        activityType: ActivityType = .soccer,
        interaction: Interaction? = .singleChoice,
        countRequirement: ContentCountRequirement? = nil
    ) throws -> ChallengeRequest {
        ChallengeRequest(
            activityType: activityType,
            curriculumStage: CurriculumStageID(rawValue: stage),
            primarySkill: skill,
            difficulty: try XCTUnwrap(Difficulty(difficulty)),
            interaction: interaction,
            countRequirement: countRequirement
        )
    }

    private func soccerBallInteger(_ ball: SoccerAnswerBall) throws -> Int {
        guard case .integer(let value) = ball.semanticValue else {
            throw TestError.unexpectedSoccerSemanticValue
        }
        return value
    }

    private func ordinaryMathPrompt(
        from challenge: Challenge
    ) throws -> MathExpressionRepresentation {
        guard challenge.prompt.representations.count == 1,
              case .mathExpression(let expression) = challenge.prompt.representations[0] else {
            throw TestError.unexpectedPrompt
        }
        return expression
    }

    private func ordinaryBinaryComponents(
        from prompt: MathExpressionRepresentation,
        operation: String
    ) throws -> (lhs: Int, rhs: Int) {
        let parts = prompt.structureID.rawValue.split(separator: ".")
        guard parts.count == 4,
              parts[0] == "math",
              String(parts[1]) == operation,
              let lhs = Int(parts[2]),
              let rhs = Int(parts[3]) else {
            throw TestError.unexpectedStructure
        }
        return (lhs, rhs)
    }

    private func soccerExpectedInteger(_ challenge: Challenge) throws -> Int {
        guard case .semanticValue(.integer(let value)) = challenge.expectedAnswer else {
            throw TestError.unexpectedExpectedAnswer
        }
        return value
    }

    private func soccerPromptExpression(
        _ challenge: Challenge
    ) throws -> MathExpressionRepresentation {
        guard challenge.prompt.representations.count == 1,
              case .mathExpression(let expression) = challenge.prompt.representations[0] else {
            throw TestError.unexpectedPrompt
        }
        return expression
    }

    private func soccerArithmeticComponents(
        _ challenge: Challenge,
        operation: String
    ) throws -> (first: Int, second: Int) {
        let structure = try soccerPromptExpression(challenge).structureID.rawValue
        let parts = structure.split(separator: ".")
        guard parts.count == 4,
              parts[0] == "math",
              String(parts[1]) == operation,
              let first = Int(parts[2]),
              let second = Int(parts[3]) else {
            throw TestError.unexpectedStructure
        }
        return (first, second)
    }

    private func orderedBuildExpressions(
        from challenge: BuildChallenge
    ) throws -> [MathExpressionRepresentation] {
        let tokensByID = Dictionary(uniqueKeysWithValues: challenge.availableTokens.map {
            ($0.id, $0)
        })
        return try challenge.expectedTokenSequence.map { id in
            guard let token = tokensByID[id],
                  case .mathExpression(let expression) = token.representation else {
                throw TestError.unexpectedBuildToken
            }
            return expression
        }
    }

    private func buildEquationValues(
        from challenge: BuildChallenge
    ) throws -> (lhs: Int, operation: String, rhs: Int, result: Int) {
        let tokens = try orderedBuildExpressions(from: challenge)
        guard tokens.count == 5,
              tokens[3].structureID.rawValue == "math.operator.equals",
              let lhs = number(from: tokens[0]),
              let rhs = number(from: tokens[2]),
              let result = number(from: tokens[4]) else {
            throw TestError.unexpectedBuildEquation
        }
        return (lhs, tokens[1].structureID.rawValue, rhs, result)
    }

    private func number(from expression: MathExpressionRepresentation) -> Int? {
        let prefix = "math.number."
        guard expression.structureID.rawValue.hasPrefix(prefix) else {
            return nil
        }
        return Int(expression.structureID.rawValue.dropFirst(prefix.count))
    }

    private func buildPromptExpression(
        from challenge: BuildChallenge
    ) throws -> MathExpressionRepresentation {
        guard challenge.prompt.representations.count == 1,
              case .mathExpression(let expression) = challenge.prompt.representations[0] else {
            throw TestError.unexpectedPrompt
        }
        return expression
    }

    private func semanticInteger(from set: EquivalenceSet) throws -> Int {
        guard case .integer(let value) = set.semanticValue else {
            throw TestError.unexpectedEquivalenceSemanticValue
        }
        return value
    }

    private func hasArithmeticPrefix(_ set: EquivalenceSet, _ prefix: String) -> Bool {
        guard set.representations.count == 2,
              case .mathExpression(let expression) = set.representations[1] else {
            return false
        }
        return expression.structureID.rawValue.hasPrefix(prefix)
    }

    private func equivalenceArithmeticComponents(
        from set: EquivalenceSet,
        prefix: String? = nil
    ) throws -> (first: Int, second: Int) {
        guard set.representations.count == 2,
              case .mathExpression(let expression) = set.representations[1] else {
            throw TestError.unexpectedEquivalenceRepresentation
        }
        let structure = expression.structureID.rawValue
        let parts = structure.split(separator: ".")
        guard parts.count == 4,
              prefix.map({ structure.hasPrefix("\($0).") }) ?? true,
              let first = Int(parts[2]),
              let second = Int(parts[3]) else {
            throw TestError.unexpectedStructure
        }
        return (first, second)
    }

    private func integerValue(from item: ComparableItem) throws -> Int {
        guard case .integer(let value) = item.comparisonValue else {
            throw TestError.unexpectedComparisonValue
        }
        return value
    }

    private func expression(from item: ComparableItem) throws -> MathExpressionRepresentation {
        guard case .mathExpression(let expression) = item.representation else {
            throw TestError.unexpectedComparableRepresentation
        }
        return expression
    }

    private func hasStructurePrefix(_ item: ComparableItem, _ prefix: String) -> Bool {
        guard let expression = try? expression(from: item) else {
            return false
        }
        return expression.structureID.rawValue.hasPrefix(prefix)
    }

    private func structureComponents(
        from item: ComparableItem,
        prefix: String? = nil
    ) throws -> (first: Int, second: Int) {
        let structure = try expression(from: item).structureID.rawValue
        let parts = structure.split(separator: ".")
        guard parts.count == 4,
              prefix.map({ structure.hasPrefix("\($0).") }) ?? true,
              let first = Int(parts[2]),
              let second = Int(parts[3]) else {
            throw TestError.unexpectedStructure
        }
        return (first, second)
    }

    private func expectedInteger(from challenge: Challenge) throws -> Int {
        guard case .semanticValue(.integer(let value)) = challenge.expectedAnswer else {
            throw TestError.unexpectedExpectedAnswer
        }
        return value
    }

    private func mathStructure(from challenge: Challenge) throws -> RepresentationStructureID {
        guard case .mathExpression(let expression) = challenge.prompt.representations.first else {
            throw TestError.unexpectedPrompt
        }
        return expression.structureID
    }

    private func assertGeneratedAnswers(
        stage: String,
        skill: SkillID,
        difficulty: Double,
        areWithin range: ClosedRange<Int>
    ) throws {
        for _ in 0 ..< 75 {
            let request = try makeRequest(
                stage: stage,
                skill: skill,
                difficulty: difficulty
            )
            let challenge = try XCTUnwrap(provider.challenge(for: request))
            XCTAssertTrue(range.contains(try expectedInteger(from: challenge)))
        }
    }

    private enum TestError: Error {
        case unexpectedExpectedAnswer
        case unexpectedPrompt
        case unexpectedComparisonValue
        case unexpectedComparableRepresentation
        case unexpectedEquivalenceSemanticValue
        case unexpectedEquivalenceRepresentation
        case unexpectedBuildToken
        case unexpectedBuildEquation
        case unexpectedSoccerSemanticValue
        case unexpectedStudyRepresentation
        case unexpectedStructure
    }
}
