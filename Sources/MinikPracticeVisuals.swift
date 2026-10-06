import SwiftUI

enum MinikVisualIdentity: Equatable, Sendable {
    case language
    case math
    case game
}

private struct MinikVisualIdentityKey: EnvironmentKey {
    static let defaultValue = MinikVisualIdentity.language
}

extension EnvironmentValues {
    var minikVisualIdentity: MinikVisualIdentity {
        get { self[MinikVisualIdentityKey.self] }
        set { self[MinikVisualIdentityKey.self] = newValue }
    }
}

extension ProductConfiguration {
    var visualIdentity: MinikVisualIdentity {
        switch contentDomain {
        case .language: return .language
        case .math: return .math
        case .game: return .game
        }
    }
}

struct MinikPracticeScreen<Content: View>: View {
    let progressLabel: String
    let onExit: () -> Void
    let content: (MinikPracticeLayoutMetrics) -> Content

    init(
        progressLabel: String,
        onExit: @escaping () -> Void,
        @ViewBuilder content: @escaping (MinikPracticeLayoutMetrics) -> Content
    ) {
        self.progressLabel = progressLabel
        self.onExit = onExit
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let tablet = MinikPracticeLayoutMetrics.usesTabletLayout(for: geometry.size)
            let metrics = MinikPracticeLayoutMetrics(
                containerWidth: geometry.size.width,
                isTablet: tablet,
                containerHeight: geometry.size.height
            )

            ScrollView {
                VStack(spacing: metrics.stackSpacing) {
                    MinikPracticeHeader(
                        progressLabel: progressLabel,
                        onExit: onExit
                    )

                    content(metrics)
                        // iPad: the exercise sits in the middle of the screen instead
                        // of hugging the top above an empty half screen.
                        .frame(maxHeight: tablet ? CGFloat.infinity : nil)
                }
                .frame(maxWidth: metrics.contentMaxWidth)
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.verticalPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: tablet ? geometry.size.height : nil)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            // The practice chrome below (surface, header, buttons and tiles) uses
            // larger sizes on iPad.
            .environment(\.minikPracticeTablet, tablet)
        }
        // The portrait fill artwork stays a background so it never sizes the layout. As a ZStack
        // sibling it made the stack taller than the screen and pushed the panel down (off-screen
        // in landscape), the same defect fixed in LanguageActivityScreen and MinikHomeScreen.
        .background {
            MinikPracticeBackground()
                .ignoresSafeArea()
        }
    }
}

struct MinikPracticeSurface<Content: View>: View {
    let compact: Bool
    let content: () -> Content
    @Environment(\.minikPracticeTablet) private var tablet

    init(
        compact: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.compact = compact
        self.content = content
    }

    var body: some View {
        VStack(spacing: tablet ? 30 : (compact ? 18 : 24)) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(tablet ? 36 : (compact ? 18 : 28))
        .background(
            RoundedRectangle(cornerRadius: tablet ? 40 : (compact ? 28 : 36), style: .continuous)
                .fill(.white.opacity(0.94))
        )
        .overlay {
            RoundedRectangle(cornerRadius: tablet ? 40 : (compact ? 28 : 36), style: .continuous)
                .strokeBorder(.white.opacity(0.7), lineWidth: 1.2)
        }
        .shadow(color: Color(red: 0.08, green: 0.35, blue: 0.53).opacity(0.12), radius: 26, y: 14)
        .shadow(color: .white.opacity(0.25), radius: 3, y: -1)
    }
}

