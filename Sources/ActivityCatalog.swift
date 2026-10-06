import Foundation

enum ActivityTheme: String, Sendable {
    case sky
    case meadow
    case sunshine
    case coral
    case berry
}

struct ActivitySection<Kind: Hashable & Sendable>: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let activities: [Kind]
}

enum ActivityCatalog {
    static func languageSections(
        for configuration: ProductConfiguration
    ) -> [ActivitySection<LanguageActivityKind>] {
        guard configuration.contentDomain == .language else {
            return []
        }

        return LanguageActivityKind.sections
    }

    static func mathSections(
        for configuration: ProductConfiguration,
        levelID: MathCurriculumLevelID
    ) -> [ActivitySection<MathProductionActivityID>] {
        guard configuration.contentDomain == .math else {
            return []
        }

        return MathProductionActivityID.sections.compactMap { section in
            let activities = section.activities.filter { $0.curriculumRole == .curriculum }
            guard !activities.isEmpty else { return nil }
            return ActivitySection(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                activities: activities
            )
        }
    }

    static func productGameSections(
        for configuration: ProductConfiguration
    ) -> [ActivitySection<ProductGameKind>] {
        guard configuration.variant == .minikMath else {
            return []
        }
        return [
            ActivitySection(
                id: "just-for-fun",
                title: String(localized: "Just for Fun"),
                subtitle: String(localized: "Take a playful break with Minik."),
                activities: [.pingPong]
            )
        ]
    }
}

enum ProductGameKind: String, Hashable, Identifiable, Sendable {
    case pingPong

    var id: String { rawValue }
    var title: String { String(localized: "Ping Pong") }
    var subtitle: String { String(localized: "Play table tennis with Minik") }
    var symbolName: String { "figure.table.tennis" }
    var theme: ActivityTheme { .berry }
}

enum LanguageActivityKind: String, CaseIterable, Hashable, Identifiable, Sendable {
    case learn
    case multipleChoice
    case build
    case pairs
    case memory
    case firstLetterChoices
    case firstLetterPictures
    case wordBuild
    case letterPairs
    case imageToWord
    case wordToImage
    case wordMemory
    case wordCards
    case mixed
    case soccer
    case tower
    // This is a language-product menu item, not a language-learning activity.
    // Its destination deliberately bypasses LanguageActivitySessionFactory.
    case ticTacToe

    var id: String { rawValue }
    var title: String { String(localized: titleKey) }

    var titleKey: String.LocalizationValue {
        switch self {
        case .learn: return "Learn"
        case .multipleChoice: return "Choose"
        case .build: return "Build"
        case .pairs: return "Pairs"
        case .memory: return "Memory"
        case .firstLetterChoices: return "First Letter"
        case .firstLetterPictures: return "Picture Starters"
        case .wordBuild: return "Word Build"
        case .letterPairs: return "Letter Pairs"
        case .imageToWord: return "Picture to Word"
        case .wordToImage: return "Word to Picture"
        case .wordMemory: return "Picture Memory"
        case .wordCards: return "Word Cards"
        case .mixed: return "Mixed"
        case .soccer: return "Soccer"
        case .tower: return "Alphabet Blocks"
        case .ticTacToe: return "Tic-Tac-Toe"
        }
    }

    var subtitle: String {
        switch self {
        case .learn: return String(localized: "Meet new words and letters")
        case .multipleChoice: return String(localized: "Pick the matching answer")
        case .build: return String(localized: "Put the pieces in order")
        case .pairs: return String(localized: "Match what belongs together")
        case .memory: return String(localized: "Flip and find matches")
        case .firstLetterChoices: return String(localized: "Choose the starting letter")
        case .firstLetterPictures: return String(localized: "Match the first sound to a picture")
        case .wordBuild: return String(localized: "Spell the whole word")
        case .letterPairs: return String(localized: "Match words with their starters")
        case .imageToWord: return String(localized: "Find the word for the picture")
        case .wordToImage: return String(localized: "Find the picture for the word")
        case .wordMemory: return String(localized: "Match pictures and hear their words")
        case .wordCards: return String(localized: "Browse words again and again")
        case .mixed: return String(localized: "Cycle through picture, word, and spelling practice")
        case .soccer: return String(localized: "Kick letters to build the word")
        case .tower: return String(localized: "Drag letters to build a word tower")
        case .ticTacToe: return String(localized: "Just for Fun")
        }
    }

