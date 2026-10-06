import SwiftUI

struct LanguageActivityLayout {
    let width: CGFloat
    let height: CGFloat
    let wide: Bool
    let accessibility: Bool
}

/// The space between a Language panel's edges and its content.
enum LanguagePanelInsets {
    static func horizontal(wide: Bool) -> CGFloat { wide ? 21 : 14 }
    static func vertical(wide: Bool) -> CGFloat { wide ? 12 : 8 }
}

/// Android draws two Language panels. Letter Pairs' white card (16 dp corners, 18 dp
/// from the screen's edges) is the default. WriteScreen's practice screens use
/// bg_white_rounded: #F9F9F9 with 20 dp corners, 20 dp from the sides and 22 dp from
/// the top and bottom (30 dp and 32 dp on tablets).
enum LanguagePanelStyle {
    case card
    case rounded

    func horizontalMargin(wide: Bool) -> CGFloat {
        switch self {
        case .card: return wide ? 40 : 18
        case .rounded: return wide ? 30 : 20
        }
    }

    func verticalMargin(wide: Bool) -> CGFloat {
        switch self {
        case .card: return wide ? 30 : 18
        case .rounded: return wide ? 32 : 22
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .card: return 16
        case .rounded: return 20
        }
    }

    var fill: Color {
        switch self {
        case .card: return .white
        case .rounded: return Color(red: 0.976, green: 0.976, blue: 0.976)
        }
    }
}

/// Android's framed Language activity surface. The board is laid out for the
/// space the panel really has; whenever it is still taller (accessibility text,
/// small viewports) the panel scrolls, and it neither scrolls nor bounces when
/// it fits. Only accessibility text sizes (AX1-AX5) select accessibility layouts.
struct LanguageActivityScreen<Content: View>: View {
    private let sceneAsset: String?
    private let panelStyle: LanguagePanelStyle
    private let minimumContentHeight: (CGFloat, Bool) -> CGFloat
    private let content: (LanguageActivityLayout) -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(sceneAsset: String? = nil,
         panelStyle: LanguagePanelStyle = .card,
         minimumContentHeight: @escaping (CGFloat, Bool) -> CGFloat = { _, _ in 0 },
         @ViewBuilder content: @escaping (LanguageActivityLayout) -> Content) {
        self.sceneAsset = sceneAsset
        self.panelStyle = panelStyle
        self.minimumContentHeight = minimumContentHeight
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 700
            let horizontalMargin = panelStyle.horizontalMargin(wide: wide)
            let verticalMargin = panelStyle.verticalMargin(wide: wide)
            let panelWidth = max(1, min(900, geometry.size.width - 2 * horizontalMargin))
            let panelHeight = max(1, geometry.size.height - 2 * verticalMargin)
            let horizontalInset = LanguagePanelInsets.horizontal(wide: wide)
            let verticalInset = LanguagePanelInsets.vertical(wide: wide)
            let contentWidth = max(1, panelWidth - 2 * horizontalInset)
            let viewportHeight = max(1, panelHeight - 2 * verticalInset)
            // A genuinely small viewport lays the board out at a usable height and
            // scrolls instead of squeezing it.
            let boardHeight: CGFloat = panelHeight < 560 ? 700 : viewportHeight
            let layout = LanguageActivityLayout(
                width: contentWidth,
                height: max(minimumContentHeight(contentWidth, wide), boardHeight),
                wide: wide, accessibility: dynamicTypeSize.isAccessibilitySize
            )
            ScrollView {
                content(layout)
                    .frame(width: contentWidth)
                    .frame(minHeight: viewportHeight)
                    .padding(.horizontal, horizontalInset)
                    .padding(.vertical, verticalInset)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: panelWidth, height: panelHeight)
            .background {
                panelStyle.fill
                if let sceneAsset {
                    MinikArtworkImage(name: sceneAsset, contentMode: .fill)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: panelStyle.cornerRadius))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // The fill artwork stays a background so it never sizes the layout. As a
        // ZStack sibling its portrait aspect made the stack taller than the screen,
        // and GeometryReader pinned that stack at the top: the panel slid down,
        // in landscape completely off-screen.
        // Android's practice screens show the tie-dye artwork as it is (WriteScreen's
        // minik_background_frame, minik_background elsewhere), without the white veil
        // MinikArtworkBackground lays over it.
        .background {
            MinikArtworkImage(name: MinikVisualAsset.background, contentMode: .fill)
                .ignoresSafeArea()
                .clipped()
                .ignoresSafeArea()
        }
    }
}

