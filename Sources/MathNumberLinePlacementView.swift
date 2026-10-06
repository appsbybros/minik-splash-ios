import SwiftUI

struct MathNumberLinePlacementView: View {
    @State private var session: MathNumberLinePlacementSession
    @State private var roundStartedAt = Date()
    @StateObject private var speechPlayer = InterfaceSpeechPlayer()
    @Environment(\.interfaceLocaleID) private var interfaceLocaleID
    private let onAttempt: (ActivityAttemptData) -> Void
    private let onComplete: () -> Void
    private let onExit: () -> Void

    init(
        session: MathNumberLinePlacementSession,
        onAttempt: @escaping (ActivityAttemptData) -> Void = { _ in },
        onComplete: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {}
    ) {
        _session = State(initialValue: session)
        self.onAttempt = onAttempt
        self.onComplete = onComplete
        self.onExit = onExit
    }

    var body: some View {
        MinikPracticeScreen(
            progressLabel: "\(session.currentRoundIndex + 1) / \(session.roundCount)",
            onExit: exit
        ) { metrics in
            MinikPracticeSurface(compact: metrics.compact) {
                VStack(spacing: metrics.compact ? 16 : 24) {
                    prompt
                    numberLine
                    controls
                }
            }
        }
        .onAppear(perform: speakPrompt)
        .onDisappear(perform: speechPlayer.stop)
    }

    private var prompt: some View {
        VStack(spacing: 10) {
            Text("Build this quantity")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(red: 0.17, green: 0.45, blue: 0.57))
            HStack(spacing: 14) {
                RepresentationView(representation: session.currentRound.prompt, context: .buildPrompt)
                Button(action: speakPrompt) {
                    MinikArtworkImage(name: MinikVisualAsset.speaker)
                        .frame(width: 42, height: 42)
                }
                    .buttonStyle(MinikUtilityButtonStyle())
                    .accessibilityLabel(String(localized: "Hear the target number"))
            }
        }
    }

    private var numberLine: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let fraction = CGFloat(session.selectedValue - session.currentRound.lowerBound)
                    / CGFloat(session.currentRound.upperBound - session.currentRound.lowerBound)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(red: 0.17, green: 0.45, blue: 0.57)).frame(height: 5)
                    Circle().fill(Color(red: 0.96, green: 0.39, blue: 0.32))
                        .frame(width: 26, height: 26)
                        .offset(x: fraction * max(0, proxy.size.width - 26))
                }
            }
            .frame(maxWidth: 520, minHeight: 30, maxHeight: 30)
            HStack {
                Text(verbatim: String(session.currentRound.lowerBound))
                Spacer()
                Text(verbatim: String(session.currentRound.upperBound))
            }
            .font(.headline.monospacedDigit())
            .frame(maxWidth: 520)
            Text(verbatim: String(session.selectedValue))
                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(session.selectedValue))
    }

    @ViewBuilder
    private var controls: some View {
        if session.answerResult == .correct {
            MinikFeedbackBadge(isCorrect: true)
            Button(action: advance) { Label("Next", systemImage: "arrow.forward") }
                .buttonStyle(MinikPrimaryActionStyle())
        } else {
            if session.answerResult == .incorrect {
                MinikFeedbackBadge(isCorrect: false)
            }
            HStack(spacing: 22) {
                Button(action: { session.move(by: -1) }) { Image(systemName: "arrow.left.circle.fill") }
                    .buttonStyle(MinikUtilityButtonStyle())
                    .accessibilityLabel(String(localized: "Back"))
                    .disabled(session.selectedValue == session.currentRound.lowerBound)
                Button(action: { session.move(by: 1) }) { Image(systemName: "arrow.right.circle.fill") }
                    .buttonStyle(MinikUtilityButtonStyle())
                    .accessibilityLabel(String(localized: "Next"))
                    .disabled(session.selectedValue == session.currentRound.upperBound)
                MathSubmitBuzzer(action: submit)
            }
        }
    }

    private func submit() {
        let round = session.currentRound
        guard let result = session.submit(),
              let attempt = ActivityAttemptData(
                itemID: ActivityItemID(rawValue: round.id.rawValue),
                attemptIndex: session.submissionCount,
                result: result == .correct ? .correct : .incorrect,
                responseDurationSeconds: Date().timeIntervalSince(roundStartedAt),
                activityFamily: .buildQuantity,
                mathLevelID: round.mathLevelID,
                skillID: round.skillID
              ) else { return }
        onAttempt(attempt)
        if result == .incorrect { roundStartedAt = Date() }
    }

    private func advance() {
        let wasComplete = session.isComplete
        session.nextRound()
        if !wasComplete && session.isComplete { onComplete() }
        else { roundStartedAt = Date(); speakPrompt() }
    }

    private func speakPrompt() {
        speechPlayer.speak(session.currentRound.spokenPrompt, interfaceLocale: interfaceLocaleID)
    }

    private func exit() {
        speechPlayer.stop()
        onExit()
    }
}
