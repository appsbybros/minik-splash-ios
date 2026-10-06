import Foundation
import SwiftUI

/// Android TicTacToeFragment (fragment_tic_tac_toe_plus): a rounded card over the
/// Minik background with the gradient title, the red close X, the X / O choice
/// chips, the status line, the 3x3 board and Minik holding a board underneath.
/// The card keeps the Android phone's proportions everywhere: iPhones use the
/// Android dp sizes as they are, and larger screens scale the whole card by one
/// factor, so an iPad shows the same composition centred instead of stretched.
struct TicTacToeView: View {
    @State private var session: TicTacToeSession
    @State private var inputIsEnabled = false
    @State private var introductionHasStarted = false
    // Android dims the tiles to 55 % until the spoken introduction ends.
    @State private var boardAwaitsIntroduction = true
    @State private var statusIsDimmed = false
    @State private var confettiIsVisible = false
    @State private var resultTask: Task<Void, Never>?
    @State private var blinkTask: Task<Void, Never>?
    @State private var confettiTask: Task<Void, Never>?
    @StateObject private var feedbackPlayer: TicTacToeFeedbackPlayer
    @Environment(\.interfaceLocaleID) private var interfaceLocaleID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    // Android sets this text in sp, which follows the system text size. These
    // start at the Android sizes and follow Dynamic Type the same way.
    @ScaledMetric(relativeTo: .title) private var titleFontBase: CGFloat = 28
    @ScaledMetric(relativeTo: .subheadline) private var chipFontBase: CGFloat = 14
    @ScaledMetric(relativeTo: .title3) private var statusFontBase: CGFloat = 20

    private let preferences: TicTacToePreferencesProviding
    private let onResolvedRound: (TicTacToeOutcome) -> Void
    private let onCompletedRound: () -> Void
    private let onExit: () -> Void

    init(
        preferences: TicTacToePreferencesProviding = TicTacToePreferences(),
        onResolvedRound: @escaping (TicTacToeOutcome) -> Void = { _ in },
        onCompletedRound: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {}
    ) {
        self.preferences = preferences
        self.onResolvedRound = onResolvedRound
        self.onCompletedRound = onCompletedRound
        self.onExit = onExit
        _session = State(initialValue: TicTacToeSession(
            level: preferences.selectedLevel,
            adaptiveState: preferences.adaptiveState
        ))
        _feedbackPlayer = StateObject(wrappedValue: TicTacToeFeedbackPlayer())
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = TicTacToeLayout(
                container: geometry.size,
                titleFontBase: titleFontBase,
                chipFontBase: chipFontBase,
                statusFontBase: statusFontBase,
                accessibilitySize: dynamicTypeSize.isAccessibilitySize
            )

            // The card is exactly as tall as the screen at every ordinary text
            // size, so it neither scrolls nor bounces. With accessibility text it
            // can be taller, and then it scrolls instead of clipping the board.
            ScrollView {
                gameCard(layout)
                    .padding(.vertical, layout.verticalMargin)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled()
            .scrollIndicators(.hidden)
        }
        // Android's root background, minik_background. As a background its
        // aspect ratio can never size the layout.
        .background {
            MinikPracticeBackground()
                .ignoresSafeArea()
        }
        .onAppear(perform: beginIntroductionIfNeeded)
        .onDisappear(perform: cancelActivityWork)
    }

