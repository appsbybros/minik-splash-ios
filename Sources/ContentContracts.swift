import Foundation

enum ActivityType: String, Hashable, Codable, Sendable {
    case learn
    case multipleChoice
    case chooseRepresentation
    case missingPart
    case build
    case mixed
    case cards
    case pairs
    case memory
    case tower
    case soccer
}

struct StudyCardID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A study card identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct ComparableItemID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A comparable item identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct BuildTokenID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A build token identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct SoccerRoundID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A soccer round identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct SoccerBallID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A soccer ball identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct TowerRoundID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A tower round identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct TowerBlockID: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A tower block identifier cannot be empty.")
        self.rawValue = rawValue
    }
}

struct StudyCard: Hashable, Sendable {
    let id: StudyCardID
    let representations: [Representation]
    let primarySkill: SkillID
    let secondarySkills: Set<SkillID>
    let curriculumStage: CurriculumStageID

    init?(
        id: StudyCardID,
        representations: [Representation],
        primarySkill: SkillID,
        secondarySkills: Set<SkillID> = [],
        curriculumStage: CurriculumStageID
    ) {
        guard !representations.isEmpty else {
            return nil
        }

        self.id = id
        self.representations = representations
        self.primarySkill = primarySkill
        self.secondarySkills = secondarySkills
        self.curriculumStage = curriculumStage
    }
}

enum ContentCountKind: Hashable, Sendable {
    case choices
    case items
}

struct ContentCountRequirement: Hashable, Sendable {
    let kind: ContentCountKind
    let count: Int

    init?(kind: ContentCountKind, count: Int) {
        guard count > 0 else {
            return nil
        }
        self.kind = kind
        self.count = count
    }
}

struct ChallengeRequest: Hashable, Sendable {
    let activityType: ActivityType
    let curriculumStage: CurriculumStageID
    let primarySkill: SkillID
    let difficulty: Difficulty
    let interaction: Interaction?
    let countRequirement: ContentCountRequirement?
}

/// Base capability shared by catalog-driven and generator-driven providers.
protocol ContentProvider: Sendable {
    func challenge(for request: ChallengeRequest) -> Challenge?
}

protocol StudyContentProviding: Sendable {
    func studyCards(for request: ChallengeRequest) -> [StudyCard]
}

protocol EquivalenceContentProviding: Sendable {
    func equivalenceSets(for request: ChallengeRequest) -> [EquivalenceSet]
}

protocol ComparableContentProviding: Sendable {
    func comparableSet(for request: ChallengeRequest) -> ComparableSet?
}

protocol BuildContentProviding: Sendable {
    func buildChallenge(for request: ChallengeRequest) -> BuildChallenge?
}

protocol SoccerContentProviding: Sendable {
    func soccerRound(for request: ChallengeRequest) -> SoccerRound?
}

struct EquivalenceSet: Hashable, Sendable {
    let semanticValue: SemanticValue
    let representations: [Representation]

    init?(semanticValue: SemanticValue, representations: [Representation]) {
        // Equal visible representations may still be distinct presentation instances.
        guard representations.count >= 2 else {
            return nil
        }
        self.semanticValue = semanticValue
        self.representations = representations
    }
}

enum ExactNumericValue: Hashable, Sendable {
    case integer(Int)
    case rational(Rational)
}

struct ComparableItem: Hashable, Sendable {
    let id: ComparableItemID
    let representation: Representation
    let comparisonValue: ExactNumericValue
}

struct ComparableSet: Hashable, Sendable {
    let items: [ComparableItem]

    init?(items: [ComparableItem]) {
        guard !items.isEmpty,
              Set(items.map(\.id)).count == items.count else {
            return nil
        }
        self.items = items
    }
}

struct TowerBlock: Hashable, Sendable {
    let id: TowerBlockID
    let representation: Representation
    let orderedToken: LearningTextRepresentation
    let contentItemID: ContentItemID

    init(
        id: TowerBlockID,
        orderedToken: LearningTextRepresentation,
        contentItemID: ContentItemID
    ) {
        self.id = id
        self.representation = .learningText(orderedToken)
        self.orderedToken = orderedToken
        self.contentItemID = contentItemID
    }
}

