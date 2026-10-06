import SwiftUI

struct MathPlaceValueRepresentationView: View {
    let value: MathPlaceValueRepresentation
    let context: RepresentationView.Context

    private var components: [MathPlaceValueComponent] {
        value.components.sorted { $0.placeValue > $1.placeValue }
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 82, maximum: 132), spacing: 10)],
            spacing: 10
        ) {
            ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                VStack(spacing: 5) {
                    support(for: component)
                    Text(verbatim: "\(component.digit) × \(component.placeValue)")
                        .font(.system(size: labelSize, weight: .bold, design: .rounded))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    @ViewBuilder
    private func support(for component: MathPlaceValueComponent) -> some View {
        if component.digit == 0 {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.91, green: 0.96, blue: 0.98))
                .frame(height: imageHeight)
        } else if let asset = supportAsset(for: component.placeValue) {
            Image(asset.assetName)
                .resizable()
                .scaledToFit()
                .frame(height: imageHeight)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.35, green: 0.76, blue: 0.82))
                .frame(height: imageHeight)
                .overlay(
                    Text(String(component.placeValue))
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                )
        }
    }

    private func supportAsset(for placeValue: Int) -> MathObjectAsset? {
        let id: String
        switch placeValue {
        case 100: id = "math_place_value_organizer"
        case 10: id = "math_ten_frame"
        default:
            return MathObjectCatalog.production?
                .theme(forStableKey: "\(value.structureID.rawValue).ones")?
                .object(forItemAt: 0)
        }
        return MathObjectCatalog.production?.groupingAsset(named: id)
    }

    private var imageHeight: CGFloat {
        switch context {
        case .memoryCard, .pairsTile: return 52
        case .soccerPrompt, .multipleChoicePrompt, .learnHero, .cardsHero: return 76
        default: return 62
        }
    }

    private var labelSize: CGFloat {
        switch context {
        case .memoryCard, .pairsTile: return 15
        case .soccerPrompt, .multipleChoicePrompt, .learnHero, .cardsHero: return 20
        default: return 17
        }
    }
}

struct MathFractionRepresentationView: View {
    let value: MathFractionRepresentation
    let context: RepresentationView.Context

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 3) {
                ForEach(0..<value.value.denominator, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(index < value.value.numerator
                            ? Color(red: 0.20, green: 0.72, blue: 0.78)
                            : Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color(red: 0.17, green: 0.45, blue: 0.57), lineWidth: 2)
                        )
                }
            }
            .frame(width: barWidth, height: barHeight)

            Text(verbatim: value.value.displayText)
                .font(.system(size: labelSize, weight: .bold, design: .rounded))
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    private var barWidth: CGFloat {
        switch context {
        case .memoryCard, .pairsTile: return 108
        case .soccerPrompt, .multipleChoicePrompt: return 150
        default: return 210
        }
    }

    private var barHeight: CGFloat {
        switch context {
        case .memoryCard, .pairsTile: return 42
        default: return 58
        }
    }

    private var labelSize: CGFloat {
        switch context {
        case .memoryCard, .pairsTile: return 18
        default: return 25
        }
    }
}

struct MathNumberLineRepresentationView: View {
    let value: MathNumberLineRepresentation
    let context: RepresentationView.Context

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let usable = max(1, proxy.size.width - 20)
                let offset = normalizedPosition * usable
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(red: 0.17, green: 0.45, blue: 0.57)).frame(height: 4)
                    Circle().fill(Color(red: 0.96, green: 0.39, blue: 0.32)).frame(width: 20, height: 20).offset(x: offset)
                }.padding(.horizontal, 10)
            }.frame(width: lineWidth, height: 24)
            HStack { Text(verbatim: value.lowerBound.displayText); Spacer(); Text(verbatim: value.upperBound.displayText) }
                .font(.system(size: 16, weight: .bold, design: .rounded)).frame(width: lineWidth)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    private var normalizedPosition: CGFloat {
        let spanNumerator = value.upperBound.numerator * value.lowerBound.denominator - value.lowerBound.numerator * value.upperBound.denominator
        let positionNumerator = value.position.numerator * value.lowerBound.denominator - value.lowerBound.numerator * value.position.denominator
        guard spanNumerator != 0 else { return 0 }
        return min(1, max(0, CGFloat(positionNumerator * value.upperBound.denominator) / CGFloat(spanNumerator * value.position.denominator)))
    }

    private var lineWidth: CGFloat {
        switch context { case .memoryCard, .pairsTile: return 115; case .soccerPrompt, .multipleChoicePrompt: return 160; default: return 230 }
    }
}

struct MathEqualGroupsRepresentationView: View {
    let value: MathEqualGroupsRepresentation
    let context: RepresentationView.Context

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: groupWidth, maximum: groupWidth + 28), spacing: 8)],
            spacing: 8
        ) {
            ForEach(0..<value.groupCount, id: \.self) { groupIndex in
                groupCard(index: groupIndex)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    private func groupCard(index: Int) -> some View {
        ZStack {
            if let asset = MathObjectCatalog.production?.groupingAsset(
                named: value.itemsPerGroup == 10 ? "math_ten_frame" : "math_grouping_tray"
            ) {
                Image(asset.assetName)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.34)
                    .accessibilityHidden(true)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: itemSize, maximum: itemSize), spacing: 2)],
                spacing: 2
            ) {
                ForEach(0..<value.itemsPerGroup, id: \.self) { itemIndex in
                    object(index: index * value.itemsPerGroup + itemIndex)
                }
            }
            .padding(7)
        }
        .frame(minHeight: groupHeight)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func object(index: Int) -> some View {
        if let object = MathObjectCatalog.production?
            .theme(forStableKey: value.structureID.rawValue)?.object(forItemAt: index) {
            Image(object.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: itemSize, height: itemSize)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(Color(red: 0.98, green: 0.62, blue: 0.28))
                .frame(width: itemSize, height: itemSize)
        }
    }

    private var groupWidth: CGFloat {
        switch context {
        case .memoryCard, .pairsTile: return 74
        case .soccerPrompt, .multipleChoicePrompt, .learnHero, .cardsHero: return 104
        default: return 88
        }
    }

    private var groupHeight: CGFloat { value.itemsPerGroup > 5 ? groupWidth : groupWidth * 0.82 }
    private var itemSize: CGFloat { value.itemsPerGroup > 5 ? 18 : 23 }
}

