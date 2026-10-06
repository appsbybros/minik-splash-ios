import SwiftUI
import UIKit

/// Android IntroScreen / fragment_intro_plus and the fixed-header activity menu.
/// These are Language routes; Math keeps its existing hub.
struct LanguageIntroView: View {
    let rewards: RewardState
    let variant: ProductVariant
    let onPractice: () -> Void
    let onParentArea: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection

    init(
        rewards: RewardState,
        variant: ProductVariant = .minikPlus,
        onPractice: @escaping () -> Void,
        onParentArea: @escaping () -> Void
    ) {
        self.rewards = rewards
        self.variant = variant
        self.onPractice = onPractice
        self.onParentArea = onParentArea
    }

    var body: some View {
        GeometryReader { geometry in
            let height = max(560, geometry.size.height - 32)
            let wide = geometry.size.width >= 700
            let width = max(1, min(760, geometry.size.width - (wide ? 104 : 48)))
            ScrollView {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        logo(wide: wide, screenHeight: geometry.size.height)
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            LanguageStatistic(title: "Points", value: rewards.points)
                            LanguageStatistic(title: "Best streak", value: Int64(rewards.bestStreak))
                        }
                        .frame(maxWidth: 280)
                    }
                    Text("Welcome to Minik!")
                        .font(.title2.bold())
                        .foregroundStyle(LanguagePalette.title)
                        .multilineTextAlignment(.center)
                    MinikArtworkImage(name: MinikVisualAsset.welcome)
                        .scaleEffect(x: layoutDirection == .rightToLeft ? 1 : -1, y: 1)
                        .frame(height: min(wide ? 250 : 180, max(90, height - 430)))
                        .padding(.horizontal, -20)
                    Spacer(minLength: 8)
                    Button(action: onParentArea) {
                        Text("Parent Area").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LanguageOutlineActionStyle())
                    Button(action: onPractice) {
                        Text("Practice").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LanguageOutlineActionStyle())
                }
                .padding(20)
                .frame(width: width)
                .frame(minHeight: height)
                .background(.white, in: RoundedRectangle(cornerRadius: wide ? 24 : 16))
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            // The panel fits the screen at ordinary sizes; when larger text or a
            // short screen makes it taller, it scrolls instead of cutting off.
            .scrollBounceBehavior(.basedOnSize)
        }
        // A background never sizes the layout (see LanguageActivityScreen).
        .background {
            MinikArtworkBackground()
                .ignoresSafeArea()
        }
    }

    /// IntroScreen: English Only shows minik_plus_english_only in Android's
    /// English box with a -8 dp start margin in place of the Plus logo's 13 dp
    /// (26 dp on tablets), so its "MINIK" starts about where "MINIKplus" does.
    @ViewBuilder
    private func logo(wide: Bool, screenHeight: CGFloat) -> some View {
        if LanguageEnglishOnlyLogoAsset.isShown(for: variant) {
            let box = LanguageEnglishOnlyLogoAsset.box(screenHeight: screenHeight, tablet: wide)
            let plusStart: CGFloat = wide ? 26 : 13
            LanguageEnglishOnlyLogo()
                .frame(width: box.width, height: box.height)
                .padding(.leading, LanguageEnglishOnlyLogoAsset.startMargin - plusStart)
        } else {
            MinikLanguageLogo()
                .frame(width: wide ? 88 : 70, height: wide ? 95 : 76)
        }
    }
}

/// Android's Plus activity menu (fragment_select_screen_plus.xml and
/// ButtonsMenuFragment): a white card inset on the Minik background, the logo
/// at its start with Home and Trophy centred beside it, and below them a
/// scrolling board of Letters, Words and Games: pairs of shallow framed artwork
/// tiles with two-line captions, Flash Cards alone and centred under the Words.
/// The Trophy opens the Top 20 as a dialog over the menu, as Android does.
struct LanguageMenuView: View {
    let configuration: ProductConfiguration
    let learnedLanguage: LanguageIdentifier
    let onSelect: (LanguageActivityKind) -> Void
    let onHome: () -> Void
    @Environment(\.interfaceLocaleID) private var interfaceLocaleID
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Android's sp text follows the font-size setting; these follow Dynamic Type.
    @ScaledMetric(relativeTo: .headline) private var sectionTitlePercent: CGFloat = 100
    @ScaledMetric(relativeTo: .title2) private var wideSectionTitlePercent: CGFloat = 100
    @ScaledMetric(relativeTo: .footnote) private var captionPercent: CGFloat = 100
    @ScaledMetric(relativeTo: .title3) private var wideCaptionPercent: CGFloat = 100
    @ScaledMetric(relativeTo: .callout) private var hintPercent: CGFloat = 100
    @ScaledMetric(relativeTo: .title2) private var wideHintPercent: CGFloat = 100
    @StateObject private var speechPlayer = InterfaceSpeechPlayer()
    @State private var scrollTracker = LanguageMenuScrollTracker()
    @State private var didRegisterPresentation = false
    @State private var scrollHintEligible = false
    @State private var contentContinuesBelow = false
    @State private var scrollHintOffset: CGFloat = 0
    @State private var skipsNextHintDip = false
    @State private var recordsArePresented = false

    init(
        configuration: ProductConfiguration,
        learnedLanguage: LanguageIdentifier,
        onSelect: @escaping (LanguageActivityKind) -> Void,
        onHome: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.learnedLanguage = learnedLanguage
        self.onSelect = onSelect
        self.onHome = onHome
    }