    private func gameCard(_ layout: TicTacToeLayout) -> some View {
        let unit = layout.scale
        let cardShape = RoundedRectangle(cornerRadius: 20 * unit, style: .continuous)

        return VStack(spacing: 0) {
            titleText(layout)
                .padding(.top, 22 * unit)
            markSelector(layout)
                .padding(.top, 8 * unit)
            statusLabel(layout)
                .padding(.top, 8 * unit)
            boardView(layout)
                .padding(.top, 16 * unit)
            mascot(layout)
                .padding(.top, 6 * unit)
            Spacer(minLength: 0)
        }
        .frame(width: layout.cardWidth, height: layout.cardHeight)
        .background {
            // Android's plus_background fills the card. As a background it never
            // sizes the card, and a scrolling card is never stretched by it.
            ZStack {
                Color.white
                MinikArtworkImage(name: MinikVisualAsset.ticTacToeScene, contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            closeButton(layout)
        }
        .overlay {
            // Android's confetti view is the card's top layer, clipped to the card.
            if confettiIsVisible {
                TicTacToeConfettiView(reduceMotion: reduceMotion, scale: unit)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .clipShape(cardShape)
        .shadow(color: Color.black.opacity(0.3), radius: 10 * unit, y: 6 * unit)
    }

    private func titleText(_ layout: TicTacToeLayout) -> some View {
        Text(TicTacToeFeedbackCopy.title)
            .font(.system(size: layout.titleFontSize, weight: .bold))
            // Android shades the title across the text from blue at the left to
            // green at the right, in both reading directions.
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.47, blue: 0.95),
                        Color(red: 0.00, green: 0.75, blue: 0.85),
                        Color(red: 0.09, green: 0.65, blue: 0.42)
                    ],
                    startPoint: UnitPoint(x: 0, y: 0.5),
                    endPoint: UnitPoint(x: 1, y: 0.5)
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: layout.titleWidth, height: layout.titleHeight)
            .accessibilityAddTraits(.isHeader)
    }

    /// Android's close X: 27 dp, 18 dp from the top and end edges of the card,
    /// with a 44 pt touch area around it.
    private func closeButton(_ layout: TicTacToeLayout) -> some View {
        let unit = layout.scale
        let visualSize = 27 * unit
        let targetSize = max(44, visualSize)
        let edgeInset = max(0, 18 * unit - (targetSize - visualSize) / 2)

        return Button(action: exitActivity) {
            MinikArtworkImage(name: MinikVisualAsset.close)
                .frame(width: visualSize, height: visualSize)
                .frame(width: targetSize, height: targetSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, edgeInset)
        .padding(.trailing, edgeInset)
        .accessibilityLabel("Close game")
    }

    private func mascot(_ layout: TicTacToeLayout) -> some View {
        // Android's ImageView spans the content width under the board with an
        // 8 dp padding and fits Minik inside it, centred.
        let inset = 8 * layout.scale
        return MinikArtworkImage(name: MinikVisualAsset.ticTacToeMascot)
            .padding(inset)
            .frame(width: layout.contentWidth, height: layout.mascotAreaHeight)
    }

    private func markSelector(_ layout: TicTacToeLayout) -> some View {
        // Android's chips: 15 dp end margin plus the chip group's 8 dp spacing.
        // Android's phone chip group is always right to left, so the X chip is
        // on the right in every language; each chip's text keeps the screen's
        // own direction (see markButton).
        HStack(spacing: layout.chipSpacing) {
            markButton(.cross)
            markButton(.circle)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.ticTacToeChipMetrics, layout.chipMetrics)
        .frame(width: layout.contentWidth, height: layout.chipRowHeight)
        .accessibilityElement(children: .contain)
    }

    private func markButton(_ mark: TicTacToeMark) -> some View {
        let selected = session.childMark == mark
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                _ = session.selectChildMark(mark)
            }
        } label: {
            TicTacToeChoiceChip(text: chipText(for: mark), selected: selected)
                .environment(\.layoutDirection, layoutDirection)
        }
        .buttonStyle(TicTacToeChipButtonStyle(reduceMotion: reduceMotion))
        .disabled(session.hasRoundStarted || session.isRoundComplete || !inputIsEnabled)
        .accessibilityLabel(mark == .cross
            ? String(localized: "Play as X")
            : String(localized: "Play as O"))
        .accessibilityValue(selected
            ? String(localized: "Selected")
            : String(localized: "Not selected"))
        .accessibilityHint(
            session.hasRoundStarted
                ? String(localized: "Mark selection is locked for this round")
                : String(localized: "Double tap to choose this mark")
        )
    }

