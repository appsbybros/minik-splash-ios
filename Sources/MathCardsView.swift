import SwiftUI

struct MathCardsView: View {
    @State private var session: CardsSession
    @State private var timedMode = false
    @StateObject private var speechPlayer = InterfaceSpeechPlayer()
    @Environment(\.interfaceLocaleID) private var interfaceLocaleID
    private let onExit: () -> Void

    init(session: CardsSession, onExit: @escaping () -> Void = {}) {
        _session = State(initialValue: session)
        self.onExit = onExit
    }

    var body: some View {
        MinikPracticeScreen(
            progressLabel: "\(session.currentCardIndex + 1) / \(session.cardCount)",
            onExit: exit
        ) { metrics in
            MinikPracticeSurface(compact: metrics.compact) {
                VStack(spacing: metrics.compact ? 16 : 22) {
                    HStack {
                        Button(action: replay) {
                            HStack(spacing: 8) {
                                MinikArtworkImage(name: MinikVisualAsset.speaker)
                                    .frame(width: 34, height: 34)
                                Text("Listen")
                            }
                        }
                        .buttonStyle(MinikUtilityButtonStyle())

                        Spacer()

                        Button(action: shuffle) {
                            Label(String(localized: "Shuffle"), systemImage: "shuffle")
                        }
                        .buttonStyle(MinikUtilityButtonStyle())

                        Toggle(String(localized: "Timed"), isOn: $timedMode)
                            .labelsHidden()
                            .accessibilityLabel(String(localized: "Timed cards"))
                    }

                    VStack(spacing: metrics.compact ? 16 : 22) {
                        ForEach(
                            Array(session.currentCard.representations.enumerated()),
                            id: \.offset
                        ) { _, representation in
                            RepresentationView(
                                representation: representation,
                                context: .cardsHero
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: metrics.compact ? 190 : 250)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.white.opacity(0.97))
                    )

                    Button(action: advance) {
                        Label(String(localized: "Next"), systemImage: "arrow.forward")
                    }
                    .buttonStyle(MinikPrimaryActionStyle())
                }
            }
        }
        .task(id: timedTaskID) {
            guard timedMode else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            advance()
        }
        .onAppear(perform: replay)
        .onDisappear(perform: speechPlayer.stop)
    }

    private var timedTaskID: String {
        "\(session.currentCard.id.rawValue).\(timedMode)"
    }

    private var spokenMathContent: String? {
        let mathRepresentations = session.currentCard.representations.compactMap { representation -> MathRepresentation? in
            guard case .math(let math) = representation else { return nil }
            return math
        }
        if let expression = mathRepresentations.first(where: {
            if case .missingValueExpression = $0 { return true }
            return false
        }) ?? mathRepresentations.first(where: {
            if case .arithmeticExpression = $0 { return true }
            return false
        }) {
            return expression.displayText
        }
        return mathRepresentations.compactMap { representation -> String? in
            guard case .numeral(let numeral) = representation else { return nil }
            return String(numeral.value)
        }.first
    }

    private func replay() {
        if let spokenMathContent {
            speechPlayer.speak(spokenMathContent, interfaceLocale: interfaceLocaleID)
        }
    }

    private func advance() {
        speechPlayer.stop()
        session.advance()
        replay()
    }

    private func shuffle() {
        speechPlayer.stop()
        session.shuffle()
        replay()
    }

    private func exit() {
        speechPlayer.stop()
        onExit()
    }
}