    var body: some View {
        GeometryReader { geometry in
            let metrics = LanguageMenuMetrics(
                size: geometry.size,
                englishOnlyLogo: LanguageEnglishOnlyLogoAsset.isShown(for: configuration.variant)
            )
            let cardWidth = max(1, min(metrics.cardMaxWidth, geometry.size.width - 2 * metrics.cardSideMargin))
            let contentWidth = max(1, cardWidth - 2 * metrics.contentSidePadding)
            // Accessibility text on a phone gets one column, so captions wrap
            // between words rather than letter by letter.
            let sections = menuSections(singleColumn: dynamicTypeSize.isAccessibilitySize && !metrics.tablet)
            ScrollViewReader { proxy in
                card(metrics: metrics, contentWidth: contentWidth, sections: sections, proxy: proxy)
                    .frame(width: cardWidth)
                    .frame(maxHeight: .infinity)
                    .background(.white, in: RoundedRectangle(cornerRadius: metrics.cardCornerRadius))
                    .clipShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius))
                    .padding(.top, metrics.cardTopMargin)
                    .padding(.bottom, metrics.cardBottomMargin)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear {
                        registerPresentation(using: proxy)
                    }
                    .onChange(of: contentContinuesBelow) { _, continues in
                        applyStoreScreenshotScroll(continues: continues, using: proxy)
                    }
            }
        }
        // A background never sizes the layout (see LanguageActivityScreen).
        .background {
            MinikArtworkBackground()
                .ignoresSafeArea()
        }
        .overlay {
            if recordsArePresented {
                LanguageRecordsDialog(product: configuration.variant) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        recordsArePresented = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onDisappear {
            speechPlayer.stop()
            rememberPlace()
        }
        .task(id: showsScrollHint) {
            guard showsScrollHint else { return }
            // Back from a dialog the hint is still the one that was showing; on
            // Android it dips only when it appears.
            if skipsNextHintDip {
                skipsNextHintDip = false
                return
            }
            guard !reduceMotion else { return }
            // startScrollHintAnimation: three dips of 7 dp, 650 ms each.
            do {
                for _ in 0..<3 {
                    withAnimation(.easeInOut(duration: 0.325)) { scrollHintOffset = 7 }
                    try await Task.sleep(nanoseconds: 325_000_000)
                    withAnimation(.easeInOut(duration: 0.325)) { scrollHintOffset = 0 }
                    try await Task.sleep(nanoseconds: 325_000_000)
                }
            } catch {
                scrollHintOffset = 0
            }
        }
    }

    private var showsScrollHint: Bool {
        scrollHintEligible && contentContinuesBelow
    }

    private func card(
        metrics: LanguageMenuMetrics,
        contentWidth: CGFloat,
        sections: [LanguageMenuSection],
        proxy: ScrollViewProxy
    ) -> some View {
        VStack(spacing: 0) {
            header(metrics)
            // The board scrolls below the logo row, which stays in place.
            ScrollView {
                menuContent(metrics: metrics, contentWidth: contentWidth, sections: sections)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .background {
                LanguageMenuPositionProbe { rect in
                    scrollTracker.viewport = rect
                    returnToPlace(using: proxy)
                    refreshScrollContinuation()
                }
            }
            // Like Android's scrollDownHint, the hint takes its own space at the
            // bottom of the card rather than covering the board.
            if showsScrollHint {
                scrollHint(metrics) {
                    scrollFurther(sections: sections, using: proxy)
                }
                .padding(.horizontal, metrics.hintSideMargin)
                .padding(.bottom, metrics.hintBottomMargin)
            }
        }
    }

    /// The logo 12 dp from the top at the start; Home and Trophy centred across
    /// the card and centred on the logo's lower part (their 20 dp top margin), so
    /// they reach a little below it, where the board passes over them.
    private func header(_ metrics: LanguageMenuMetrics) -> some View {
        ZStack(alignment: .top) {
            headerLogo(metrics)
                .frame(width: metrics.logoWidth, height: metrics.logoHeight)
                .padding(.leading, metrics.logoStart)
                .padding(.top, metrics.logoTop)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .top, spacing: 0) {
                Button {
                    // Home goes to the Intro, whose Practice opens a new menu.
                    scrollTracker.leavesForNewMenu = true
                    onHome()
                } label: {
                    MinikArtworkImage(name: MinikVisualAsset.home)
                        .padding(metrics.iconPadding)
                        .frame(width: metrics.homeSize, height: metrics.homeSize)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(interfaceLocaleID.text("Home")))
                .padding(.top, metrics.homeTop)
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        recordsArePresented = true
                    }
                } label: {
                    MinikArtworkImage(name: MinikVisualAsset.trophy)
                        .padding(metrics.iconPadding)
                        .frame(width: metrics.trophyWidth, height: metrics.trophyHeight)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(interfaceLocaleID.text("Top 20 records")))
                .padding(.leading, metrics.homeEnd)
                .padding(.top, metrics.trophyTop)
            }
            .buttonStyle(.plain)
            .padding(.top, metrics.headerGroupTop)
            .frame(maxWidth: .infinity)
        }
        .frame(height: metrics.headerHeight, alignment: .top)
    }

    /// ButtonsMenuFragment: English Only swaps minik_plus_logo for
    /// minik_plus_english_only, fitted in its own box (see LanguageMenuMetrics).
    @ViewBuilder
    private func headerLogo(_ metrics: LanguageMenuMetrics) -> some View {
        if metrics.showsEnglishOnlyLogo {
            LanguageEnglishOnlyLogo()
        } else {
            MinikLanguageLogo()
        }
    }

    private func menuContent(
        metrics: LanguageMenuMetrics,
        contentWidth: CGFloat,
        sections: [LanguageMenuSection]
    ) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(sections) { section in
                    sectionView(section, metrics: metrics, contentWidth: contentWidth)
                        .padding(.top, section.isFirst ? 0 : metrics.sectionGap)
                }
            }
            .padding(.horizontal, metrics.contentSidePadding)
            .padding(.top, metrics.contentTopPadding)
            .padding(.bottom, metrics.contentBottomPadding)
            // The end of the board: once it is in view, Android's
            // canScrollVertically(1) is false and the hint goes away.
            Color.clear
                .frame(height: 1)
                .id(LanguageMenuScrollID.end)
                .background {
                    LanguageMenuPositionProbe { rect in
                        scrollTracker.endMinY = rect.minY
                        refreshScrollContinuation()
                    }
                }
        }
    }

    private func sectionView(
        _ section: LanguageMenuSection,
        metrics: LanguageMenuMetrics,
        contentWidth: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            Text(section.title)
                .font(.system(size: sectionTitleFontSize(metrics), weight: .bold))
                .foregroundStyle(LanguagePalette.menuText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 4)
                .padding(.bottom, metrics.sectionTitleBottom)
                .accessibilityAddTraits(.isHeader)
                .id(section.titleScrollID)
                .background { scrollTargetProbe(section.titleScrollID) }
            ForEach(section.rows) { row in
                rowView(row, metrics: metrics, contentWidth: contentWidth)
                    .padding(.top, row.isFirst ? 0 : metrics.rowGap)
                    .id(row.id)
                    .background { scrollTargetProbe(row.id) }
            }
        }
    }

    private func scrollTargetProbe(_ id: String) -> some View {
        LanguageMenuPositionProbe { rect in
            scrollTracker.targetMinY[id] = rect.minY
            scrollTracker.targetHeight[id] = rect.height
        }
    }

    @ViewBuilder
    private func rowView(
        _ row: LanguageMenuRow,
        metrics: LanguageMenuMetrics,
        contentWidth: CGFloat
    ) -> some View {
        if row.activities.count > 1 {
            // Two weighted cells 20 dp apart; the row's gravity centres a shorter
            // cell vertically.
            HStack(alignment: .center, spacing: metrics.columnGap) {
                ForEach(row.activities) { activity in
                    tile(activity, metrics: metrics, frameWidth: nil)
                        .frame(maxWidth: .infinity)
                }
            }
        } else if let activity = row.activities.first {
            if row.fullWidth {
                tile(activity, metrics: metrics, frameWidth: columnWidth(metrics, contentWidth: contentWidth))
            } else {
                tile(activity, metrics: metrics, frameWidth: nil)
                    .frame(width: singleTileWidth(activity, metrics: metrics, contentWidth: contentWidth))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// One menu button: the framed artwork and its caption below, the whole cell
    /// tappable as Android's transparent MaterialButton covering both.
    private func tile(_ activity: LanguageActivityKind, metrics: LanguageMenuMetrics, frameWidth: CGFloat?) -> some View {
        let title = menuCaption(for: activity)
        return Button {
            scrollTracker.leavesForNewMenu = !Self.opensOverMenu(activity)
            onSelect(activity)
        } label: {
            VStack(spacing: 0) {
                tileFrame(activity, metrics: metrics)
                    .frame(width: frameWidth)
                Text(title)
                    .font(.system(size: captionFontSize(metrics), weight: .bold))
                    .lineSpacing(1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LanguagePalette.menuText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, metrics.captionTop)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title.replacingOccurrences(of: "\n", with: " ")))
    }

    /// bg_minik_gradient_rounded (12 dp corners) behind a white card with 10 dp
    /// corners: the frame shows 5 dp at the start and bottom and 2 dp at the top
    /// and end (7 and 3 dp on tablets). The gradient is not mirrored: purple on the
    /// physical left, teal on the right, in Hebrew as well.
    private func tileFrame(_ activity: LanguageActivityKind, metrics: LanguageMenuMetrics) -> some View {
        let innerShape = RoundedRectangle(cornerRadius: metrics.innerCornerRadius)
        return innerShape
            .fill(.white)
            .overlay { tileArtwork(activity, metrics: metrics) }
            .clipShape(innerShape)
            .padding(metrics.frameInsets)
            .frame(height: metrics.tileHeight)
            .background {
                RoundedRectangle(cornerRadius: metrics.outerCornerRadius)
                    .fill(LanguagePalette.border)
                    .environment(\.layoutDirection, .leftToRight)
            }
    }

    @ViewBuilder
    private func tileArtwork(_ activity: LanguageActivityKind, metrics: LanguageMenuMetrics) -> some View {
        if let name = menuArtworkName(for: activity) {
            artworkImage(name, box: artworkBox(for: activity, metrics: metrics))
        }
    }

    private func artworkImage(_ name: String, box: LanguageMenuArtworkBox) -> some View {
        MinikArtworkImage(name: name)
            .frame(width: box.width, height: box.height)
    }

    /// ButtonsMenuFragment shows minik_plus_letters_drag_logo_heb on Answers with
    /// Words whichever language is learned.
    private func menuArtworkName(for activity: LanguageActivityKind) -> String? {
        if activity == .imageToWord {
            return MinikVisualAsset.activityArtwork(for: .wordBuild, language: .hebrew)
        }
        return MinikVisualAsset.activityArtwork(for: activity, language: learnedLanguage)
    }

    /// The artwork's view in the layouts: most are sized by height alone (the width
    /// follows the image), the rest fit a square; images taller than the card are
    /// cropped by it, as on Android. The First Letter and Flash Cards sizes are set
    /// by ButtonsMenuFragment for the learned language on phones and tablets alike.
    private func artworkBox(for activity: LanguageActivityKind, metrics: LanguageMenuMetrics) -> LanguageMenuArtworkBox {
        let hebrew = learnedLanguage == .hebrew
        let scale = metrics.tablet ? metrics.scale : 1
        switch activity {
        case .firstLetterChoices, .firstLetterPictures:
            let side: CGFloat = (hebrew ? 110 : 80) * scale
            return LanguageMenuArtworkBox(width: side, height: side)
        case .wordCards:
            let side: CGFloat = (hebrew ? 125 : 75) * scale
            return LanguageMenuArtworkBox(width: side, height: side)
        default:
            break
        }
        if metrics.tablet {
            let side: CGFloat = (activity == .learn ? 112 : 84) * scale
            return LanguageMenuArtworkBox(width: side, height: side)
        }
        switch activity {
        case .letterPairs:
            return LanguageMenuArtworkBox(width: nil, height: 72)
        case .tower:
            return LanguageMenuArtworkBox(width: 80, height: 80)
        case .wordMemory:
            return LanguageMenuArtworkBox(width: 74, height: 74)
        case .ticTacToe:
            return LanguageMenuArtworkBox(width: 54, height: 54)
        default:
            return LanguageMenuArtworkBox(width: nil, height: 74)
        }
    }

    private func menuCaption(for activity: LanguageActivityKind) -> String {
        LanguageMenuAndroidText.caption(activity, locale: interfaceLocaleID)
            ?? interfaceLocaleID.text(activity.titleKey)
    }

    private func columnWidth(_ metrics: LanguageMenuMetrics, contentWidth: CGFloat) -> CGFloat {
        max(1, (contentWidth - metrics.columnGap) / 2)
    }

    /// Flash Cards spans 46% of the board (48% on tablets); any other lone tile
    /// keeps a column's width.
    private func singleTileWidth(
        _ activity: LanguageActivityKind,
        metrics: LanguageMenuMetrics,
        contentWidth: CGFloat
    ) -> CGFloat {
        if activity == .wordCards {
            return max(1, contentWidth * metrics.singleTileFraction)
        }
        return columnWidth(metrics, contentWidth: contentWidth)
    }

    private func sectionTitleFontSize(_ metrics: LanguageMenuMetrics) -> CGFloat {
        metrics.sectionTitlePoints * (metrics.tablet ? wideSectionTitlePercent : sectionTitlePercent) / 100
    }

    private func captionFontSize(_ metrics: LanguageMenuMetrics) -> CGFloat {
        metrics.captionPoints * (metrics.tablet ? wideCaptionPercent : captionPercent) / 100
    }

    private func hintFontSize(_ metrics: LanguageMenuMetrics) -> CGFloat {
        metrics.hintTextPoints * (metrics.tablet ? wideHintPercent : hintPercent) / 100
    }

    /// Android's scrollDownHint: a pale yellow pill with bold text and a down
    /// chevron after it, shown the first three times the menu opens while more of
    /// the board lies below.
    private func scrollHint(_ metrics: LanguageMenuMetrics, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: metrics.hintIconGap) {
                Text(LanguageMenuAndroidText.scrollHint(interfaceLocaleID))
                    .font(.system(size: hintFontSize(metrics), weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                LanguageMenuChevron()
                    .fill(LanguagePalette.menuText)
                    .frame(width: metrics.hintIconSize, height: metrics.hintIconSize)
            }
            .foregroundStyle(LanguagePalette.menuText)
            .padding(.horizontal, metrics.hintHorizontalPadding)
            .frame(minHeight: metrics.hintHeight)
            .background(LanguagePalette.scrollHintFill, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .offset(y: scrollHintOffset)
        .accessibilityLabel(Text(LanguageMenuAndroidText.scrollHintAccessibility(interfaceLocaleID)))
    }

    /// Android scrolls 72% of the board's height per tap. Here the furthest row
    /// that starts within that distance moves to the top, so nothing is skipped.
    private func scrollFurther(sections: [LanguageMenuSection], using proxy: ScrollViewProxy) {
        let viewport = scrollTracker.viewport
        let distance = viewport.height * 0.72
        var target: String?
        var anchor = UnitPoint.top
        for id in sections.flatMap(\.scrollTargetIDs) {
            guard let minY = scrollTracker.targetMinY[id] else { continue }
            let distanceFromTop = minY - viewport.minY
            if distanceFromTop <= 1 { continue }
            if distanceFromTop <= distance {
                target = id
                continue
            }
            if target == nil {
                target = id
                anchor = distanceFromTop <= viewport.height ? .top : .bottom
            }
            break
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
            if let target {
                proxy.scrollTo(target, anchor: anchor)
            } else {
                proxy.scrollTo(LanguageMenuScrollID.end, anchor: .bottom)
            }
        }
    }

    private func refreshScrollContinuation() {
        let viewport = scrollTracker.viewport
        guard viewport.height > 0 else { return }
        let continues = scrollTracker.endMinY > viewport.maxY + 1
        if continues != contentContinuesBelow {
            contentContinuesBelow = continues
        }
    }

    /// The parity capture scene "menu.games" opens the menu scrolled to its end,
    /// as Android's second menu reference shows it.
    private func applyStoreScreenshotScroll(continues: Bool, using proxy: ScrollViewProxy) {
        guard continues,
              !scrollTracker.didApplyStoreScreenshotScroll,
              StoreScreenshotScene.name == "menu.games" else { return }
        scrollTracker.didApplyStoreScreenshotScroll = true
        proxy.scrollTo(LanguageMenuScrollID.end, anchor: .bottom)
    }

    private func registerPresentation(using proxy: ScrollViewProxy) {
        guard !didRegisterPresentation else { return }
        didRegisterPresentation = true
        // App Store and parity captures show the menu as Android's references do.
        guard StoreScreenshotScene.name == nil else { return }
        if let place = LanguageMenuSession.returnPlace {
            // Back from an activity Android shows as a dialog over the menu: the
            // board is where it was, and the hint keeps its state rather than
            // counting another showing (setupScrollDownHint does not run again).
            LanguageMenuSession.returnPlace = nil
            scrollHintEligible = place.hintEligible
            skipsNextHintDip = place.hintShowing
            scrollTracker.pendingPlace = place
            returnToPlace(using: proxy)
            return
        }
        scrollHintEligible = LanguageMenuScrollHintRepository().registerPresentationIfNeeded()
        // ButtonsMenuFragment says select_screen_voice the first time the menu
        // appears while the app runs.
        if !LanguageMenuSession.hasSpokenPrompt {
            LanguageMenuSession.hasSpokenPrompt = true
            let prompt = LanguageMenuAndroidText.selectScreenVoice(interfaceLocaleID)
            speechPlayer.speak(interfaceLocaleID.spokenText(for: prompt), interfaceLocale: interfaceLocaleID)
        }
    }

    /// Android opens Pairs, Flash Cards and the four games as dialogs over the
    /// menu (ButtonsMenuFragment), so closing one shows the menu as it was. Here
    /// they replace the menu, so where it was is kept for the menu that comes
    /// back. Home, Learn and the WriteScreen activities come back to a new menu
    /// at the top, as Android's do.
    private func rememberPlace() {
        if scrollTracker.leavesForNewMenu {
            LanguageMenuSession.returnPlace = nil
        } else {
            // A place not yet restored is still the one to return to.
            LanguageMenuSession.returnPlace = scrollTracker.pendingPlace ?? currentPlace()
        }
    }

    /// The first target wholly in view and its distance below the board's top.
    private func currentPlace() -> LanguageMenuPlace {
        let viewport = scrollTracker.viewport
        var firstID: String?
        var firstMinY = CGFloat.greatestFiniteMagnitude
        for (id, minY) in scrollTracker.targetMinY where minY >= viewport.minY - 0.5 && minY < firstMinY {
            firstID = id
            firstMinY = minY
        }
        var offset: CGFloat = 0
        var firstHeight: CGFloat = 0
        if let firstID {
            offset = firstMinY - viewport.minY
            firstHeight = scrollTracker.targetHeight[firstID] ?? 0
        }
        return LanguageMenuPlace(
            targetID: viewport.height > 0 ? firstID : nil,
            offset: offset,
            targetHeight: firstHeight,
            hintEligible: scrollHintEligible,
            hintShowing: showsScrollHint
        )
    }

    /// Scrolls the remembered target back to the same distance below the
    /// board's top, once the board has been measured.
    private func returnToPlace(using proxy: ScrollViewProxy) {
        guard let place = scrollTracker.pendingPlace, scrollTracker.viewport.height > 0 else { return }
        scrollTracker.pendingPlace = nil
        guard let targetID = place.targetID else { return }
        let travel = scrollTracker.viewport.height - place.targetHeight
        let fraction: CGFloat = travel > 1 ? min(1, max(0, place.offset / travel)) : 0
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(targetID, anchor: UnitPoint(x: 0.5, y: fraction))
        }
    }

    /// ButtonsMenuFragment shows these as DialogFragments over the menu; the
    /// others replace it with LearnScreen or WriteScreen.
    private static func opensOverMenu(_ activity: LanguageActivityKind) -> Bool {
        switch activity {
        case .letterPairs, .wordCards, .soccer, .tower, .wordMemory, .ticTacToe:
            return true
        case .learn, .firstLetterChoices, .firstLetterPictures, .imageToWord, .wordToImage,
             .wordBuild, .mixed, .multipleChoice, .build, .pairs, .memory:
            return false
        }
    }

    private func menuSections(singleColumn: Bool) -> [LanguageMenuSection] {
        var sections: [LanguageMenuSection] = []
        for section in ActivityCatalog.languageSections(for: configuration) {
            sections.append(menuSection(section, isFirst: sections.isEmpty, singleColumn: singleColumn))
        }
        return sections
    }

    /// Android's rows: start-to-end pairs in the Plus layout's order, Flash Cards
    /// alone after the Words pairs.
    private func menuSection(
        _ section: ActivitySection<LanguageActivityKind>,
        isFirst: Bool,
        singleColumn: Bool
    ) -> LanguageMenuSection {
        let ordered = section.activities.sorted { Self.androidMenuOrder($0) < Self.androidMenuOrder($1) }
        let paired = ordered.filter { $0 != .wordCards }
        let perRow = singleColumn ? 1 : 2
        var rows: [LanguageMenuRow] = []
        var start = 0
        while start < paired.count {
            let end = min(start + perRow, paired.count)
            rows.append(LanguageMenuRow(
                id: section.id + "-" + String(rows.count),
                activities: Array(paired[start..<end]),
                isFirst: rows.isEmpty,
                fullWidth: singleColumn
            ))
            start = end
        }
        if ordered.contains(.wordCards) {
            rows.append(LanguageMenuRow(
                id: section.id + "-" + String(rows.count),
                activities: [.wordCards],
                isFirst: rows.isEmpty,
                fullWidth: singleColumn
            ))
        }
        return LanguageMenuSection(
            id: section.id,
            title: interfaceLocaleID.text(sectionTitleKey(section.id)),
            isFirst: isFirst,
            rows: rows
        )
    }

    private func sectionTitleKey(_ id: String) -> String.LocalizationValue {
        switch id {
        case "letters": return "Letters"
        case "words": return "Words"
        default: return "Games"
        }
    }

    /// fragment_select_screen_plus.xml from start to end, row by row.
    private static func androidMenuOrder(_ activity: LanguageActivityKind) -> Int {
        switch activity {
        case .learn: return 0
        case .letterPairs: return 1
        case .firstLetterChoices: return 2
        case .firstLetterPictures: return 3
        case .imageToWord: return 4
        case .wordToImage: return 5
        case .wordBuild: return 6
        case .mixed: return 7
        case .wordCards: return 8
        case .soccer: return 9
        case .tower: return 10
        case .wordMemory: return 11
        case .ticTacToe: return 12
        case .multipleChoice, .build, .pairs, .memory: return 13
        }
    }
}

/// fragment_select_screen_plus.xml in points: the phone layout, and the
/// layout-sw600dp values on iPad. The iPad mini (744 points wide) uses the
/// tablet values as they are; larger iPads scale them up so the board keeps
/// its proportions instead of stretching.
private struct LanguageMenuMetrics {
    let tablet: Bool
    let scale: CGFloat
    /// English Only's logo box (see LanguageEnglishOnlyLogoAsset), or nil for
    /// the Plus wordmark.
    private let englishOnlyLogoBox: CGSize?

    /// `size` is the safe area: Android picks the English Only logo box by the
    /// screen height left between the system bars.
    init(size: CGSize, englishOnlyLogo: Bool) {
        let isTablet = size.width >= 700
        let tabletScale: CGFloat = isTablet ? min(1.4, max(1, size.width / 744)) : 1
        tablet = isTablet
        scale = tabletScale
        if englishOnlyLogo {
            let box = LanguageEnglishOnlyLogoAsset.box(screenHeight: size.height, tablet: isTablet)
            englishOnlyLogoBox = CGSize(width: box.width * tabletScale, height: box.height * tabletScale)
        } else {
            englishOnlyLogoBox = nil
        }
    }

    private func value(_ phone: CGFloat, _ tabletValue: CGFloat) -> CGFloat {
        tablet ? tabletValue * scale : phone
    }

    // The white card. Android's links row (the games website and Rate us)
    // below the card awaits the owner's decision for iOS; until then the
    // card's bottom margin matches the top one.
    var cardSideMargin: CGFloat { value(28, 40) }
    var cardTopMargin: CGFloat { value(18, 38) }
    var cardBottomMargin: CGFloat { value(18, 38) }
    var cardMaxWidth: CGFloat { value(1000, 1000) }
    var cardCornerRadius: CGFloat { value(16, 24) }

    // The logo row.
    var showsEnglishOnlyLogo: Bool { englishOnlyLogoBox != nil }
    var logoTop: CGFloat { 12 * (tablet ? scale : 1) }
    /// English Only's box starts at -8 dp (its image is centred in the box,
    /// whose transparent start the card clips).
    var logoStart: CGFloat {
        if englishOnlyLogoBox != nil {
            return LanguageEnglishOnlyLogoAsset.startMargin * (tablet ? scale : 1)
        }
        return value(11, 12)
    }
    var logoHeight: CGFloat { englishOnlyLogoBox?.height ?? value(70, 95) }
    /// minik_plus_logo is 121 x 131 pixels and sized by its height.
    var logoWidth: CGFloat { englishOnlyLogoBox?.width ?? logoHeight * 121 / 131 }
    /// Home and Trophy are constrained to the logo's top and bottom and the
    /// board starts at its bottom, so both follow the logo's box.
    var headerHeight: CGFloat { logoTop + logoHeight }
    var homeSize: CGFloat { value(64, 86) }
    var homeTop: CGFloat { value(0, 10) }
    var homeEnd: CGFloat { value(10, 25) }
    var trophyWidth: CGFloat { value(58, 86) }
    var trophyHeight: CGFloat { value(54, 76) }
    var trophyTop: CGFloat { value(5, 11) }
    var iconPadding: CGFloat { 2 * (tablet ? scale : 1) }
    /// Home and Trophy are constrained to the logo's top and bottom with a top
    /// margin (20 dp, 15 dp on tablets), so they centre on the space below it.
    var headerGroupTop: CGFloat {
        let groupMargin = value(20, 15)
        let groupHeight = max(homeTop + homeSize, trophyTop + trophyHeight)
        return logoTop + groupMargin + (logoHeight - groupMargin - groupHeight) / 2
    }

    // The scrolling board.
    var contentSidePadding: CGFloat { value(20, 40) }
    var contentTopPadding: CGFloat { value(20, 30) }
    var contentBottomPadding: CGFloat { value(28, 40) }
    var sectionTitlePoints: CGFloat { value(17, 24) }
    var sectionTitleBottom: CGFloat { value(6, 12) }
    var sectionGap: CGFloat { value(24, 38) }
    var rowGap: CGFloat { value(16, 28) }
    var columnGap: CGFloat { value(20, 36) }
    var singleTileFraction: CGFloat { tablet ? 0.48 : 0.46 }

    // A tile.
    var tileHeight: CGFloat { value(78, 116) }
    var frameInsets: EdgeInsets {
        EdgeInsets(top: value(2, 3), leading: value(5, 7), bottom: value(5, 7), trailing: value(2, 3))
    }
    var outerCornerRadius: CGFloat { 12 * (tablet ? scale : 1) }
    var innerCornerRadius: CGFloat { value(10, 16) }
    var captionTop: CGFloat { value(5, 8) }
    var captionPoints: CGFloat { value(13, 20) }

    // The "more below" hint.
    var hintHeight: CGFloat { value(52, 64) }
    var hintSideMargin: CGFloat { value(16, 24) }
    var hintBottomMargin: CGFloat { value(10, 16) }
    var hintHorizontalPadding: CGFloat { value(18, 24) }
    var hintTextPoints: CGFloat { value(16, 22) }
    var hintIconSize: CGFloat { value(28, 34) }
    var hintIconGap: CGFloat { value(8, 10) }
}

private struct LanguageMenuRow: Identifiable {
    let id: String
    let activities: [LanguageActivityKind]
    let isFirst: Bool
    /// Accessibility text on a phone: one tile per row across the board.
    let fullWidth: Bool
}

private struct LanguageMenuSection: Identifiable {
    let id: String
    let title: String
    let isFirst: Bool
    let rows: [LanguageMenuRow]

    var titleScrollID: String { "title-" + id }
    var scrollTargetIDs: [String] { [titleScrollID] + rows.map(\.id) }
}

private struct LanguageMenuArtworkBox {
    /// Nil when Android sizes the image by its height alone.
    let width: CGFloat?
    let height: CGFloat
}

private enum LanguageMenuScrollID {
    static let end = "language-menu-end"
}

private enum LanguageMenuSession {
    /// DeviceStatusManager.alreadySpokeSelectScreen: once while the app runs.
    static var hasSpokenPrompt = false
    /// Where the menu was when an activity Android shows over it replaced it.
    static var returnPlace: LanguageMenuPlace?
}

/// Where the board was: a section title or row, how far below the board's top
/// it was, and the "more below" hint's state.
private struct LanguageMenuPlace {
    let targetID: String?
    let offset: CGFloat
    let targetHeight: CGFloat
    let hintEligible: Bool
    let hintShowing: Bool
}

/// Where the menu's rows and its end are while it scrolls. A plain class, so
/// recording positions as the board moves does not redraw the menu.
private final class LanguageMenuScrollTracker {
    var viewport: CGRect = .zero
    var endMinY: CGFloat = 0
    var targetMinY: [String: CGFloat] = [:]
    var targetHeight: [String: CGFloat] = [:]
    var didApplyStoreScreenshotScroll = false
    /// Set when Home, Learn or a WriteScreen activity takes the child away:
    /// the menu that comes back is a new one, at the top.
    var leavesForNewMenu = false
    /// A place to return to, waiting for the board to be measured.
    var pendingPlace: LanguageMenuPlace?
}

/// Reports a view's frame in global coordinates when it appears and whenever
/// it moves, as scrolling does.
private struct LanguageMenuPositionProbe: View {
    let report: (CGRect) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { report(proxy.frame(in: .global)) }
                .onChange(of: proxy.frame(in: .global)) { _, rect in
                    report(rect)
                }
        }
    }
}

/// Android's ic_arrow_down_rounded_24 (a filled down chevron) on its 24-unit grid.
private struct LanguageMenuChevron: Shape {
    func path(in rect: CGRect) -> Path {
        let unitX = rect.width / 24
        let unitY = rect.height / 24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 7.41 * unitX, y: rect.minY + 8.59 * unitY))
        path.addLine(to: CGPoint(x: rect.minX + 12 * unitX, y: rect.minY + 13.17 * unitY))
        path.addLine(to: CGPoint(x: rect.minX + 16.59 * unitX, y: rect.minY + 8.59 * unitY))
        path.addLine(to: CGPoint(x: rect.minX + 18 * unitX, y: rect.minY + 10 * unitY))
        path.addLine(to: CGPoint(x: rect.minX + 12 * unitX, y: rect.minY + 16 * unitY))
        path.addLine(to: CGPoint(x: rect.minX + 6 * unitX, y: rect.minY + 10 * unitY))
        path.closeSubpath()
        return path
    }
}