    private func chipText(for mark: TicTacToeMark) -> String {
        // Android's chip text is the mark and its name: "❌ איקס" / "⭕ עיגול",
        // "❌ X" / "⭕ O" in English.
        mark == .cross
            ? "❌ " + String(localized: "X")
            : "⭕ " + String(localized: "O")
    }

    private func statusLabel(_ layout: TicTacToeLayout) -> some View {
        Text(statusText)
            .font(.system(size: layout.statusFontSize))
            .foregroundStyle(TicTacToePalette.status)
            .multilineTextAlignment(.center)
            .lineLimit(layout.statusLineLimit)
            .minimumScaleFactor(0.6)
            .frame(width: layout.contentWidth, height: layout.statusHeight)
            .opacity(statusIsDimmed ? 0.35 : 1)
            .accessibilityLabel(statusText)
    }

    private func boardView(_ layout: TicTacToeLayout) -> some View {
        // Android: a square grid with 2 dp padding and 5 dp around every tile.
        let unit = layout.scale
        let gap = 10 * unit

        return LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(layout.cellSide), spacing: gap), count: 3),
            spacing: gap
        ) {
            ForEach(TicTacToePosition.all, id: \.self) { position in
                boardCell(position, layout: layout)
            }
        }
        .padding(7 * unit)
        .frame(width: layout.boardSide, height: layout.boardSide)
        // A board is spatial, not prose. Keep row/column positions stable in RTL.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tic-Tac-Toe board")
    }

    private func boardCell(_ position: TicTacToePosition, layout: TicTacToeLayout) -> some View {
        let mark = session.mark(at: position)
        let isWinningCell = session.winningLine.contains(position)
        let unit = layout.scale
        let insets = cellInsets(unit: unit, emphasized: isWinningCell)

        return Button {
            play(at: position)
        } label: {
            ZStack {
                tileBackground(unit: unit, insets: insets)

                if let mark {
                    Text(displayText(for: mark))
                        .font(.system(size: layout.markFontSize))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(insets)
                        .transition(
                            reduceMotion
                                ? AnyTransition.opacity
                                : AnyTransition.scale(scale: 0.9).combined(with: .opacity)
                        )
                }
            }
            .frame(width: layout.cellSide, height: layout.cellSide)
            .contentShape(RoundedRectangle(cornerRadius: 12 * unit, style: .continuous))
            .opacity(boardAwaitsIntroduction ? 0.55 : 1)
        }
        .buttonStyle(TicTacToeCellButtonStyle(
            reduceMotion: reduceMotion,
            pressedInsets: insets,
            pressedCornerRadius: 10 * unit
        ))
        .disabled(!inputIsEnabled || session.isRoundComplete || mark != nil)
        .accessibilityLabel(cellAccessibilityLabel(position: position, mark: mark))
        .accessibilityValue(isWinningCell ? String(localized: "Winning line") : "")
        .accessibilityHint(cellAccessibilityHint(mark: mark))
    }

    /// Android's tile: a 12 dp rounded frame shaded left to right purple, pink and
    /// teal around a white 10 dp rounded card.
    private func tileBackground(unit: CGFloat, insets: EdgeInsets) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12 * unit, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.52, green: 0.31, blue: 0.71),
                            Color(red: 0.94, green: 0.70, blue: 0.72),
                            Color(red: 0.24, green: 0.79, blue: 0.84)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            RoundedRectangle(cornerRadius: 10 * unit, style: .continuous)
                .fill(Color.white)
                .padding(insets)
        }
    }

    /// Android insets the white card 2 dp at the top and the end and 5 dp at the
    /// start and the bottom; the start is the right side in Hebrew. A tile of the
    /// winning line shows a slightly wider frame.
    private func cellInsets(unit: CGFloat, emphasized: Bool) -> EdgeInsets {
        let extra: CGFloat = emphasized ? 2 * unit : 0
        let thin = 2 * unit + extra
        let thick = 5 * unit + extra
        // The board is laid out left to right, so the reading direction of the
        // screen picks the thick side.
        let thickOnRight = layoutDirection == .rightToLeft
        return EdgeInsets(
            top: thin,
            leading: thickOnRight ? thin : thick,
            bottom: thick,
            trailing: thickOnRight ? thick : thin
        )
    }

    private var statusText: String {
        switch session.outcome {
        case .childWin:
            return TicTacToeFeedbackCopy.childWinStatus
        case .minikWin:
            return TicTacToeFeedbackCopy.minikWinStatus
        case .draw:
            return TicTacToeFeedbackCopy.drawStatus
        case .none:
            return session.hasRoundStarted
                ? TicTacToeFeedbackCopy.tapSquare
                : TicTacToeFeedbackCopy.chooseMark
        }
    }

    private func beginIntroductionIfNeeded() {
        guard !introductionHasStarted else {
            return
        }
        introductionHasStarted = true
        inputIsEnabled = false

        var messages = [TicTacToeFeedbackCopy.introduction]
        if !preferences.hasSpokenFirstInstruction {
            preferences.hasSpokenFirstInstruction = true
            messages.append(TicTacToeFeedbackCopy.firstInstruction)
        }

        feedbackPlayer.speak(messages, interfaceLocale: interfaceLocaleID) {
            boardAwaitsIntroduction = false
            inputIsEnabled = true
        }
    }

    private func play(at position: TicTacToePosition) {
        guard inputIsEnabled,
              !session.isRoundComplete,
              session.mark(at: position) == nil else {
            return
        }

        feedbackPlayer.playChildMoveSound(index: Bool.random() ? 0 : 1)
        var random = SystemRandomNumberGenerator()
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.72)) {
            _ = session.playChildMove(at: position, using: &random)
        }

        guard let outcome = session.outcome else {
            return
        }
        preferences.adaptiveState = session.adaptiveState
        beginResultFeedback(outcome)
    }

    private func beginResultFeedback(_ outcome: TicTacToeOutcome) {
        inputIsEnabled = false
        onResolvedRound(outcome)
        startStatusBlinking()

        let resultDuration: UInt64
        let spokenFeedback: String
        switch outcome {
        case .childWin:
            resultDuration = 5_500_000_000
            spokenFeedback = TicTacToeFeedbackCopy.positivePhrases.randomElement()
                ?? TicTacToeFeedbackCopy.childWinStatus
            showConfetti()
        case .minikWin:
            resultDuration = 4_000_000_000
            spokenFeedback = TicTacToeFeedbackCopy.androidCompatibleMinikWinPhrase
        case .draw:
            resultDuration = 4_000_000_000
            spokenFeedback = TicTacToeFeedbackCopy.drawPhrases.randomElement()
                ?? TicTacToeFeedbackCopy.drawStatus
        }
        feedbackPlayer.speak([spokenFeedback], interfaceLocale: interfaceLocaleID)

        resultTask?.cancel()
        resultTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: resultDuration)
            guard !Task.isCancelled else {
                return
            }
            stopStatusBlinking()
            feedbackPlayer.speak([TicTacToeFeedbackCopy.nextRound], interfaceLocale: interfaceLocaleID) {
                onCompletedRound()
                session.startNextRound()
                inputIsEnabled = true
            }
        }
    }

    private func startStatusBlinking() {
        stopStatusBlinking()
        guard !reduceMotion else {
            statusIsDimmed = false
            return
        }

        blinkTask = Task { @MainActor in
            while !Task.isCancelled, session.isRoundComplete {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else {
                    return
                }
                withAnimation(.easeInOut(duration: 0.16)) {
                    statusIsDimmed.toggle()
                }
            }
        }
    }

    private func stopStatusBlinking() {
        blinkTask?.cancel()
        blinkTask = nil
        statusIsDimmed = false
    }

    private func showConfetti() {
        confettiTask?.cancel()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            confettiIsVisible = true
        }
        // Android emits for three seconds and lets the last pieces fall out.
        confettiTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_200_000_000)
            guard !Task.isCancelled else {
                return
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                confettiIsVisible = false
            }
        }
    }

    private func displayText(for mark: TicTacToeMark) -> String {
        mark == .cross ? "❌" : "⭕"
    }

    private func cellAccessibilityLabel(
        position: TicTacToePosition,
        mark: TicTacToeMark?
    ) -> String {
        let rows = [
            String(localized: "top"),
            String(localized: "middle"),
            String(localized: "bottom")
        ]
        let columns = [
            String(localized: "left"),
            String(localized: "center"),
            String(localized: "right")
        ]
        let value: String
        switch mark {
        case .cross: value = String(localized: "X")
        case .circle: value = String(localized: "O")
        case .none: value = String(localized: "empty")
        }
        return String(
            format: String(localized: "%@ %@, %@"),
            rows[position.row],
            columns[position.column],
            value
        )
    }

    private func cellAccessibilityHint(mark: TicTacToeMark?) -> String {
        if session.isRoundComplete {
            return String(localized: "Unavailable while the round finishes")
        }
        if !inputIsEnabled {
            return String(localized: "Unavailable while feedback is playing")
        }
        if mark != nil {
            return String(localized: "This square is already occupied")
        }
        return String(localized: "Double tap to place your mark")
    }

    private func cancelActivityWork() {
        resultTask?.cancel()
        resultTask = nil
        blinkTask?.cancel()
        blinkTask = nil
        confettiTask?.cancel()
        confettiTask = nil
        feedbackPlayer.stop()
    }

    private func exitActivity() {
        cancelActivityWork()
        onExit()
    }
}

