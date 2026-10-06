import SwiftUI

private enum SoccerActivityState: Sendable {
    case singleRound(SoccerSession)
    case languagePractice(LanguageSoccerPracticeSession)

    var currentSession: SoccerSession {
        switch self {
        case .singleRound(let session):
            return session
        case .languagePractice(let practice):
            return practice.currentSession
        }
    }

    var languageChallengePresentationIndex: Int? {
        guard case .languagePractice(let practice) = self else {
            return nil
        }
        return practice.roundNumber
    }

    mutating func selectBall(_ ballID: SoccerBallID) {
        switch self {
        case .singleRound(var session):
            session.selectBall(ballID)
            self = .singleRound(session)
        case .languagePractice(var practice):
            practice.selectBall(ballID)
            self = .languagePractice(practice)
        }
    }

    mutating func resolveShot(outcome: GameOutcome) {
        switch self {
        case .singleRound(var session):
            session.resolveShot(outcome: outcome)
            self = .singleRound(session)
        case .languagePractice(var practice):
            practice.resolveShot(outcome: outcome)
            self = .languagePractice(practice)
        }
    }

    mutating func nextAnswerChoiceTarget() {
        guard case .singleRound(var session) = self else {
            return
        }
        session.nextTarget()
        self = .singleRound(session)
    }

    mutating func prepareNextOrderedKick() {
        switch self {
        case .singleRound(var session):
            session.prepareNextKick()
            self = .singleRound(session)
        case .languagePractice(var practice):
            practice.prepareNextKick()
            self = .languagePractice(practice)
        }
    }

    @discardableResult
    mutating func advanceLanguageRound() -> Bool {
        guard case .languagePractice(var practice) = self,
              practice.advanceToNextRound() else {
            return false
        }
        self = .languagePractice(practice)
        return true
    }
}