/// The close and replay row at the top of a Language panel.
enum LanguagePanelHeader {
    /// A compact 48-point bar (56 on iPad; 80 and 110 with the logo), which the
    /// other Language boards budget for.
    case compact
    /// WriteScreen's practice header (fragment_choose_right_image), measured from
    /// the panel: the 57 dp speaker 15 dp below its top (100 dp and 20 dp on
    /// tablets) and the close artwork 20 dp from its top and end edges (a 38 dp
    /// view with 3 dp padding 17 dp from the corner; 55 dp and 32 dp on tablets).
    /// `scale` enlarges it with the board on iPads larger than the iPad mini.
    case practice

    func height(wide: Bool, showsLogo: Bool = false, scale: CGFloat = 1) -> CGFloat {
        switch self {
        case .compact:
            return showsLogo ? (wide ? 110 : 80) : (wide ? 56 : 48)
        case .practice:
            return speakerTop(wide: wide, scale: scale) + speakerDiameter(wide: wide, scale: scale)
        }
    }

    func speakerDiameter(wide: Bool, scale: CGFloat = 1) -> CGFloat {
        switch self {
        case .compact: return wide ? 56 : 48
        case .practice: return (wide ? 100 : 57) * scale
        }
    }

    func speakerTop(wide: Bool, scale: CGFloat = 1) -> CGFloat {
        switch self {
        case .compact:
            return 0
        case .practice:
            let margin: CGFloat = (wide ? 20 : 15) * scale
            return max(0, margin - LanguagePanelInsets.vertical(wide: wide))
        }
    }
}

struct LanguagePanelNavigation: View {
    let wide: Bool
    var showsLogo = false
    var header = LanguagePanelHeader.compact
    /// Enlarges the practice header with the board on iPads larger than the iPad mini.
    var scale: CGFloat = 1
    var onReplay: (() -> Void)?
    let onExit: () -> Void

    var body: some View {
        switch header {
        case .compact:
            compactBar
        case .practice:
            practiceBar
        }
    }