/// Android fragment_tic_tac_toe_plus (phone) in dp: a 312 x 688 card with 16 + 10
/// content insets, so the board is 260 wide, and Minik fills the height under
/// the board. iPhones use these sizes as they are; larger screens multiply all
/// of them by one factor, which keeps the composition and centres the card.
private struct TicTacToeLayout {
    let scale: CGFloat
    let verticalMargin: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let contentWidth: CGFloat
    let titleWidth: CGFloat
    let titleFontSize: CGFloat
    let titleHeight: CGFloat
    let chipMetrics: TicTacToeChipMetrics
    let chipSpacing: CGFloat
    let chipRowHeight: CGFloat
    let statusFontSize: CGFloat
    let statusHeight: CGFloat
    let statusLineLimit: Int
    let boardSide: CGFloat
    let cellSide: CGFloat
    let markFontSize: CGFloat
    let mascotAreaHeight: CGFloat

    init(
        container: CGSize,
        titleFontBase: CGFloat,
        chipFontBase: CGFloat,
        statusFontBase: CGFloat,
        accessibilitySize: Bool
    ) {
        let width = max(container.width, 1)
        let height = max(container.height, 1)
        // The card with Android's 29 dp side margins, and 12 above and below it.
        let fit = min(width / 370, height / 712)
        let unit = min(max(fit, 1), 2.2)
        let margin = (12 * unit).rounded(.down)
        let card = max(1, min(width - 58 * unit, 312 * unit).rounded(.down))
        let content = max(1, card - 52 * unit)

        // Text follows the system text size like Android's sp, capped so the
        // board stays on screen at the accessibility sizes.
        let titleFont = min(titleFontBase, 45) * unit
        let titleLine = (titleFont * 1.3).rounded(.up)
        let chipFont = min(chipFontBase, 25) * unit
        let chipHeight = max(32 * unit, (chipFont * 1.3).rounded(.up) + 12 * unit)
        let chipRow = max(48 * unit, chipHeight + 16 * unit)
        let statusFont = min(statusFontBase, 40) * unit
        let statusLines = accessibilitySize ? 2 : 1
        let statusBlock = (statusFont * 1.3).rounded(.up) * CGFloat(statusLines)

        // Gaps: 12 + 10 above the title, 8 above the chips, 8 above the status,
        // 16 above the board, 6 under it and 12 + 12 at the bottom of the card.
        let gaps: CGFloat = 84 * unit
        let fixedHeight = gaps + titleLine + chipRow + statusBlock
        let available = max(1, (height - 2 * margin).rounded(.down))
        let spare = max(0, available - fixedHeight)
        // As on Android the board fills the content width; only a short screen
        // makes it smaller, so Minik keeps at least 60 % of its height.
        let fittedBoard = min(content, spare / 1.6)
        let board = max(fittedBoard, min(content, 180 * unit)).rounded(.down)
        let naturalMascot = available - fixedHeight - board
        let minimumMascot = (board * 0.4).rounded(.up)
        let cell = max(1, (board - 34 * unit) / 3)

        scale = unit
        verticalMargin = margin
        cardWidth = card
        cardHeight = naturalMascot >= minimumMascot ? available : fixedHeight + board + minimumMascot
        contentWidth = content
        titleWidth = max(1, card - 112 * unit)
        titleFontSize = titleFont
        titleHeight = titleLine
        chipMetrics = TicTacToeChipMetrics(
            fontSize: chipFont,
            height: chipHeight,
            horizontalPadding: 12 * unit,
            touchHeight: chipRow
        )
        chipSpacing = 23 * unit
        chipRowHeight = chipRow
        statusFontSize = statusFont
        statusHeight = statusBlock
        statusLineLimit = statusLines
        boardSide = board
        cellSide = cell
        markFontSize = cell * 0.53
        mascotAreaHeight = max(naturalMascot, minimumMascot)
    }
}

