import SwiftUI

/// Android fragment_learn: the outlined capital and small letter above the dashed
/// divider, the example picture and its word below it, the yellow Next pill at the
/// bottom. Phones follow layout/fragment_learn.xml; iPads follow
/// layout-sw600dp/fragment_learn.xml with the values-sw700dp and values-sw800dp
/// sizes and keep the phone reference's divider. At every text size the page keeps
/// this composition, fills the screen and scrolls only when a screen is too short
/// for it; only a phone at an accessibility size too large for it gets one column.
struct LanguageLearnPage: View {
    let card: LanguageLearnCardPresentation
    let nextStartsOver: Bool
    let isComplete: Bool
    let hasSpeech: Bool
    let onHome: () -> Void
    let onReplay: () -> Void
    let onNext: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.interfaceLocaleID) private var interfaceLocaleID
    // Android sizes the word and the Next label in sp, so both follow the text size.
    @ScaledMetric(relativeTo: .title) private var textScalePercent: CGFloat = 100

    /// Android bottomLetterText #252526.
    fileprivate static let wordColor = Color(red: 0.145, green: 0.145, blue: 0.149)

    var body: some View {
        GeometryReader { geometry in
            let metrics = LearnLayoutMetrics(
                width: geometry.size.width,
                textScale: textScalePercent / 100
            )
            let minimumHeight = minimumPageHeight(metrics)
            ScrollView {
                if usesAccessibleColumn(metrics, minimumHeight: minimumHeight, screenHeight: geometry.size.height) {
                    accessiblePage(metrics)
                        .frame(minHeight: geometry.size.height, alignment: .top)
                } else {
                    page(metrics, height: max(geometry.size.height, minimumHeight))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // A background, so the white never sizes the page.
        .background { Color.white.ignoresSafeArea() }
    }

    private var nextTitleKey: String.LocalizationValue {
        switch nextStartsOver {
        case true: return "Start over"
        case false: return "Next"
        }
    }

    private var wordLayoutDirection: LayoutDirection {
        card.word.direction?.layoutDirection ?? .leftToRight
    }

    // MARK: Pages

    /// Android keeps this composition at every text size, and so does the page.
    /// Only a phone whose screen is too short for it at an accessibility size gets
    /// the column, where the word no longer shares its narrow row with Play. An
    /// iPad always has room beside Play, so it scrolls the composition instead.
    private func usesAccessibleColumn(
        _ metrics: LearnLayoutMetrics,
        minimumHeight: CGFloat,
        screenHeight: CGFloat
    ) -> Bool {
        guard dynamicTypeSize.isAccessibilitySize, !metrics.isTablet else {
            return false
        }
        return minimumHeight > screenHeight
    }

    /// Home and the letters above the divider; the picture, word and Next below it.
    private func page(_ metrics: LearnLayoutMetrics, height: CGFloat) -> some View {
        let dividerY = height * metrics.dividerShare
        let lowerHeight = height - dividerY - metrics.dividerThickness
        // Android centres the letters between lettersTop and the divider; they
        // never rise into the Home button.
        let centredLettersY = (metrics.lettersTop + dividerY - metrics.capitalBox.height) / 2
        let lettersY = max(metrics.homeBottom + 4, centredLettersY)
        let imageSize = exampleImageSize(metrics, lowerHeight: lowerHeight)

        return VStack(spacing: 0) {
            ZStack(alignment: .top) {
                homeButton(metrics)
                    .padding(.top, metrics.homeTop)
                // Display only, so its padded layer never takes Home's taps.
                lettersRow(metrics)
                    .padding(.top, lettersY)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .frame(height: dividerY, alignment: .top)

            dividerLine(metrics)

            lowerRegion(metrics, imageSize: imageSize)
                .frame(maxWidth: .infinity)
                .frame(height: lowerHeight)
        }
        .frame(width: metrics.width, height: height)
    }

    /// Phone: the picture and word are centred between the divider and Next, as
    /// fragment_learn's bottomBox. iPad: they stand on Next, as layout-sw600dp.
    private func lowerRegion(_ metrics: LearnLayoutMetrics, imageSize: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            exampleImage(size: imageSize)
                .padding(.top, metrics.isTablet ? 0 : metrics.imageTop)
            wordRow(metrics)
                .padding(.top, metrics.imageToWord)
            if !metrics.isTablet {
                Spacer(minLength: 0)
            }
            nextButton(metrics)
                .padding(.top, metrics.wordToNext)
                .padding(.bottom, metrics.nextBottom)
        }
    }

    /// A phone at an accessibility size too large for the page: the same parts in
    /// one scrolling column, with Play under the word so the word keeps the full width.
    private func accessiblePage(_ metrics: LearnLayoutMetrics) -> some View {
        let imageScale: CGFloat = 0.85
        let imageSize = CGSize(
            width: metrics.imageBox.width * imageScale,
            height: metrics.imageBox.height * imageScale
        )
        return VStack(spacing: 24) {
            homeButton(metrics)
            lettersRow(metrics)
            dividerLine(metrics)
            exampleImage(size: imageSize)
            wordText(metrics)
                .padding(.horizontal, metrics.wordSidePadding)
                .environment(\.layoutDirection, wordLayoutDirection)
            if hasSpeech {
                LanguageReplayButton(
                    label: "Replay current card",
                    action: onReplay,
                    glyphSize: metrics.playGlyph
                )
            }
            nextButton(metrics, maxLines: 2)
        }
        .padding(.top, metrics.homeTop)
        .padding(.bottom, metrics.nextBottom)
        .frame(width: metrics.width)
    }

    // MARK: Parts

    private func homeButton(_ metrics: LearnLayoutMetrics) -> some View {
        Button(action: onHome) {
            MinikArtworkImage(name: MinikVisualAsset.home)
                .frame(width: metrics.homeSide, height: metrics.homeSide)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Home")
        .accessibilityHint("Returns to the activity menu")
    }

    /// Bottom-aligned boxes; each original form is fitted and centred in its box.
    private func lettersRow(_ metrics: LearnLayoutMetrics) -> some View {
        HStack(alignment: .bottom, spacing: metrics.letterGap) {
            MinikArtworkImage(name: card.capitalLetterAsset)
                .frame(width: metrics.capitalBox.width, height: metrics.capitalBox.height)
            MinikArtworkImage(name: card.smallLetterAsset)
                .frame(width: metrics.smallBox.width, height: metrics.smallBox.height)
        }
        // English: capital then lowercase. Hebrew: handwritten then print,
        // as LearnScreen.applyLettersDirection specifies, regardless of UI.
        .environment(\.layoutDirection, card.letter.language == .hebrew ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.letter.text)
    }

    /// minik_divider_line across the full width at its own 1180x4 proportion,
    /// as Android's fitCenter draws it. Android's layout-sw600dp has only an
    /// invisible 45% Guideline here; iPads keep the binding phone reference's
    /// line as an intentional adaptation.
    private func dividerLine(_ metrics: LearnLayoutMetrics) -> some View {
        Image("language_learn_divider")
            .resizable()
            .frame(height: metrics.dividerThickness)
            .accessibilityHidden(true)
    }

    private func exampleImage(size: CGSize) -> some View {
        Image(card.example.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .accessibilityLabel(card.word.text)
    }

    // One line: a long word shrinks instead of wrapping letter by letter. At the
    // largest accessibility size, Watermelon and Grandfather need about half size
    // beside Play on a 375-point phone; the lower floor keeps a margin there.
    private func wordText(_ metrics: LearnLayoutMetrics) -> some View {
        Text(card.word.text)
            .font(.system(size: metrics.wordSize, weight: .bold))
            .foregroundStyle(Self.wordColor)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
    }

    /// The word centred as on Android, with the owner-required Play after it in
    /// the word's reading direction; a clear twin on the other side keeps the
    /// word centred and the Android vertical rhythm unchanged.
    private func wordRow(_ metrics: LearnLayoutMetrics) -> some View {
        HStack(spacing: 8) {
            if hasSpeech {
                Color.clear
                    .frame(width: metrics.playFrame.width, height: 1)
                    .accessibilityHidden(true)
            }
            wordText(metrics)
            if hasSpeech {
                LanguageReplayButton(
                    label: "Replay current card",
                    action: onReplay,
                    glyphSize: metrics.playGlyph
                )
            }
        }
        .padding(.horizontal, metrics.wordSidePadding)
        .environment(\.layoutDirection, wordLayoutDirection)
    }

    private func nextButton(_ metrics: LearnLayoutMetrics, maxLines: Int = 1) -> some View {
        Button(action: onNext) {
            Text(interfaceLocaleID.text(nextTitleKey))
                .font(.system(size: metrics.nextSize, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(maxLines)
                .minimumScaleFactor(0.6)
                // With the 24-point side padding: Android's 88-point minimum width.
                .frame(minWidth: 40)
        }
        .buttonStyle(LearnNextButtonStyle())
        .disabled(isComplete)
    }

    // MARK: Height budget

    private func wordRowHeight(_ metrics: LearnLayoutMetrics) -> CGFloat {
        let wordLine = (metrics.wordSize * 1.25).rounded(.up)
        if hasSpeech {
            return max(wordLine, metrics.playFrame.height)
        }
        return wordLine
    }

    /// Height the lower region needs besides the picture at the current text size.
    private func lowerFixedHeight(_ metrics: LearnLayoutMetrics) -> CGFloat {
        let nextLine = (metrics.nextSize * 1.25).rounded(.up)
        let nextHeight = nextLine + LearnNextButtonStyle.verticalPadding * 2
        let pictureGaps = metrics.imageTop + metrics.imageToWord
        let controls = wordRowHeight(metrics) + metrics.wordToNext + nextHeight + metrics.nextBottom
        return pictureGaps + controls
    }

    /// The picture keeps Android's box and is the first part to shrink.
    private func exampleImageSize(_ metrics: LearnLayoutMetrics, lowerHeight: CGFloat) -> CGSize {
        let box = metrics.imageBox
        let available = lowerHeight - lowerFixedHeight(metrics)
        let fittedHeight = min(box.height, max(metrics.minimumImageHeight, available))
        return CGSize(width: box.width * fittedHeight / box.height, height: fittedHeight)
    }

    /// The page is never laid out shorter than this: below it the letters,
    /// picture and controls would overlap, so a shorter screen scrolls instead.
    private func minimumPageHeight(_ metrics: LearnLayoutMetrics) -> CGFloat {
        // Home, a gap, the letters and a gap above the divider.
        let topMinimum = metrics.homeBottom + 4 + metrics.capitalBox.height + 8
        // The divider, the smallest picture and the controls under it.
        let lowerMinimum = metrics.dividerThickness + metrics.minimumImageHeight + lowerFixedHeight(metrics)
        return max(topMinimum / metrics.dividerShare, lowerMinimum / (1 - metrics.dividerShare))
    }
}

/// Android fragment_learn sizes in points (1 dp = 1 pt) for the page width:
/// layout/ on phones; on iPads layout-sw600dp with values-sw700dp, or
/// values-sw800dp from 800 points.
private struct LearnLayoutMetrics {
    let width: CGFloat
    let isTablet: Bool
    let homeSide: CGFloat
    let homeTop: CGFloat
    let capitalBox: CGSize
    let smallBox: CGSize
    let letterGap: CGFloat
    /// The letters are centred between this offset and the divider.
    let lettersTop: CGFloat
    let dividerShare: CGFloat
    let dividerThickness: CGFloat
    let imageBox: CGSize
    let minimumImageHeight: CGFloat
    /// Phone: the picture's top margin. iPad: the least gap under the divider.
    let imageTop: CGFloat
    let imageToWord: CGFloat
    /// Word row to the Next pill: Android's margin plus the 4 dp button inset.
    let wordToNext: CGFloat
    /// Under the Next pill: Android's margin plus the 4 dp button inset.
    let nextBottom: CGFloat
    let wordSize: CGFloat
    let wordSidePadding: CGFloat
    let nextSize: CGFloat
    let playGlyph: CGFloat

    init(width: CGFloat, textScale: CGFloat) {
        let tablet = width >= 700
        let large = width >= 800
        self.width = width
        isTablet = tablet
        // fitCenter draws the 1180x4 divider artwork at the full width.
        dividerThickness = max(1, width * 4 / 1180)
        if tablet {
            homeSide = 110
            homeTop = 16
            capitalBox = large ? CGSize(width: 240, height: 245) : CGSize(width: 190, height: 195)
            smallBox = large ? CGSize(width: 185, height: 190) : CGSize(width: 130, height: 135)
            letterGap = 40
            // The bottom of the Home button (16 + 110).
            lettersTop = 126
            dividerShare = 0.45
            let side = width * (large ? 0.45 : 0.4)
            imageBox = CGSize(width: side, height: side)
            minimumImageHeight = 200
            imageTop = 24
            imageToWord = 20
            wordToNext = 46
            nextBottom = large ? 54 : 49
            wordSize = 60 * textScale
            nextSize = 40 * textScale
            // The phone's 30-point Play beside a 32-point word, scaled to 60.
            playGlyph = 56
        } else {
            homeSide = 64
            homeTop = 15
            capitalBox = CGSize(width: 140, height: 140)
            smallBox = CGSize(width: 100, height: 100)
            letterGap = 20
            lettersTop = 65
            dividerShare = 0.42
            imageBox = CGSize(width: 215, height: 210)
            minimumImageHeight = 120
            imageTop = 35
            imageToWord = 15
            wordToNext = 29
            nextBottom = 34
            wordSize = 32 * textScale
            nextSize = 26 * textScale
            playGlyph = 30
        }
        wordSidePadding = 24
    }

    var homeBottom: CGFloat { homeTop + homeSide }

    var playFrame: CGSize { LanguageReplayButton.hitArea(glyphSize: playGlyph) }
}

/// Android's Material 3 Next button (next_word_bg_tint, next_word_text_tint): a
/// #FDE000 pill with a #F9F9FA bold label, 24 dp side and 6 dp vertical padding
/// and no elevation; disabled at 30% and 50% alpha.
private struct LearnNextButtonStyle: ButtonStyle {
    static let verticalPadding: CGFloat = 8
    private static let pillColor = Color(red: 0.992, green: 0.878, blue: 0.0)
    private static let labelColor = Color(red: 0.976, green: 0.976, blue: 0.980)

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.5))
            .padding(.horizontal, 24)
            .padding(.vertical, Self.verticalPadding)
            .background(
                Capsule()
                    .fill(Self.pillColor.opacity(isEnabled ? 1 : 0.3))
            )
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }

    /// Increase Contrast swaps Android's white label for the dark word colour.
    private var foreground: Color {
        colorSchemeContrast == .increased ? LanguageLearnPage.wordColor : Self.labelColor
    }
}

struct LanguageReplayButton: View {
    var label: LocalizedStringKey = "Replay current word"
    let action: () -> Void
    /// The play glyph's point size; the hit area grows with it.
    var glyphSize: CGFloat = 30

    /// 56x48 points at the default glyph.
    static func hitArea(glyphSize: CGFloat) -> CGSize {
        CGSize(width: glyphSize + 26, height: glyphSize + 18)
    }

    var body: some View {
        let area = Self.hitArea(glyphSize: glyphSize)
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: glyphSize, weight: .semibold))
                .foregroundStyle(LanguagePalette.border)
                .frame(width: area.width, height: area.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
