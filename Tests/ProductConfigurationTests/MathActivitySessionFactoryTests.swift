import XCTest
@testable import MinikPlus

final class MathActivitySessionFactoryTests: XCTestCase {
    private let mathFactory = MathActivitySessionFactory(
        configuration: .configuration(for: .minikMath)
    )

    func testCurrentRunnableMathLevelsAreM1ThroughM10() {
        XCTAssertEqual(MathCurriculumPolicy.runnableLevels.map(\.id), [.m1, .m2, .m3, .m4, .m5, .m6, .m7, .m8, .m9, .m10])
        XCTAssertEqual(
            MathCurriculumPolicy.runnableLevels.map(\.title),
            ["Level 1", "Level 2", "Level 3", "Level 4", "Level 5", "Level 6", "Level 7", "Level 8", "Level 9", "Level 10"]
        )
        XCTAssertTrue(MathCurriculumPolicy.runnableLevels.allSatisfy {
            !$0.title.contains($0.id.rawValue)
        })
    }

    func testCatalogRecognizesTenIndependentMathLevelsWithoutAnAThroughEMapping() {
        XCTAssertEqual(
            MathCurriculumPolicy.levels.map(\.id),
            [.m1, .m2, .m3, .m4, .m5, .m6, .m7, .m8, .m9, .m10]
        )
        XCTAssertEqual(
            MathCurriculumPolicy.levels.map(\.id.rawValue),
            (1 ... 10).map { "M\($0)" }
        )
        let languageLevelIDs: Set<String> = ["A", "B", "C", "D", "E"]
        XCTAssertTrue(
            MathCurriculumPolicy.levels.allSatisfy {
                !languageLevelIDs.contains($0.id.rawValue)
            }
        )
    }

    func testNoCanonicalMathLevelRemainsPlanned() {
        let plannedIDs: [MathCurriculumLevelID] = []
        XCTAssertEqual(
            MathCurriculumPolicy.levels
                .filter { $0.availability == .planned }
                .map(\.id),
            plannedIDs
        )

    }

    func testLevelIdentityAndDescriptorTypesRemainOpenForFutureCurriculum() {
        let futureID = MathCurriculumLevelID(rawValue: "M11")
        let futureDescriptor = MathCurriculumLevelDescriptor(
            id: futureID,
            title: "Level 11",
            subtitle: "Future curriculum",
            availability: .planned
        )

        XCTAssertEqual(futureDescriptor.id.curriculumStageID.rawValue, "M11")
        XCTAssertNil(MathCurriculumPolicy.level(for: futureID))
        for activity in MathActivityKind.allCases {
            XCTAssertNil(mathFactory.makeSession(for: activity, levelID: futureID))
        }
    }

    func testM1ProductionRoutingUsesEveryMeaningfulQuantityActivity() throws {
        let expected: Set<MathActivityKind> = [
            .learn, .multipleChoice, .tower, .pairs, .memory, .soccer
        ]
        XCTAssertEqual(Set(MathCurriculumPolicy.supportedActivities(for: .m1)), expected)
        XCTAssertEqual(MathCurriculumPolicy.unsupportedActivities(for: .m1), [.build])

        for activity in expected {
            XCTAssertNotNil(mathFactory.makeSession(for: activity, levelID: .m1))
        }

        guard case .learn(let session)? = mathFactory.makeSession(
            for: .learn,
            levelID: .m1
        ) else {
            return XCTFail("Expected the existing M1 Learn route.")
        }

        XCTAssertEqual(session.cardCount, 6)
        XCTAssertTrue(session.cards.allSatisfy {
            $0.curriculumStage == MathCurriculumLevelID.m1.curriculumStageID
                && $0.primarySkill == MathSkillIDs.quantityToNumber
        })

        let choose = try XCTUnwrap(mathFactory.makeMultipleChoiceSession(for: .m1))
        for challenge in choose.challenges {
            guard case .visualQuantity = challenge.prompt.representations.first else {
                return XCTFail("Expected a Level 1 quantity prompt.")
            }
        }

        let tower = try XCTUnwrap(mathFactory.makeTowerSession(for: .m1))
        XCTAssertTrue(tower.rounds.flatMap(\.items).allSatisfy {
            if case .visualQuantity(let quantity) = $0.representation,
               case .integer(let value) = $0.comparisonValue {
                return quantity.quantity == value
            }
            return false
        })

        try assertQuantityEquivalenceSemantics(
            try XCTUnwrap(mathFactory.makePairsSession(for: .m1)).equivalenceSets
        )
        try assertQuantityEquivalenceSemantics(
            try XCTUnwrap(mathFactory.makeMemorySession(for: .m1)).equivalenceSets
        )
        XCTAssertNil(mathFactory.makeBuildSession(for: .m1))
    }

