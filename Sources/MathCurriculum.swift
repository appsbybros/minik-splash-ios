import Foundation

struct MathCurriculumLevelID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        precondition(!rawValue.isEmpty, "A Math curriculum level identifier cannot be empty.")
        self.rawValue = rawValue
    }

    static let m1 = MathCurriculumLevelID(rawValue: "M1")
    static let m2 = MathCurriculumLevelID(rawValue: "M2")
    static let m3 = MathCurriculumLevelID(rawValue: "M3")
    static let m4 = MathCurriculumLevelID(rawValue: "M4")
    static let m5 = MathCurriculumLevelID(rawValue: "M5")
    static let m6 = MathCurriculumLevelID(rawValue: "M6")
    static let m7 = MathCurriculumLevelID(rawValue: "M7")
    static let m8 = MathCurriculumLevelID(rawValue: "M8")
    static let m9 = MathCurriculumLevelID(rawValue: "M9")
    static let m10 = MathCurriculumLevelID(rawValue: "M10")

    var curriculumStageID: CurriculumStageID {
        CurriculumStageID(rawValue: rawValue)
    }
}

enum MathCurriculumAvailability: Hashable, Sendable {
    case implemented
    case planned
}

struct MathCurriculumLevelDescriptor: Identifiable, Hashable, Sendable {
    let id: MathCurriculumLevelID
    let title: String
    let subtitle: String
    let availability: MathCurriculumAvailability

    var stableTitle: String { id.rawValue }
}

struct MathActivitySpecification: Hashable, Sendable {
    let activityType: ActivityType
    let primarySkill: SkillID
    let interaction: Interaction?
}

enum MathCurriculumPolicy {
    static let levels: [MathCurriculumLevelDescriptor] = [
        MathCurriculumLevelDescriptor(
            id: .m1,
            title: String(localized: "Level 1"),
            subtitle: String(localized: "Numbers represent quantities"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m2,
            title: String(localized: "Level 2"),
            subtitle: String(localized: "Numbers compose and decompose; early operations"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m3,
            title: String(localized: "Level 3"),
            subtitle: String(localized: "Operations and relationships between expressions"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m4,
            title: String(localized: "Level 4"),
            subtitle: String(localized: "Place value, numbers to 100, and richer addition and subtraction"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m5,
            title: String(localized: "Level 5"),
            subtitle: String(localized: "Meaning of multiplication and division"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m6,
            title: String(localized: "Level 6"),
            subtitle: String(localized: "Fluency, factors, multiples, and initial fraction relationships"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m7,
            title: String(localized: "Level 7"),
            subtitle: String(localized: "Fractions and decimals as numbers"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m8,
            title: String(localized: "Level 8"),
            subtitle: String(localized: "Fraction, decimal, percent, and ratio relationships"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m9,
            title: String(localized: "Level 9"),
            subtitle: String(localized: "Pre-algebra"),
            availability: .implemented
        ),
        MathCurriculumLevelDescriptor(
            id: .m10,
            title: String(localized: "Level 10"),
            subtitle: String(localized: "Algebraic relationships"),
            availability: .implemented
        )
    ]

    static var runnableLevels: [MathCurriculumLevelDescriptor] {
        levels.filter { level in
            level.availability == .implemented
                && !supportedActivities(for: level.id).isEmpty
        }
    }

    static var defaultRunnableLevel: MathCurriculumLevelDescriptor {
        guard let level = runnableLevels.first else {
            preconditionFailure("The Math product requires at least one runnable level.")
        }
        return level
    }

    static var latestRunnableLevel: MathCurriculumLevelDescriptor {
        guard let level = runnableLevels.last else {
            preconditionFailure("The Math product requires at least one runnable level.")
        }
        return level
    }

    static func level(
        for id: MathCurriculumLevelID
    ) -> MathCurriculumLevelDescriptor? {
        levels.first { $0.id == id }
    }

    static func supportedActivities(
        for levelID: MathCurriculumLevelID
    ) -> [MathActivityKind] {
        MathActivityKind.allCases.filter {
            specification(for: $0, levelID: levelID) != nil
        }
    }

    static func unsupportedActivities(
        for levelID: MathCurriculumLevelID
    ) -> [MathActivityKind] {
        MathActivityKind.allCases.filter {
            specification(for: $0, levelID: levelID) == nil
        }
    }

    static func specification(
        for activity: MathActivityKind,
        levelID: MathCurriculumLevelID
    ) -> MathActivitySpecification? {
        guard level(for: levelID)?.availability == .implemented,
              let coreSkill = coreSkill(for: levelID) else {
            return nil
        }

        switch activity {
        case .learn:
            return MathActivitySpecification(
                activityType: .learn,
                primarySkill: coreSkill,
                interaction: nil
            )
        case .multipleChoice:
            return singleChoiceSpecification(skill: coreSkill)
        case .build:
            // Ordered equation construction does not express M1's
            // quantity-to-numeral relationship with the current Build engine.
            return levelID == .m1 ? nil : buildSpecification(skill: coreSkill)
        case .tower:
            return towerSpecification
        case .pairs:
            return matchingSpecification(activityType: .pairs)
        case .memory:
            return matchingSpecification(activityType: .memory)
        case .soccer:
            return soccerSpecification(skill: coreSkill)
        }
    }

    private static func coreSkill(
        for levelID: MathCurriculumLevelID
    ) -> SkillID? {
        switch levelID {
        case .m1:
            return MathSkillIDs.quantityToNumber
        case .m2:
            return MathSkillIDs.addition
        case .m3:
            return MathSkillIDs.missingAddend
        case .m4:
            return MathSkillIDs.placeValue
        case .m5:
            return MathSkillIDs.equalGroups
        case .m6:
            return MathSkillIDs.factors
        case .m7:
            return MathSkillIDs.decimalFractions
        case .m8:
            return MathSkillIDs.fractionDecimalPercent
        case .m9:
            return MathSkillIDs.equations
        case .m10:
            return MathSkillIDs.linearRelationships
        default:
            return nil
        }
    }

    private static func singleChoiceSpecification(
        skill: SkillID
    ) -> MathActivitySpecification {
        MathActivitySpecification(
            activityType: .multipleChoice,
            primarySkill: skill,
            interaction: .singleChoice
        )
    }

    private static func buildSpecification(
        skill: SkillID
    ) -> MathActivitySpecification {
        MathActivitySpecification(
            activityType: .build,
            primarySkill: skill,
            interaction: .orderedTokens
        )
    }

    private static var towerSpecification: MathActivitySpecification {
        MathActivitySpecification(
            activityType: .tower,
            primarySkill: MathSkillIDs.orderValues,
            interaction: .orderedTokens
        )
    }

    private static func matchingSpecification(
        activityType: ActivityType
    ) -> MathActivitySpecification {
        MathActivitySpecification(
            activityType: activityType,
            primarySkill: MathSkillIDs.equivalentValues,
            interaction: .matching
        )
    }

    private static func soccerSpecification(
        skill: SkillID
    ) -> MathActivitySpecification {
        MathActivitySpecification(
            activityType: .soccer,
            primarySkill: skill,
            interaction: .singleChoice
        )
    }
}