struct MinikFeedbackBadge: View {
    let isCorrect: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet
    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 14) {
            MinikArtworkImage(
                name: isCorrect ? MinikVisualAsset.success : MinikVisualAsset.tryAgain
            )
            .frame(width: tablet ? 90 : 72, height: tablet ? 102 : 82)
            .scaleEffect(reduceMotion || hasAppeared ? 1 : 0.72)

            Text(isCorrect
                ? String(localized: "Great job!")
                : String(localized: "Try again"))
                .font(tablet ? Font.title3.weight(.semibold) : Font.headline.weight(.semibold))
        }
        .foregroundStyle(isCorrect ? Color(red: 0.1, green: 0.52, blue: 0.28) : Color(red: 0.73, green: 0.34, blue: 0.22))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(isCorrect ? Color(red: 0.9, green: 0.98, blue: 0.91) : Color(red: 1.0, green: 0.94, blue: 0.9))
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.85), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            guard !reduceMotion else {
                hasAppeared = true
                return
            }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) {
                hasAppeared = true
            }
        }
    }
}

struct MinikPrimaryActionStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(tablet ? Font.title3.weight(.semibold) : Font.headline.weight(.semibold))
            .foregroundStyle(Color(red: 0.16, green: 0.29, blue: 0.34))
            .padding(.horizontal, 24)
            .padding(.vertical, tablet ? 20 : 16)
            .frame(maxWidth: .infinity, minHeight: tablet ? 68 : 56)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [Color(red: 1.0, green: 0.88, blue: 0.25), Color(red: 0.98, green: 0.67, blue: 0.19)]
                                : [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.91, green: 0.56, blue: 0.12).opacity(isEnabled ? 0.24 : 0), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct MinikYellowActionStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(tablet ? Font.title3.weight(.bold) : Font.headline.weight(.bold))
            .foregroundStyle(Color(red: 0.18, green: 0.30, blue: 0.34))
            .padding(.horizontal, tablet ? 28 : 24)
            .padding(.vertical, tablet ? 16 : 13)
            .frame(minHeight: tablet ? 60 : 50)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.02))
            )
            .shadow(color: Color(red: 0.76, green: 0.57, blue: 0.0).opacity(0.18), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct MinikUtilityButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(tablet ? Font.title3.weight(.semibold) : Font.headline.weight(.semibold))
            .foregroundStyle(isEnabled ? Color(red: 0.16, green: 0.47, blue: 0.59) : .secondary)
            .frame(minWidth: 44, minHeight: tablet ? 52 : 44)
            .padding(.horizontal, tablet ? 18 : 14)
            .padding(.vertical, tablet ? 12 : 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(isEnabled ? 0.9 : 0.65))
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color(red: 0.72, green: 0.87, blue: 0.97).opacity(isEnabled ? 1 : 0.45), lineWidth: 1.2)
            }
            .shadow(color: Color(red: 0.16, green: 0.56, blue: 0.76).opacity(isEnabled ? 0.12 : 0.05), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct MinikChoiceButtonStyle: ButtonStyle {
    enum FeedbackState: Equatable {
        case idle
        case selected
        case correct
        case incorrect
    }

    let feedbackState: FeedbackState
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        let palette = palette(for: feedbackState)

        configuration.label
            .padding(tablet ? 24 : (compact ? 16 : 20))
            .frame(maxWidth: .infinity, minHeight: tablet ? 148 : (compact ? 108 : 124))
            .background(
                RoundedRectangle(cornerRadius: tablet ? 30 : (compact ? 24 : 28), style: .continuous)
                    .fill(palette.fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: tablet ? 30 : (compact ? 24 : 28), style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: feedbackState == .idle
                                ? [Color(red: 0.59, green: 0.38, blue: 0.91), Color(red: 0.25, green: 0.78, blue: 0.91)]
                                : [palette.stroke, palette.stroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: feedbackState == .idle ? 2 : palette.lineWidth
                    )
            }
            .shadow(color: palette.shadow.opacity(isEnabled ? 1 : 0.35), radius: palette.shadowRadius, y: palette.shadowY)
            .opacity(isEnabled ? 1 : 0.9)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private func palette(for state: FeedbackState) -> ChoicePalette {
        switch state {
        case .idle:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color.white.opacity(0.96), Color(red: 0.96, green: 0.99, blue: 1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                stroke: Color(red: 0.73, green: 0.87, blue: 0.97),
                lineWidth: 1.2,
                shadow: Color(red: 0.16, green: 0.58, blue: 0.76).opacity(0.13),
                shadowRadius: 14,
                shadowY: 8
            )
        case .selected:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color(red: 0.93, green: 0.98, blue: 1.0), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.3, green: 0.7, blue: 0.92),
                lineWidth: 2.2,
                shadow: Color(red: 0.17, green: 0.62, blue: 0.84).opacity(0.2),
                shadowRadius: 18,
                shadowY: 10
            )
        case .correct:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color(red: 0.9, green: 0.99, blue: 0.92), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.18, green: 0.66, blue: 0.33),
                lineWidth: 2.4,
                shadow: Color(red: 0.15, green: 0.64, blue: 0.34).opacity(0.2),
                shadowRadius: 18,
                shadowY: 10
            )
        case .incorrect:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color(red: 1.0, green: 0.94, blue: 0.92), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.88, green: 0.45, blue: 0.36),
                lineWidth: 2.2,
                shadow: Color(red: 0.88, green: 0.45, blue: 0.36).opacity(0.18),
                shadowRadius: 16,
                shadowY: 9
            )
        }
    }
}