    func testM2RoutesAllSevenActivityFamiliesWithTheCurrentContentSplit() throws {
        let expected = Set(MathActivityKind.allCases)
        XCTAssertEqual(
            Set(MathCurriculumPolicy.supportedActivities(for: .m2)),
            expected
        )
        XCTAssertTrue(MathCurriculumPolicy.unsupportedActivities(for: .m2).isEmpty)

        for activity in expected {
            XCTAssertNotNil(mathFactory.makeSession(for: activity, levelID: .m2))
        }

        guard case .learn(let learn)? = mathFactory.makeSession(for: .learn, levelID: .m2),
        case .multipleChoice(let choose)? = mathFactory.makeSession(
            for: .multipleChoice,
            levelID: .m2
        ),
        case .build(let build)? = mathFactory.makeSession(for: .build, levelID: .m2),
        case .soccer(let soccer)? = mathFactory.makeSession(for: .soccer, levelID: .m2)
        else {
            return XCTFail("Expected existing M2 sessions.")
        }

        XCTAssertTrue(learn.cards.allSatisfy {
            $0.curriculumStage == MathCurriculumLevelID.m2.curriculumStageID
                && $0.primarySkill == MathSkillIDs.addition
        })
        XCTAssertTrue(choose.challenges.allSatisfy {
            $0.curriculumStage == MathCurriculumLevelID.m2.curriculumStageID
                && $0.primarySkill == MathSkillIDs.addition
        })
        XCTAssertTrue(build.challenges.allSatisfy {
            $0.curriculumStage == MathCurriculumLevelID.m2.curriculumStageID
                && $0.primarySkill == MathSkillIDs.addition
        })
        XCTAssertTrue(soccer.round.challengeTargets.allSatisfy {
            $0.challenge.curriculumStage == MathCurriculumLevelID.m2.curriculumStageID
                && $0.challenge.primarySkill == MathSkillIDs.addition
        })

        let tower = try XCTUnwrap(mathFactory.makeTowerSession(for: .m2))
        for item in tower.rounds.flatMap(\.items) {
            guard case .integer(let value) = item.comparisonValue else {
                return XCTFail("Expected an integer comparison value.")
            }
            XCTAssertEqual(try directNumber(from: item.representation), value)
        }

        try assertQuantityEquivalenceSemantics(
            try XCTUnwrap(mathFactory.makePairsSession(for: .m2)).equivalenceSets
        )
        try assertQuantityEquivalenceSemantics(
            try XCTUnwrap(mathFactory.makeMemorySession(for: .m2)).equivalenceSets
        )
    }

    func testM3EveryExistingActivityHasAnIntentionalProductionRoute() {
        XCTAssertEqual(
            Set(MathCurriculumPolicy.supportedActivities(for: .m3)),
            Set(MathActivityKind.allCases)
        )
        XCTAssertTrue(MathCurriculumPolicy.unsupportedActivities(for: .m3).isEmpty)

        for activity in MathActivityKind.allCases {
            XCTAssertNotNil(mathFactory.makeSession(for: activity, levelID: .m3))
        }
    }

    func testM3LearnUsesMissingAddendRelationships() throws {
        let session = try XCTUnwrap(mathFactory.makeLearnSession(for: .m3))

        XCTAssertEqual(session.cardCount, 6)
        for card in session.cards {
            XCTAssertEqual(card.curriculumStage, MathCurriculumLevelID.m3.curriculumStageID)
            XCTAssertEqual(card.primarySkill, MathSkillIDs.missingAddend)
            XCTAssertEqual(card.representations.count, 2)

            let missingValue = try directNumber(from: card.representations[1])
            let relationship = try missingAddendRelationship(from: card.representations[0])
            XCTAssertEqual(relationship.known + missingValue, relationship.total)
        }
    }

