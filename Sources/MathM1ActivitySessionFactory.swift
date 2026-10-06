enum MathM1ActivitySession: Sendable {
    case learn(LearnSession)
    case pairs(PairsSession)
    case buildNumber(BuildSession)
    case buildQuantity(MathCountConstructionSession)
    case visualToAnswer(MultipleChoiceSession)
    case answerToRepresentation(MultipleChoiceSession)
    case buildMath(BuildSession)
    case mixed(MathM1MixedSession)
    case cards(CardsSession)
    case soccer(SoccerSession)
    case tower(MathCountConstructionSession)
    case memory(MemorySession)
}

struct MathM1MixedSession: Sendable {
    static let eligibleActivities: [MathProductionActivityID] = [
        .mathPairs,
        .buildNumber,
        .buildQuantity,
        .visualToAnswer,
        .answerToRepresentation,
        .buildMath,
        .mathSoccer,
        .mathTower,
        .mathMemory
    ]

    private(set) var currentActivity: MathProductionActivityID

    init() {
        currentActivity = Self.eligibleActivities.randomElement() ?? .visualToAnswer
    }

    mutating func advance() {
        let alternatives = Self.eligibleActivities.filter { $0 != currentActivity }
        currentActivity = alternatives.randomElement() ?? currentActivity
    }
}

struct MathM1ActivitySessionFactory: Sendable {
    private static let challengeCount = 6
    private let provider = MathM1ContentProvider()

    init(configuration: ProductConfiguration) {
        precondition(configuration.variant == .minikMath)
    }

    func makeSession(for activity: MathProductionActivityID) -> MathM1ActivitySession? {
        switch activity {
        case .learnMath:
            return LearnSession(cards: provider.studyCards()).map(MathM1ActivitySession.learn)
        case .mathPairs:
            return PairsSession(equivalenceSets: provider.equivalenceSets())
                .map(MathM1ActivitySession.pairs)
        case .buildNumber:
            return makeBuildNumberSession().map(MathM1ActivitySession.buildNumber)
        case .buildQuantity:
            return makeCountSession(includeZero: true).map(MathM1ActivitySession.buildQuantity)
        case .visualToAnswer:
            return makeChoiceSession(direction: .quantityToNumeral)
                .map(MathM1ActivitySession.visualToAnswer)
        case .answerToRepresentation:
            return makeChoiceSession(direction: .numeralToQuantity)
                .map(MathM1ActivitySession.answerToRepresentation)
        case .buildMath:
            return makeBuildCountSession().map(MathM1ActivitySession.buildMath)
        case .mathMixed:
            return .mixed(MathM1MixedSession())
        case .mathCards:
            return CardsSession(cards: provider.studyCards(shuffled: true))
                .map(MathM1ActivitySession.cards)
        case .mathSoccer:
            return provider.soccerRound().map { SoccerSession(round: $0) }
                .map(MathM1ActivitySession.soccer)
        case .mathTower:
            return makeCountSession(includeZero: true).map(MathM1ActivitySession.tower)
        case .mathMemory:
            return MemorySession(equivalenceSets: provider.equivalenceSets())
                .map(MathM1ActivitySession.memory)
        case .pingPong:
            return nil
        }
    }

    private func makeChoiceSession(
        direction: MathM1ChoiceDirection
    ) -> MultipleChoiceSession? {
        let challenges = targets(includeZero: true).compactMap {
            provider.choiceChallenge(target: $0, direction: direction)
        }
        guard challenges.count == Self.challengeCount else { return nil }
        return MultipleChoiceSession(challenges: challenges, progressionPolicy: .retryUntilCorrect)
    }

    private func makeBuildNumberSession() -> BuildSession? {
        let challenges = targets(includeZero: true).compactMap(provider.buildNumberChallenge)
        guard challenges.count == Self.challengeCount else { return nil }
        return BuildSession(challenges: challenges)
    }

    private func makeBuildCountSession() -> BuildSession? {
        let challenges = targets(includeZero: false).compactMap(provider.buildCountChallenge)
        guard challenges.count == Self.challengeCount else { return nil }
        return BuildSession(challenges: challenges)
    }

    private func makeCountSession(includeZero: Bool) -> MathCountConstructionSession? {
        let rounds = targets(includeZero: includeZero).compactMap(provider.countRound)
        guard rounds.count == Self.challengeCount else { return nil }
        return MathCountConstructionSession(rounds: rounds)
    }

    private func targets(includeZero: Bool) -> [Int] {
        let source = includeZero ? MathM1ContentProvider.values : Array(1...10)
        return Array(source.shuffled().prefix(Self.challengeCount))
    }
}