struct MinikTokenButtonStyle: ButtonStyle {
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, tablet ? 18 : (compact ? 12 : 16))
            .padding(.vertical, tablet ? 18 : (compact ? 12 : 16))
            .frame(maxWidth: .infinity, minHeight: tablet ? 90 : (compact ? 64 : 76))
            .background(
                RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [Color.white.opacity(0.98), Color(red: 0.95, green: 0.99, blue: 1.0)]
                                : [Color.white.opacity(0.78), Color.white.opacity(0.68)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous)
                    .strokeBorder(
                        isEnabled
                            ? Color(red: 0.69, green: 0.84, blue: 0.96)
                            : Color(red: 0.8, green: 0.85, blue: 0.9),
                        lineWidth: 1.2
                    )
            }
            .shadow(
                color: Color(red: 0.19, green: 0.58, blue: 0.77).opacity(isEnabled ? 0.14 : 0.05),
                radius: compact ? 10 : 14,
                y: compact ? 6 : 8
            )
            .opacity(isEnabled ? 1 : 0.82)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct MinikMatchTileStyle: ButtonStyle {
    enum State: Equatable {
        case idle
        case selected
        case incorrect
    }

    let state: State
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        let palette = palette(for: state)

        configuration.label
            .padding(tablet ? 24 : (compact ? 16 : 20))
            .frame(maxWidth: .infinity, minHeight: tablet ? 156 : (compact ? 116 : 132))
            .background(
                RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
                    .fill(palette.fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
                    .strokeBorder(palette.stroke, lineWidth: palette.lineWidth)
            }
            .shadow(color: palette.shadow.opacity(isEnabled ? 1 : 0.35), radius: palette.shadowRadius, y: palette.shadowY)
            .opacity(isEnabled ? 1 : 0.9)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private func palette(for state: State) -> ChoicePalette {
        switch state {
        case .idle:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color.white.opacity(0.97), Color(red: 0.96, green: 0.99, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.72, green: 0.86, blue: 0.97),
                lineWidth: 1.2,
                shadow: Color(red: 0.16, green: 0.58, blue: 0.76).opacity(0.13),
                shadowRadius: 14,
                shadowY: 8
            )
        case .selected:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color(red: 0.93, green: 0.98, blue: 1.0), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.3, green: 0.7, blue: 0.92),
                lineWidth: 2.2,
                shadow: Color(red: 0.17, green: 0.62, blue: 0.84).opacity(0.2),
                shadowRadius: 18,
                shadowY: 10
            )
        case .incorrect:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color(red: 1.0, green: 0.95, blue: 0.93), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.88, green: 0.45, blue: 0.36),
                lineWidth: 2.2,
                shadow: Color(red: 0.88, green: 0.45, blue: 0.36).opacity(0.18),
                shadowRadius: 16,
                shadowY: 9
            )
        }
    }
}

struct MinikMemoryCardStyle: ButtonStyle {
    enum State: Equatable {
        case faceDown
        case faceUp
        case matched
    }