/// ButtonsMenuFragment.setupScrollDownHint: the hint is offered the first three
/// times the menu opens.
struct LanguageMenuScrollHintRepository {
    static let maximumPresentationCount = 3

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "minik.languageMenu.scrollHintPresentationCount.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    @discardableResult
    func registerPresentationIfNeeded() -> Bool {
        let presentationCount = max(0, userDefaults.integer(forKey: storageKey))
        guard presentationCount < Self.maximumPresentationCount else {
            return false
        }

        userDefaults.set(presentationCount + 1, forKey: storageKey)
        return true
    }
}

/// Android's Plus menu text (values*/strings.xml) in every interface language,
/// with Android's line breaks. The String Catalog's activity titles keep serving
/// the other screens; these strings have no catalog entries.
enum LanguageMenuAndroidText {
    static func caption(_ activity: LanguageActivityKind, locale: InterfaceLocaleID) -> String? {
        captions(locale)[activity]
    }

    static func scrollHint(_ locale: InterfaceLocaleID) -> String {
        switch locale {
        case .english: return "There’s more below — scroll down"
        case .amharic: return "ከታች ተጨማሪ አለ — ወደ ታች ያሸብልሉ"
        case .arabic: return "هناك المزيد في الأسفل — مرّر إلى الأسفل"
        case .german: return "Unten gibt es noch mehr — scrolle nach unten"
        case .spanish: return "Hay más abajo — baja para ver más"
        case .french: return "Il y en a d'autres plus bas — fais défiler vers le bas"
        case .hebrew: return "יש עוד למטה — גללו מטה"
        case .dutch: return "Hieronder staat nog meer — scrol omlaag"
        case .portugueseBrazil: return "Tem mais lá embaixo — role para baixo"
        case .portuguesePortugal: return "Há mais em baixo — desce para ver mais"
        case .russian: return "Ниже есть ещё — прокрути вниз"
        }
    }