private enum TicTacToePalette {
    // Android chip_bg_minik_plus_colors and chip_text_teal, and the status #333333.
    static let chipSelected = Color(red: 0.137, green: 0.447, blue: 0.506)
    static let chipUnselected = Color(red: 0.824, green: 0.820, blue: 0.902)
    static let chipText = Color(red: 0.420, green: 0.227, blue: 0.071)
    static let status = Color(red: 0.2, green: 0.2, blue: 0.2)
}

/// Sizes of Android's Material choice chips, handed to the chip labels.
private struct TicTacToeChipMetrics: Equatable, Sendable {
    var fontSize: CGFloat = 14
    var height: CGFloat = 32
    var horizontalPadding: CGFloat = 12
    var touchHeight: CGFloat = 48
}

private struct TicTacToeChipMetricsKey: EnvironmentKey {
    static let defaultValue = TicTacToeChipMetrics()
}

private extension EnvironmentValues {
    var ticTacToeChipMetrics: TicTacToeChipMetrics {
        get { self[TicTacToeChipMetricsKey.self] }
        set { self[TicTacToeChipMetricsKey.self] = newValue }
    }
}

/// Android's Material choice chip: 32 tall inside a 48 touch row, 12 at each side,
/// #237281 with white text when chosen and #D2D1E6 with brown text otherwise.
private struct TicTacToeChoiceChip: View {
    let text: String
    let selected: Bool
    @Environment(\.ticTacToeChipMetrics) private var metrics