struct MathPercentRepresentationView: View {
    let value: MathPercentRepresentation
    let context: RepresentationView.Context

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.20, green: 0.72, blue: 0.78))
                        .frame(width: proxy.size.width * filledFraction)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(red: 0.17, green: 0.45, blue: 0.57), lineWidth: 2)
                }
            }
            .frame(width: barWidth, height: barHeight)

            Text(verbatim: "\(value.percentValue.displayText)%")
                .font(.system(size: labelSize, weight: .bold, design: .rounded))
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    private var filledFraction: CGFloat {
        let raw = CGFloat(value.percentValue.numerator)
            / CGFloat(value.percentValue.denominator * 100)
        return min(1, max(0, raw))
    }

    private var barWidth: CGFloat {
        switch context {
        case .memoryCard, .pairsTile: return 110
        case .soccerBall: return 90
        case .soccerPrompt, .multipleChoicePrompt: return 160
        default: return 220
        }
    }

    private var barHeight: CGFloat {
        switch context {
        case .memoryCard, .pairsTile, .soccerBall: return 26
        default: return 40
        }
    }

    private var labelSize: CGFloat {
        switch context {
        case .memoryCard, .pairsTile, .soccerBall: return 17
        default: return 25
        }
    }
}

struct MathRatioRepresentationView: View {
    let value: MathRatioRepresentation
    let context: RepresentationView.Context

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                ratioGroup(count: value.first, color: Color(red: 0.96, green: 0.39, blue: 0.32))
                ratioGroup(count: value.second, color: Color(red: 0.20, green: 0.72, blue: 0.78))
            }
            Text(verbatim: "\(value.first):\(value.second)")
                .font(.system(size: labelSize, weight: .bold, design: .rounded))
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    private func ratioGroup(count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { _ in
                Circle().fill(color).frame(width: dotSize, height: dotSize)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
    }

    private var dotSize: CGFloat {
        switch context {
        case .memoryCard, .pairsTile, .soccerBall: return 10
        default: return 16
        }
    }

    private var labelSize: CGFloat {
        switch context {
        case .memoryCard, .pairsTile, .soccerBall: return 17
        default: return 25
        }
    }
}

struct MathProbabilityRepresentationView: View {
    let value: MathProbabilityRepresentation
    let context: RepresentationView.Context

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 5) {
                ForEach(0..<value.totalCount, id: \.self) { index in
                    Circle()
                        .fill(index < value.favorableCount
                            ? Color(red: 0.96, green: 0.39, blue: 0.32)
                            : Color(red: 0.20, green: 0.72, blue: 0.78))
                        .frame(width: dotSize, height: dotSize)
                }
            }
            Text(verbatim: value.exactValue.displayText)
                .font(.system(size: labelSize, weight: .bold, design: .rounded))
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    private var dotSize: CGFloat {
        switch context {
        case .memoryCard, .pairsTile, .soccerBall: return 12
        default: return 19
        }
    }

    private var labelSize: CGFloat {
        switch context {
        case .memoryCard, .pairsTile, .soccerBall: return 17
        default: return 25
        }
    }
}

struct MathGeometryRepresentationView: View {
    let value: MathGeometryRepresentation
    let context: RepresentationView.Context

    var body: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.91, green: 0.96, blue: 0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(red: 0.17, green: 0.45, blue: 0.57), lineWidth: 3)
                )
                .frame(width: rectangleWidth, height: rectangleHeight)
                .overlay(alignment: .bottom) {
                    Text(verbatim: String(value.width)).font(.caption.bold()).offset(y: 19)
                }
                .overlay(alignment: .trailing) {
                    Text(verbatim: String(value.height)).font(.caption.bold()).offset(x: 18)
                }
            Text(verbatim: value.displayLabel)
                .font(.system(size: labelSize, weight: .bold, design: .rounded))
                .padding(.top, 10)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
    }

    private var rectangleWidth: CGFloat {
        max(34, CGFloat(value.width) * geometryScale)
    }
    private var rectangleHeight: CGFloat {
        max(34, CGFloat(value.height) * geometryScale)
    }
    private var geometryScale: CGFloat {
        let maximumExtent: CGFloat
        switch context { case .memoryCard, .pairsTile, .soccerBall: maximumExtent = 78; default: maximumExtent = 126 }
        return maximumExtent / CGFloat(max(value.width, value.height))
    }
    private var labelSize: CGFloat {
        switch context { case .memoryCard, .pairsTile, .soccerBall: return 15; default: return 21 }
    }
}

private extension MathGeometryRepresentation {
    var displayLabel: String {
        let symbol = measure == .rectangleArea ? "A" : "P"
        return "\(symbol) = ?"
    }
}