    static func scrollHintAccessibility(_ locale: InterfaceLocaleID) -> String {
        switch locale {
        case .english: return "There are more below. Tap to continue."
        case .amharic: return "ከታች ተጨማሪ አለ። ለመቀጠል ይንኩ።"
        case .arabic: return "هناك المزيد في الأسفل. اضغط للمتابعة."
        case .german: return "Unten gibt es noch mehr. Tippe, um weiterzumachen."
        case .spanish: return "Hay más abajo. Toca para continuar."
        case .french: return "Il y en a d'autres plus bas. Appuie pour continuer."
        case .hebrew: return "יש עוד למטה. הקישו כדי להמשיך."
        case .dutch: return "Hieronder staat nog meer. Tik om verder te gaan."
        case .portugueseBrazil: return "Tem mais lá embaixo. Toque para continuar."
        case .portuguesePortugal: return "Há mais em baixo. Toca para continuar."
        case .russian: return "Ниже есть ещё. Нажми, чтобы продолжить."
        }
    }

    static func selectScreenVoice(_ locale: InterfaceLocaleID) -> String {
        switch locale {
        case .english: return "Choose an activity to start"
        case .amharic: return "ለመጀመር እንቅስቃሴ ይምረጡ"
        case .arabic: return "اختر نشاطًا للبدء"
        case .german: return "Wählt eine Aktivität, um zu starten"
        case .spanish: return "Elige una actividad para empezar"
        case .french: return "Choisis une activité pour commencer"
        case .hebrew: return "בחרו תרגול כדי להתחיל"
        case .dutch: return "Kies een activiteit om te beginnen"
        case .portugueseBrazil: return "Escolha uma atividade para começar"
        case .portuguesePortugal: return "Escolhe uma atividade para começar"
        case .russian: return "Выбери занятие, чтобы начать"
        }
    }