    var body: some View {
        Text(text)
            .font(.system(size: metrics.fontSize))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(selected ? Color.white : TicTacToePalette.chipText)
            .padding(.horizontal, metrics.horizontalPadding)
            .frame(height: metrics.height)
            .background(
                selected ? TicTacToePalette.chipSelected : TicTacToePalette.chipUnselected,
                in: Capsule()
            )
            .frame(height: metrics.touchHeight)
            .contentShape(Rectangle())
    }
}

/// Android keeps the chips' look after the first move locks them, so a disabled
/// chip is drawn as it is; a pressed chip lightens briefly.
private struct TicTacToeChipButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Android's tile ripple: a light shade over the white card while it is pressed.
private struct TicTacToeCellButtonStyle: ButtonStyle {
    let reduceMotion: Bool
    let pressedInsets: EdgeInsets
    let pressedCornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: pressedCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.09 : 0))
                    .padding(pressedInsets)
                    .allowsHitTesting(false)
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: configuration.isPressed ? 0.08 : 0.12),
                value: configuration.isPressed
            )
    }
}

/// Android ConfettiRectView: small yellow and orange rounded rectangles emitted
/// across the top of the card for three seconds, falling with gravity, turning
/// and fading out. With Reduce Motion the confetti is one still frame.
private struct TicTacToeConfettiView: View {
    let reduceMotion: Bool
    let scale: CGFloat
    @State private var startDate = Date()
    @State private var pieces = TicTacToeConfettiPiece.burst()

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let elapsed = reduceMotion ? 1.4 : timeline.date.timeIntervalSince(startDate)
                drawPieces(in: &context, size: size, elapsed: elapsed)
            }
        }
    }

    private func drawPieces(in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        let width = Double(size.width)
        let height = Double(size.height)
        guard width > 0, height > 0 else {
            return
        }
        let unit = Double(scale)

        for piece in pieces {
            let age = elapsed - piece.delay
            guard age >= 0, age <= piece.lifetime else {
                continue
            }
            let drop = 0.5 * TicTacToeConfettiPiece.gravity * unit * age * age
            let y = piece.startY * height + piece.speedY * unit * age + drop
            guard y - piece.height * unit < height else {
                continue
            }
            let sway = sin(age * 2.4 + piece.phase) * 4 * unit
            let x = piece.startX * width + piece.speedX * unit * age + sway
            let depth = 0.6 + 0.7 * min(max(y / height, 0), 1)
            let progress = age / piece.lifetime
            let pieceWidth = CGFloat(piece.width * unit * depth)
            let pieceHeight = CGFloat(piece.height * unit * depth)
            let rect = CGRect(
                x: -pieceWidth / 2,
                y: -pieceHeight / 2,
                width: pieceWidth,
                height: pieceHeight
            )

            var pieceContext = context
            pieceContext.opacity = max(0, 1 - progress * progress)
            pieceContext.translateBy(x: CGFloat(x), y: CGFloat(y))
            pieceContext.rotate(by: .degrees(piece.angle + piece.spin * age))
            pieceContext.fill(
                Path(roundedRect: rect, cornerRadius: 2 * scale),
                with: .color(piece.color)
            )
        }
    }
}