    private var compactBar: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .top) {
                if showsLogo {
                    MinikLanguageLogo().frame(width: wide ? 88 : 64, height: wide ? 95 : 70)
                }
                Spacer(minLength: 0)
                Button(action: onExit) {
                    MinikArtworkImage(name: MinikVisualAsset.close)
                        .frame(width: wide ? 48 : 34, height: wide ? 48 : 34)
                        .frame(width: wide ? 56 : 44, height: wide ? 56 : 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close exercise")
                .padding(.top, showsLogo ? 10 : 0)
            }
            if let onReplay {
                LanguageReplayButton(action: onReplay)
            }
        }
        .frame(height: header.height(wide: wide, showsLogo: showsLogo))
    }

    /// Android's practice header: the speaker centred, the close artwork at the
    /// end (the left in Hebrew), its tap target centred on the artwork.
    private var practiceBar: some View {
        let artwork: CGFloat = (wide ? 49 : 32) * scale
        let target: CGFloat = max(wide ? 56 : 44, artwork)
        let artworkMargin: CGFloat = (wide ? 35 : 20) * scale
        let centring = (artwork - target) / 2
        let closeTop = max(0, artworkMargin - LanguagePanelInsets.vertical(wide: wide) + centring)
        let closeEnd = max(0, artworkMargin - LanguagePanelInsets.horizontal(wide: wide) + centring)
        return ZStack(alignment: .topTrailing) {
            if let onReplay {
                // Centred as in the phone screenshots. Android's tablet layout leaves it 27 dp
                // off centre only because Plus hides the home button whose 55 dp start margin
                // the speaker keeps.
                LanguageSpeakerButton(diameter: header.speakerDiameter(wide: wide, scale: scale), action: onReplay)
                    .padding(.top, header.speakerTop(wide: wide, scale: scale))
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            Button(action: onExit) {
                MinikArtworkImage(name: MinikVisualAsset.close)
                    .frame(width: artwork, height: artwork)
                    .frame(width: target, height: target)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close exercise")
            .padding(.top, closeTop)
            .padding(.trailing, closeEnd)
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .frame(height: header.height(wide: wide, scale: scale), alignment: .top)
    }
}

/// Android's speaker button (bg_icon_button_outline_circle around
/// ic_lock_silent_mode_off tinted #3F4FAD): a 2 dp #3F4FAD ring on a pale
/// #3F4FAD fill (alpha 0x20) with the speaker glyph inside. Android's glyph is a
/// tall cone with short waves, about half the circle wide and a little more than
/// half tall, so the one-wave symbol fills a square of about half the circle; the
/// two-wave symbol came out wider and flatter.
struct LanguageSpeakerButton: View {
    let diameter: CGFloat
    var label: LocalizedStringKey = "Replay current word"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.1.fill")
                .resizable()
                .scaledToFit()
                .frame(width: diameter * 0.54, height: diameter * 0.54)
                .foregroundStyle(LanguagePracticePalette.ink)
                // Android's speaker icon is not mirrored in right-to-left layouts.
                .environment(\.layoutDirection, .leftToRight)
                .frame(width: diameter, height: diameter)
                .background(LanguagePracticePalette.ink.opacity(0.125), in: Circle())
                .overlay { Circle().strokeBorder(LanguagePracticePalette.ink, lineWidth: 2) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct LanguageRewardStateKey: EnvironmentKey {
    static let defaultValue = RewardState()
}

extension EnvironmentValues {
    var languageRewardState: RewardState {
        get { self[LanguageRewardStateKey.self] }
        set { self[LanguageRewardStateKey.self] = newValue }
    }
}

struct LanguagePointsBadge: View {
    @Environment(\.languageRewardState) private var rewards

    var body: some View {
        VStack(spacing: 3) {
            Text("Points").font(.subheadline.bold())
            Text(rewards.points, format: .number).font(.title3.bold().monospacedDigit())
        }
        // The badge has a fixed width: larger text shrinks onto one line instead
        // of wrapping letter by letter.
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 4)
        .foregroundStyle(Color(red: 0.29, green: 0.22, blue: 0.71))
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Color(red: 0.97, green: 0.96, blue: 1), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color(red: 0.55, green: 0.49, blue: 0.96), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct LanguagePairTileStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color(red: 1, green: 0.70, blue: 0) : .clear, lineWidth: 3)
            }
            .padding(EdgeInsets(top: 2, leading: 5, bottom: 5, trailing: 2))
            .background {
                // item_letter_pair_image mirrors its 5 dp start padding, but its
                // bg_minik_gradient_rounded is not mirrored: purple on the physical left
                // in Hebrew as well.
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.52, green: 0.31, blue: 0.71),
                        Color(red: 0.94, green: 0.70, blue: 0.72),
                        Color(red: 0.24, green: 0.79, blue: 0.84)
                    ], startPoint: UnitPoint(x: 0, y: 0.5), endPoint: UnitPoint(x: 1, y: 0.5)))
                    .environment(\.layoutDirection, .leftToRight)
            }
            .scaleEffect(selected && !reduceMotion ? 1.045 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.11), value: selected)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct LanguageEncouragementEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var languageEncouragementEnabled: Bool {
        get { self[LanguageEncouragementEnabledKey.self] }
        set { self[LanguageEncouragementEnabledKey.self] = newValue }
    }
}

private struct LanguageWordBonusRunKey: EnvironmentKey { static let defaultValue = 0 }
extension EnvironmentValues {
    var languageWordBonusRun: Int {
        get { self[LanguageWordBonusRunKey.self] }
        set { self[LanguageWordBonusRunKey.self] = newValue }
    }
}
