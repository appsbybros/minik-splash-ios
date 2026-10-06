import Foundation

enum MathPresentationMechanic: Hashable, Sendable {
    case learn
    case matching
    case build
    case choice
    case soccerPrompt
    case soccerBall
    case countConstruction
}

struct MathContentFitGate: Sendable {
    private let evaluator: @Sendable (Representation, MathPresentationMechanic) -> Bool

    init(
        evaluator: @escaping @Sendable (Representation, MathPresentationMechanic) -> Bool
    ) {
        self.evaluator = evaluator
    }

    func allows(
        _ representations: [Representation],
        for mechanic: MathPresentationMechanic
    ) -> Bool {
        !representations.isEmpty && representations.allSatisfy { evaluator($0, mechanic) }
    }

    static let production = MathContentFitGate { representation, mechanic in
        guard let text = representation.mathFitText else { return true }
        return MathPresentationFitPolicy.decision(
            for: text,
            constraints: MathContentFitGate.constraints(for: mechanic)
        ) != .unfit
    }

    static let rejectingForTests = MathContentFitGate { _, _ in false }

    private static func constraints(
        for mechanic: MathPresentationMechanic
    ) -> MathPresentationConstraints {
        switch mechanic {
        case .soccerBall:
            return MathPresentationConstraints(
                availableWidth: 118,
                maximumExpandedWidth: 150,
                preferredFontSize: 26
            )
        case .matching:
            return MathPresentationConstraints(
                availableWidth: 230,
                maximumExpandedWidth: 320,
                preferredFontSize: 30
            )
        case .build:
            return MathPresentationConstraints(
                availableWidth: 360,
                maximumExpandedWidth: 560,
                preferredFontSize: 42
            )
        case .choice, .soccerPrompt, .countConstruction:
            return MathPresentationConstraints(
                availableWidth: 360,
                maximumExpandedWidth: 560,
                preferredFontSize: 40
            )
        case .learn:
            return MathPresentationConstraints(
                availableWidth: 420,
                maximumExpandedWidth: 620,
                preferredFontSize: 46
            )
        }
    }
}

private extension Representation {
    var mathFitText: String? {
        switch self {
        case .mathExpression(let expression): return expression.expression
        case .visualQuantity: return nil
        case .math(let representation): return representation.displayText
        case .learningText, .imageAsset, .audioAsset: return nil
        }
    }
}