    let state: State
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        let palette = palette(for: state)

        configuration.label
            .padding(tablet ? 20 : (compact ? 14 : 18))
            .frame(maxWidth: .infinity, minHeight: tablet ? 168 : (compact ? 126 : 144))
            .background(
                RoundedRectangle(cornerRadius: compact ? 26 : 30, style: .continuous)
                    .fill(palette.fill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 26 : 30, style: .continuous)
                    .strokeBorder(palette.stroke, lineWidth: palette.lineWidth)
            }
            .shadow(color: palette.shadow.opacity(isEnabled ? 1 : 0.9), radius: palette.shadowRadius, y: palette.shadowY)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private func palette(for state: State) -> ChoicePalette {
        switch state {
        case .faceDown:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [
                        Color(red: 0.522, green: 0.314, blue: 0.706),
                        Color(red: 0.941, green: 0.698, blue: 0.722),
                        Color(red: 0.235, green: 0.792, blue: 0.835)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                stroke: Color.white.opacity(0.72),
                lineWidth: 1.4,
                shadow: Color(red: 0.3, green: 0.49, blue: 0.91).opacity(0.24),
                shadowRadius: 18,
                shadowY: 10
            )
        case .faceUp:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color.white.opacity(0.98), Color(red: 0.96, green: 0.99, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.72, green: 0.86, blue: 0.97),
                lineWidth: 1.2,
                shadow: Color(red: 0.16, green: 0.58, blue: 0.76).opacity(0.13),
                shadowRadius: 14,
                shadowY: 8
            )
        case .matched:
            return ChoicePalette(
                fill: LinearGradient(
                    colors: [Color(red: 0.9, green: 0.99, blue: 0.93), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                stroke: Color(red: 0.18, green: 0.66, blue: 0.33),
                lineWidth: 2.2,
                shadow: Color(red: 0.15, green: 0.64, blue: 0.34).opacity(0.18),
                shadowRadius: 16,
                shadowY: 9
            )
        }
    }
}

struct MinikSoccerBallStyle: ButtonStyle {
    enum State: Equatable {
        case idle
        case selected
    }

    let state: State
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let ringColor = state == .selected
            ? Color(red: 0.98, green: 0.73, blue: 0.23)
            : Color.white.opacity(0.92)
        let shadowColor = state == .selected
            ? Color(red: 0.96, green: 0.72, blue: 0.21).opacity(0.28)
            : Color(red: 0.08, green: 0.45, blue: 0.2).opacity(0.18)