    func testM3ChooseUsesSemanticMissingValueCorrectness() throws {
        var session = try XCTUnwrap(mathFactory.makeMultipleChoiceSession(for: .m3))

        XCTAssertEqual(session.challengeCount, 6)
        for challenge in session.challenges {
            XCTAssertEqual(challenge.curriculumStage, MathCurriculumLevelID.m3.curriculumStageID)
            XCTAssertEqual(challenge.primarySkill, MathSkillIDs.missingAddend)
            XCTAssertEqual(challenge.validationRule, .numericEquivalence)
            let expected = try expectedInteger(from: challenge)
            let relationship = try missingAddendRelationship(
                from: try XCTUnwrap(challenge.prompt.representations.first)
            )
            XCTAssertEqual(relationship.known + expected, relationship.total)
        }

        let challenge = session.currentChallenge
        let expected = try expectedInteger(from: challenge)
        let correctChoice = try XCTUnwrap(challenge.choices.first {
            $0.semanticValue == .integer(expected)
        })
        session.selectChoice(correctChoice.id)
        XCTAssertEqual(session.answerResult, .correct)
    }

    func testM3BuildKeepsTheMissingValueTaskInsideTheBuildInteraction() throws {
        var session = try XCTUnwrap(mathFactory.makeBuildSession(for: .m3))

        XCTAssertEqual(session.challengeCount, 6)
        for challenge in session.challenges {
            XCTAssertEqual(challenge.curriculumStage, MathCurriculumLevelID.m3.curriculumStageID)
            XCTAssertEqual(challenge.primarySkill, MathSkillIDs.missingAddend)
            XCTAssertEqual(challenge.validationMode, .submitSequence)

            // This older factory uses expression payloads. The production M3 factory's
            // typed prompt contract is covered in MathM3ActivitySessionFactoryTests.
            XCTAssertEqual(challenge.prompt.representations.count, 1)
            guard case .mathExpression(let prompt) = try XCTUnwrap(challenge.prompt.representations.first) else {
                return XCTFail("Expected the generic factory's missing-addend expression.")
            }
            let expressions = try orderedExpressions(from: challenge)
            let pieces = try expressions.map(expressionText)
            guard pieces.count == 5 else {
                return XCTFail("Build must retain the complete five-token equation.")
            }
            let lhs = try XCTUnwrap(Int(pieces[0]))
            let rhs = try XCTUnwrap(Int(pieces[2]))
            let result = try XCTUnwrap(Int(pieces[4]))

            XCTAssertTrue([lhs, rhs, result].allSatisfy { (0...15).contains($0) })
            XCTAssertEqual(pieces[1], "+")
            XCTAssertEqual(pieces[3], "=")
            XCTAssertEqual(lhs + rhs, result)
            XCTAssertEqual(prompt.expression, "\(lhs) + \u{25A1} = \(result)")

            for tokenID in challenge.expectedTokenSequence { session.selectToken(tokenID) }
            XCTAssertNil(session.answerResult)
            session.submit()
            XCTAssertEqual(session.answerResult, .correct)
            session.nextChallenge()
        }
        XCTAssertTrue(session.isComplete)
    }

    func testM3TowerOrdersArithmeticExpressionsByTypedComparisonValue() throws {
        let session = try XCTUnwrap(mathFactory.makeTowerSession(for: .m3))

        XCTAssertEqual(session.roundCount, 6)
        for round in session.rounds {
            for item in round.items {
                guard case .integer(let comparisonValue) = item.comparisonValue else {
                    return XCTFail("Expected an integer comparison value.")
                }
                XCTAssertEqual(try arithmeticValue(from: item.representation), comparisonValue)
            }
        }
    }

    func testM3PairsMatchesEquivalentExpressionsBySemanticValue() throws {
        let session = try XCTUnwrap(mathFactory.makePairsSession(for: .m3))

        XCTAssertEqual(session.equivalenceSets.count, 4)
        try assertM3EquivalentExpressionSemantics(session.equivalenceSets)
    }

    func testM3MemoryMatchesEquivalentExpressionsBySemanticValue() throws {
        let session = try XCTUnwrap(mathFactory.makeMemorySession(for: .m3))

        XCTAssertEqual(session.equivalenceSets.count, 4)
        try assertM3EquivalentExpressionSemantics(session.equivalenceSets)
    }

    func testM3SoccerKeepsMissingValueCorrectnessConnectedToTheChosenBall() throws {
        let session = try XCTUnwrap(mathFactory.makeSoccerSession(for: .m3))
        let ballsByID = Dictionary(uniqueKeysWithValues: session.round.answerBalls.map {
            ($0.id, $0)
        })

        XCTAssertEqual(session.targetCount, 6)
        for target in session.round.challengeTargets {
            let challenge = target.challenge
            XCTAssertEqual(challenge.curriculumStage, MathCurriculumLevelID.m3.curriculumStageID)
            XCTAssertEqual(challenge.primarySkill, MathSkillIDs.missingAddend)
            let expected = try expectedInteger(from: challenge)
            let relationship = try missingAddendRelationship(
                from: try XCTUnwrap(challenge.prompt.representations.first)
            )
            XCTAssertEqual(relationship.known + expected, relationship.total)
            XCTAssertEqual(ballsByID[target.intendedBallID]?.semanticValue, .integer(expected))
        }
    }

