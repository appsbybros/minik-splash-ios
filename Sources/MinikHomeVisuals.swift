import SwiftUI

struct MinikHomeScreen<Content: View>: View {
    let content: (MinikHomeLayoutMetrics) -> Content

    init(@ViewBuilder content: @escaping (MinikHomeLayoutMetrics) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = MinikHomeLayoutMetrics(containerWidth: geometry.size.width)

            ScrollView {
                content(metrics)
                    .frame(maxWidth: metrics.contentMaxWidth)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.vertical, metrics.verticalPadding)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
        // The fill artwork stays a background so it never sizes the layout. As a
        // ZStack sibling its portrait aspect made the stack taller than the screen,
        // and GeometryReader pinned that stack at the top: the scroll view slid
        // down, cutting off its end (in landscape it left the screen entirely).
        .background {
            MinikArtworkBackground()
                .ignoresSafeArea()
        }
    }
}

struct MinikHomeLayoutMetrics {
    let containerWidth: CGFloat

    var compact: Bool {
        containerWidth < 430
    }

    var horizontalPadding: CGFloat {
        compact ? 18 : containerWidth < 768 ? 24 : 32
    }

    var verticalPadding: CGFloat {
        compact ? 22 : 30
    }

    var contentMaxWidth: CGFloat {
        let usableWidth = max(0, containerWidth - horizontalPadding * 2)
        let desiredCap: CGFloat

        if containerWidth < 768 {
            desiredCap = 720
        } else if containerWidth < 1100 {
            desiredCap = 860
        } else {
            desiredCap = 980
        }

        return min(usableWidth, desiredCap)
    }
}

struct MinikHomeSectionCard<Content: View>: View {
    let compact: Bool
    let content: () -> Content

    init(
        compact: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.compact = compact
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 16 : 20) {
            content()
        }
        .padding(compact ? 18 : 24)
        .background(
            RoundedRectangle(cornerRadius: compact ? 28 : 34, style: .continuous)
                .fill(.white.opacity(0.96))
        )
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 28 : 34, style: .continuous)
                .strokeBorder(Color(red: 0.45, green: 0.82, blue: 0.92).opacity(0.34), lineWidth: 1.2)
        }
        .shadow(color: Color(red: 0.11, green: 0.42, blue: 0.58).opacity(0.12), radius: 24, y: 12)
    }
}

struct MinikHomeActivityCardStyle: ButtonStyle {
    let theme: ActivityTheme
    var usesArtwork = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(usesArtwork ? 12 : 18)
            .frame(maxWidth: .infinity, minHeight: usesArtwork ? 148 : 156, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        usesArtwork
                            ? LinearGradient(colors: [.white, Color.white.opacity(0.94)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: palette(for: theme), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        usesArtwork
                            ? Color(red: 0.37, green: 0.76, blue: 0.91).opacity(0.58)
                            : Color.white.opacity(0.4),
                        lineWidth: usesArtwork ? 2 : 1.1
                    )
            }
            .shadow(color: Color(red: 0.30, green: 0.58, blue: 0.73).opacity(usesArtwork ? 0.10 : 0.08), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private func palette(for theme: ActivityTheme) -> [Color] {
        switch theme {
        case .sky:
            return [Color(red: 0.38, green: 0.82, blue: 0.96), Color(red: 0.29, green: 0.58, blue: 0.95)]
        case .meadow:
            return [Color(red: 0.39, green: 0.82, blue: 0.56), Color(red: 0.18, green: 0.65, blue: 0.39)]
        case .sunshine:
            return [Color(red: 0.99, green: 0.8, blue: 0.32), Color(red: 0.95, green: 0.6, blue: 0.28)]
        case .coral:
            return [Color(red: 0.98, green: 0.58, blue: 0.46), Color(red: 0.9, green: 0.36, blue: 0.41)]
        case .berry:
            return [Color(red: 0.78, green: 0.49, blue: 0.98), Color(red: 0.57, green: 0.37, blue: 0.9)]
        }
    }
}

struct MinikHomeSelectionChipStyle: ButtonStyle {
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(isSelected ? Color(red: 0.16, green: 0.43, blue: 0.55) : Color(red: 0.24, green: 0.48, blue: 0.57))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? .white.opacity(0.96) : .white.opacity(0.72))
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? Color(red: 0.27, green: 0.78, blue: 0.93) : Color.white.opacity(0.7),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .shadow(color: Color(red: 0.15, green: 0.51, blue: 0.73).opacity(isSelected ? 0.16 : 0.08), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct MinikHomeUnavailableView: View {
    let title: String
    let message: String
    let onBack: () -> Void

    var body: some View {
        MinikHomeScreen { metrics in
            VStack(spacing: metrics.compact ? 18 : 22) {
                Spacer(minLength: metrics.compact ? 20 : 40)

                MinikHomeSectionCard(compact: metrics.compact) {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: metrics.compact ? 38 : 46, weight: .bold))
                            .foregroundStyle(Color(red: 0.96, green: 0.61, blue: 0.26))

                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color(red: 0.14, green: 0.38, blue: 0.48))
                            .multilineTextAlignment(.center)

                        Text(message)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color(red: 0.28, green: 0.47, blue: 0.56))
                            .multilineTextAlignment(.center)

                        Button(action: onBack) {
                            Label("Back", systemImage: "arrow.left")
                        }
                        .buttonStyle(MinikPrimaryActionStyle())
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: metrics.compact ? 20 : 40)
            }
        }
    }
}