struct TowerOrderedTokenContent: Hashable, Sendable {
    let contentItemID: ContentItemID
    let vocabularyLevel: LanguageVocabularyLevel?
    let targetText: LearningTextRepresentation
    let expectedTokenSequence: [LearningTextRepresentation]
    let image: AssetReference?
    let speechCue: LearningSpeechUtterance

    init?(
        contentItemID: ContentItemID,
        vocabularyLevel: LanguageVocabularyLevel? = nil,
        targetText: LearningTextRepresentation,
        expectedTokenSequence: [LearningTextRepresentation],
        image: AssetReference?,
        speechCue: LearningSpeechUtterance
    ) {
        guard !targetText.text.isEmpty,
              let language = targetText.language,
              !expectedTokenSequence.isEmpty,
              expectedTokenSequence.allSatisfy({ token in
                  !token.text.isEmpty
                      && !token.text.contains(where: { $0.isWhitespace })
                      && token.language == targetText.language
                      && token.direction == targetText.direction
              }),
              expectedTokenSequence.map(\.text).joined()
                == targetText.text.filter({ !$0.isWhitespace }),
              speechCue.language == language,
              !speechCue.text.isEmpty else {
            return nil
        }

        self.contentItemID = contentItemID
        self.vocabularyLevel = vocabularyLevel
        self.targetText = targetText
        self.expectedTokenSequence = expectedTokenSequence
        self.image = image
        self.speechCue = speechCue
    }
}

enum TowerRoundMechanic: Hashable, Sendable {
    case valueOrdering
    case orderedTokens(TowerOrderedTokenContent)
}

struct TowerOrderedTokenRound: Hashable, Sendable {
    let id: TowerRoundID
    let blocks: [TowerBlock]
    let mechanic: TowerRoundMechanic

    init?(
        id: TowerRoundID,
        blocks: [TowerBlock],
        content: TowerOrderedTokenContent
    ) {
        let blockIDs = Set(blocks.map(\.id))
        let blockTokens = blocks.map(\.orderedToken)

        guard !blocks.isEmpty,
              blockIDs.count == blocks.count,
              blocks.allSatisfy({ $0.contentItemID == content.contentItemID }),
              Self.occurrences(in: blockTokens)
                == Self.occurrences(in: content.expectedTokenSequence) else {
            return nil
        }

        self.id = id
        self.blocks = blocks
        self.mechanic = .orderedTokens(content)
    }

    var content: TowerOrderedTokenContent {
        guard case .orderedTokens(let content) = mechanic else {
            preconditionFailure("Language Tower rounds require ordered-token content.")
        }
        return content
    }

    private static func occurrences(
        in tokens: [LearningTextRepresentation]
    ) -> [LearningTextRepresentation: Int] {
        tokens.reduce(into: [:]) { counts, token in
            counts[token, default: 0] += 1
        }
    }
}

struct BuildToken: Hashable, Sendable {
    let id: BuildTokenID
    let representation: Representation
}

struct LanguageWordBuildContent: Hashable, Sendable {
    let contentItemID: ContentItemID
    let targetText: LearningTextRepresentation

    init?(contentItemID: ContentItemID, targetText: LearningTextRepresentation) {
        guard !targetText.text.isEmpty,
              targetText.language != nil,
              targetText.text.contains(where: { !$0.isWhitespace }) else {
            return nil
        }
        self.contentItemID = contentItemID
        self.targetText = targetText
    }
}

enum BuildValidationMode: Hashable, Sendable {
    case submitSequence
    case immediatePrefix
}

struct BuildChallenge: Hashable, Sendable {
    let id: ChallengeID
    let prompt: Prompt
    let availableTokens: [BuildToken]
    let expectedTokenSequence: [BuildTokenID]
    let primarySkill: SkillID
    let secondarySkills: Set<SkillID>
    let curriculumStage: CurriculumStageID
    let difficulty: Difficulty
    let validationMode: BuildValidationMode
    let languageWordContent: LanguageWordBuildContent?

