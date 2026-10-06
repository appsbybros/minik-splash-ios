enum MathActivitySession: Sendable {
    case learn(LearnSession)
    case multipleChoice(MultipleChoiceSession)
    case build(BuildSession)
    case tower(TowerSession)
    case pairs(PairsSession)
    case memory(MemorySession)
    case soccer(SoccerSession)
}

struct MathActivitySessionFactory: Sendable {
    private static let challengeCount = 6

    private let configuration: ProductConfiguration
    private let provider = MathContentProvider()

    init(configuration: ProductConfiguration) {
        self.configuration = configuration
    }

    func makeSession(
        for activity: MathActivityKind,
        levelID: MathCurriculumLevelID
    ) -> MathActivitySession? {
        switch activity {
        case .learn:
            return makeLearnSession(for: levelID).map(MathActivitySession.learn)
        case .multipleChoice:
            return makeMultipleChoiceSession(for: levelID).map(MathActivitySession.multipleChoice)
        case .build:
            return makeBuildSession(for: levelID).map(MathActivitySession.build)
        case .tower:
            return makeTowerSession(for: levelID).map(MathActivitySession.tower)
        case .pairs:
            return makePairsSession(for: levelID).map(MathActivitySession.pairs)
        case .memory:
            return makeMemorySession(for: levelID).map(MathActivitySession.memory)
        case .soccer:
            return makeSoccerSession(for: levelID).map(MathActivitySession.soccer)
        }
    }

    func makeLearnSession(for levelID: MathCurriculumLevelID) -> LearnSession? {
        guard let request = request(for: .learn, levelID: levelID) else {
            return nil
        }

        return LearnSession(cards: provider.studyCards(for: request))
    }

    func makeMultipleChoiceSession(
        for levelID: MathCurriculumLevelID
    ) -> MultipleChoiceSession? {
        guard let request = request(for: .multipleChoice, levelID: levelID),
              let challenges = makeChallenges(
                  count: Self.challengeCount,
                  build: {
                      provider.challenge(for: request)
                  }
              ) else {
            return nil
        }

        return MultipleChoiceSession(challenges: challenges)
    }

    func makeBuildSession(for levelID: MathCurriculumLevelID) -> BuildSession? {
        guard let request = request(for: .build, levelID: levelID),
              let challenges = makeBuildChallenges(
                  count: Self.challengeCount,
                  build: {
                      provider.buildChallenge(for: request)
                  }
              ) else {
            return nil
        }

        return BuildSession(challenges: challenges)
    }

    func makeTowerSession(for levelID: MathCurriculumLevelID) -> TowerSession? {
        guard let request = request(for: .tower, levelID: levelID),
              let rounds = makeComparableSets(
                  count: Self.challengeCount,
                  build: {
                      provider.comparableSet(for: request)
                  }
              ) else {
            return nil
        }

        return TowerSession(rounds: rounds)
    }

    func makePairsSession(for levelID: MathCurriculumLevelID) -> PairsSession? {
        guard let request = request(for: .pairs, levelID: levelID) else {
            return nil
        }
        let sets = provider.equivalenceSets(for: request)

        guard sets.count == 4 else {
            return nil
        }

        return PairsSession(equivalenceSets: sets)
    }

    func makeMemorySession(for levelID: MathCurriculumLevelID) -> MemorySession? {
        guard let request = request(for: .memory, levelID: levelID) else {
            return nil
        }
        let sets = provider.equivalenceSets(for: request)

        guard sets.count == 4 else {
            return nil
        }

        return MemorySession(equivalenceSets: sets)
    }

    func makeSoccerSession(for levelID: MathCurriculumLevelID) -> SoccerSession? {
        guard let request = request(for: .soccer, levelID: levelID),
              let round = provider.soccerRound(for: request) else {
            return nil
        }

        return SoccerSession(round: round)
    }

    private func request(
        for activity: MathActivityKind,
        levelID: MathCurriculumLevelID
    ) -> ChallengeRequest? {
        guard configuration.variant == .minikMath,
              configuration.contentDomain == .math,
              let specification = MathCurriculumPolicy.specification(
                  for: activity,
                  levelID: levelID
              ),
              let difficulty = Difficulty(0.5) else {
            return nil
        }

        return ChallengeRequest(
            activityType: specification.activityType,
            curriculumStage: levelID.curriculumStageID,
            primarySkill: specification.primarySkill,
            difficulty: difficulty,
            interaction: specification.interaction,
            countRequirement: nil
        )
    }

    private func makeChallenges(
        count: Int,
        build: () -> Challenge?
    ) -> [Challenge]? {
        var challenges: [Challenge] = []
        challenges.reserveCapacity(count)

        for _ in 0 ..< count {
            guard let challenge = build() else {
                return nil
            }
            challenges.append(challenge)
        }

        return challenges
    }

    private func makeBuildChallenges(
        count: Int,
        build: () -> BuildChallenge?
    ) -> [BuildChallenge]? {
        var challenges: [BuildChallenge] = []
        challenges.reserveCapacity(count)

        for _ in 0 ..< count {
            guard let challenge = build() else {
                return nil
            }
            challenges.append(challenge)
        }

        return challenges
    }

    private func makeComparableSets(
        count: Int,
        build: () -> ComparableSet?
    ) -> [ComparableSet]? {
        var rounds: [ComparableSet] = []
        rounds.reserveCapacity(count)

        for _ in 0 ..< count {
            guard let round = build() else {
                return nil
            }
            rounds.append(round)
        }

        return rounds
    }
}