    private static func captions(_ locale: InterfaceLocaleID) -> [LanguageActivityKind: String] {
        switch locale {
        case .english: return englishCaptions
        case .amharic: return amharicCaptions
        case .arabic: return arabicCaptions
        case .german: return germanCaptions
        case .spanish: return spanishCaptions
        case .french: return frenchCaptions
        case .hebrew: return hebrewCaptions
        case .dutch: return dutchCaptions
        case .portugueseBrazil: return portugueseBrazilCaptions
        case .portuguesePortugal: return portuguesePortugalCaptions
        case .russian: return russianCaptions
        }
    }

    private static let englishCaptions: [LanguageActivityKind: String] = [
        .learn: "Practice",
        .letterPairs: "Pairs",
        .firstLetterChoices: "First Letter\nChoices",
        .firstLetterPictures: "First Letter\nPictures",
        .imageToWord: "Answers\nwith Words",
        .wordToImage: "Answers\nwith Pictures",
        .wordBuild: "Build\nwith Letters",
        .mixed: "Mixed\npractice",
        .wordCards: "Flash\nCards",
        .soccer: "Letter\nSoccer",
        .tower: "Letter\nTower",
        .wordMemory: "Word\nMemory",
        .ticTacToe: "Tic\nTac Toe"
    ]