    init?(
        id: ChallengeID,
        prompt: Prompt,
        availableTokens: [BuildToken],
        expectedTokenSequence: [BuildTokenID],
        primarySkill: SkillID,
        secondarySkills: Set<SkillID> = [],
        curriculumStage: CurriculumStageID,
        difficulty: Difficulty,
        validationMode: BuildValidationMode = .submitSequence,
        languageWordContent: LanguageWordBuildContent? = nil
    ) {
        let availableIDs = Set(availableTokens.map(\.id))
        guard !availableTokens.isEmpty,
              availableIDs.count == availableTokens.count,
              !expectedTokenSequence.isEmpty,
              Set(expectedTokenSequence).count == expectedTokenSequence.count,
              expectedTokenSequence.allSatisfy(availableIDs.contains) else {
            return nil
        }

        if let languageWordContent {
            let tokensByID = Dictionary(
                uniqueKeysWithValues: availableTokens.map { ($0.id, $0) }
            )
            let expectedText = expectedTokenSequence.compactMap { tokenID -> String? in
                guard let token = tokensByID[tokenID],
                      case .learningText(let text) = token.representation,
                      text.language == languageWordContent.targetText.language,
                      text.direction == languageWordContent.targetText.direction,
                      !text.text.isEmpty,
                      !text.text.contains(where: { $0.isWhitespace }) else {
                    return nil
                }
                return text.text
            }
            guard expectedText.count == expectedTokenSequence.count,
                  expectedText.joined()
                    == languageWordContent.targetText.text.filter({ !$0.isWhitespace }) else {
                return nil
            }
        }

        self.id = id
        self.prompt = prompt
        self.availableTokens = availableTokens
        self.expectedTokenSequence = expectedTokenSequence
        self.primarySkill = primarySkill
        self.secondarySkills = secondarySkills
        self.curriculumStage = curriculumStage
        self.difficulty = difficulty
        self.validationMode = validationMode
        self.languageWordContent = languageWordContent
    }
}

struct SoccerAnswerBall: Hashable, Sendable {
    let id: SoccerBallID
    let representation: Representation
    let semanticValue: SemanticValue
    let orderedToken: LearningTextRepresentation?

    var orderedTokenDisplayText: String? {
        orderedToken?.text
    }

    init(
        id: SoccerBallID,
        representation: Representation,
        semanticValue: SemanticValue
    ) {
        self.id = id
        self.representation = representation
        self.semanticValue = semanticValue
        self.orderedToken = nil
    }

    init(
        id: SoccerBallID,
        orderedToken: LearningTextRepresentation,
        contentItemID: ContentItemID
    ) {
        self.id = id
        self.representation = .learningText(orderedToken)
        self.semanticValue = .contentItem(contentItemID)
        self.orderedToken = orderedToken
    }
}

struct SoccerChallengeTarget: Hashable, Sendable {
    let challenge: Challenge
    let intendedBallID: SoccerBallID
}

struct SoccerOrderedTokenContent: Hashable, Sendable {
    let contentItemID: ContentItemID
    let vocabularyLevel: LanguageVocabularyLevel?
    let targetText: LearningTextRepresentation
    let expectedTokenSequence: [LearningTextRepresentation]
    let image: AssetReference?
    let speechCue: LearningSpeechUtterance

    init?(
        contentItemID: ContentItemID,
        vocabularyLevel: LanguageVocabularyLevel? = nil,
        targetText: LearningTextRepresentation,
        expectedTokenSequence: [LearningTextRepresentation],
        image: AssetReference?,
        speechCue: LearningSpeechUtterance
    ) {
        guard !targetText.text.isEmpty,
              let language = targetText.language,
              !expectedTokenSequence.isEmpty,
              expectedTokenSequence.allSatisfy({ token in
                  !token.text.isEmpty
                      && !token.text.contains(where: { $0.isWhitespace })
                      && token.language == targetText.language
                      && token.direction == targetText.direction
              }),
              expectedTokenSequence.map(\.text).joined()
                == targetText.text.filter({ !$0.isWhitespace }),
              speechCue.language == language,
              !speechCue.text.isEmpty else {
            return nil
        }

        self.contentItemID = contentItemID
        self.vocabularyLevel = vocabularyLevel
        self.targetText = targetText
        self.expectedTokenSequence = expectedTokenSequence
        self.image = image
        self.speechCue = speechCue
    }
}