/// One Android confetti piece in dp and seconds. Android emits 120 pieces a
/// second for three seconds with sizes of 3 to 7 dp, a third of them long.
private struct TicTacToeConfettiPiece {
    static let gravity: Double = 330
    static let palette: [Color] = [
        Color(red: 1.0, green: 0.757, blue: 0.027),
        Color(red: 1.0, green: 0.627, blue: 0.0),
        Color(red: 1.0, green: 0.718, blue: 0.302),
        Color(red: 1.0, green: 0.596, blue: 0.0),
        Color(red: 1.0, green: 0.439, blue: 0.263),
        Color(red: 1.0, green: 0.878, blue: 0.510)
    ]

    let startX: Double
    let startY: Double
    let speedX: Double
    let speedY: Double
    let angle: Double
    let spin: Double
    let width: Double
    let height: Double
    let lifetime: Double
    let delay: Double
    let phase: Double
    let color: Color

    static func burst(count: Int = 360, emittingFor duration: Double = 3) -> [TicTacToeConfettiPiece] {
        var generator = SystemRandomNumberGenerator()
        var result: [TicTacToeConfettiPiece] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let base = Double.random(in: 3...7, using: &generator)
            let isLong = Double.random(in: 0...1, using: &generator) < 0.35
            let stretch = isLong
                ? Double.random(in: 1.8...3.2, using: &generator)
                : Double.random(in: 0.9...1.6, using: &generator)
            let colorIndex = Int.random(in: 0..<palette.count, using: &generator)
            let piece = TicTacToeConfettiPiece(
                startX: Double.random(in: 0...1, using: &generator),
                startY: -Double.random(in: 0...0.15, using: &generator),
                speedX: Double.random(in: -22...22, using: &generator),
                speedY: Double.random(in: 33...76, using: &generator),
                angle: Double.random(in: 0...360, using: &generator),
                spin: Double.random(in: -270...270, using: &generator),
                width: base,
                height: base * stretch,
                lifetime: Double.random(in: 2.8...4.2, using: &generator),
                delay: Double(index) / Double(max(count, 1)) * duration,
                phase: Double.random(in: 0...6.28, using: &generator),
                color: palette[colorIndex]
            )
            result.append(piece)
        }
        return result
    }
}