    private static let amharicCaptions: [LanguageActivityKind: String] = [
        .learn: "ልምምድ",
        .letterPairs: "ጥንዶች",
        .firstLetterChoices: "የመጀመሪያ ፊደል\nምርጫዎች",
        .firstLetterPictures: "የመጀመሪያ ፊደል\nምስሎች",
        .imageToWord: "መልሶች\nበቃል",
        .wordToImage: "መልሶች\nበምስል",
        .wordBuild: "ቃል\nበፊደላት ይገንቡ",
        .mixed: "የተቀላቀለ ልምምድ",
        .wordCards: "የመማሪያ ካርዶች",
        .soccer: "ፊደል\nእግር ኳስ",
        .tower: "የፊደል\nማማ",
        .wordMemory: "የቃል\nማስታወሻ",
        .ticTacToe: "ቲክ\nታክ ቶ"
    ]

    private static let arabicCaptions: [LanguageActivityKind: String] = [
        .learn: "تدرّب",
        .letterPairs: "الأزواج",
        .firstLetterChoices: "الحرف الأول\nخيارات",
        .firstLetterPictures: "الحرف الأول\nصور",
        .imageToWord: "إجابات\nبالكلمات",
        .wordToImage: "إجابات\nبالصور",
        .wordBuild: "بناء\nبالحروف",
        .mixed: "تدريب\nمتنوع",
        .wordCards: "بطاقات تعليمية",
        .soccer: "كرة قدم\nالحروف",
        .tower: "برج\nالحروف",
        .wordMemory: "ذاكرة\nالكلمات",
        .ticTacToe: "إكس\nدائرة"
    ]