        configuration.label
            // SoccerView gives each ball its size for the screen (the label's frame is
            // the plate). A fixed 138-154 point plate pushed the second row of balls
            // and the Kick button below an iPad's screen (report 1 #4).
            .background(
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color(red: 0.95, green: 0.98, blue: 1.0)],
                                center: .topLeading,
                                startRadius: 10,
                                endRadius: compact ? 88 : 98
                            )
                        )

                    Circle()
                        .strokeBorder(ringColor, lineWidth: state == .selected ? 4 : 2)
                }
            )
            .overlay {
                Circle()
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: shadowColor.opacity(isEnabled ? 1 : 0.35), radius: state == .selected ? 18 : 12, y: state == .selected ? 10 : 7)
            .opacity(isEnabled ? 1 : 0.88)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct MinikTowerBlockStyle: ButtonStyle {
    let compact: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.minikPracticeTablet) private var tablet

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, tablet ? 18 : (compact ? 12 : 16))
            .padding(.vertical, tablet ? 16 : (compact ? 12 : 14))
            .frame(maxWidth: .infinity, minHeight: tablet ? 94 : (compact ? 68 : 80))
            .background(
                RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [Color.white.opacity(0.98), Color(red: 0.95, green: 0.99, blue: 1.0)]
                                : [Color.white.opacity(0.82), Color.white.opacity(0.74)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 22 : 26, style: .continuous)
                    .strokeBorder(
                        isEnabled
                            ? Color(red: 0.69, green: 0.84, blue: 0.96)
                            : Color(red: 0.79, green: 0.84, blue: 0.9),
                        lineWidth: 1.2
                    )
            }
            .shadow(
                color: Color(red: 0.19, green: 0.58, blue: 0.77).opacity(isEnabled ? 0.14 : 0.06),
                radius: compact ? 10 : 14,
                y: compact ? 6 : 8
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct MinikPracticeHeader: View {
    let progressLabel: String
    let onExit: () -> Void
    @Environment(\.minikPracticeTablet) private var tablet

    init(progressLabel: String, onExit: @escaping () -> Void) {
        self.progressLabel = progressLabel
        self.onExit = onExit
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onExit) {
                MinikArtworkImage(name: MinikVisualAsset.close)
                    .frame(width: tablet ? 60 : 44, height: tablet ? 60 : 44)
                    .background(.white.opacity(0.9), in: Circle())
            }
            .accessibilityLabel("Close exercise")

            Spacer(minLength: 12)

            Text(progressLabel)
                .font(tablet ? Font.title2.weight(.semibold) : Font.headline.weight(.semibold))
                .foregroundStyle(Color(red: 0.14, green: 0.38, blue: 0.48))
                .padding(.horizontal, tablet ? 24 : 18)
                .padding(.vertical, tablet ? 14 : 11)
                .background(.white.opacity(0.9), in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.65), lineWidth: 1)
                }
                .accessibilityLabel(String(
                    format: String(localized: "Challenge progress %@"),
                    progressLabel
                ))
        }
    }
}

struct MinikPracticeBackground: View {
    @Environment(\.minikVisualIdentity) private var visualIdentity

    @ViewBuilder
    var body: some View {
        if visualIdentity == .math {
            // Minik Math's activities sit on the rainbow sky of the new Minik Plus
            // design, like the Math hub (report 1 #10); the white practice surface
            // keeps the content readable on it. The sky fills whatever size it is
            // given and never sizes the layout.
            MinikSkyBackground()
        } else {
            MinikArtworkBackground()
        }
    }
}

struct MinikPracticeLayoutMetrics {
    let containerWidth: CGFloat
    /// An iPad-sized screen (usesTabletLayout(for:)): a tablet layout
    /// with larger sizes and spacing rather than an enlarged phone one.
    var isTablet: Bool = false
    /// The screen's height inside the safe areas (0 when unknown), for a board that
    /// sizes itself to fit the screen without scrolling (Soccer).
    var containerHeight: CGFloat = 0

    /// Both sides at least 600 points: every iPad in portrait and landscape, not an
    /// iPhone in landscape or an iPad app in a narrow Split View.
    static func usesTabletLayout(for size: CGSize) -> Bool {
        min(size.width, size.height) >= 600
    }

    var contentMaxWidth: CGFloat {
        if isTablet {
            if containerWidth >= 1100 { return 960 }
            if containerWidth >= 900 { return 860 }
            return 760
        }
        if containerWidth >= 1100 { return 840 }
        if containerWidth >= 800 { return 760 }
        return 680
    }

    var compact: Bool {
        containerWidth < 430
    }

    var horizontalPadding: CGFloat {
        isTablet ? 32 : (compact ? 16 : 24)
    }

    var verticalPadding: CGFloat {
        isTablet ? 32 : (compact ? 18 : 28)
    }

    var stackSpacing: CGFloat {
        isTablet ? 32 : (compact ? 18 : 24)
    }
}

private struct MinikPracticeTabletKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside MinikPracticeScreen on an iPad-sized screen: the practice chrome
    /// (surface, header, buttons, tiles) uses its larger iPad sizes.
    var minikPracticeTablet: Bool {
        get { self[MinikPracticeTabletKey.self] }
        set { self[MinikPracticeTabletKey.self] = newValue }
    }
}

private struct ChoicePalette {
    let fill: LinearGradient
    let stroke: Color
    let lineWidth: CGFloat
    let shadow: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat
}
