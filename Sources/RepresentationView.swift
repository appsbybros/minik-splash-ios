import SwiftUI

struct RepresentationView: View {
    enum Context: Hashable {
        case standard
        case multipleChoicePrompt
        case multipleChoiceChoice
        case soccerPrompt
        case soccerBall
        case buildPrompt
        case buildToken
        case buildConstructedToken
        case pairsTile
        case memoryCard
        case cardsHero
        case towerPrompt
        case towerBlock
        case learnHero
        case languageLearnHero
        case learnSupporting
        case learnIllustration
    }

    let representation: Representation
    let context: Context

    init(
        representation: Representation,
        context: Context = .standard
    ) {
        self.representation = representation
        self.context = context
    }

    @ViewBuilder
    var body: some View {
        switch representation {
        case .learningText(let text):
            learningText(text)

        case .imageAsset(let reference):
            Image(reference.rawValue)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: imageMaxWidth,
                    maxHeight: imageMaxHeight
                )
                .accessibilityLabel("Educational image")

        case .audioAsset:
            Label("Audio", systemImage: "speaker.wave.2")
                .font(.title2)
                .foregroundStyle(.secondary)

        case .mathExpression(let expression):
            mathText(expression.expression)

        case .visualQuantity(let quantity):
            let catalog = MathObjectCatalog.production
            MathQuantityView(
                quantity: quantity.quantity,
                theme: catalog?.theme(forStableKey: "visual.quantity.\(quantity.quantity)"),
                emphasized: context == .learnHero
            )

        case .math(let math):
            mathRepresentation(math)
        }
    }

    @ViewBuilder
    private func mathRepresentation(_ representation: MathRepresentation) -> some View {
        switch representation {
        case .quantity(let quantity):
            let catalog = MathObjectCatalog.production
            MathQuantityView(
                quantity: quantity.count,
                theme: catalog?.theme(forStableKey: quantity.structureID.rawValue),
                emphasized: context == .learnHero
            )
            .accessibilityLabel(representation.accessibilityDescription)
        case .groupedQuantity(let quantity):
            let catalog = MathObjectCatalog.production
            MathQuantityView(
                quantity: quantity.groupCounts.reduce(0, +),
                mode: .grouped(groupCounts: quantity.groupCounts),
                theme: catalog?.theme(forStableKey: quantity.structureID.rawValue),
                groupingAsset: catalog?.groupingAsset(forGroupCount: quantity.groupCounts.count),
                emphasized: context == .learnHero
            )
            .accessibilityLabel(representation.accessibilityDescription)
        case .placeValue(let value):
            MathPlaceValueRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        case .equalGroups(let value):
            MathEqualGroupsRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        case .fraction(let value):
            MathFractionRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        case .numberLine(let value):
            MathNumberLineRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        case .percent(let value):
            MathPercentRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        case .ratio(let value):
            MathRatioRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        case .probability(let value):
            MathProbabilityRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        case .geometry(let value):
            MathGeometryRepresentationView(value: value, context: context)
                .accessibilityLabel(representation.accessibilityDescription)
        default:
            mathText(representation.displayText)
                .accessibilityLabel(representation.accessibilityDescription)
        }
    }

    private func mathText(_ text: String) -> some View {
        Text(text)
            .font(mathFont)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(mathMinimumScaleFactor)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func learningText(_ representation: LearningTextRepresentation) -> some View {
        if let direction = representation.direction {
            learningTextLabel(representation.text, isSingleCharacter: representation.text.count == 1)
                .environment(\.layoutDirection, direction.layoutDirection)
        } else {
            learningTextLabel(representation.text, isSingleCharacter: representation.text.count == 1)
        }
    }

    @ViewBuilder
    private func learningTextLabel(_ text: String, isSingleCharacter: Bool) -> some View {
        let label = Text(text)
            .font(font(for: isSingleCharacter))
            .fontWeight(isSingleCharacter || context == .multipleChoicePrompt ? .bold : .semibold)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.65)

        if context == .cardsHero {
            label.foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.47, blue: 0.95),
                        Color(red: 0.00, green: 0.75, blue: 0.85),
                        Color(red: 0.09, green: 0.65, blue: 0.42)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            label.foregroundStyle(Color.primary.opacity(0.92))
        }
    }

    private func font(for isSingleCharacter: Bool) -> Font {
        switch context {
        case .standard:
            return .title
        case .multipleChoicePrompt:
            if isSingleCharacter {
                return .system(size: 72, weight: .bold, design: .rounded)
            }
            return .system(size: 34, weight: .bold, design: .rounded)
        case .multipleChoiceChoice:
            if isSingleCharacter {
                return .system(size: 44, weight: .bold, design: .rounded)
            }
            return .system(size: 24, weight: .semibold, design: .rounded)
        case .soccerPrompt:
            if isSingleCharacter {
                return .system(size: 76, weight: .bold, design: .rounded)
            }
            return .system(size: 36, weight: .bold, design: .rounded)
        case .soccerBall:
            if isSingleCharacter {
                return .system(size: 32, weight: .bold, design: .rounded)
            }
            return .system(size: 20, weight: .semibold, design: .rounded)
        case .buildPrompt:
            if isSingleCharacter {
                return .system(size: 78, weight: .bold, design: .rounded)
            }
            return .system(size: 36, weight: .bold, design: .rounded)
        case .buildToken:
            if isSingleCharacter {
                return .system(size: 34, weight: .bold, design: .rounded)
            }
            return .system(size: 22, weight: .semibold, design: .rounded)
        case .buildConstructedToken:
            if isSingleCharacter {
                return .system(size: 38, weight: .bold, design: .rounded)
            }
            return .system(size: 24, weight: .semibold, design: .rounded)
        case .pairsTile:
            if isSingleCharacter {
                return .system(size: 46, weight: .bold, design: .rounded)
            }
            return .system(size: 24, weight: .semibold, design: .rounded)
        case .memoryCard:
            if isSingleCharacter {
                return .system(size: 42, weight: .bold, design: .rounded)
            }
            return .system(size: 22, weight: .semibold, design: .rounded)
        case .cardsHero:
            if isSingleCharacter {
                return .system(size: 92, weight: .bold, design: .rounded)
            }
            return .system(size: 52, weight: .bold, design: .rounded)
        case .towerPrompt:
            if isSingleCharacter {
                return .system(size: 72, weight: .bold, design: .rounded)
            }
            return .system(size: 34, weight: .bold, design: .rounded)
        case .towerBlock:
            if isSingleCharacter {
                return .system(size: 36, weight: .bold, design: .rounded)
            }
            return .system(size: 22, weight: .semibold, design: .rounded)
        case .learnHero:
            if isSingleCharacter {
                return .system(size: 84, weight: .bold, design: .rounded)
            }
            return .system(size: 42, weight: .bold, design: .rounded)
        case .languageLearnHero:
            if isSingleCharacter {
                return .system(size: 116, weight: .bold, design: .rounded)
            }
            return .system(size: 48, weight: .bold, design: .rounded)
        case .learnSupporting:
            if isSingleCharacter {
                return .system(size: 52, weight: .bold, design: .rounded)
            }
            return .system(size: 28, weight: .semibold, design: .rounded)
        case .learnIllustration:
            return .title
        }
    }

    private var imageMaxWidth: CGFloat {
        switch context {
        case .multipleChoiceChoice:
            return 220
        case .soccerPrompt:
            return 260
        case .soccerBall:
            return 150
        case .buildPrompt:
            return 320
        case .pairsTile:
            return 220
        case .memoryCard:
            return 210
        case .cardsHero:
            return 420
        case .towerPrompt:
            return 300
        case .towerBlock:
            return 220
        case .learnIllustration:
            return 240
        default:
            return 360
        }
    }

    private var imageMaxHeight: CGFloat {
        switch context {
        case .multipleChoiceChoice:
            return 170
        case .soccerPrompt:
            return 210
        case .soccerBall:
            return 110
        case .buildPrompt:
            return 240
        case .pairsTile:
            return 170
        case .memoryCard:
            return 160
        case .cardsHero:
            return 280
        case .towerPrompt:
            return 220
        case .towerBlock:
            return 160
        case .learnIllustration:
            return 220
        default:
            return 300
        }
    }

    private var mathFont: Font {
        switch context {
        case .multipleChoicePrompt:
            return .system(size: 40, weight: .bold, design: .rounded)
        case .soccerPrompt:
            return .system(size: 42, weight: .bold, design: .rounded)
        case .soccerBall:
            return .system(size: 26, weight: .semibold, design: .rounded)
        case .buildPrompt:
            return .system(size: 42, weight: .bold, design: .rounded)
        case .buildToken:
            return .system(size: 30, weight: .semibold, design: .rounded)
        case .buildConstructedToken:
            return .system(size: 32, weight: .bold, design: .rounded)
        case .pairsTile:
            return .system(size: 30, weight: .semibold, design: .rounded)
        case .memoryCard:
            return .system(size: 28, weight: .semibold, design: .rounded)
        case .cardsHero:
            return .system(size: 48, weight: .bold, design: .rounded)
        case .towerPrompt:
            return .system(size: 40, weight: .bold, design: .rounded)
        case .towerBlock:
            return .system(size: 28, weight: .semibold, design: .rounded)
        case .learnHero, .languageLearnHero:
            return .system(size: 46, weight: .bold, design: .rounded)
        case .learnSupporting:
            return .system(size: 30, weight: .semibold, design: .rounded)
        default:
            return .largeTitle
        }
    }

    private var mathMinimumScaleFactor: CGFloat {
        CGFloat(MathPresentationFitPolicy.minimumReadablePointSize / mathPreferredPointSize)
    }

    private var mathPreferredPointSize: Double {
        switch context {
        case .multipleChoicePrompt: return 40
        case .soccerPrompt: return 42
        case .soccerBall: return 26
        case .buildPrompt: return 42
        case .buildToken: return 30
        case .buildConstructedToken: return 32
        case .pairsTile: return 30
        case .memoryCard: return 28
        case .cardsHero: return 48
        case .towerPrompt: return 40
        case .towerBlock: return 28
        case .learnHero, .languageLearnHero: return 46
        case .learnSupporting: return 30
        default: return 34
        }
    }
}