    private static let germanCaptions: [LanguageActivityKind: String] = [
        .learn: "Üben",
        .letterPairs: "Paare",
        .firstLetterChoices: "Anfangsbuchstabe\nAuswahl",
        .firstLetterPictures: "Anfangsbuchstabe\nBilder",
        .imageToWord: "Antworten\nmit Wörtern",
        .wordToImage: "Antworten\nmit Bildern",
        .wordBuild: "Bauen\nmit Buchstaben",
        .mixed: "Gemischte Übungen",
        .wordCards: "Lernkarten",
        .soccer: "Buchstaben\nFußball",
        .tower: "Buchstaben\nTurm",
        .wordMemory: "Wort-\nMemory",
        .ticTacToe: "Drei\ngewinnt"
    ]

    private static let spanishCaptions: [LanguageActivityKind: String] = [
        .learn: "Practicar",
        .letterPairs: "Parejas",
        .firstLetterChoices: "Primera letra\nOpciones",
        .firstLetterPictures: "Primera letra\nImágenes",
        .imageToWord: "Respuestas\ncon palabras",
        .wordToImage: "Respuestas\ncon imágenes",
        .wordBuild: "Construir\ncon letras",
        .mixed: "Práctica\nmixta",
        .wordCards: "Tarjetas didácticas",
        .soccer: "Fútbol\nde letras",
        .tower: "Torre\nde letras",
        .wordMemory: "Memoria\nde palabras",
        .ticTacToe: "Tres\nen raya"
    ]

    private static let frenchCaptions: [LanguageActivityKind: String] = [
        .learn: "S'entraîner",
        .letterPairs: "Paires",
        .firstLetterChoices: "Première lettre\nChoix",
        .firstLetterPictures: "Première lettre\nImages",
        .imageToWord: "Réponses\navec mots",
        .wordToImage: "Réponses\navec images",
        .wordBuild: "Construire\navec lettres",
        .mixed: "Exercices mixtes",
        .wordCards: "Cartes mémo",
        .soccer: "Football\ndes lettres",
        .tower: "Tour\nde lettres",
        .wordMemory: "Mémoire\nde mots",
        .ticTacToe: "Morpion"
    ]

    private static let hebrewCaptions: [LanguageActivityKind: String] = [
        .learn: "חזרה",
        .letterPairs: "זוגות",
        .firstLetterChoices: "אות ראשונה\nאפשרויות",
        .firstLetterPictures: "אות ראשונה\nתמונות",
        .imageToWord: "תשובות\nבמילים",
        .wordToImage: "תשובות\nבתמונות",
        .wordBuild: "תשובות בהרכבת\nאותיות",
        .mixed: "תרגול משולב\nלפי רמה",
        .wordCards: "כרטיסיות",
        .soccer: "כדורגל\nאותיות",
        .tower: "מגדל\nאותיות",
        .wordMemory: "זיכרון\nמילים",
        .ticTacToe: "איקס\nעיגול"
    ]

    private static let dutchCaptions: [LanguageActivityKind: String] = [
        .learn: "Oefenen",
        .letterPairs: "Paren",
        .firstLetterChoices: "Eerste letter\nKeuzes",
        .firstLetterPictures: "Eerste letter\nAfbeeldingen",
        .imageToWord: "Antwoorden\nmet woorden",
        .wordToImage: "Antwoorden\nmet afbeeldingen",
        .wordBuild: "Bouwen\nmet letters",
        .mixed: "Gemengde oefening",
        .wordCards: "Oefenkaartjes",
        .soccer: "Letter\nvoetbal",
        .tower: "Letter\ntoren",
        .wordMemory: "Woorden\nMemory",
        .ticTacToe: "Boter\nkaas"
    ]