enum SoccerRoundMechanic: Hashable, Sendable {
    case answerChoice
    case orderedTokens(SoccerOrderedTokenContent)
}

struct SoccerRound: Hashable, Sendable {
    let id: SoccerRoundID
    let answerBalls: [SoccerAnswerBall]
    let challengeTargets: [SoccerChallengeTarget]
    let mechanic: SoccerRoundMechanic

    init?(
        id: SoccerRoundID,
        answerBalls: [SoccerAnswerBall],
        challengeTargets: [SoccerChallengeTarget]
    ) {
        let ballIDs = Set(answerBalls.map(\.id))
        let ballSemanticValues = Set(answerBalls.map(\.semanticValue))
        let challengeIDs = Set(challengeTargets.map(\.challenge.id))
        let intendedBallIDs = Set(challengeTargets.map(\.intendedBallID))

        guard !answerBalls.isEmpty,
              !challengeTargets.isEmpty,
              ballIDs.count == answerBalls.count,
              ballSemanticValues.count == answerBalls.count,
              challengeIDs.count == challengeTargets.count,
              intendedBallIDs.count == challengeTargets.count,
              intendedBallIDs == ballIDs else {
            return nil
        }

        let ballsByID = Dictionary(uniqueKeysWithValues: answerBalls.map { ($0.id, $0) })
        guard challengeTargets.allSatisfy({ target in
                  guard case .semanticValue(let expectedValue) = target.challenge.expectedAnswer,
                        let intendedBall = ballsByID[target.intendedBallID] else {
                      return false
                  }
                  return expectedValue == intendedBall.semanticValue
              }) else {
            return nil
        }

        self.id = id
        self.answerBalls = answerBalls
        self.challengeTargets = challengeTargets
        self.mechanic = .answerChoice
    }

    init?(
        id: SoccerRoundID,
        answerBalls: [SoccerAnswerBall],
        orderedTokenContent: SoccerOrderedTokenContent
    ) {
        let ballIDs = Set(answerBalls.map(\.id))
        let ballTokens = answerBalls.compactMap(\.orderedToken)
        let expectedTokens = orderedTokenContent.expectedTokenSequence

        guard !answerBalls.isEmpty,
              ballIDs.count == answerBalls.count,
              ballTokens.count == answerBalls.count,
              answerBalls.allSatisfy({ ball in
                  ball.semanticValue == .contentItem(orderedTokenContent.contentItemID)
              }),
              Self.occurrences(in: ballTokens) == Self.occurrences(in: expectedTokens) else {
            return nil
        }

        self.id = id
        self.answerBalls = answerBalls
        self.challengeTargets = []
        self.mechanic = .orderedTokens(orderedTokenContent)
    }

    private static func occurrences(
        in tokens: [LearningTextRepresentation]
    ) -> [LearningTextRepresentation: Int] {
        tokens.reduce(into: [:]) { counts, token in
            counts[token, default: 0] += 1
        }
    }
}

struct AttemptResult: Hashable, Sendable {
    let challengeID: ChallengeID
    let activityType: ActivityType
    let primarySkill: SkillID
    let curriculumStage: CurriculumStageID
    let difficulty: Difficulty
    let isCorrect: Bool
    let attemptNumber: Int
    let responseDuration: Duration?

    init?(
        challengeID: ChallengeID,
        activityType: ActivityType,
        primarySkill: SkillID,
        curriculumStage: CurriculumStageID,
        difficulty: Difficulty,
        isCorrect: Bool,
        attemptNumber: Int,
        responseDuration: Duration? = nil
    ) {
        guard attemptNumber > 0,
              responseDuration.map({ $0 >= .zero }) ?? true else {
            return nil
        }

        self.challengeID = challengeID
        self.activityType = activityType
        self.primarySkill = primarySkill
        self.curriculumStage = curriculumStage
        self.difficulty = difficulty
        self.isCorrect = isCorrect
        self.attemptNumber = attemptNumber
        self.responseDuration = responseDuration
    }
}

enum GameOutcome: String, Hashable, Codable, Sendable {
    case goal
    case miss
    case saved
}
