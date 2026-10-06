import Foundation

enum MathPresentationDecision: Equatable, Sendable {
    case normal
    case reducedFont(points: Double)
    case expanded(width: Double)
    case multiline(points: Double)
    case unfit
}

struct MathPresentationConstraints: Equatable, Sendable {
    let availableWidth: Double
    let maximumExpandedWidth: Double
    let preferredFontSize: Double
    let approximateGlyphWidthFactor: Double

    init(
        availableWidth: Double,
        maximumExpandedWidth: Double,
        preferredFontSize: Double,
        approximateGlyphWidthFactor: Double = 0.62
    ) {
        self.availableWidth = availableWidth
        self.maximumExpandedWidth = maximumExpandedWidth
        self.preferredFontSize = preferredFontSize
        self.approximateGlyphWidthFactor = approximateGlyphWidthFactor
    }
}

enum MathPresentationFitPolicy {
    static let minimumReadablePointSize = 18.0
    static let candidateAttemptLimit = 12
    static let lastResortLineCount = 2
    static let minimumSoccerAnswerPool = 4

    static func decision(
        for text: String,
        constraints: MathPresentationConstraints
    ) -> MathPresentationDecision {
        guard !text.isEmpty,
              constraints.availableWidth > 0,
              constraints.maximumExpandedWidth >= constraints.availableWidth,
              constraints.preferredFontSize >= minimumReadablePointSize else {
            return .unfit
        }

        let glyphUnits = Double(text.count) * constraints.approximateGlyphWidthFactor
        let preferredWidth = glyphUnits * constraints.preferredFontSize
        if preferredWidth <= constraints.availableWidth { return .normal }

        let fittedPointSize = constraints.availableWidth / glyphUnits
        if fittedPointSize >= minimumReadablePointSize {
            return .reducedFont(points: fittedPointSize)
        }

        let readableWidth = glyphUnits * minimumReadablePointSize
        if readableWidth <= constraints.maximumExpandedWidth {
            return .expanded(width: readableWidth)
        }

        if readableWidth <= constraints.maximumExpandedWidth * Double(lastResortLineCount) {
            return .multiline(points: minimumReadablePointSize)
        }

        return .unfit
    }

    static func resolvedCandidate<C>(
        generate: () -> C?,
        isReadable: (C) -> Bool,
        compactFallback: (() -> C?)? = nil
    ) -> MathPresentationCandidateResult<C> {
        for _ in 0..<candidateAttemptLimit {
            guard let candidate = generate() else { continue }
            if isReadable(candidate) { return .candidate(candidate) }
        }
        if let fallback = compactFallback?(), isReadable(fallback) {
            return .compactFallback(fallback)
        }
        return .unavailable
    }
}

enum MathPresentationCandidateResult<C> {
    case candidate(C)
    case compactFallback(C)
    case unavailable
}