struct SoccerView: View {
    @State private var activityState: SoccerActivityState
    @State private var shotTask: Task<Void, Never>?
    @State private var targetStartedAt = Date()
    @State private var languageAttemptTracker = LanguageOrderedTokenAttemptTracker()
    @State private var didEvaluateIntroduction = false
    @State private var showsIntroduction = false
    @StateObject private var speechPlayer: LearningSpeechPlayer
    @StateObject private var interfaceSpeechPlayer: InterfaceSpeechPlayer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.interfaceLocaleID) private var interfaceLocaleID
    private let onComplete: () -> Void
    private let onExit: () -> Void
    private let mathActivityFamily: ActivityFamily?
    private let mathLevelID: MathCurriculumLevelID
    private let onAttempt: (ActivityAttemptData) -> Void
    private let introductionRepository: SoccerIntroductionRepository?

    init(
        session: SoccerSession,
        mathActivityFamily: ActivityFamily? = nil,
        mathLevelID: MathCurriculumLevelID = .m1,
        onAttempt: @escaping (ActivityAttemptData) -> Void = { _ in },
        onComplete: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {}
    ) {
        _activityState = State(initialValue: .singleRound(session))
        _speechPlayer = StateObject(wrappedValue: LearningSpeechPlayer())
        _interfaceSpeechPlayer = StateObject(wrappedValue: InterfaceSpeechPlayer())
        self.mathActivityFamily = mathActivityFamily
        self.mathLevelID = mathLevelID
        self.onAttempt = onAttempt
        self.onComplete = onComplete
        self.onExit = onExit
        self.introductionRepository = nil
    }

    init(
        languagePracticeSession: LanguageSoccerPracticeSession,
        introductionRepository: SoccerIntroductionRepository = SoccerIntroductionRepository(),
        onAttempt: @escaping (ActivityAttemptData) -> Void = { _ in },
        onExit: @escaping () -> Void = {}
    ) {
        _activityState = State(initialValue: .languagePractice(languagePracticeSession))
        _speechPlayer = StateObject(wrappedValue: LearningSpeechPlayer())
        _interfaceSpeechPlayer = StateObject(wrappedValue: InterfaceSpeechPlayer())
        self.mathActivityFamily = nil
        self.mathLevelID = .m1
        self.onAttempt = onAttempt
        self.onComplete = {}
        self.onExit = onExit
        self.introductionRepository = introductionRepository
    }

    private var session: SoccerSession {
        activityState.currentSession
    }

    var body: some View {
        MinikPracticeScreen(
            progressLabel: "\(session.progressCount) / \(session.targetCount)",
            onExit: exitActivity
        ) { metrics in
            let compact = metrics.compact

            MinikPracticeSurface(compact: compact) {
                VStack(spacing: compact ? 18 : 24) {
                    scoreboardSection(compact: compact)

                    fieldSection(compact: compact)

                    answerSection(
                        compact: compact,
                        availableWidth: metrics.containerWidth
                    )

                    actionSection(compact: compact)
                }
            }
        }
        .overlay {
            if showsIntroduction {
                introductionOverlay
            }
        }
        .onAppear(perform: handleAppearance)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                speechPlayer.stop()
                interfaceSpeechPlayer.stop()
            }
        }
        .onDisappear(perform: stopActivityAudioAndMotion)
    }

    private func scoreboardSection(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 14) {
            Text(session.orderedTokenContent == nil
                ? String(localized: "Soccer challenge")
                : String(localized: "Build the word"))
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(red: 0.14, green: 0.42, blue: 0.54))

            HStack(spacing: compact ? 12 : 16) {
                scorePill(
                    title: "You",
                    value: session.childScore,
                    tint: Color(red: 0.17, green: 0.58, blue: 0.82)
                )

                Text("vs")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.12), in: Capsule(style: .continuous))

                scorePill(
                    title: keeperTitle,
                    value: session.keeperScore,
                    tint: Color(red: 0.98, green: 0.67, blue: 0.24)
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(localizedFormat(
                "Score. You %lld, %@ %lld",
                Int64(session.childScore),
                keeperTitle,
                Int64(session.keeperScore)
            ))
        }
        .frame(maxWidth: .infinity)
    }

    private func scorePill(title: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))

            Text(String(value))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.88), tint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func fieldSection(compact: Bool) -> some View {
        VStack(spacing: compact ? 16 : 20) {
            VStack(spacing: compact ? 10 : 12) {
                if session.orderedTokenContent != nil {
                    HStack {
                        Spacer()

                        Button(action: speakRoundCue) {
                            HStack(spacing: 8) {
                                MinikArtworkImage(name: MinikVisualAsset.speaker)
                                    .frame(width: 30, height: 30)
                                Text("Listen")
                            }
                        }
                        .buttonStyle(MinikUtilityButtonStyle())
                        .accessibilityLabel("Replay current word")
                        .accessibilityHint("Speaks the current word again")
                    }
                }

                Text(session.orderedTokenContent == nil
                    ? String(localized: "Pick the matching ball")
                    : String(localized: "Kick the next letter"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))

                ForEach(
                    Array(session.promptRepresentations.enumerated()),
                    id: \.offset
                ) { _, representation in
                    RepresentationView(
                        representation: representation,
                        context: .soccerPrompt
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            if session.orderedTokenContent != nil {
                constructedWordSection(compact: compact)
            }

            soccerScene(compact: compact)

            if session.orderedTokenContent == nil,
               session.gameOutcome == nil,
               session.selectedBallID != nil {
                Label("Selected ball is ready to kick", systemImage: "figure.soccer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.94))
                    .accessibilityHint("Kick is now available")
            }
        }
        .padding(compact ? 18 : 24)
        .background(fieldBackground)
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 30 : 36, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: compact ? 30 : 36, style: .continuous))
    }

    private func soccerScene(compact: Bool) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let ballSize = compact ? 60.0 : 68.0
            let restingY = size.height * 0.28
            let targetOffset = shotOffset(in: size)

            ZStack {
                goalView(width: min(size.width * 0.54, compact ? 240 : 300))
                    .offset(y: -size.height * 0.22)

                keeperView
                    .offset(y: -size.height * 0.1)
                    .offset(x: session.gameOutcome == .saved ? size.width * 0.14 : 0)

                if let selectedBall = selectedBall {
                    soccerBallFace(
                        for: selectedBall,
                        compact: compact,
                        selected: true,
                        sceneMode: true
                    )
                    .frame(width: ballSize, height: ballSize)
                    .offset(
                        x: session.gameOutcome == nil ? 0 : targetOffset.width,
                        y: session.gameOutcome == nil ? restingY : targetOffset.height
                    )
                    .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.78), value: session.gameOutcome)
                    .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: compact ? 220 : 260)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sceneAccessibilityLabel)
    }

    private var fieldBackground: some View {
        MinikArtworkImage(name: MinikVisualAsset.soccerField, contentMode: .fill)
            .overlay(Color.green.opacity(0.06))
    }

    private func goalView(width: CGFloat) -> some View {
        MinikArtworkImage(name: MinikVisualAsset.soccerGoal)
            .frame(width: width, height: width * 0.42)
    }

    private var keeperView: some View {
        VStack(spacing: 6) {
            MinikArtworkImage(name: MinikVisualAsset.soccerGoalie)
                .frame(width: 86, height: 98)

            Text(keeperTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.86))
        }
    }

    private func answerSection(compact: Bool, availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            Text(session.orderedTokenContent == nil
                ? String(localized: "Choose your ball")
                : String(localized: "Available letters"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(red: 0.16, green: 0.43, blue: 0.55))

            LazyVGrid(
                columns: answerColumns(for: availableWidth, compact: compact),
                spacing: compact ? 16 : 18
            ) {
                ForEach(session.availableBalls, id: \.id) { ball in
                    Button {
                        selectOrKick(ball.id)
                    } label: {
                        VStack(spacing: 10) {
                            answerChoiceFace(
                                for: ball,
                                compact: compact,
                                selected: session.selectedBallID == ball.id
                            )
                            .frame(width: compact ? 72 : 82, height: compact ? 72 : 82)

                            if session.selectedBallID == ball.id {
                                Label(
                                    session.orderedTokenContent == nil
                                        ? String(localized: "Ready to kick")
                                        : String(localized: "Shot in progress"),
                                    systemImage: "checkmark.circle.fill"
                                )
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color(red: 0.19, green: 0.57, blue: 0.79))
                            } else {
                                Text(" ")
                                    .font(.footnote.weight(.semibold))
                                    .hidden()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .contentShape(Circle())
                    }
                    .buttonStyle(
                        MinikSoccerBallStyle(
                            state: session.selectedBallID == ball.id ? .selected : .idle,
                            compact: compact
                        )
                    )
                    .disabled(session.selectedBallID != nil || session.gameOutcome != nil)
                    .accessibilityLabel(ballAccessibilityLabel(for: ball))
                    .accessibilityHint(answerBallHint(for: ball))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func answerChoiceFace(
        for ball: SoccerAnswerBall,
        compact: Bool,
        selected: Bool
    ) -> some View {
        if session.orderedTokenContent != nil {
            ZStack {
                Circle()
                    .fill(languageLetterGradient(for: ball))
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.9), lineWidth: selected ? 4 : 2)
                    }

                ballRepresentation(for: ball, compact: compact, sceneMode: false)
            }
        } else {
            soccerBallFace(
                for: ball,
                compact: compact,
                selected: selected,
                sceneMode: false
            )
        }
    }

    private func languageLetterGradient(for ball: SoccerAnswerBall) -> LinearGradient {
        let index = session.availableBalls.firstIndex(where: { $0.id == ball.id }) ?? 0
        let palettes: [[Color]] = [
            [Color(red: 0.27, green: 0.82, blue: 0.84), Color(red: 0.18, green: 0.69, blue: 0.78)],
            [Color(red: 0.96, green: 0.42, blue: 0.64), Color(red: 0.86, green: 0.27, blue: 0.53)],
            [Color(red: 0.68, green: 0.43, blue: 0.91), Color(red: 0.52, green: 0.29, blue: 0.79)],
            [Color(red: 0.98, green: 0.69, blue: 0.29), Color(red: 0.94, green: 0.50, blue: 0.20)]
        ]
        return LinearGradient(
            colors: palettes[index % palettes.count],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var introductionOverlay: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Soccer")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.11, green: 0.36, blue: 0.78))

                    MinikArtworkImage(name: MinikVisualAsset.soccerGoalie)
                        .frame(width: 132, height: 146)

                    Text(soccerIntroductionText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(red: 0.05, green: 0.14, blue: 0.30))
                        .multilineTextAlignment(.center)

                    Button(action: dismissIntroduction) {
                        Text(String(localized: "Start"))
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(MinikYellowActionStyle())
                }
                .padding(28)
                .frame(maxWidth: 520)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.white.opacity(0.97))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityElement(children: .contain)
    }

    private var soccerIntroductionText: String {
        String(localized: "Tap letters in the correct order to kick toward the goal.\nA goal with the right letter earns you a point.\nMissing or being saved with a wrong letter gives the keeper a point.\nThe round continues until the word is complete.")
    }

    private func handleAppearance() {
        guard !didEvaluateIntroduction else { return }
        didEvaluateIntroduction = true

        if introductionRepository?.registerPresentationIfNeeded() == true {
            showsIntroduction = true
            speechPlayer.stop()
            interfaceSpeechPlayer.speak(
                soccerIntroductionText,
                interfaceLocale: interfaceLocaleID
            )
        } else {
            speakRoundCue()
        }
    }

    private func dismissIntroduction() {
        interfaceSpeechPlayer.stop()
        showsIntroduction = false
        speakRoundCue()
    }

    private func answerColumns(for availableWidth: CGFloat, compact: Bool) -> [GridItem] {
        if dynamicTypeSize >= .accessibility1 {
            return [GridItem(.flexible(minimum: 0, maximum: 260), spacing: compact ? 16 : 18)]
        }

        let minimumWidth: CGFloat
        if availableWidth < 420 {
            minimumWidth = 118
        } else if compact {
            minimumWidth = 132
        } else {
            minimumWidth = 150
        }

        return [GridItem(.adaptive(minimum: minimumWidth, maximum: 188), spacing: compact ? 16 : 18)]
    }

    @ViewBuilder
    private func actionSection(compact: Bool) -> some View {
        if let educationalIsCorrect = session.educationalIsCorrect,
           let gameOutcome = session.gameOutcome {
            VStack(spacing: compact ? 14 : 16) {
                MinikFeedbackBadge(isCorrect: educationalIsCorrect)
                    .accessibilityLabel(feedbackAccessibilityLabel(isCorrect: educationalIsCorrect))

                outcomeBanner(for: gameOutcome)

                if session.orderedTokenContent != nil {
                    if session.isComplete {
                        roundResultBanner
                    } else {
                        Text(educationalIsCorrect
                            ? String(localized: "Great kick! Get ready for the next letter.")
                            : String(localized: "That letter stays in play. Try again after the field resets."))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.25, green: 0.46, blue: 0.55))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Button(action: continueAfterShot) {
                        Label(
                            session.currentTargetIndex == session.targetCount - 1
                                ? "Finish"
                                : "Continue",
                            systemImage: "arrow.forward"
                        )
                    }
                    .buttonStyle(MinikPrimaryActionStyle())
                    .accessibilityHint("Moves to the next soccer challenge")
                }
            }
        } else if session.orderedTokenContent == nil, session.selectedBallID != nil {
            VStack(spacing: compact ? 14 : 16) {
                Button {
                    activityState.resolveShot(outcome: simulatedOutcome())
                } label: {
                    Label("Kick", systemImage: "figure.soccer")
                }
                .buttonStyle(MinikPrimaryActionStyle())
                .accessibilityHint("Resolves this shot")
            }
        } else {
            Text(session.orderedTokenContent == nil
                ? String(localized: "Choose one ball before you kick.")
                : String(localized: "Tap the next letter to kick it toward the goal."))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(red: 0.31, green: 0.49, blue: 0.58))
                .frame(maxWidth: .infinity)
        }
    }

    private func outcomeBanner(for outcome: GameOutcome) -> some View {
        HStack(spacing: 12) {
            Image(systemName: outcomeSymbol(outcome))
                .font(.title3.weight(.bold))
                .foregroundStyle(outcomeColor(outcome))

            VStack(alignment: .leading, spacing: 2) {
                Text("Shot result")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.36, green: 0.48, blue: 0.55))

                Text(outcomeLabel(outcome))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.27, blue: 0.33))
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.95, green: 0.99, blue: 1.0))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.95), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedFormat("Shot result, %@", outcomeLabel(outcome)))
    }

    private var roundResultBanner: some View {
        VStack(spacing: 4) {
            Text("Word complete")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.14, green: 0.42, blue: 0.54))

            Text(localizedFormat(
                "You %lld • %@ %lld",
                Int64(session.childScore),
                keeperTitle,
                Int64(session.keeperScore)
            ))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.25, green: 0.46, blue: 0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.95, green: 0.99, blue: 1.0))
        )
        .accessibilityElement(children: .combine)
    }

    private func feedbackAccessibilityLabel(isCorrect: Bool) -> String {
        if session.orderedTokenContent != nil {
            return isCorrect
                ? String(localized: "Correct letter")
                : String(localized: "Incorrect letter, try again")
        }
        return isCorrect
            ? String(localized: "Correct answer")
            : String(localized: "Incorrect answer, try again")
    }

    private func soccerBallFace(
        for ball: SoccerAnswerBall,
        compact: Bool,
        selected: Bool,
        sceneMode: Bool
    ) -> some View {
        ZStack {
            MinikArtworkImage(name: MinikVisualAsset.soccerBall)
                .scaleEffect(selected ? 1.02 : 1)

            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(
                    width: sceneMode ? (compact ? 38 : 42) : (compact ? 46 : 52),
                    height: sceneMode ? (compact ? 38 : 42) : (compact ? 46 : 52)
                )

            ballRepresentation(for: ball, compact: compact, sceneMode: sceneMode)
                .zIndex(2)
        }
    }

    @ViewBuilder
    private func ballRepresentation(
        for ball: SoccerAnswerBall,
        compact: Bool,
        sceneMode: Bool
    ) -> some View {
        if let token = ball.orderedToken,
           let displayText = ball.orderedTokenDisplayText {
            Text(verbatim: displayText)
                .font(.system(
                    size: sceneMode ? (compact ? 24 : 27) : (compact ? 29 : 33),
                    weight: .black,
                    design: .rounded
                ))
                .foregroundStyle(Color(red: 0.07, green: 0.16, blue: 0.20))
                .minimumScaleFactor(0.68)
                .lineLimit(1)
                .environment(\.layoutDirection, layoutDirection(for: token.direction))
        } else {
            RepresentationView(
                representation: ball.representation,
                context: .soccerBall
            )
            .padding(sceneMode ? 13 : 16)
        }
    }

    private func layoutDirection(for direction: ContentDirection?) -> LayoutDirection {
        direction == .rightToLeft ? .rightToLeft : .leftToRight
    }

    private func ballAccessibilityLabel(for ball: SoccerAnswerBall) -> String {
        ball.orderedToken?.speechText
            ?? ball.orderedToken?.text
            ?? ball.representation.accessibilityDescription
    }

    private func answerBallHint(for ball: SoccerAnswerBall) -> String {
        if session.selectedBallID == ball.id {
            return session.orderedTokenContent == nil
                ? String(localized: "Selected ball")
                : String(localized: "Shot in progress")
        }

        if session.selectedBallID != nil {
            return session.orderedTokenContent == nil
                ? String(localized: "Unavailable until you continue")
                : String(localized: "Unavailable while the shot finishes")
        }

        return session.orderedTokenContent == nil
            ? String(localized: "Double tap to choose this ball")
            : String(localized: "Double tap to kick this letter")
    }

    private func shotOffset(in size: CGSize) -> CGSize {
        guard let gameOutcome = session.gameOutcome else {
            return CGSize(width: 0, height: size.height * 0.28)
        }

        switch gameOutcome {
        case .goal:
            return CGSize(width: 0, height: -size.height * 0.22)
        case .saved:
            return CGSize(width: size.width * 0.15, height: -size.height * 0.14)
        case .miss:
            return CGSize(width: size.width * 0.26, height: -size.height * 0.3)
        }
    }

    private var selectedBall: SoccerAnswerBall? {
        guard let selectedBallID = session.selectedBallID else {
            return nil
        }

        return session.round.answerBalls.first { $0.id == selectedBallID }
    }

    private var sceneAccessibilityLabel: String {
        if let outcome = session.gameOutcome {
            return localizedFormat("Soccer field. %@.", outcomeLabel(outcome))
        }

        if session.selectedBallID != nil {
            return session.orderedTokenContent == nil
                ? String(localized: "Soccer field. Ball selected and ready to kick.")
                : String(localized: "Soccer field. Shot in progress.")
        }

        return String(localized: "Soccer field.")
    }

    private func simulatedOutcome() -> GameOutcome {
        switch Int.random(in: 0 ... 2) {
        case 0:
            .goal
        case 1:
            .miss
        default:
            .saved
        }
    }

    private func outcomeLabel(_ outcome: GameOutcome) -> String {
        switch outcome {
        case .goal:
            String(localized: "Goal")
        case .miss:
            String(localized: "Miss")
        case .saved:
            String(localized: "Saved")
        }
    }

    private func outcomeSymbol(_ outcome: GameOutcome) -> String {
        switch outcome {
        case .goal:
            return "sparkles"
        case .miss:
            return "arrow.up.forward.circle.fill"
        case .saved:
            return "hand.raised.fill"
        }
    }

    private func outcomeColor(_ outcome: GameOutcome) -> Color {
        switch outcome {
        case .goal:
            return Color(red: 0.18, green: 0.65, blue: 0.34)
        case .miss:
            return Color(red: 0.88, green: 0.48, blue: 0.3)
        case .saved:
            return Color(red: 0.18, green: 0.56, blue: 0.82)
        }
    }

    private func continueAfterShot() {
        let wasComplete = session.isComplete
        activityState.nextAnswerChoiceTarget()
        targetStartedAt = Date()

        if !wasComplete && session.isComplete {
            onComplete()
        }
    }

    private var keeperTitle: String {
        session.orderedTokenContent == nil
            ? String(localized: "Keeper")
            : String(localized: "Minik")
    }

    private func selectOrKick(_ ballID: SoccerBallID) {
        let target = session.orderedTokenContent == nil ? session.currentTarget.challenge : nil
        let languageContentItemID = session.orderedTokenContent?.contentItemID
        let languageTokenIndex = session.progressCount
        let responseDurationSeconds = Date().timeIntervalSince(targetStartedAt)
        activityState.selectBall(ballID)
        if let target,
           let correct = session.educationalIsCorrect,
           let family = mathActivityFamily,
           let attempt = ActivityAttemptData(
               itemID: ActivityItemID(rawValue: target.id.rawValue),
               attemptIndex: 1,
               result: correct ? .correct : .incorrect,
               responseDurationSeconds: Date().timeIntervalSince(targetStartedAt),
               activityFamily: family,
               mathLevelID: mathLevelID,
               skillID: target.primarySkill
           ) {
            onAttempt(attempt)
        }
        if let languageContentItemID,
           let presentationIndex = activityState.languageChallengePresentationIndex,
           session.selectedBallID == ballID,
           let correct = session.educationalIsCorrect,
           let attempt = languageAttemptTracker.makeAttempt(
               presentationIndex: presentationIndex,
               contentItemID: languageContentItemID,
               tokenIndex: languageTokenIndex,
               result: correct ? .correct : .incorrect,
               responseDurationSeconds: responseDurationSeconds,
               activityFamily: .soccer
           ) {
            onAttempt(attempt)
        }
        guard session.orderedTokenContent != nil,
              session.selectedBallID == ballID else {
            return
        }

        if let cue = session.selectedOrderedTokenSpeechCue {
            speechPlayer.speak(cue)
        }

        let outcome = simulatedOutcome()
        shotTask?.cancel()
        shotTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: reduceMotion ? 20_000_000 : 180_000_000)
            guard !Task.isCancelled,
                  session.selectedBallID == ballID,
                  session.gameOutcome == nil else {
                return
            }
            activityState.resolveShot(outcome: outcome)

            let completedRound = session.isComplete
            try? await Task.sleep(
                nanoseconds: reduceMotion
                    ? (completedRound ? 160_000_000 : 100_000_000)
                    : (completedRound ? 1_600_000_000 : 900_000_000)
            )
            guard !Task.isCancelled else {
                return
            }

            if completedRound {
                if activityState.advanceLanguageRound() {
                    targetStartedAt = Date()
                    speakRoundCue()
                }
            } else {
                activityState.prepareNextOrderedKick()
                targetStartedAt = Date()
            }
        }
    }

    private func constructedWordSection(compact: Bool) -> some View {
        HStack(spacing: compact ? 10 : 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your word")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.8))

                Text(constructedWordText)
                    .font(.system(size: compact ? 30 : 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.65)
                    .environment(\.layoutDirection, orderedContentLayoutDirection)
            }

            Spacer(minLength: 12)

            Text(verbatim: "\(session.builtTokens.count) / \(session.targetCount)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, compact ? 14 : 18)
        .padding(.vertical, compact ? 12 : 14)
        .background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localizedFormat(
            "Built word, %@, %lld of %lld letters",
            constructedWordAccessibilityText,
            Int64(session.builtTokens.count),
            Int64(session.targetCount)
        ))
    }

    private var constructedWordText: String {
        guard let builtDisplayText = session.builtDisplayText,
              !builtDisplayText.isEmpty else {
            return String(repeating: "•", count: session.targetCount)
        }
        return builtDisplayText
    }

    private var constructedWordAccessibilityText: String {
        guard let builtDisplayText = session.builtDisplayText,
              !builtDisplayText.isEmpty else {
            return String(localized: "empty")
        }
        return builtDisplayText
    }

    private var orderedContentLayoutDirection: LayoutDirection {
        switch session.orderedTokenContent?.targetText.direction {
        case .rightToLeft:
            return .rightToLeft
        case .leftToRight, nil:
            return .leftToRight
        }
    }

    private func speakRoundCue() {
        guard let cue = session.orderedTokenContent?.speechCue else {
            return
        }
        speechPlayer.speak(cue)
    }

    private func exitActivity() {
        stopActivityAudioAndMotion()
        onExit()
    }

    private func stopActivityAudioAndMotion() {
        shotTask?.cancel()
        shotTask = nil
        speechPlayer.stop()
        interfaceSpeechPlayer.stop()
    }

    private func localizedFormat(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: String(localized: key), arguments: arguments)
    }
}