    private static let portugueseBrazilCaptions: [LanguageActivityKind: String] = [
        .learn: "Praticar",
        .letterPairs: "Pares",
        .firstLetterChoices: "Primeira letra\nOpções",
        .firstLetterPictures: "Primeira letra\nImagens",
        .imageToWord: "Respostas\ncom palavras",
        .wordToImage: "Respostas\ncom imagens",
        .wordBuild: "Montar\ncom letras",
        .mixed: "Prática\nmista",
        .wordCards: "Cartões de estudo",
        .soccer: "Futebol\nde letras",
        .tower: "Torre\nde letras",
        .wordMemory: "Memória\nde palavras",
        .ticTacToe: "Jogo\nda velha"
    ]

    private static let portuguesePortugalCaptions: [LanguageActivityKind: String] = [
        .learn: "Praticar",
        .letterPairs: "Pares",
        .firstLetterChoices: "Primeira letra\nOpções",
        .firstLetterPictures: "Primeira letra\nImagens",
        .imageToWord: "Respostas\ncom Palavras",
        .wordToImage: "Respostas\ncom Imagens",
        .wordBuild: "Construir\ncom letras",
        .mixed: "Prática\nmista",
        .wordCards: "Cartões de estudo",
        .soccer: "Futebol\nde letras",
        .tower: "Torre\nde letras",
        .wordMemory: "Memória\nde palavras",
        .ticTacToe: "Jogo\ndo galo"
    ]

    private static let russianCaptions: [LanguageActivityKind: String] = [
        .learn: "Тренировка",
        .letterPairs: "Пары",
        .firstLetterChoices: "Первая буква\nВарианты",
        .firstLetterPictures: "Первая буква\nКартинки",
        .imageToWord: "Ответы\nсловами",
        .wordToImage: "Ответы\nс картинками",
        .wordBuild: "Составление\nиз букв",
        .mixed: "Смешанные задания",
        .wordCards: "Карточки",
        .soccer: "Футбол\nс буквами",
        .tower: "Башня\nбукв",
        .wordMemory: "Слова\nна память",
        .ticTacToe: "Крестики\nнолики"
    ]
}

enum LanguagePalette {
    static let title = Color(red: 0.48, green: 0.25, blue: 0.72)
    static let teal = Color(red: 0.13, green: 0.72, blue: 0.75)
    /// Android's #203745: the menu's section titles, captions and hint.
    static let menuText = Color(red: 32 / 255, green: 55 / 255, blue: 69 / 255)
    /// Android's #FFF3C4 "more below" hint.
    static let scrollHintFill = Color(red: 1, green: 243 / 255, blue: 196 / 255)
    static let border = LinearGradient(
        colors: [Color(red: 0.52, green: 0.31, blue: 0.71),
                 Color(red: 0.94, green: 0.70, blue: 0.72),
                 Color(red: 0.24, green: 0.79, blue: 0.84)],
        startPoint: UnitPoint(x: 0, y: 0.5), endPoint: UnitPoint(x: 1, y: 0.5)
    )
}

/// The full Android minik_plus_logo artwork used by Intro and menu.
/// The former small pencil mascot is a different Android drawable.
struct MinikLanguageLogo: View {
    var body: some View {
        MinikArtworkImage(name: "minik_language_logo")
            .accessibilityHidden(true)
    }
}

/// Android's minik_plus_english_only, the "MINIK" wordmark English Only shows on
/// the Intro and the menu in place of minik_plus_logo (IntroScreen and
/// ButtonsMenuFragment). Until the shared catalog has the image, English Only
/// keeps the Plus wordmark.
enum LanguageEnglishOnlyLogoAsset {
    static let name = "minik_language_logo_english_only"
    /// logo_plus_english_margin_start, which replaces the Plus logo's margin.
    static let startMargin: CGFloat = -8
    static let isAvailable: Bool = UIImage(named: name) != nil

    static func isShown(for variant: ProductVariant) -> Bool {
        variant == .minikPlusEnglish && isAvailable
    }

    /// logo_plus_english_width x logo_plus_english_height, which the image fits
    /// centred: values-sw360dp-h640dp/h720dp/h800dp/h900dp-port on phones, by
    /// the height between the system bars, and values-sw700dp on tablets.
    static func box(screenHeight: CGFloat, tablet: Bool) -> CGSize {
        if tablet {
            return CGSize(width: 133, height: 90)
        }
        if screenHeight >= 900 {
            return CGSize(width: 103, height: 67)
        }
        if screenHeight >= 800 {
            return CGSize(width: 95, height: 61)
        }
        if screenHeight >= 720 {
            return CGSize(width: 87, height: 56)
        }
        return CGSize(width: 80, height: 48)
    }
}

struct LanguageEnglishOnlyLogo: View {
    var body: some View {
        MinikArtworkImage(name: LanguageEnglishOnlyLogoAsset.name)
            .accessibilityHidden(true)
    }
}

/// RecordsLeaderboardDialogFragment over the menu, which stays where it was
/// behind a 58% dim: 94% x 90% of the screen on phones (at most 560 x 760 dp)
/// and 92% x 88% on tablets (at most 1120 x 860 dp), the card 6 dp inside that
/// (10 dp on tablets) with 24 dp (30 dp) corners and a 1 dp #E8E5F1 stroke.
/// A tap outside closes it.
private struct LanguageRecordsDialog: View {
    let product: ProductVariant
    let onClose: () -> Void

    private static let stroke = Color(red: 232 / 255, green: 229 / 255, blue: 241 / 255)

    var body: some View {
        GeometryReader { geometry in
            let tablet = geometry.size.width >= 600
            let width = min(geometry.size.width * (tablet ? 0.92 : 0.94), tablet ? 1120 : 560)
            let height = min(geometry.size.height * (tablet ? 0.88 : 0.90), tablet ? 860 : 760)
            let corner: CGFloat = tablet ? 30 : 24
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)
                RecordsLeaderboardView(product: product, onClose: onClose)
                    .clipShape(RoundedRectangle(cornerRadius: corner))
                    .overlay {
                        RoundedRectangle(cornerRadius: corner)
                            .strokeBorder(Self.stroke, lineWidth: 1)
                    }
                    .padding(tablet ? 10 : 6)
                    .frame(width: width, height: height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }
}

struct LanguageStatistic: View {
    let title: LocalizedStringKey
    let value: Int64

    var body: some View {
        VStack(spacing: 5) {
            Text(title).font(.caption.weight(.semibold))
            Text(value, format: .number).font(.title3.bold().monospacedDigit())
        }
        // Two badges share one row beside the logo: larger text shrinks onto
        // one line instead of wrapping letter by letter.
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(LanguagePalette.title)
        .frame(maxWidth: .infinity, minHeight: 62)
        .padding(.horizontal, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(LanguagePalette.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct LanguageOutlineActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Color(red: 0.067, green: 0.067, blue: 0.067))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .background(.white, in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(LanguagePalette.border, lineWidth: 2)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
