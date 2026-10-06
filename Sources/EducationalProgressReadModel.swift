import Foundation

struct EducationalActivityProgressRow: Hashable, Sendable, Identifiable {
    let activityID: ProgressActivityID
    let title: String
    let totalAttempts: Int
    let firstAttemptCount: Int
    let firstAttemptCorrectCount: Int
    let practiceDurationSeconds: Double
    let lastPracticedAt: Date?

    var id: String { activityID.rawValue }

    var firstAttemptAccuracy: Double? {
        guard firstAttemptCount > 0 else { return nil }
        return Double(firstAttemptCorrectCount) / Double(firstAttemptCount)
    }
}

struct EducationalRecentPracticeItem: Hashable, Sendable, Identifiable {
    let activityID: ProgressActivityID
    let title: String
    let practicedAt: Date
    let totalAttempts: Int

    var id: String { activityID.rawValue }
}

struct EducationalProgressReadModel: Hashable, Sendable {
    let product: ProductVariant
    let totalAttempts: Int
    let firstAttemptCount: Int
    let firstAttemptCorrectCount: Int
    let practiceDurationSeconds: Double
    let activityRows: [EducationalActivityProgressRow]
    let recentPractice: [EducationalRecentPracticeItem]
    let mathLevelID: MathCurriculumLevelID?
    let mathLevelMode: MathLevelMode?

    var isEmpty: Bool { totalAttempts == 0 && activityRows.isEmpty }

    var firstAttemptAccuracy: Double? {
        guard firstAttemptCount > 0 else { return nil }
        return Double(firstAttemptCorrectCount) / Double(firstAttemptCount)
    }
}

enum EducationalProgressReadModelBuilder {
    static func make(
        snapshot: ProgressSnapshot,
        product: ProductVariant,
        mathLevelState: MathLevelState? = nil,
        recentLimit: Int = 5
    ) -> EducationalProgressReadModel {
        let rows = snapshot.summaries
            .filter {
                $0.context.product == product
                    && $0.gradedAttempts > 0
                    && EducationalProgressActivityPolicy.isMasteryActivity($0.context.activityID)
            }
            .map { summary in
                EducationalActivityProgressRow(
                    activityID: summary.context.activityID,
                    title: EducationalProgressActivityNames.title(for: summary.context.activityID),
                    totalAttempts: summary.gradedAttempts,
                    firstAttemptCount: summary.firstAttemptCorrectAnswers
                        + summary.firstAttemptIncorrectAnswers
                        + summary.firstAttemptSkips,
                    firstAttemptCorrectCount: summary.firstAttemptCorrectAnswers,
                    practiceDurationSeconds: summary.practiceDurationSeconds,
                    lastPracticedAt: summary.lastPracticedAt
                )
            }
            .sorted { $0.activityID.rawValue < $1.activityID.rawValue }

        let recent = rows.compactMap { row -> EducationalRecentPracticeItem? in
            guard let practicedAt = row.lastPracticedAt else { return nil }
            return EducationalRecentPracticeItem(
                activityID: row.activityID,
                title: row.title,
                practicedAt: practicedAt,
                totalAttempts: row.totalAttempts
            )
        }.sorted {
            if $0.practicedAt == $1.practicedAt {
                return $0.activityID.rawValue < $1.activityID.rawValue
            }
            return $0.practicedAt > $1.practicedAt
        }

        return EducationalProgressReadModel(
            product: product,
            totalAttempts: rows.reduce(0) { $0 + $1.totalAttempts },
            firstAttemptCount: rows.reduce(0) { $0 + $1.firstAttemptCount },
            firstAttemptCorrectCount: rows.reduce(0) { $0 + $1.firstAttemptCorrectCount },
            practiceDurationSeconds: rows.reduce(0) { $0 + $1.practiceDurationSeconds },
            activityRows: rows,
            recentPractice: Array(recent.prefix(max(0, recentLimit))),
            mathLevelID: product == .minikMath ? mathLevelState?.activeLevelID : nil,
            mathLevelMode: product == .minikMath ? mathLevelState?.mode : nil
        )
    }
}

enum EducationalProgressActivityPolicy {
    private static let excludedActivityIDs: Set<String> = [
        "language.learn",
        "language.wordCards",
        "language.ticTacToe",
        "math.learnMath",
        "math.mathCards",
        "math.pingPong",
        "pingPong"
    ]

    static func isMasteryActivity(_ activityID: ProgressActivityID) -> Bool {
        !excludedActivityIDs.contains(activityID.rawValue)
    }
}

enum EducationalProgressActivityNames {
    static func title(for activityID: ProgressActivityID) -> String {
        let rawValue = activityID.rawValue
        if rawValue.hasPrefix("math."),
           let activity = MathProductionActivityID(rawValue: String(rawValue.dropFirst(5))) {
            return activity.title
        }
        if rawValue.hasPrefix("language."),
           let activity = LanguageActivityKind(rawValue: String(rawValue.dropFirst(9))) {
            return activity.title
        }

        switch rawValue {
        case "math.multipleChoice": return String(localized: "Math choices")
        case "math.buildNumber": return String(localized: "Build Number")
        case "math.buildQuantity": return String(localized: "Build Quantity")
        case "math.buildMath": return String(localized: "Build Math")
        case "math.pairs": return String(localized: "Math Pairs")
        case "math.memory": return String(localized: "Math Memory")
        case "math.soccer": return String(localized: "Math Soccer")
        case "math.tower": return String(localized: "Math Tower")
        case "math.mixed": return String(localized: "Math Mixed")
        default: return String(localized: "Practice activity")
        }
    }
}
