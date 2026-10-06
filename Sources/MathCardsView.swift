import SwiftUI

/// Math Cards is the level's facts table: every fact on one screen, one row per
/// fact, to read and hear again. Learn Math is the step-by-step version, one fact
/// per screen with its picture, so the two activities no longer look the same.
struct MathCardsView: View {
    @State private var session: CardsSession
    @State private var heardCardIDs: Set<StudyCardID> = []
    @State private var speakingCardID: StudyCardID?
    @StateObject private var speechPlayer = InterfaceSpeechPlayer()
    @Environment(\.interfaceLocaleID) private var interfaceLocaleID
    private let onExit: () -> Void

    init(session: CardsSession, onExit: @escaping () -> Void = {}) {
        _session = State(initialValue: session)
        self.onExit = onExit
    }

    var body: some View {
        MinikPracticeScreen(
            progressLabel: "\(heardCardIDs.count) / \(session.cardCount)",
            onExit: exit
        ) { metrics in
            MinikPracticeSurface(compact: metrics.compact) {
                VStack(spacing: metrics.compact ? 12 : 16) {
                    header(compact: metrics.compact)

                    ForEach(tableCards, id: \.id) { card in
                        factRow(card, compact: metrics.compact)
                    }

                    if heardCardIDs.count >= session.cardCount {
                        MinikFeedbackBadge(isCorrect: true)
                    }
                }
            }
        }
        .onDisappear(perform: speechPlayer.stop)
    }

    private func header(compact: Bool) -> some View {
        VStack(spacing: 6) {
            Text(String(localized: "Facts Table"))
                .font(.system(size: compact ? 22 : 27, weight: .bold, design: .rounded))
                .foregroundStyle(MathInk.navy)
            Text(String(localized: "All the facts of this level. Tap a fact to hear it."))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MathInk.softInk)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// One fact: its representations side by side (number, picture, exercise),
    /// a speaker that turns into a check mark once the fact was heard.
    private func factRow(_ card: StudyCard, compact: Bool) -> some View {
        let isSpeaking = speakingCardID == card.id
        let wasHeard = heardCardIDs.contains(card.id)
        return Button {
            play(card)
        } label: {
            HStack(spacing: compact ? 8 : 14) {
                ForEach(Array(card.representations.enumerated()), id: \.offset) { index, representation in
                    if index > 0 {
                        Capsule()
                            .fill(MathInk.rim)
                            .frame(width: 3, height: compact ? 40 : 52)
                            .accessibilityHidden(true)
                    }
                    RepresentationView(representation: representation, context: .pairsTile)
                        .frame(maxWidth: .infinity, maxHeight: compact ? 96 : 116)
                }

                Group {
                    if wasHeard {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: compact ? 22 : 26, weight: .bold))
                            .foregroundStyle(Color(red: 0.17, green: 0.61, blue: 0.31))
                    } else {
                        MinikArtworkImage(name: MinikVisualAsset.speaker)
                    }
                }
                .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 10 : 14)
            .frame(maxWidth: .infinity, minHeight: compact ? 84 : 104)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSpeaking ? MathInk.lavender : Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSpeaking ? MathInk.purple : MathInk.rim, lineWidth: isSpeaking ? 2.5 : 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityLabel(accessibilityText(for: card))
        .accessibilityHint(String(localized: "Plays this fact aloud"))
    }

    /// The facts in a steady order: by their number when every fact has one
    /// (0 to 10 on level 1), otherwise in the session's order.
    private var tableCards: [StudyCard] {
        let cards = session.presentationCards
        guard cards.allSatisfy({ Self.numeralValue(in: $0) != nil }) else {
            return cards
        }
        return cards.sorted {
            (Self.numeralValue(in: $0) ?? 0) < (Self.numeralValue(in: $1) ?? 0)
        }
    }

    private static func numeralValue(in card: StudyCard) -> Int? {
        for representation in card.representations {
            if case .math(let math) = representation, case .numeral(let numeral) = math {
                return numeral.value
            }
        }
        return nil
    }

    private func accessibilityText(for card: StudyCard) -> String {
        card.representations.map(\.accessibilityDescription).joined(separator: ", ")
    }

    /// The fact read aloud: an exercise with its answer filled in or added
    /// ("3 + 2 = 5"), the exercise alone, or the number.
    private static func spokenText(for card: StudyCard) -> String? {
        let mathRepresentations = card.representations.compactMap { representation -> MathRepresentation? in
            guard case .math(let math) = representation else { return nil }
            return math
        }
        let number = mathRepresentations.compactMap { math -> Int? in
            guard case .numeral(let numeral) = math else { return nil }
            return numeral.value
        }.first
        if let missing = mathRepresentations.first(where: {
            if case .missingValueExpression = $0 { return true }
            return false
        }) {
            guard let number else { return missing.displayText }
            return missing.displayText.replacingOccurrences(of: "□", with: String(number))
        }
        if let expression = mathRepresentations.first(where: {
            if case .arithmeticExpression = $0 { return true }
            return false
        }) {
            guard let number else { return expression.displayText }
            return "\(expression.displayText) = \(number)"
        }
        if let number {
            return String(number)
        }
        return nil
    }

    private func play(_ card: StudyCard) {
        speakingCardID = card.id
        heardCardIDs.insert(card.id)
        if let text = Self.spokenText(for: card) {
            speechPlayer.speak(text, interfaceLocale: interfaceLocaleID)
        }
    }

    private func exit() {
        speechPlayer.stop()
        onExit()
    }
}