    func testLanguageProductsCannotCreateAnyMathM3Session() {
        for variant in [ProductVariant.minikPlus, .minikPlusEnglish] {
            let factory = MathActivitySessionFactory(
                configuration: .configuration(for: variant)
            )
            for activity in MathActivityKind.allCases {
                XCTAssertNil(factory.makeSession(for: activity, levelID: .m3))
            }
        }
    }

    private func assertM3EquivalentExpressionSemantics(
        _ sets: [EquivalenceSet]
    ) throws {
        for set in sets {
            guard case .integer(let semanticValue) = set.semanticValue else {
                return XCTFail("Expected an integer equivalence value.")
            }
            XCTAssertEqual(set.representations.count, 2)
            XCTAssertEqual(try directNumber(from: set.representations[0]), semanticValue)
            XCTAssertEqual(try arithmeticValue(from: set.representations[1]), semanticValue)
        }
    }

    private func assertQuantityEquivalenceSemantics(
        _ sets: [EquivalenceSet]
    ) throws {
        for set in sets {
            guard case .integer(let semanticValue) = set.semanticValue,
                  case .mathExpression = set.representations[0],
                  case .visualQuantity(let quantity) = set.representations[1] else {
                return XCTFail("Expected number and quantity representations.")
            }
            XCTAssertEqual(try directNumber(from: set.representations[0]), semanticValue)
            XCTAssertEqual(quantity.quantity, semanticValue)
        }
    }

    private func expectedInteger(from challenge: Challenge) throws -> Int {
        guard case .semanticValue(.integer(let value)) = challenge.expectedAnswer else {
            throw TestError.unexpectedExpectedAnswer
        }
        return value
    }

    private func directNumber(from representation: Representation) throws -> Int {
        guard case .mathExpression(let expression) = representation else {
            throw TestError.unexpectedRepresentation
        }
        let parts = expression.structureID.rawValue.split(separator: ".")
        guard parts.count == 3,
              parts[0] == "math",
              parts[1] == "number",
              let value = Int(parts[2]) else {
            throw TestError.unexpectedStructure
        }
        return value
    }

    private func missingAddendRelationship(
        from representation: Representation
    ) throws -> (known: Int, total: Int) {
        guard case .mathExpression(let expression) = representation else {
            throw TestError.unexpectedRepresentation
        }
        let parts = expression.structureID.rawValue.split(separator: ".")
        guard parts.count == 4,
              parts[0] == "math",
              parts[1] == "missingAddend",
              let known = Int(parts[2]),
              let total = Int(parts[3]) else {
            throw TestError.unexpectedStructure
        }
        return (known, total)
    }

    private func arithmeticValue(from representation: Representation) throws -> Int {
        guard case .mathExpression(let expression) = representation else {
            throw TestError.unexpectedRepresentation
        }
        let parts = expression.structureID.rawValue.split(separator: ".")
        guard parts.count == 4,
              parts[0] == "math",
              let lhs = Int(parts[2]),
              let rhs = Int(parts[3]) else {
            throw TestError.unexpectedStructure
        }
        switch parts[1] {
        case "add":
            return lhs + rhs
        case "subtract":
            return lhs - rhs
        default:
            throw TestError.unexpectedStructure
        }
    }

    private func orderedExpressions(
        from challenge: BuildChallenge
    ) throws -> [Representation] {
        let tokensByID = Dictionary(uniqueKeysWithValues: challenge.availableTokens.map {
            ($0.id, $0.representation)
        })
        return try challenge.expectedTokenSequence.map { tokenID in
            guard let representation = tokensByID[tokenID] else {
                throw TestError.unexpectedBuildToken
            }
            return representation
        }
    }

    private func expressionText(from representation: Representation) throws -> String {
        guard case .mathExpression(let expression) = representation else {
            throw TestError.unexpectedRepresentation
        }
        return expression.expression
    }

    private enum TestError: Error {
        case unexpectedBuildToken
        case unexpectedExpectedAnswer
        case unexpectedRepresentation
        case unexpectedStructure
    }
}