    var symbolName: String {
        switch self {
        case .learn: return "sparkles"
        case .multipleChoice: return "checkmark.circle"
        case .build: return "textformat.abc"
        case .pairs: return "square.grid.2x2"
        case .memory: return "rectangle.on.rectangle"
        case .firstLetterChoices: return "text.cursor"
        case .firstLetterPictures: return "photo.on.rectangle"
        case .wordBuild: return "text.badge.plus"
        case .letterPairs: return "link"
        case .imageToWord: return "photo"
        case .wordToImage: return "photo.fill"
        case .wordMemory: return "square.stack.3d.up"
        case .wordCards: return "rectangle.stack"
        case .mixed: return "shuffle"
        case .soccer: return "soccerball"
        case .tower: return "building.columns"
        case .ticTacToe: return "squareshape.split.3x3"
        }
    }

    var theme: ActivityTheme {
        switch self {
        case .learn, .wordCards, .firstLetterPictures, .imageToWord, .wordToImage, .mixed:
            return .sky
        case .multipleChoice, .firstLetterChoices:
            return .sunshine
        case .build, .wordBuild:
            return .coral
        case .pairs, .letterPairs, .tower, .ticTacToe:
            return .berry
        case .memory, .wordMemory, .soccer:
            return .meadow
        }
    }

    static let sections: [ActivitySection<LanguageActivityKind>] = [
        ActivitySection(
            id: "letters",
            title: String(localized: "Letters"),
            subtitle: String(localized: "Short playful activities for early reading."),
            activities: [.learn, .letterPairs, .firstLetterChoices, .firstLetterPictures]
        ),
        ActivitySection(
            id: "words",
            title: String(localized: "Words"),
            subtitle: String(localized: "Picture, memory, and word-building games."),
            activities: [
                .mixed,
                .wordBuild,
                .imageToWord,
                .wordToImage,
                .wordCards
            ]
        ),
        ActivitySection(
            id: "games",
            title: String(localized: "Games"),
            subtitle: String(localized: "Pick a game and have fun."),
            activities: [.soccer, .tower, .wordMemory, .ticTacToe]
        )
    ]

    /// The Android-visible production menu contract. Generic engines such as
    /// `multipleChoice`, `build`, `pairs`, and `memory` remain available to
    /// development tooling but are not separate production activities.
    static let productionKinds: [LanguageActivityKind] = sections.flatMap(\.activities)
}

enum MathActivityKind: String, CaseIterable, Hashable, Identifiable, Sendable {
    case learn
    case multipleChoice
    case build
    case tower
    case pairs
    case memory
    case soccer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .learn: return String(localized: "Learn")
        case .multipleChoice: return String(localized: "Choose")
        case .build: return String(localized: "Build")
        case .tower: return String(localized: "Tower")
        case .pairs: return String(localized: "Pairs")
        case .memory: return String(localized: "Memory")
        case .soccer: return String(localized: "Soccer")
        }
    }

    var subtitle: String {
        switch self {
        case .learn: return String(localized: "Meet a new number idea")
        case .multipleChoice: return String(localized: "Pick the right answer")
        case .build: return String(localized: "Build the answer step by step")
        case .tower: return String(localized: "Stack from smallest to biggest")
        case .pairs: return String(localized: "Match equal values")
        case .memory: return String(localized: "Find the matching pair")
        case .soccer: return String(localized: "Kick the right answer")
        }
    }

    var symbolName: String {
        switch self {
        case .learn: return "sparkles"
        case .multipleChoice: return "checkmark.circle"
        case .build: return "square.and.pencil"
        case .tower: return "building.columns"
        case .pairs: return "square.grid.2x2"
        case .memory: return "rectangle.stack"
        case .soccer: return "soccerball"
        }
    }

    var theme: ActivityTheme {
        switch self {
        case .learn, .memory:
            return .sky
        case .multipleChoice:
            return .sunshine
        case .build:
            return .coral
        case .tower:
            return .berry
        case .pairs, .soccer:
            return .meadow
        }
    }

    static let sections: [ActivitySection<MathActivityKind>] = [
        ActivitySection(
            id: "practice",
            title: String(localized: "Practice"),
            subtitle: String(localized: "Gentle number activities to build confidence."),
            activities: [.learn, .multipleChoice, .build]
        ),
        ActivitySection(
            id: "play",
            title: String(localized: "Play"),
            subtitle: String(localized: "Games that keep math moving and hands-on."),
            activities: [.tower, .pairs, .memory, .soccer]
        )
    ]
}

extension LanguageIdentifier {
    var hubTitle: String {
        switch self {
        case .english:
            return String(localized: "English")
        case .hebrew:
            return "עברית"
        default:
            return Locale(identifier: rawValue).localizedString(forIdentifier: rawValue) ?? rawValue
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .english:
            return String(localized: "English")
        case .hebrew:
            return String(localized: "Hebrew")
        default:
            return hubTitle
        }
    }
}
